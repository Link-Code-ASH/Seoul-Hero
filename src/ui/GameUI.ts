import type { MetaState } from '../state/MetaState';
import type { RunState } from '../state/RunState';
import { DevPanel } from '../dev/DevPanel';
import { Hud } from './Hud';
import { shopScreen, postWaveScreen, pauseScreen, resultScreen, settingsScreen } from './screens';
import type { Screen } from './screens';
import { archiveScreen, type ArchiveViewState } from './ArchiveScreen';
import { lobbyScreen } from './LobbyScreen';
import { gateFlowScreen } from './GateFlowScreen';
import { associationScreen, growthScreen, offlineScreen, supplyScreen, type GrowthViewState } from './MetaScreens';
import type { MetaReward } from '../meta/SupplySystem';
import type { GateEntryDraft, GateEntryStep } from '../systems/GateEntrySystem';
import { accountPanel, type AccountView } from './AccountPanel';
import { images } from '../data/images';
export class GameUI {
  readonly hud = new Hud();
  readonly dev = new DevPanel();
  readonly joystick = document.createElement('div');
  readonly overlay = document.createElement('main');
  readonly toast = document.createElement('div');
  readonly soundButton = document.createElement('button');
  readonly account = document.createElement('aside');
  private toastTimeout = 0;
  constructor(readonly root: HTMLElement, onAction: (action: string) => void, onChange: (target: HTMLInputElement | HTMLSelectElement) => void) {
    const header = document.createElement('header');
    header.className = 'site-header';
    header.innerHTML = `<a href="#" data-action="lobby" class="wordmark" aria-label="서울 히어로 로비"><img class="brand-mark" src="${images.brandPortrait.url}" alt=""><b>SEOUL HERO</b></a><span class="header-note">각성자 협회 · 서울 지부</span>`;
    this.overlay.className = 'screen';
    this.toast.className = 'toast'; this.toast.setAttribute('role', 'status'); this.toast.hidden = true;
    this.joystick.className = 'joystick'; this.joystick.innerHTML = '<span></span>'; this.joystick.setAttribute('aria-label', '가상 이동 조이스틱');
    this.soundButton.className = 'sound-button'; this.soundButton.dataset.action = 'sound';
    this.soundButton.textContent = '♪ 소리 켜기';
    this.account.className = 'account-panel';
    root.append(header, this.hud.element, this.overlay, this.dev.element, this.joystick, this.toast, this.soundButton, this.account);
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
  show(screen: Screen, meta: MetaState, run: RunState | null, archive: ArchiveViewState, gateDraft: GateEntryDraft, growth:GrowthViewState, supplyResults:readonly MetaReward[], offlineClaimed = false): void {
    this.hud.hideWaveEndNotice();
    const inRun = ['waveActive', 'paused', 'shop', 'postWave'].includes(screen);
    this.root.dataset.screen = screen;
    this.account.hidden = screen !== 'lobby' && screen !== 'settings';
    this.hud.element.hidden = !inRun;
    if (!inRun) this.hud.clearWalletSweep();
    if (run && inRun) this.hud.update(run);
    this.joystick.hidden = screen !== 'waveActive';
    this.overlay.hidden = screen === 'waveActive';
    this.overlay.classList.toggle('overlay-screen', inRun || screen === 'result');
    const renderers: Partial<Record<Screen, () => string>> = {
      postWave: () => run ? postWaveScreen(run) : '',
      shop: () => run ? shopScreen(run) : '', lobby: () => lobbyScreen(meta),
      gateMap: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateDepth: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateCharacter: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateWeapon: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateBlessing: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateConfirm: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft),
      growth:()=>growthScreen(meta,growth),association:()=>associationScreen(meta),offline:()=>offlineScreen(meta,offlineClaimed),supply:()=>supplyScreen(meta,supplyResults),
      archive: () => archiveScreen(archive), settings: () => settingsScreen(meta), paused: pauseScreen,
      result: () => run ? resultScreen(run) : '', waveActive: () => '',
    };
    this.overlay.innerHTML = renderers[screen]?.() ?? '';
    this.overlay.scrollTop = 0;
    this.overlay.scrollLeft = 0;
    const depthList=this.overlay.querySelector<HTMLElement>('.gate-depth-scroll');
    const selectedDepth=depthList?.querySelector<HTMLElement>('.gate-depth-option.selected');
    if(depthList&&selectedDepth)depthList.scrollTop=Math.max(0,selectedDepth.offsetTop-depthList.clientHeight/2+selectedDepth.clientHeight/2);
    if (screen === 'shop') this.overlay.querySelector<HTMLElement>('.shop-screen')?.focus({ preventScroll: true });
    else if (screen !== 'waveActive') this.overlay.querySelector<HTMLElement>('button, input')?.focus({ preventScroll: true });
  }
  updateAccount(view: AccountView): void {
    this.account.innerHTML = accountPanel(view);
  }
  notify(message: string): void {
    window.clearTimeout(this.toastTimeout);
    this.toast.textContent = message; this.toast.hidden = false;
    this.toastTimeout = window.setTimeout(() => { this.toast.hidden = true; }, 6000);
  }
  updateAudio(unlocked: boolean, muted: boolean, status: string): void {
    const label = !unlocked ? '♪ 소리 켜기' : muted ? '♪ 음소거 해제' : '♪ 소리 켜짐';
    if (this.soundButton.textContent !== label) this.soundButton.textContent = label;
    this.soundButton.title = status;
    this.soundButton.setAttribute('aria-pressed', String(unlocked && !muted));
  }
}
