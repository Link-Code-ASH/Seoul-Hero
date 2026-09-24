import type { Rarity } from '../data/items';
import { calculateStageReward } from '../meta/StageReward';
import { metaUpgrades } from '../data/meta';
import { characters } from '../data/characters';
import { weapons } from '../data/weapons';
import { items } from '../data/items';
import { enemies } from '../data/enemies';
import { images } from '../data/images';
import { maps } from '../data/maps';
import { eliteModifiers, type EliteModifierId } from '../data/eliteModifiers';
import { DEFAULT_STATS, type StatKey } from '../data/stats';
import { replaceModifiers } from '../stats/PlayerStats';
import { isTerminal } from '../state/RunPhase';
import { GAME_CONFIG } from '../data/config';
import { GameLoop } from './GameLoop';
import { Simulation } from './Simulation';
import { RunSettlement } from './RunSettlement';
import { KeyboardInput } from '../input/KeyboardInput';
import { InputManager } from '../input/InputManager';
import { TouchInput } from '../input/TouchInput';
import { WorldRenderer } from '../rendering/WorldRenderer';
import { SaveManager } from '../save/SaveManager';
import { AccountStorageAdapter, LocalStorageAdapter } from '../save/StorageAdapter';
import { SAVE_KEY } from '../save/SaveData';
import { parseSave } from '../save/migrations';
import { cloudClient } from '../cloud/CloudClient';
import { readCloudSave, type CloudSnapshot } from '../cloud/CloudSave';
import { CloudSync } from '../cloud/CloudSync';
import type { AccountChoice } from '../ui/AccountPanel';
import { getUpgradeCost, purchaseUpgrade } from '../meta/progression';
import { isCharacterUnlocked, isMapUnlocked, type MetaState } from '../state/MetaState';
import type { Screen } from '../ui/screens';
import { GameUI } from '../ui/GameUI';
import { archivePageSize, firstArchiveId, type ArchiveCategory } from '../ui/ArchiveScreen';
import { AudioManager } from '../audio/AudioManager';
import { musicForScene } from '../audio/AudioPolicy';
import { allAudioUrls, sfx } from '../data/audio';
import type { SfxId } from '../data/audio';
import { ensureWeeklyGate } from '../systems/WeeklyGateSystem';
import { BalanceTelemetryStore } from '../analytics/BalanceTelemetry';
import { availableStartingWeapons, createGateEntryDraft, gateEntrySteps, validateGateEntry, type GateEntryDraft, type GateEntryStep } from '../systems/GateEntrySystem';
import { upgradeGrowth, type GrowthKind } from '../meta/GrowthSystem';
import { accrueOfflineRewards, advanceOfflineForDebug, claimOfflineRewards } from '../meta/OfflineRewardSystem';
import { openSupplyBox, type MetaReward } from '../meta/SupplySystem';
import { dangunBlessings, weeklyGateRules } from '../data/weeklyGate';
import type { GrowthViewState } from '../ui/MetaScreens';

/** Owns browser-side wiring. Simulation remains independent of screens and storage. */
export class AppController {
  private save = new SaveManager(new LocalStorageAdapter());
  private meta: MetaState = this.save.load();
  private accountUserId = '';
  private accountEmail = '';
  private accountStatus = '이 기기에 저장 중';
  private accountChoice: AccountChoice | null = null;
  private remoteChoice: CloudSnapshot | null = null;
  private cloudSync: CloudSync | null = null;
  private lastCloudFingerprint = '';
  private authSubscription: { unsubscribe: () => void } | null = null;
  private connectingAccount = false;
  private deferredAuthChange = false;
  private rendererReady = false;
  private rendererLoading = false;
  private readonly audio = new AudioManager(this.meta.settings);
  private readonly renderer = new WorldRenderer();
  private readonly keyboard = new KeyboardInput();
  private readonly ui: GameUI;
  private readonly input: InputManager;
  private readonly loop: GameLoop;
  private simulation: Simulation | null = null;
  private screen: Screen = 'lobby';
  private archiveCategory: ArchiveCategory = 'characters';
  private archiveSelectionId = firstArchiveId('characters');
  private archivePage = 0;
  private gateDraft: GateEntryDraft = createGateEntryDraft(this.meta);
  private growthView:GrowthViewState={tab:'character',selectedId:Object.keys(characters)[0]??'',page:0};
  private supplyResults:MetaReward[]=[];
  private supplyFanfareTimer=0;
  private offlineClaimed=false;
  private offlineClaimTimer=0;
  private readonly settlement = new RunSettlement();
  private readonly balanceLogs = new BalanceTelemetryStore();
  private telemetrySavedRun: import('../state/RunState').RunState | null = null;
  private refreshElapsed = 0;
  private autosaveTimer = 0;
  private readonly walkTest = { x: 0, y: 0, remaining: 0 };
  private terminalRevealRun: import('../state/RunState').RunState | null = null;
  private terminalRevealElapsed = 0;
  private postWaveRevealRun: import('../state/RunState').RunState | null = null;
  private postWaveRevealElapsed = 0;

