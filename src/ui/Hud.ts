import { inventoryArt, weaponArt } from './InventoryArt';
import { enemies } from '../data/enemies';
import { weapons } from '../data/weapons';
import { images } from '../data/images';
import type { RunState } from '../state/RunState';
import { formatTime } from './helpers';
import { isTerminal } from '../state/RunPhase';
export class Hud {
  readonly element = document.createElement('div');
  private readonly walletFlightLayer = document.createElement('div');
  private readonly waveEndNotice = document.createElement('div');
  private readonly hp: HTMLElement;
  private readonly stats: HTMLElement;
  private readonly clock: HTMLElement;
  private readonly wave: HTMLElement;
  private readonly boss: HTMLElement;
  constructor() {
    this.element.className = 'hud';
    this.element.innerHTML = `<div class="hud-top"><div class="player-status"><div class="hp-line">${inventoryArt(40)}<div class="hp-track"><div id="hp-fill"></div><span id="hp-text"></span></div></div><div class="hud-readout" id="hud-stats"></div></div><div class="timer"><span id="hud-wave"></span><strong id="hud-clock">00:00</strong></div><button data-action="pause" class="pause-button" aria-label="일시정지">Ⅱ</button></div><div class="weapon-strip" id="hud-weapons"></div><div class="boss-status" id="boss-status"></div>`;
    this.hp = this.get('#hp-fill'); this.stats = this.get('#hud-stats');
    this.clock = this.get('#hud-clock'); this.wave = this.get('#hud-wave'); this.boss = this.get('#boss-status');
    this.walletFlightLayer.className = 'wallet-flight-layer';
    this.waveEndNotice.className = 'wave-end-announcement';
    this.waveEndNotice.hidden = true;
    this.element.append(this.walletFlightLayer, this.waveEndNotice);
  }
  private get(selector: string): HTMLElement { return this.element.querySelector<HTMLElement>(selector)!; }
  getWalletScreenTarget(): { x: number; y: number } | null {
    const wallet = this.element.querySelector<HTMLElement>('.wallet-reserve');
    if (!wallet) return null;
    const bounds = wallet.getBoundingClientRect();
    if (bounds.width <= 0 || bounds.height <= 0) return null;
    return { x: bounds.left + bounds.width / 2, y: bounds.top + bounds.height / 2 };
  }
  playWalletSweep(origins: readonly { x: number; y: number }[]): void {
    this.clearWalletSweep();
    const target = this.getWalletScreenTarget();
    if (!target || origins.length === 0) return;
    const limit = 48;
    const step = Math.max(1, Math.ceil(origins.length / limit));
    const visibleOrigins = origins.filter((_, index) => index % step === 0).slice(0, limit);
    visibleOrigins.forEach((origin, index) => {
      const startX = Math.max(18, Math.min(window.innerWidth - 18, origin.x));
      const startY = Math.max(18, Math.min(window.innerHeight - 18, origin.y));
      const dx = target.x - startX, dy = target.y - startY;
      const bend = (index % 2 === 0 ? 1 : -1) * Math.min(72, 18 + Math.abs(dx) * 0.08);
      const stone = document.createElement('img');
      stone.className = 'wallet-flight-stone';
      stone.src = images.magicStone.url; stone.alt = '';
      stone.style.left = `${startX}px`; stone.style.top = `${startY}px`;
      this.walletFlightLayer.append(stone);
      const animation = stone.animate([
        { transform: 'translate(-50%, -50%) scale(.72)', opacity: 0 },
        { transform: 'translate(-50%, -50%) scale(1)', opacity: 1, offset: 0.12 },
        { transform: `translate(calc(-50% + ${dx * 0.58 + bend}px), calc(-50% + ${dy * 0.58 - 55}px)) scale(.82)`, opacity: 1, offset: 0.62 },
        { transform: `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) scale(.28)`, opacity: 0.25 },
      ], { duration: 850, delay: index * 34, easing: 'cubic-bezier(.22,.72,.2,1)', fill: 'forwards' });
      animation.finished.then(() => stone.remove()).catch(() => stone.remove());
    });
  }
  clearWalletSweep(): void { this.walletFlightLayer.replaceChildren(); }
  showWaveEndNotice(waveNumber: number): void {
    this.waveEndNotice.innerHTML = `<small>WAVE ${waveNumber}</small><strong>웨이브 종료</strong>`;
    this.waveEndNotice.hidden = false;
  }
  hideWaveEndNotice(): void { this.waveEndNotice.hidden = true; }
  update(run: RunState): void {
    this.element.classList.toggle('wallet-sweeping', (run.phase === 'postWave' || isTerminal(run.phase)) && run.pickups.length > 0);
    this.hp.style.width = `${Math.max(0, run.player.hp / run.player.maxHp * 100)}%`;
    this.get('#hp-text').textContent = `${Math.ceil(run.player.hp)} / ${run.player.maxHp}`;
    this.get('#hud-weapons').innerHTML = run.ownedWeapons.map((slot,index) => `<span class="weapon-slot"><i>${index + 1}</i>${weaponArt(slot.id)}<b>${weapons[slot.id]?.name ?? slot.id}</b><small>LV.${slot.level}${slot.branchId ? `-${slot.branchId}` : ''}</small></span>`).join('');
    this.stats.innerHTML = `<span class="hud-chip" title="보유 마력석"><img class="pickup-ui-icon" src="${images.magicStone.url}" alt=""><b>${Math.floor(run.runCurrency)}</b></span><span class="hud-chip wallet-reserve" title="다음 획득에 추가되는 마력석"><img class="wallet-icon" src="${images.wallet.url}" alt="지갑"><b>${Math.floor(run.walletBonusRemaining + run.walletStoredThisRun)}</b></span>`;
    this.clock.textContent = formatTime(Math.ceil(run.waveRemainingTime));
    this.wave.textContent = `${run.bossSpawned ? 'BOSS WAVE' : 'WAVE'} ${run.currentWave} / ${run.totalWaves}`;
    const boss = run.enemies.find(enemy => enemy.boss);
    this.boss.hidden = !boss;
    if (boss) this.boss.textContent = `${enemies[boss.definitionId]?.name ?? '보스'} · ${Math.ceil(boss.hp)} / ${boss.maxHp}`;
  }
}
