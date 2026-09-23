import type { RunState } from '../state/RunState';
import type { HostileProjectile, HostileHazard } from '../entities/types';
import { ENEMY_RULES } from '../data/enemyConfig';
import { maps } from '../data/maps';
import { ObjectPool } from '../utils/ObjectPool';
import { segmentCircleHit } from '../utils/math';
import { damagePlayer } from './PlayerDamageSystem';
import type { GameEventSink } from '../core/GameEvents';
export class HostileAttackSystem {
  private readonly bullets = new ObjectPool<HostileProjectile>(() => ({ x: 0, y: 0, vx: 0, vy: 0, radius: 0, damage: 0, remaining: 0 }));
  private readonly areas = new ObjectPool<HostileHazard>(() => ({ x: 0, y: 0, radius: 0, damage: 0, warning: 0, remaining: 0, triggered: false }));
  constructor(private readonly random: () => number, private readonly emit: GameEventSink) {}
  shoot(run: RunState, x: number, y: number, angle: number, damage: number): void {
    if (run.hostileProjectiles.length >= ENEMY_RULES.maxHostileProjectiles) return;
    const p = this.bullets.acquire();
    Object.assign(p, { x, y, vx: Math.cos(angle) * ENEMY_RULES.bulletSpeed, vy: Math.sin(angle) * ENEMY_RULES.bulletSpeed,
      radius: ENEMY_RULES.projectileRadius, damage, remaining: ENEMY_RULES.projectileLifetime });
    run.hostileProjectiles.push(p);
  }
  area(run: RunState, x: number, y: number, radius: number, warning: number, damage: number): void {
    if (run.hazards.length >= ENEMY_RULES.maxHazards) return;
    const h = this.areas.acquire(); Object.assign(h, { x, y, radius, warning, damage, remaining: warning + 0.25, triggered: false }); run.hazards.push(h);
  }
  update(run: RunState, dt: number): void {
    const arena = maps[run.mapId]!, player = run.player;
    let kept = 0;
    for (const p of run.hostileProjectiles) {
      const x = p.x + p.vx * dt, y = p.y + p.vy * dt;
      const hit = Number.isFinite(segmentCircleHit(p.x, p.y, x, y, player.x, player.y, player.radius + p.radius));
      p.x = x; p.y = y; p.remaining -= dt;
      if (hit) damagePlayer(run, p.damage, this.random, this.emit);
      if (hit || p.remaining <= 0 || Math.abs(x) > arena.arenaWidth / 2 || Math.abs(y) > arena.arenaHeight / 2) this.bullets.release(p);
      else run.hostileProjectiles[kept++] = p;
    }
    run.hostileProjectiles.length = kept; kept = 0;
    for (const h of run.hazards) {
      h.warning -= dt; h.remaining -= dt;
      if (!h.triggered && h.warning <= 0) {
        h.triggered = true;
        if ((player.x - h.x) ** 2 + (player.y - h.y) ** 2 <= (h.radius + player.radius) ** 2) damagePlayer(run, h.damage, this.random, this.emit);
      }
      if (h.remaining <= 0) this.areas.release(h); else run.hazards[kept++] = h;
    }
    run.hazards.length = kept;
  }
  clear(run: RunState): void {
    for (const p of run.hostileProjectiles) this.bullets.release(p);
    for (const h of run.hazards) this.areas.release(h);
    run.hostileProjectiles.length = 0; run.hazards.length = 0;
  }
}

