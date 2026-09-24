import type { MetaState } from '../state/MetaState';
import type { RunState } from '../state/RunState';
import { DevPanel } from '../dev/DevPanel';
import { Hud } from './Hud';
import { shopScreen, postWaveScreen, pauseScreen, resultScreen, settingsScreen } from './screens';
import type { Screen } from './screens';
import { archiveScreen, type ArchiveViewState } from './ArchiveScreen';
import { lobbyScreen } from './LobbyScreen';
import { gateFlowScreen } from './GateFlowScreen';
import { associationScreen, growthScreen, offlineScreen, offlineClaimVisual, offlineEmptyArt, offlineEmptyRows, supplyScreen, type GrowthViewState } from './MetaScreens';
import type { MetaReward } from '../meta/SupplySystem';
import type { GateEntryDraft, GateEntryStep } from '../systems/GateEntrySystem';
import { accountPanel, type AccountView } from './AccountPanel';
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
  show(screen: Screen, meta: MetaState, run: RunState | null, archive: ArchiveViewState, gateDraft: GateEntryDraft, growth:GrowthViewState, supplyResults:readonly MetaReward[]): void {
    const growthScroll = screen === 'growth' && this.root.dataset.screen === 'growth' && this.overlay.querySelector('.facility-tabs .active')?.getAttribute('data-action') === `growth-tab:${growth.tab}`
      ? this.overlay.querySelector<HTMLElement>('.facility-list-grid')?.scrollTop ?? 0 : 0;
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
    this.overlay.classList.toggle('overlay-screen', inRun || screen === 'result');
    const renderers: Partial<Record<Screen, () => string>> = {
      postWave: () => run ? postWaveScreen(run) : '',
      shop: () => run ? shopScreen(run) : '', lobby: () => lobbyScreen(meta),
      gateMap: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateDepth: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateCharacter: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateWeapon: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateBlessing: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateConfirm: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft),
      growth:()=>growthScreen(meta,growth),association:()=>associationScreen(meta),offline:()=>offlineScreen(meta),supply:()=>supplyScreen(meta,supplyResults),
      archive: () => archiveScreen(archive), settings: () => settingsScreen(meta), paused: pauseScreen,
      result: () => run ? resultScreen(run) : '', waveActive: () => '',
    };
    this.overlay.innerHTML = renderers[screen]?.() ?? '';
    if (screen === 'growth') this.overlay.querySelector<HTMLElement>('.facility-list-grid')!.scrollTop = growthScroll;
    if (screen === 'settings') this.overlay.querySelector('.settings-account-slot')?.append(this.account);
    this.overlay.scrollTop = 0;
    this.overlay.scrollLeft = 0;
    const depthList=this.overlay.querySelector<HTMLElement>('.gate-depth-scroll');
    const selectedDepth=depthList?.querySelector<HTMLElement>('.gate-depth-option.selected');
    if(depthList&&selectedDepth)depthList.scrollTop=Math.max(0,selectedDepth.offsetTop-depthList.clientHeight/2+selectedDepth.clientHeight/2);
    if (screen === 'shop') this.overlay.querySelector<HTMLElement>('.shop-screen')?.focus({ preventScroll: true });
    else if (screen !== 'waveActive' && screen !== 'lobby') this.overlay.querySelector<HTMLElement>('button, input')?.focus({ preventScroll: true });
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
