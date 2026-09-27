import type { BalanceRunSummary } from '../analytics/BalanceTelemetry';
import type { ShopTab } from './ShopScreen';
import type { MetaState } from '../state/MetaState';
import type { RunState } from '../state/RunState';
import { DevPanel } from '../dev/DevPanel';
import { Hud } from './Hud';
import { shopScreen, postWaveScreen, pauseScreen, resultScreen, settingsScreen, titleScreen } from './screens';
import type { Screen } from './screens';
import { archiveScreen, type ArchiveViewState } from './ArchiveScreen';
import { lobbyScreen } from './LobbyScreen';
import { gateDepthDossier, gateFlowScreen } from './GateFlowScreen';
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
  private shopTab: ShopTab = 'weapons';
  private settingsTab = 'audio';
  private resultSummary: BalanceRunSummary | null = null;
  setResultSummary(summary: BalanceRunSummary): void { this.resultSummary = summary; }
  private toastTimeout = 0;
  private accountChoiceVisible = false;
  constructor(readonly root: HTMLElement, onAction: (action: string) => void, onChange: (target: HTMLInputElement | HTMLSelectElement) => void) {
    this.overlay.className = 'screen';
    this.toast.className = 'toast'; this.toast.setAttribute('role', 'status'); this.toast.hidden = true;
    this.soundButton.className = 'sound-button'; this.soundButton.dataset.action = 'sound';
    this.soundButton.innerHTML = '<span aria-hidden="true">♫</span><b>OFF</b>';
    this.soundButton.setAttribute('aria-label', '배경음악 꺼짐');
    this.account.className = 'account-panel';
    root.append(this.hud.element, this.overlay, this.dev.element, this.toast, this.soundButton, this.account);
    root.addEventListener('click', event => {
      const action = event.target instanceof Element ? event.target.closest<HTMLElement>('[data-action]')?.dataset.action : undefined;
      if (action?.startsWith('shop-tab:')) {
        event.preventDefault(); this.shopTab = action === 'shop-tab:items' ? 'items' : 'weapons'; this.applyShopTab(); return;
      }
      if (action?.startsWith('settings-tab:')) {
        event.preventDefault(); this.settingsTab = action.slice(13); this.applySettingsTab(); return;
      }
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
    // Keep the original controls alive when their temporary screen is rebuilt.
    const pauseButton = this.hud.element.querySelector<HTMLElement>('.pause-button') ?? this.overlay.querySelector<HTMLElement>('.pause-button');
    if (pauseButton) this.hud.element.querySelector('.hud-top')?.append(pauseButton);
    if (this.soundButton.parentElement !== this.root) this.root.append(this.soundButton);
    const sameScreen = this.root.dataset.screen === screen;
    this.overlay.classList.toggle('screen-update', sameScreen);
    if (screen === 'shop' && !sameScreen) this.shopTab = 'weapons';
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
    this.soundButton.hidden = screen !== 'lobby' && screen !== 'title';
    this.overlay.hidden = screen === 'waveActive';
    this.overlay.classList.toggle('overlay-screen', inRun || screen === 'result' || screen === 'revivalChoice');
    const renderers: Partial<Record<Screen, () => string>> = {
      title: () => titleScreen(canContinue),
      postWave: () => run ? postWaveScreen(run) : '',
      shop: () => run ? shopScreen(run, meta, this.shopTab) : '', lobby: () => lobbyScreen(meta),
      guild: () => guildScreen(meta, guild),
      revivalChoice: () => revivalScreen(meta),
      gateMap: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateDepth: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateCharacter: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateWeapon: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateBlessing: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft), gateConfirm: () => gateFlowScreen(screen as GateEntryStep,meta,gateDraft),
      growth:()=>growthScreen(meta,growth),association:()=>associationScreen(meta),offline:()=>offlineScreen(meta),supply:()=>supplyScreen(meta,supplyResults),
      archive: () => archiveScreen(archive), settings: () => settingsScreen(meta), paused: pauseScreen,
      result: () => run ? resultScreen(run, this.resultSummary) : '', waveActive: () => '',
    };
    this.overlay.innerHTML = renderers[screen]?.() ?? '';
    if (screen === 'shop' && pauseButton) this.overlay.querySelector('.shop-header')?.append(pauseButton);
    if (screen === 'title') this.overlay.querySelector('.title-actions')?.append(this.soundButton);
    if (screen === 'lobby') this.overlay.querySelector('.hq-header nav')?.append(this.soundButton);
    if (screen === 'growth') this.overlay.querySelector<HTMLElement>('.facility-list-grid')!.scrollTop = growthScroll;
    if (screen === 'archive') this.overlay.querySelector<HTMLElement>('.archive-entry-grid')!.scrollTop = archiveScroll;
    for (const saved of panelScroll) {
      const panel = [...this.overlay.querySelectorAll<HTMLElement>('.shop-catalog, .shop-stat-list, .gate-card-grid')].find(el => el.className === saved.className);
      if (panel) panel.scrollTop = saved.top;
    }
    if (screen === 'settings') { this.overlay.querySelector('.settings-account-slot')?.append(this.account); this.applySettingsTab(); }
    this.overlay.scrollTop = 0;
    this.overlay.scrollLeft = 0;
    if (screen === 'shop') this.overlay.querySelector<HTMLElement>('.shop-screen')?.focus({ preventScroll: true });
    else if (!sameScreen && screen !== 'waveActive' && screen !== 'lobby' && screen !== 'guild' && screen !== 'title') {
      const heading = this.overlay.querySelector<HTMLElement>('h1');
      if (heading) { heading.tabIndex = -1; heading.focus({ preventScroll: true }); }
    }
  }
  updateGateSelection(screen: GateEntryStep, meta: MetaState, draft: GateEntryDraft): boolean {
    if (this.root.dataset.screen !== screen) return false;
    const selectedAction: Partial<Record<GateEntryStep,string>> = {
      gateMap: `gate-map:${draft.mapId}`, gateDepth: `gate-depth-select:${draft.gateDepth}`,
      gateCharacter: `gate-character:${draft.characterId}`, gateWeapon: `gate-weapon:${draft.startingWeaponId}`,
      gateBlessing: `gate-blessing:${draft.blessingId}`,
    };
    const action = selectedAction[screen];
    const cards = [...this.overlay.querySelectorAll<HTMLButtonElement>(screen === 'gateDepth' ? '.depth-tile' : '.gate-select-card')];
    if (!action || !cards.some(card => card.dataset.action === action)) return false;
    for (const card of cards) {
      const selected = card.dataset.action === action;
      card.classList.toggle('selected', selected);
      card.setAttribute('aria-pressed', String(selected));
      const label = card.querySelector<HTMLElement>('.selection-seal');
      if (label) label.textContent = screen === 'gateCharacter' ? selected ? '작전 편성 완료' : '각성자 선택' : selected ? '선택됨' : '선택';
      if (screen === 'gateDepth') {
        card.querySelector('.depth-selected-flag')?.remove();
        if (selected) {
          const flag = document.createElement('strong');
          flag.className = 'depth-selected-flag';
          flag.textContent = '선택됨';
          card.append(flag);
        }
      }
    }
    if (screen === 'gateDepth') {
      const dossier = this.overlay.querySelector('.depth-dossier');
      if (dossier) dossier.outerHTML = gateDepthDossier(meta,draft);
    } else if (screen === 'gateMap') {
      const image = cards.find(card => card.dataset.action === action)?.querySelector('img')?.getAttribute('src');
      if (image) this.overlay.querySelector<HTMLElement>('.gate-flow-screen')?.style.setProperty('--gate-bg',`url("${image}")`);
    }
    this.overlay.querySelector<HTMLButtonElement>('.gate-next')?.removeAttribute('disabled');
    return true;
  }
  updateGateDepthPage(meta: MetaState, draft: GateEntryDraft): boolean {
    if (this.root.dataset.screen !== 'gateDepth') return false;
    const template = document.createElement('template');
    template.innerHTML = gateFlowScreen('gateDepth',meta,draft);
    const grid = template.content.querySelector('.depth-grid');
    const pager = template.content.querySelector('.depth-pager');
    const oldGrid = this.overlay.querySelector('.depth-grid');
    const oldPager = this.overlay.querySelector('.depth-pager');
    if (!grid || !pager || !oldGrid || !oldPager) return false;
    oldGrid.replaceWith(grid);
    oldPager.replaceWith(pager);
    return true;
  }
  private applyShopTab(): void {
    for (const section of this.overlay.querySelectorAll<HTMLElement>('.shop-section')) section.hidden = section.id !== `shop-${this.shopTab}`;
    for (const button of this.overlay.querySelectorAll<HTMLElement>('.shop-tab')) button.setAttribute('aria-pressed', String(button.dataset.action === `shop-tab:${this.shopTab}`));
  }
  private applySettingsTab(): void {
    for (const panel of this.overlay.querySelectorAll<HTMLElement>('[data-settings-panel]')) panel.hidden = panel.dataset.settingsPanel !== this.settingsTab;
    for (const button of this.overlay.querySelectorAll<HTMLElement>('[data-action^="settings-tab:"]')) button.setAttribute('aria-pressed', String(button.dataset.action === `settings-tab:${this.settingsTab}`));
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
  updateAudio(audible: boolean, muted: boolean, status: string): void {
    const on = audible && !muted;
    const label = on ? '배경음악 켜짐' : '배경음악 꺼짐';
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
