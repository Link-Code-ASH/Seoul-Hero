import type { MetaState } from '../state/MetaState';
import type { RunState } from '../state/RunState';
import { DevPanel } from '../dev/DevPanel';
import { Hud } from './Hud';
import { shopScreen, postWaveScreen, pauseScreen, resultScreen, settingsScreen, titleScreen } from './screens';
import type { Screen } from './screens';
import { archiveScreen, type ArchiveViewState } from './ArchiveScreen';
import { lobbyScreen } from './LobbyScreen';
import { gateFlowScreen } from './GateFlowScreen';
import { associationScreen, growthScreen, offlineScreen, offlineClaimVisual, offlineEmptyArt, offlineEmptyRows, supplyScreen, type GrowthViewState } from './MetaScreens';
import type { MetaReward } from '../meta/SupplySystem';
import type { GateEntryDraft, GateEntryStep } from '../systems/GateEntrySystem';
import { accountPanel, type AccountView } from './AccountPanel';
import { revivalScreen } from './RevivalScreen';
import { guildScreen, type GuildViewState } from './GuildScreen';
import type { GuildPointId } from '../data/guild';
import { guildPoint } from '../systems/GuildSystem';
export class GameUI {
  readonly hud = new Hud();
  readonly dev = new DevPanel();
  readonly overlay = document.createElement('main');
  readonly toast = document.createElement('div');
  readonly soundButton = document.createElement('button');
  readonly account = document.createElement('aside');
  private toastTimeout = 0;
  private accountChoiceVisible = false;
  constructor(readonly root: HTMLElement, onAction: (action: string) => void, onChange: (target: HTMLInputElement | HTMLSelectElement) => void) {
    this.overlay.className = 'screen';
    this.toast.className = 'toast'; this.toast.setAttribute('role', 'status'); this.toast.hidden = true;
    this.soundButton.className = 'sound-button'; this.soundButton.dataset.action = 'sound';
    this.soundButton.innerHTML = '<span aria-hidden="true">♫</span><b>OFF</b>';
    this.soundButton.setAttribute('aria-label', '소리 꺼짐');
    this.account.className = 'account-panel';
    root.append(this.hud.element, this.overlay, this.dev.element, this.toast, this.soundButton, this.account);
    root.addEventListener('click', event => {
      const action = event.target instanceof Element ? event.target.closest<HTMLElement>('[data-action]')?.dataset.action : undefined;
      if (action) { event.preventDefault(); onAction(action); }
    });
    root.addEventListener('change', event => { if (event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement) onChange(event.target); });
    root.addEventListener('input', event => {
      const slider = event.target;
      if (!(slider instanceof HTMLInputElement) || slider.type !== 'range' || !slider.dataset.setting) return;
      const value = slider.closest('.setting-row')?.querySelector<HTMLOutputElement>('output');
      if (value) value.value = `${Math.round(Number(slider.value) * 100)}%`;
    });
  }
  show(screen: Screen, meta: MetaState, run: RunState | null, archive: ArchiveViewState, gateDraft: GateEntryDraft, growth:GrowthViewState, supplyResults:readonly MetaReward[], guild: GuildViewState, canContinue = false): void {
    const sameScreen = this.root.dataset.screen === screen;
    const panelScroll = sameScreen ? [...this.overlay.querySelectorAll<HTMLElement>('.shop-catalog, .shop-stat-list, .gate-card-grid')].map(el => ({ className: el.className, top: el.scrollTop })) : [];
    const growthScroll = screen === 'growth' && this.root.dataset.screen === 'growth' && this.overlay.querySelector('.facility-tabs .active')?.getAttribute('data-action') === `growth-tab:${growth.tab}`
      ? this.overlay.querySelector<HTMLElement>('.facility-list-grid')?.scrollTop ?? 0 : 0;
    const previousArchive = this.overlay.querySelector<HTMLElement>('.archive-screen');
    const archiveScroll = screen === 'archive' && this.root.dataset.screen === 'archive' && previousArchive?.dataset.mapId === archive.mapId && previousArchive.dataset.category === archive.category
      ? this.overlay.querySelector<HTMLElement>('.archive-entry-grid')?.scrollTop ?? 0 : 0;
    if (this.account.parentElement !== this.root) this.root.append(this.account);
    this.hud.hideWaveEndNotice();
    const inRun = ['waveActive', 'paused', 'shop', 'postWave'].includes(screen);
    this.root.dataset.screen = screen;
    this.account.hidden = screen !== 'settings' && !this.accountChoiceVisible;
    this.hud.element.hidden = !inRun;
    if (!inRun) this.hud.clearWalletSweep();
    if (run && inRun) this.hud.update(run);
    this.soundButton.hidden = screen !== 'lobby';
    this.overlay.hidden = screen === 'waveActive';
    this.overlay.classList.toggle('overlay-screen', inRun || screen === 'result' || screen === 'revivalChoice');
    const renderers: Partial<Record<Screen, () => string>> = {
      title: () => titleScreen(canContinue),
      postWave: () => run ? postWaveScreen(run) : '',
      shop: () => run ? shopScreen(run, meta) : '', lobby: () => lobbyScreen(meta),
      guild: () => guildScreen(meta, guild),
      revivalChoice: () => revivalScreen(meta),
      gateMap: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateDepth: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateCharacter: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateWeapon: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateBlessing: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateConfirm: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft),
      growth:()=>growthScreen(meta,growth),association:()=>associationScreen(meta),offline:()=>offlineScreen(meta),supply:()=>supplyScreen(meta,supplyResults),
      archive: () => archiveScreen(archive), settings: () => settingsScreen(meta), paused: pauseScreen,
      result: () => run ? resultScreen(run) : '', waveActive: () => '',
    };
    this.overlay.innerHTML = renderers[screen]?.() ?? '';
    if (screen === 'shop') {
      const pause = document.createElement('button');
      pause.type = 'button'; pause.className = 'shop-pause-button';
      pause.dataset.action = 'pause'; pause.setAttribute('aria-label', '일시정지');
      pause.textContent = 'Ⅱ';
      this.overlay.querySelector('.shop-header')?.append(pause);
    }
    if (screen === 'growth') this.overlay.querySelector<HTMLElement>('.facility-list-grid')!.scrollTop = growthScroll;
    if (screen === 'archive') this.overlay.querySelector<HTMLElement>('.archive-entry-grid')!.scrollTop = archiveScroll;
    for (const saved of panelScroll) {
      const panel = [...this.overlay.querySelectorAll<HTMLElement>('.shop-catalog, .shop-stat-list, .gate-card-grid')].find(el => el.className === saved.className);
      if (panel) panel.scrollTop = saved.top;
    }
    if (screen === 'settings') this.overlay.querySelector('.settings-account-slot')?.append(this.account);
    this.overlay.scrollTop = 0;
    this.overlay.scrollLeft = 0;
    if (screen === 'shop') this.overlay.querySelector<HTMLElement>('.shop-screen')?.focus({ preventScroll: true });
    else if (screen !== 'waveActive' && screen !== 'lobby' && screen !== 'guild' && screen !== 'title') this.overlay.querySelector<HTMLElement>('button, input')?.focus({ preventScroll: true });
  }
  setShopPause(open: boolean): void {
    this.overlay.querySelector('.shop-pause-overlay')?.remove();
    if (!open || this.root.dataset.screen !== 'shop') return;
    const layer = document.createElement('div');
    layer.className = 'shop-pause-overlay';
    layer.innerHTML = pauseScreen('편의점 계속');
    this.overlay.append(layer);
    layer.querySelector<HTMLElement>('button')?.focus({ preventScroll: true });
  }
  updateGuildPoint(id: GuildPointId | null): void {
    const button = this.overlay.querySelector<HTMLButtonElement>('.guild-interact');
    if (!button) return;
    const point = id ? guildPoint(id) : undefined;
    button.hidden = !point;
    if (point) button.innerHTML = `${point.name} <span>살펴보기</span>`;
  }
  updateAccount(view: AccountView): void {
    this.account.innerHTML = accountPanel(view);
    this.accountChoiceVisible = Boolean(view.choice);
    this.account.hidden = this.root.dataset.screen !== 'settings' && !this.accountChoiceVisible;
  }
  notify(message: string): void {
    window.clearTimeout(this.toastTimeout);
    this.toast.textContent = message; this.toast.hidden = false;
    this.toastTimeout = window.setTimeout(() => { this.toast.hidden = true; }, 6000);
  }
  updateAudio(unlocked: boolean, muted: boolean, status: string): void {
    const on = unlocked && !muted;
    const label = on ? '소리 켜짐' : '소리 꺼짐';
    this.soundButton.querySelector('b')!.textContent = on ? 'ON' : 'OFF';
    this.soundButton.setAttribute('aria-label', label);
    this.soundButton.title = status;
    this.soundButton.setAttribute('aria-pressed', String(on));
  }
  playOfflineClaim(): void {
    const console = this.overlay.querySelector<HTMLElement>('.offline-console');
    if (!console) return;
    console.classList.add('claiming');
    console.insertAdjacentHTML('beforeend', offlineClaimVisual());
    const claimButton = console.querySelector<HTMLButtonElement>('[data-action="offline-claim"]');
    if (claimButton) claimButton.disabled = true;
  }
  finishOfflineClaim(): void {
    this.overlay.querySelector('.offline-transfer')?.remove();
    this.overlay.querySelector('.offline-console')?.classList.remove('claiming');
    this.overlay.querySelector('.offline-recovery')?.classList.remove('ready');
    const caption = this.overlay.querySelector('.recovery-caption b');
    if (caption) caption.textContent = '회수 대기';
    const status = this.overlay.querySelector('.manifest-status');
    if (status) { status.classList.remove('ready'); status.textContent = '정산 완료'; }
    const list = this.overlay.querySelector('.offline-manifest ul');
    if (list) list.innerHTML = offlineEmptyRows();
    const manifest = this.overlay.querySelector('.offline-manifest');
    if (manifest && !manifest.querySelector('.manifest-empty-art')) manifest.querySelector('ul')?.insertAdjacentHTML('afterend', offlineEmptyArt());
  }
}