  constructor(private readonly worldHost: HTMLElement, uiHost: HTMLElement) {
    this.ui = new GameUI(uiHost, this.action, this.change);
    this.input = new InputManager([this.keyboard, new TouchInput(this.ui.joystick)]);
    this.loop = new GameLoop(this.update, this.render);
  }
  async start(): Promise<void> {
    const weeklyChanged=ensureWeeklyGate(this.meta);const offlineChanged=accrueOfflineRewards(this.meta,new Date());
    const metaChanged=weeklyChanged||offlineChanged;
    if (metaChanged) this.persist();
    this.gateDraft = createGateEntryDraft(this.meta);
    this.show('lobby');
    this.refreshAccount();
    // Audio downloads start with the first user gesture, not during lobby render.
    const { data: { subscription } } = cloudClient.auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_IN' || event === 'SIGNED_OUT') window.setTimeout(() => { void this.restoreAccount(); }, 0);
    });
    this.authSubscription = subscription;
    void this.restoreAccount();
    window.addEventListener('online', this.retryCloud);
    this.ui.dev.element.hidden = !this.meta.settings.developerMode;
    window.addEventListener('keydown', this.keydown);
    window.addEventListener('pointerdown', this.unlockAudio);
    window.addEventListener('blur', this.pause);
    document.addEventListener('visibilitychange', this.visibility);
    window.addEventListener('pagehide', this.markOfflineExit);
    this.autosaveTimer = window.setInterval(this.persist, 15000);
    if (!['자동 저장 완료', '저장된 진행을 불러왔습니다.'].includes(this.save.status)) this.ui.notify(this.save.status);
  }
  private async prepareRenderer(): Promise<void> {
    if (this.rendererReady || this.rendererLoading) return;
    this.rendererLoading = true;
    try {
      await this.renderer.init(this.worldHost);
      this.rendererReady = true;
      this.renderer.setHighResolution(this.meta.settings.highResolution);
      this.loop.start();
    } catch (error) {
      this.ui.notify(error instanceof Error ? `전투 화면 준비 실패: ${error.message}` : '전투 화면을 준비하지 못했습니다.');
    } finally { this.rendererLoading = false; }
  }
  private show(screen: Screen): void {
    if(screen.startsWith('gate')&&ensureWeeklyGate(this.meta))this.persist();
    this.gateDraft.gateDepth = Math.max(1, Math.min(this.meta.gateProgression.highestUnlockedDepth, this.gateDraft.gateDepth));
    this.walkTest.remaining = 0;
    this.screen = screen;
    this.loop.paused = screen !== 'waveActive';
    this.keyboard.enabled = screen === 'waveActive';
    this.input.clear();
    this.ui.show(screen, this.meta, this.simulation?.state ?? null, { category:this.archiveCategory,selectedId:this.archiveSelectionId,page:this.archivePage }, this.gateDraft,this.growthView,this.supplyResults,this.offlineClaimed);
    this.ui.dev.element.hidden = !this.meta.settings.developerMode;
    this.audio.setScene(musicForScene(screen, this.simulation?.state ?? null), screen === 'paused' || screen === 'postWave');
    if (screen === 'lobby' && this.deferredAuthChange) {
      this.deferredAuthChange = false;
      window.setTimeout(() => { void this.restoreAccount(); }, 0);
    }
  }
  private update = (dt: number): boolean => {
    if (!this.simulation || this.screen !== 'waveActive') return false;
    const direction = this.input.read();
    if (direction.x !== 0 || direction.y !== 0) this.walkTest.remaining = 0;
    const testingWalk = this.walkTest.remaining > 0;
    this.walkTest.remaining = Math.max(0, this.walkTest.remaining - dt);
    this.simulation.update(dt, testingWalk ? this.walkTest : direction, this.renderer.viewport);
    this.syncPhase();
    return this.screen === 'waveActive';
  };
  private render = (dt: number): void => {
    const run = this.simulation?.state ?? null;
    this.simulation?.telemetry.sample(this.loop.fps);
    if (run && this.simulation && (run.phase === 'postWave' || isTerminal(run.phase))) {
      const walletScreenTarget = this.ui.hud.getWalletScreenTarget();
      const walletWorldTarget = walletScreenTarget
        ? this.renderer.clientToWorld(walletScreenTarget)
        : this.renderer.getWalletWorldTarget();
      this.simulation.sweepPickupsToWallet(dt, walletWorldTarget);
      this.syncPhase(dt);
    }
    this.audio.setScene(musicForScene(this.screen, run), this.screen === 'paused' || this.screen === 'postWave');
    this.simulation?.events.drain(this.audio.play);
    this.renderer.render(run, dt);
    this.refreshElapsed += dt;
    if (this.refreshElapsed < GAME_CONFIG.ui.refreshInterval) return;
    this.refreshElapsed = 0;
    this.ui.updateAudio(this.audio.unlocked, this.meta.settings.muted, this.audio.status);
    if (run) this.ui.hud.update(run);
    this.ui.dev.update(run, { fps: this.loop.fps, frameTime: this.loop.frameTime, timeScale: this.loop.timeScale, saveStatus: this.save.status, audio: `${this.audio.contextState} · ${this.audio.loadedCount}/${allAudioUrls().length}\nBGM ${this.audio.currentBgm}\nSFX ${this.audio.lastSound} · 재생 ${this.audio.playedCount}\n음성 ${this.audio.activeVoices}/16 · 출력 ${this.audio.outputLevel.toFixed(4)}\n이미지 ${this.renderer.art.loadedCount}/${Object.keys(images).length} · 이동 procedural\n자세 ${this.renderer.playerMotion.moving ? 'move' : 'idle'} · 강도 ${this.renderer.playerMotion.intensity.toFixed(2)} · ${this.renderer.playerMotion.facing < 0 ? 'left' : 'right'}` });
  };
  private syncPhase(dt = 0): void {
    const phase = this.simulation?.state.phase;
    if (phase === 'gameOver' || phase === 'stageClear') {
      const run = this.simulation!.state;
      if (this.terminalRevealRun !== run) {
        this.terminalRevealRun = run;
        this.terminalRevealElapsed = 0;
        if (this.screen !== 'waveActive') this.show('waveActive');
        this.keyboard.enabled = false;
        this.ui.hud.playWalletSweep(run.pickups.map(pickup => this.renderer.worldToClient(pickup)));
      }
      if (run.pickups.length > 0) { this.terminalRevealElapsed = 0; return; }
      this.terminalRevealElapsed += dt;
      if (this.terminalRevealElapsed < 0.65) return;
      if (this.simulation && this.settlement.settle(this.meta, this.simulation.state)) {
        this.gateDraft.gateDepth = this.meta.gateProgression.highestUnlockedDepth;
        this.persist();
      }
      if (this.simulation && this.telemetrySavedRun !== run) {
        this.balanceLogs.append(this.simulation.telemetry.finish());
        this.telemetrySavedRun = run;
      }
      if (this.screen !== 'result') this.show('result');
    } else if (phase === 'postWave' && this.screen !== 'postWave') {
      const run = this.simulation!.state;
      if (this.postWaveRevealRun !== run || this.postWaveRevealElapsed < 0) {
        this.postWaveRevealRun = run;
        this.postWaveRevealElapsed = 0;
        const origins = run.pickups.map(pickup => this.renderer.worldToClient(pickup));
        this.keyboard.enabled = false;
        this.input.clear();
        this.ui.hud.showWaveEndNotice(run.currentWave);
        this.ui.hud.playWalletSweep(origins);
      }
      this.terminalRevealRun = null;
      this.postWaveRevealElapsed += dt;
      if (this.postWaveRevealElapsed >= 1.05) {
        this.show('postWave');
        this.postWaveRevealElapsed = -1;
      }
    }
    else if (phase === 'shop' && this.screen !== 'shop') this.show('shop');
    else if (phase === 'paused' && this.screen !== 'paused') this.show('paused');
    else if (phase === 'waveActive' && this.screen !== 'waveActive') {
      this.postWaveRevealRun = null;
      this.postWaveRevealElapsed = 0;
      this.show('waveActive');
    }
  }
  private readonly linkedKey = (id: string): string => `seoul-gate.linked.${id}`;
  private readonly dirtyKey = (id: string): string => `seoul-gate.pending.${id}`;
  private refreshAccount(): void {
    this.ui.updateAccount({ email: this.accountEmail, status: this.accountStatus, choice: this.accountChoice });
  }
  private retryCloud = (): void => {
    if (this.cloudSync) this.cloudSync.retry();
    else void this.restoreAccount();
  };
  private async restoreAccount(): Promise<void> {
    if (this.connectingAccount) return;
    this.connectingAccount = true;
    try {
      const { data, error } = await cloudClient.auth.getUser();
      if (error && !data.user && error.name !== 'AuthSessionMissingError') throw error;
        const user = data.user;
        if (!user) {
          if (this.accountUserId) {
            if (this.simulation && !isTerminal(this.simulation.state.phase)) {
              this.deferredAuthChange = true;
              this.accountStatus = '전투 종료 후 계정 변경'; this.refreshAccount();
            } else this.leaveAccount();
          }
          return;
        }
        if (user.id === this.accountUserId) return;
        if (this.simulation && !isTerminal(this.simulation.state.phase)) {
          this.deferredAuthChange = true;
          this.accountStatus = '전투 종료 후 계정 변경'; this.refreshAccount();
          return;
        }
        const remote = await readCloudSave(user.id);
        const accountAdapter = new AccountStorageAdapter(user.id);
        const accountRaw = accountAdapter.getItem(SAVE_KEY);
        const dirty = localStorage.getItem(this.dirtyKey(user.id)) === '1';
        const linked = localStorage.getItem(this.linkedKey(user.id)) === '1';
        const guestRaw = new LocalStorageAdapter().getItem(SAVE_KEY);
        const valid = (raw: string | null): string | null => {
          if (!raw) return null;
          try { parseSave(raw); return raw; } catch { return null; }
        };
        const validAccountRaw = valid(accountRaw);
        const validGuestRaw = valid(guestRaw);
        this.accountUserId = user.id;
        this.accountEmail = user.email ?? 'Google 계정';
        if (dirty && validAccountRaw && remote) {
          const localMeta = parseSave(validAccountRaw).meta;
          const remoteMeta = parseSave(remote.raw).meta;
          if (this.cloudFingerprint(localMeta) === this.cloudFingerprint(remoteMeta)) {
            localStorage.removeItem(this.dirtyKey(user.id));
            this.activateAccount(remote.raw, remote.revision, false);
          } else this.showAccountChoice(validAccountRaw, remote, 'conflict');
        } else if (!linked && remote && validGuestRaw) {
          this.showAccountChoice(validGuestRaw, remote, 'first');
        } else {
          const raw = remote?.raw ?? validAccountRaw ?? validGuestRaw ?? this.save.export(this.meta);
        this.activateAccount(raw, remote?.revision ?? null, !remote);
      }
    } catch (error) {
      this.accountStatus = '클라우드 연결 실패 · 게스트 기록 유지';
      this.ui.notify(error instanceof Error ? error.message : '계정 연결에 실패했습니다.');
      this.refreshAccount();
    } finally { this.connectingAccount = false; }
  }
  private showAccountChoice(localRaw: string, remote: CloudSnapshot | null, reason: 'first' | 'conflict'): void {
    try {
      this.accountChoice = { local: parseSave(localRaw), remote: remote ? parseSave(remote.raw) : null, reason };
      this.remoteChoice = remote;
      this.accountStatus = '저장 기록 선택 대기';
      this.refreshAccount();
      if (this.screen !== 'lobby') this.show('lobby');
    } catch {
      this.accountStatus = '저장 기록 확인 실패 · JSON 백업을 보관하세요';
      this.refreshAccount();
    }
  }
  private activateAccount(raw: string, revision: number | null, upload: boolean): void {
    const id = this.accountUserId;
    if (!id) return;
    const adapter = new AccountStorageAdapter(id);
    const previous = adapter.getItem(SAVE_KEY);
    if (previous && previous !== raw) adapter.setItem('seoul-gate.save.unselected', previous);
    const nextSave = new SaveManager(adapter);
    let nextMeta: MetaState;
    try { nextMeta = nextSave.import(raw); }
    catch (error) {
      this.accountUserId = '';
      this.accountEmail = '';
      this.accountStatus = '계정 기록 저장 실패 · 게스트 기록 유지';
      this.ui.notify(error instanceof Error ? error.message : '계정 기록을 저장하지 못했습니다.');
      this.refreshAccount();
      return;
    }
    this.save = nextSave;
    this.meta = nextMeta;
    this.lastCloudFingerprint = this.cloudFingerprint(nextMeta);
    this.cloudSync?.stop();
    this.cloudSync = new CloudSync(id, revision,
      status => {
        if (status === '동기화 완료') localStorage.removeItem(this.dirtyKey(id));
        this.accountStatus = status;
        this.refreshAccount();
      },
      remote => this.showAccountChoice(this.save.export(this.meta), remote, 'conflict'));
    this.accountChoice = null;
    this.remoteChoice = null;
    localStorage.setItem(this.linkedKey(id), '1');
    if (!upload) localStorage.removeItem(this.dirtyKey(id));
    this.accountStatus = upload ? '클라우드에 저장 중' : '클라우드 기록 사용 중';
    this.audio.applySettings(this.meta.settings);
    this.renderer.setHighResolution(this.meta.settings.highResolution);
    this.gateDraft = createGateEntryDraft(this.meta);
    this.simulation = null;
    this.show('lobby');
    this.refreshAccount();
    if (upload) {
      localStorage.setItem(this.dirtyKey(id), '1');
      this.cloudSync.queue(this.save.export(this.meta));
    }
  }
  private leaveAccount(): void {
    this.cloudSync?.stop();
    this.cloudSync = null;
    this.lastCloudFingerprint = '';
    this.accountUserId = '';
    this.accountEmail = '';
    this.accountChoice = null;
    this.remoteChoice = null;
    this.save = new SaveManager(new LocalStorageAdapter());
    this.meta = this.save.load();
    this.accountStatus = '이 기기에 저장 중';
    this.audio.applySettings(this.meta.settings);
    this.gateDraft = createGateEntryDraft(this.meta);
    this.simulation = null;
    this.show('lobby');
    this.refreshAccount();
  }
  private chooseAccount(useCloud: boolean): void {
    const choice = this.accountChoice;
    if (!choice || !this.accountUserId) return;
    const remote = this.remoteChoice;
    const selected = useCloud ? remote?.raw : JSON.stringify(choice.local);
    const unselected = useCloud ? JSON.stringify(choice.local) : remote?.raw;
    if (!selected) return;
    if (unselected) {
      new AccountStorageAdapter(this.accountUserId).setItem('seoul-gate.save.unselected', unselected);
      this.downloadRawSave(unselected, 'seoul-gate-before-sync');
    }
    this.activateAccount(selected, remote?.revision ?? null, !useCloud);
  }
  private downloadRawSave(raw: string, name: string): void {
    const url = URL.createObjectURL(new Blob([raw], { type: 'application/json' }));
    const link = document.createElement('a');
    link.href = url; link.download = `${name}-${new Date().toISOString().slice(0, 10)}.json`;
    link.click(); window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  private cloudFingerprint(meta: MetaState): string {
    return JSON.stringify({ ...meta, offlineReward: { ...meta.offlineReward, lastExitAt: '' } });
  }
  private persist = (forceCloud = false): void => {
    if(!document.hidden)this.meta.offlineReward.lastExitAt=new Date().toISOString();
    if (!this.save.save(this.meta)) this.ui.notify(this.save.status);
    else if (this.cloudSync && this.accountUserId) {
      const fingerprint = this.cloudFingerprint(this.meta);
      if (forceCloud || fingerprint !== this.lastCloudFingerprint) {
        this.lastCloudFingerprint = fingerprint;
        localStorage.setItem(this.dirtyKey(this.accountUserId), '1');
        this.cloudSync.queue(this.save.export(this.meta));
      }
    }
  };
  private markOfflineExit=():void=>{this.meta.offlineReward.lastExitAt=new Date().toISOString();this.persist();};
  private pause = (): void => {
    if (this.screen === 'waveActive') { this.simulation?.pause(); this.syncPhase(); }
    this.input.clear();
  };
  private visibility = (): void => {
    this.audio.setHidden(document.hidden);
    this.loop.resetClock();
    if (document.hidden) { this.pause(); this.markOfflineExit(); }
    else if(accrueOfflineRewards(this.meta,new Date())){this.persist();if(this.screen==='offline'||this.screen==='lobby')this.show(this.screen);}
  };
  private keydown = (event: KeyboardEvent): void => {
    if (!event.repeat) this.unlockAudio(event);
    if (event.code === 'F3') {
      event.preventDefault();
      if (event.repeat) return;
      this.meta.settings.developerMode = !this.meta.settings.developerMode;
      this.ui.dev.element.hidden = !this.meta.settings.developerMode;
      this.persist();
      if (this.screen === 'settings') this.show('settings');
      return;
    }
    if (event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement || event.repeat) return;
    if (event.code === 'Escape' || event.code === 'KeyP') {
      if(event.code==='Escape'&&this.screen==='supply'&&this.supplyResults.length){this.supplyResults=[];this.show('supply');return;}
      if (this.screen === 'waveActive') this.pause();
      else if (this.screen === 'paused') this.action('resume');
    }
  };
  private action = (action: string): void => {
    if (!this.audio.play('buttonClick')) void this.audio.unlock().then(() => { this.audio.play('buttonClick'); });
    const [command = '', id = ''] = action.split(':');
    if (command === 'account-signin') { void this.signIn(); return; }
    if (command === 'account-signout') { void this.signOut(); return; }
    if (command === 'account-use-cloud') { this.chooseAccount(true); return; }
    if (command === 'account-upload-local') { this.chooseAccount(false); return; }
    if (command === 'sound') {
      if (this.audio.unlocked) this.meta.settings.muted = !this.meta.settings.muted;
      else this.meta.settings.muted = false;
      this.audio.applySettings(this.meta.settings); this.persist();
      if (this.screen === 'settings') this.show('settings');
      return;
    }
    if (command === 'sound-test') { this.testSound(id); return; }
    if (command === 'dev') { this.developerAction(id); return; }
    if (command === 'gate-deploy') {
      if (!this.rendererReady) { this.ui.notify('전투 이미지를 준비 중입니다. 잠시 후 다시 출동하세요.'); return; }
      const problem=validateGateEntry(this.meta,this.gateDraft); if(problem){this.ui.notify(problem);return;}
      this.simulation = new Simulation(this.gateDraft.characterId, this.gateDraft.mapId, this.meta, Math.random, { gateDepth: this.gateDraft.gateDepth,
        weeklyTraitId: this.meta.weeklyGate.ruleId, blessingId: this.gateDraft.blessingId, startingWeaponId: this.gateDraft.startingWeaponId });
      this.telemetrySavedRun = null;
      this.loop.timeScale = 1; this.loop.resetClock();
      const speed = this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-speed');
      if (speed) speed.value = '1';
      this.show('waveActive');
    } else if(command==='gate-map') {if(maps[id]&&isMapUnlocked(this.meta,id)){this.gateDraft.mapId=id;this.show('gateMap');}
    } else if (command === 'gate-depth-select') {
      const depth=Number(id); if(!Number.isInteger(depth)||depth<1||depth>this.meta.gateProgression.highestUnlockedDepth)return;
      this.gateDraft.gateDepth=depth; this.show('gateDepth');
    } else if(command==='gate-depth-page'){
      const page=Number(id);if(Number.isInteger(page)&&page>=0){this.gateDraft.depthPage=page;this.show('gateDepth');}
    } else if(command==='gate-character') {if(!characters[id]||!isCharacterUnlocked(this.meta,id))return;this.gateDraft.characterId=id;if(!availableStartingWeapons(this.meta,id).some(w=>w.id===this.gateDraft.startingWeaponId))this.gateDraft.startingWeaponId='';this.show('gateCharacter');
    } else if(command==='gate-weapon') {if(!availableStartingWeapons(this.meta,this.gateDraft.characterId).some(w=>w.id===id))return;this.gateDraft.startingWeaponId=id;this.show('gateWeapon');
    } else if(command==='gate-blessing') {if(!this.meta.blessings[id]?.unlocked||this.meta.blessings[id]!.level<1)return;this.gateDraft.blessingId=id;this.show('gateBlessing');
    } else if(command==='gate-step'&&gateEntrySteps.includes(id as GateEntryStep)) {
      const target=id as GateEntryStep;
      const hasBlessing=Object.keys(dangunBlessings).some(key=>this.meta.blessings[key]?.unlocked&&this.meta.blessings[key]!.level>0);
      this.show(target==='gateBlessing'&&!hasBlessing?(this.screen==='gateConfirm'?'gateWeapon':'gateConfirm'):target);
    } else if (command === 'archive-category' && (id === 'characters' || id === 'weapons' || id === 'enemies' || id === 'weeklyTraits' || id === 'blessings')) {
      this.archiveCategory = id;
      this.archiveSelectionId = firstArchiveId(id);
      this.archivePage=0;
      this.show('archive');
    } else if(command==='archive-page'){
      const page=Number(id);if(Number.isInteger(page)&&page>=0){this.archivePage=page;const ids=this.archiveCategory==='characters'?Object.keys(characters):this.archiveCategory==='weapons'?Object.keys(weapons):this.archiveCategory==='enemies'?Object.keys(enemies):this.archiveCategory==='weeklyTraits'?Object.keys(weeklyGateRules):Object.keys(dangunBlessings);this.archiveSelectionId=ids[page*archivePageSize()]??this.archiveSelectionId;this.show('archive');}
    } else if (command === 'archive-entry') {
      const [category, entryId] = id.split(',');
      if (category !== 'characters' && category !== 'weapons' && category !== 'enemies' && category !== 'weeklyTraits' && category !== 'blessings') return;
      this.archiveCategory = category;
      this.archiveSelectionId = entryId ?? firstArchiveId(category);
      this.show('archive');
    } else if(command==='growth-tab'&&(id==='character'||id==='weapon'||id==='blessing')){this.growthView={tab:id,selectedId:id==='character'?Object.keys(characters)[0]??'':id==='weapon'?Object.keys(weapons)[0]??'':Object.keys(dangunBlessings)[0]??'',page:0};this.show('growth');
    } else if(command==='growth-page'){const page=Number(id);if(Number.isInteger(page)&&page>=0){const ids=this.growthView.tab==='character'?Object.keys(characters):this.growthView.tab==='weapon'?Object.keys(weapons):Object.keys(dangunBlessings);this.growthView={...this.growthView,page,selectedId:ids[page*6]??this.growthView.selectedId};this.show('growth');}
    } else if(command==='growth-select') {const [kind,contentId]=id.split(',');if((kind==='character'&&characters[contentId??''])||(kind==='weapon'&&weapons[contentId??''])||(kind==='blessing'&&dangunBlessings[contentId??''])){this.growthView={...this.growthView,tab:kind as GrowthKind,selectedId:contentId??''};this.show('growth');}
    } else if(command==='growth-upgrade'){const [kind,contentId]=id.split(',');if((kind==='character'||kind==='weapon'||kind==='blessing')&&upgradeGrowth(this.meta,kind,contentId??'')){this.persist();this.show('growth');this.ui.notify('성장 단계가 올랐습니다.');}
    } else if(command==='offline-claim'){if(claimOfflineRewards(this.meta)){this.offlineClaimed=true;window.clearTimeout(this.offlineClaimTimer);this.persist();this.show('offline');this.offlineClaimTimer=window.setTimeout(()=>{this.offlineClaimed=false;if(this.screen==='offline')this.show('offline');},1250);this.ui.notify('도착 물자를 수령했습니다.');}
    } else if(command==='supply-open'){const count=Number(id)===10?10:1;const results=openSupplyBox(this.meta,count);if(results){this.supplyResults=results;window.clearTimeout(this.supplyFanfareTimer);this.audio.play('supplyLatch');this.supplyFanfareTimer=window.setTimeout(()=>this.audio.play('supplyFanfare'),1050);this.persist();this.show('supply');}}
    else if(command==='supply-dismiss'){this.supplyResults=[];this.show('supply');
    } else if (['lobby','gateMap','growth','association','offline','supply','archive','settings'].includes(command)) {
      if (this.simulation && !isTerminal(this.simulation.state.phase)) { this.pause(); return; }
      this.simulation = null;
        if(command==='gateMap'){this.gateDraft=createGateEntryDraft(this.meta);void this.prepareRenderer();}
      if(command==='supply')this.supplyResults=[];this.show(command as Screen);
    } else if (command === 'pause') this.pause();
    else if (command === 'resume') { this.simulation?.resume(); this.syncPhase(); }
    else if (command === 'shop-buy') { this.simulation?.buyShopItem(Number(id)); this.show('shop'); }
    else if (command === 'shop-lock') { this.simulation?.lockShopItem(Number(id)); this.show('shop'); }
    else if (command === 'shop-reroll') { this.simulation?.rerollShopItems(); this.show('shop'); }
    else if (command === 'shop-weapon-buy') { this.simulation?.buyShopWeapon(Number(id)); this.show('shop'); }
    else if (command === 'shop-weapon-lock') { this.simulation?.lockShopWeapon(Number(id)); this.show('shop'); }
    else if (command === 'shop-weapon-reroll') { this.simulation?.rerollShopWeapons(); this.show('shop'); }
    else if (command === 'next-wave') { this.simulation?.nextWave(); this.syncPhase(); }
    else if (command === 'post-continue') { this.simulation?.continuePostWave(); this.syncPhase(); }
    else if (command === 'branch') { if (this.simulation?.chooseBranch(id)) this.show('shop'); }
    else if (command === 'end-run' && this.simulation && this.screen === 'paused') {
      this.simulation.endRun();
      this.syncPhase();
    } else if (command === 'buy') {
      if (purchaseUpgrade(this.meta, id)) { this.persist(); this.show('association'); this.ui.notify('협회 구매 완료 · 다음 출동부터 적용됩니다.'); }
    } else if (command === 'export') this.exportSave();
    else if (command === 'reset') {
      if (!window.confirm('협회 코인, 코인샵 구매 내역, 해금과 통계를 모두 초기화할까요? 필요한 경우 먼저 JSON 백업을 내보내세요.')) return;
        this.meta = this.save.reset();
        if (this.cloudSync && this.accountUserId) {
          this.lastCloudFingerprint = this.cloudFingerprint(this.meta);
          localStorage.setItem(this.dirtyKey(this.accountUserId), '1');
        this.cloudSync.queue(this.save.export(this.meta));
      }
      ensureWeeklyGate(this.meta); this.gateDraft = createGateEntryDraft(this.meta);
      this.audio.applySettings(this.meta.settings);
      this.renderer.setHighResolution(this.meta.settings.highResolution);
      this.show('settings'); this.ui.notify(this.save.status);
    }
  };
  private async signIn(): Promise<void> {
    if (this.simulation && !isTerminal(this.simulation.state.phase)) return;
    const redirectTo = new URL(import.meta.env.BASE_URL, window.location.origin).href;
    const { error } = await cloudClient.auth.signInWithOAuth({ provider: 'google', options: { redirectTo } });
    if (error) this.ui.notify(`Google 로그인 실패: ${error.message}`);
  }
  private async signOut(): Promise<void> {
    if (this.simulation && !isTerminal(this.simulation.state.phase)) return;
    const { error } = await cloudClient.auth.signOut();
    if (error) this.ui.notify(`로그아웃 실패: ${error.message}`);
    else this.leaveAccount();
  }
  private developerAction(command: string): void {
    if (!this.meta.settings.developerMode) return;
    if(command==='balance-export'){this.exportBalanceLogs();return;}
    if(command==='balance-clear'){this.balanceLogs.clear();this.ui.notify('밸런스 분석 기록을 초기화했습니다.');return;}
    if(command==='offline-1h'||command==='offline-12h'||command==='offline-generate'){
      advanceOfflineForDebug(this.meta,command==='offline-1h'?1:12,command==='offline-generate');
      this.persist();this.show('offline');this.ui.notify(command==='offline-generate'?'미수령 보상을 생성했습니다.':'오프라인 시간을 진행했습니다.');return;
    }
    if(command==='supply-tickets'){
      this.meta.wallet.supplyTickets+=10;this.persist();
      if(this.screen==='supply')this.show('supply');
      this.ui.notify('보급권 10장을 추가했습니다.');return;
    }
    if (command === 'sound') { this.testSound(this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-sound')?.value ?? ''); return; }
    if (command === 'currency') {
      if (this.simulation && !isTerminal(this.simulation.state.phase)) this.simulation.state.runCurrency += 500;
      else { this.meta.wallet.associationCoins += 500; this.persist(); }
      if (this.screen === 'association') this.show('association');
      if (this.screen === 'shop' && this.simulation) this.show('shop');
      this.ui.notify('마력석 500을 추가했습니다.'); return;
    }
    if(command==='meta-upgrade') {const id=this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-meta-upgrade')?.value??'';const def=metaUpgrades[id];if(def){this.meta.wallet.associationCoins+=getUpgradeCost(this.meta,id)===Infinity?0:getUpgradeCost(this.meta,id);purchaseUpgrade(this.meta,id);this.persist();}return;}
    if(command==='unlock') {const target=this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-unlock-target')?.value,id=this.ui.dev.element.querySelector<HTMLInputElement>('#dev-unlock-id')?.value??'';let changed=false;if(target==='character'&&characters[id]){this.meta.characters[id]={...(this.meta.characters[id]??{fragments:0,breakthrough:0}),unlocked:true};changed=true;}else if(target==='weapon'&&weapons[id]){this.meta.sharedWeapons[id]={...(this.meta.sharedWeapons[id]??{fragments:0,level:0}),unlocked:true};changed=true;}else if(target==='item'&&items[id]&&!this.meta.account.unlockedItemIds.includes(id)){this.meta.account.unlockedItemIds.push(id);changed=true;}if(changed){this.persist();this.ui.notify('해금 완료 · 다음 Run부터 적용');}return;}
    if(command==='reward-preview'&&this.simulation){this.ui.notify('현재 성과 보상: '+calculateStageReward(this.simulation.state).total+' 마력석 (재지급 없음)');return;}
    const simulation = this.simulation;
    if (!simulation || isTerminal(simulation.state.phase)) { this.ui.notify('전투를 시작한 후 사용할 수 있습니다.'); return; }
    if (command === 'walk-left' || command === 'walk-right') {
      if (this.screen !== 'waveActive') { this.ui.notify('전투를 재개한 뒤 걷기를 확인하세요.'); return; }
      this.walkTest.x = command === 'walk-left' ? -1 : 1; this.walkTest.remaining = 2;
      return;
    }
    switch (command) {
      case 'stat-reset': replaceModifiers(simulation.state, 'run', []); break;
      case 'stat-apply': {
        const stat = this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-stat')?.value ?? '';
        const value = Number(this.ui.dev.element.querySelector<HTMLInputElement>('#dev-stat-value')?.value);
        if (!Object.hasOwn(DEFAULT_STATS, stat) || !Number.isFinite(value)) break;
        const id = 'dev-' + stat;
        replaceModifiers(simulation.state, 'run', [...simulation.state.statModifiers.filter(m => m.source === 'run' && m.id !== id),
          { id, stat: stat as StatKey, operation: 'add', value }]);
        break;
      }
      case 'wave-end': simulation.completeWave(); break;
      case 'wave-next': simulation.goToWave(simulation.state.currentWave + 1); break;
      case 'wave-go': simulation.goToWave(Number(this.ui.dev.element.querySelector<HTMLInputElement>('#dev-wave')?.value)); break;
      case 'invincible': simulation.state.invincible = !simulation.state.invincible; break;
      case 'weapon-get': case 'weapon-up': simulation.debugWeapon(this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-weapon')?.value ?? '', command === 'weapon-up'); break;
      case 'branch-test': simulation.debugBranch(this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-weapon')?.value ?? ''); break;
      case 'max-a': case 'max-b': simulation.debugMaxWeapons(command === 'max-a' ? 'A' : 'B'); break;
      case 'structure-place': simulation.debugStructures(); break;
      case 'structure-clear': simulation.debugStructures(true); break;
      case 'structure-limit': { const value=Number(this.ui.dev.element.querySelector<HTMLInputElement>('#dev-structure-limit')?.value); if(Number.isFinite(value)) simulation.state.structureEffects=[...simulation.state.structureEffects.filter(e=>e.sourceId!=='dev'),{sourceId:'dev',tag:'STRUCTURE',type:'maxCount',value:Math.max(0,Math.min(20,value))}]; break; }
      case 'weapon-reset': simulation.resetWeapons(); break;
      case 'luck': {
        const luck = Number(this.ui.dev.element.querySelector<HTMLInputElement>('#dev-luck')?.value);
        if (Number.isFinite(luck) && luck >= 0) replaceModifiers(simulation.state, 'run', [...simulation.state.statModifiers.filter(m => m.source === 'run' && m.id !== 'dev-luck'), { id: 'dev-luck', stat: 'luck', operation: 'add', value: luck }]);
        break;
      }
      case 'force-clear': simulation.spawnBoss(); simulation.clearEnemies(); break;
      case 'force-over': simulation.endRun(); break;
      case 'shop-open': simulation.debugShop(); break;
      case 'item-add': simulation.debugItem(this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-item')?.value??''); break;
      case 'item-clear': simulation.debugClearItems(); break;
      case 'shop-rarity': simulation.debugRarity((this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-rarity')?.value??'COMMON') as Rarity); break;
      case 'stress': for(let i=0;i<500;i++) simulation.spawnEnemy('crawler'); break;
      case 'run-money': simulation.state.runCurrency += 500; break;
      case 'heal': simulation.heal(); break;
      case 'clear': simulation.clearEnemies(); break;
      case 'boss': simulation.spawnBoss(); break;
      case 'spawn': {
        const modifier = this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-elite')?.value ?? '';
        simulation.spawnEnemy(this.ui.dev.element.querySelector<HTMLSelectElement>('#dev-enemy')?.value ?? 'crawler', Object.hasOwn(eliteModifiers, modifier) ? [modifier as EliteModifierId] : []);
        break;
      }
      case 'time': {
        const value = Number(this.ui.dev.element.querySelector<HTMLInputElement>('#dev-time')?.value);
        if (Number.isFinite(value)) simulation.setTime(Math.max(0, Math.min(86400, value)));
        break;
      }
    }
    this.syncPhase();
    if(simulation.state.phase === 'shop') this.show('shop');
  }
  private change = (target: HTMLInputElement | HTMLSelectElement): void => {
    const setting = target.dataset.setting;
    if (setting === 'masterVolume' || setting === 'soundVolume' || setting === 'musicVolume' || setting === 'combatVolume' || setting === 'uiVolume') this.meta.settings[setting] = Math.max(0, Math.min(1, Number(target.value)));
    else if ((setting === 'highResolution' || setting === 'developerMode' || setting === 'muted') && target instanceof HTMLInputElement) {
      this.meta.settings[setting] = target.checked;
      this.renderer.setHighResolution(this.meta.settings.highResolution);
      this.ui.dev.element.hidden = !this.meta.settings.developerMode;
    } else if (target.id === 'dev-speed') {
      const value = Number(target.value);
      if (this.meta.settings.developerMode && [0.5, 1, 2, 5, 10].includes(value)) this.loop.timeScale = value;
      return;
    } else if (target.id === 'save-file' && target instanceof HTMLInputElement) { void this.importSave(target); return; }
    if (setting) { this.audio.applySettings(this.meta.settings); this.persist(); }
  };
  private exportSave(): void {
    const blob = new Blob([this.save.export(this.meta)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a'); link.href = url; link.download = `seoul-gate-${new Date().toISOString().slice(0, 10)}.json`;
    link.click(); window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    this.ui.notify('진행 기록 백업을 내보냈습니다.');
  }
  private exportBalanceLogs(): void {
    const blob = new Blob([this.balanceLogs.exportJson()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a'); link.href = url; link.download = `seoul-gate-balance-${new Date().toISOString().slice(0, 10)}.json`;
    link.click(); window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    this.ui.notify(`밸런스 기록 ${this.balanceLogs.load().length}판을 내보냈습니다.`);
  }
  private async importSave(target: HTMLInputElement): Promise<void> {
    const file = target.files?.[0];
    if (!file) return;
    try {
      if (file.size > 1_000_000) throw new Error('백업 파일이 너무 큽니다. 1MB 이하의 JSON을 선택하세요.');
      const json = await file.text();
      if (!window.confirm('선택한 백업으로 현재 영구 진행 기록을 교체할까요?')) return;
        this.meta = this.save.import(json);
        if (this.cloudSync && this.accountUserId) {
          this.lastCloudFingerprint = this.cloudFingerprint(this.meta);
          localStorage.setItem(this.dirtyKey(this.accountUserId), '1');
        this.cloudSync.queue(this.save.export(this.meta));
      }
      this.audio.applySettings(this.meta.settings);
      this.renderer.setHighResolution(this.meta.settings.highResolution);
      this.show('settings'); this.ui.notify(this.save.status);
    } catch (error) { this.ui.notify(error instanceof Error ? error.message : '백업을 읽을 수 없습니다.'); }
    finally { target.value = ''; }
  }
  destroy(): void {
    this.authSubscription?.unsubscribe();
    this.cloudSync?.stop();
    window.removeEventListener('online', this.retryCloud);
    window.clearTimeout(this.supplyFanfareTimer);
    this.audio.destroy();
    window.removeEventListener('pointerdown', this.unlockAudio);
    this.markOfflineExit(); this.loop.stop(); this.input.destroy(); this.renderer.destroy();
    window.clearInterval(this.autosaveTimer);
    window.removeEventListener('keydown', this.keydown); window.removeEventListener('blur', this.pause);
    document.removeEventListener('visibilitychange', this.visibility); window.removeEventListener('pagehide', this.markOfflineExit);
  }
  private unlockAudio = (event?: Event): void => {
    // The explicit sound button owns its first-click enable action.
    if (event?.target instanceof Element && event.target.closest('[data-action="sound"]')) return;
    if (!this.audio.unlocked) void this.audio.unlock();
  };
  private testSound(id: string): void {
    if (!Object.hasOwn(sfx, id)) return;
    if (this.audio.unlocked) this.audio.play(id as SfxId);
    else void this.audio.unlock().then(() => { this.audio.play(id as SfxId); });
  }
}



