import { GAME_CONFIG } from '../data/config';
import { DROP_RULES } from '../data/enemyConfig';
import type { Pickup } from '../entities/types';
import type { RunState } from '../state/RunState';
import { ObjectPool } from '../utils/ObjectPool';
import { distanceSquared } from '../utils/math';
import { collectMagicStone } from './MagicStoneSystem';
import { magicStoneTier } from '../data/magicStoneConfig';
import { ignoreGameEvent, type GameEventSink } from '../core/GameEvents';
export class PickupSystem {
  private readonly pool = new ObjectPool<Pickup>(() => ({ id: 0, x: 0, y: 0, radius: 7, value: 0, units: 0, age: 0, kind: 'magicStone', tier: 1 }));
  private readonly cells = new Map<string, Pickup>();
  private mergeCursor = 0;
  private walletSweepStarted = false;
  constructor(private readonly nextId: () => number, private readonly emit: GameEventSink = ignoreGameEvent) {}
  drop(state: RunState, x: number, y: number, value: number): void {
    if (!Number.isFinite(value) || value <= 0) return;
    const size = DROP_RULES.mergeDistance, cx = Math.floor(x / size), cy = Math.floor(y / size);
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const near = this.cells.get((cx + dx) + ',' + (cy + dy));
      if (near && (near.x - x) ** 2 + (near.y - y) ** 2 <= size * size) {
        near.value += value;
        near.tier = magicStoneTier(Math.max(near.value, value));
        near.units = (near.units ?? 1) + 1;
        return;
      }
    }
    let pickup: Pickup;
    if (state.pickups.length >= GAME_CONFIG.combat.maxPickups) {
      // Keep missed stones on the field. At the cap, combine value into an
      // existing pickup instead of silently granting currency/XP.
      pickup = state.pickups[this.mergeCursor++ % state.pickups.length]!;
      pickup.value += value; pickup.tier = magicStoneTier(Math.max(pickup.value, value)); pickup.units = (pickup.units ?? 1) + 1; pickup.age = 0;
      return;
    } else {
      pickup = this.pool.acquire(); pickup.id = this.nextId(); pickup.value = 0; pickup.units = 0; pickup.kind = 'magicStone'; pickup.tier = 1;
      state.pickups.push(pickup);
    }
    pickup.x = x; pickup.y = y; pickup.age = 0;
    pickup.radius = DROP_RULES.magicStoneRadius;
    pickup.value += value;
    pickup.tier = magicStoneTier(pickup.value);
    pickup.units = (pickup.units ?? 0) + 1;
    this.cells.set(cx + ',' + cy, pickup);
  }
  private collect(state: RunState, pickup: Pickup): void {
    collectMagicStone(state, pickup.value, pickup.units ?? 1);
    this.emit('magicStoneCollected');
  }
  update(state: RunState, dt: number): void {
    let kept = 0; const player = state.player;
    this.cells.clear();
    for (const pickup of state.pickups) {
      pickup.age += dt;
      let distance = Math.sqrt(distanceSquared(pickup, player));
      if (distance > 0 && distance <= player.pickupRadius) {
        const step = Math.min(distance, GAME_CONFIG.combat.pickupAttractionSpeed * dt);
        pickup.x += (player.x - pickup.x) / distance * step; pickup.y += (player.y - pickup.y) / distance * step; distance -= step;
      }
      if (distance <= player.radius + pickup.radius) {
        this.collect(state, pickup); this.pool.release(pickup);
      } else {
        // Lifetime no longer means auto-collection. Population remains bounded
        // by maxPickups and every missed value can reach the end-of-stage wallet.
        pickup.age = Math.min(pickup.age, DROP_RULES.magicStoneLifetime);
        state.pickups[kept++] = pickup;
        const size = DROP_RULES.mergeDistance;
        this.cells.set(Math.floor(pickup.x / size) + ',' + Math.floor(pickup.y / size), pickup);
      }
    }
    state.pickups.length = kept;
  }
  collectAll(state: RunState): void {
    for (const pickup of state.pickups) this.collect(state, pickup);
    this.clear(state);
  }
  /** Moves uncollected stones into the wallet without granting Run currency or XP. */
  sweepToWallet(state: RunState, dt: number, target: { x: number; y: number }): boolean {
    if (!Number.isFinite(dt) || dt <= 0) return state.pickups.length === 0;
    if (!this.walletSweepStarted) {
      this.walletSweepStarted = true;
      state.pickups.forEach((pickup, index) => { pickup.age = -Math.min(index, 24) * 0.055; });
    }
    this.cells.clear();
    let kept = 0;
    const frameDelta = Math.min(dt, 0.05);
    const progress = 1 - Math.exp(-frameDelta * 5.2);
    for (const pickup of state.pickups) {
      pickup.age += frameDelta;
      if (pickup.age < 0) { state.pickups[kept++] = pickup; continue; }
      const dx = target.x - pickup.x;
      const dy = target.y - pickup.y;
      const distance = Math.hypot(dx, dy);
      if (!Number.isFinite(distance) || distance <= 34) {
        // Newly missed stones are locked for the rest of this Stage. Keeping
        // them separate prevents the next Wave from immediately releasing them.
        state.walletStoredThisRun += Math.max(0, pickup.value);
        this.pool.release(pickup);
        continue;
      }
      pickup.x += dx * progress;
      pickup.y += dy * progress;
      state.pickups[kept++] = pickup;
    }
    state.pickups.length = kept;
    if (kept === 0) this.walletSweepStarted = false;
    return kept === 0;
  }
  /** Fallback for players who leave POST_WAVE before the visual sweep finishes. */
  storeRemainingInWallet(state: RunState): void {
    for (const pickup of state.pickups) {
      state.walletStoredThisRun += Math.max(0, pickup.value);
      this.pool.release(pickup);
    }
    state.pickups.length = 0;
    this.cells.clear();
    this.walletSweepStarted = false;
  }
  clear(state: RunState): void { for (const pickup of state.pickups) this.pool.release(pickup); state.pickups.length = 0; this.cells.clear(); this.walletSweepStarted = false; }
}
