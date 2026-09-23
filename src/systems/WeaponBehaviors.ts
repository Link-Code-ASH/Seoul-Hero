import { attackContext, type AttackContext } from '../stats/Damage';
import type { ResolvedWeaponStats } from '../stats/WeaponStats';
import type { Weapon } from '../data/types';
import type { Enemy } from '../entities/types';
import type { RunState } from '../state/RunState';
import { WEAPON_CONFIG } from '../data/weaponConfig';
import type { CollisionSystem } from './CollisionSystem';
import { ignoreGameEvent, type GameEventSink } from '../core/GameEvents';
import { spawnRunEffect } from './RunEffectSystem';
import { segmentCircleHit } from '../utils/math';

export class WeaponBehaviors {
  private readonly pending: { x: number; y: number; startX: number; startY: number; delay: number; flightDuration: number; projectileSpawned: boolean; radius: number; angle: number; arc: number; kind: 'slash' | 'bombard'; damage: number; context: AttackContext; color: number; duration: number }[] = [];
  private readonly candidates: Enemy[] = [];
  private readonly hitIds = new Set<number>();
  private readonly orbitPrevious = new Map<string, { x: number; y: number; time: number }>();
  private readonly orbitLastHit = new Map<string, number>();
  constructor(private readonly collision: CollisionSystem, private readonly emit: GameEventSink = ignoreGameEvent) {}
  attack(run: RunState, weapon: Weapon, stats: ResolvedWeaponStats, target?: Enemy): void {
    if (!target) return;
    const context = attackContext(stats, run.player.maxHp, weapon.id);
    const hit = (enemy: Enemy) => this.collision.hit(enemy, stats.damage, run, context, weapon.visual.color);
    const player = run.player, direction = Math.atan2((target?.y ?? player.y) - player.y, (target?.x ?? player.x) - player.x);
    const effect = (kind: RunState['effects'][number]['kind'], x: number, y: number, endX: number, endY: number, radius: number, angle = 0, arc = 0): void => {
      spawnRunEffect(run, kind, { x, y, endX, endY, radius, angle, arc, color: weapon.visual.color });
    };
    if (weapon.behavior === 'slash') {
      const arc = Math.min(Math.PI * 2, stats.attackAngle * stats.areaScale);
      this.collision.nearby(player.x, player.y, stats.range, this.candidates);
      for (const enemy of this.candidates) {
        const dx = enemy.x - player.x, dy = enemy.y - player.y;
        const angle = Math.atan2(Math.sin(Math.atan2(dy, dx) - direction), Math.cos(Math.atan2(dy, dx) - direction));
        if (Math.hypot(dx, dy) <= stats.range && Math.abs(angle) <= arc / 2) hit(enemy);
      }
      // Keep the blade art at full size. Shift its center back along the swing
      // direction so the outer edge reaches a nearby target.
      const targetDistance = Math.min(stats.range, Math.hypot(target!.x - player.x, target!.y - player.y));
      const shift = targetDistance - stats.range;
      effect('slash', player.x + Math.cos(direction) * shift, player.y + Math.sin(direction) * shift,
        0, 0, stats.range, direction, arc);
      for (let i = 1; i < stats.repeatCount; i++) this.schedule('slash', player.x, player.y, i * stats.repeatInterval, stats.range, direction, arc, stats, context, weapon.visual.color);
    } else if (weapon.behavior === 'bombard') {
      const radius = stats.blastRadius;
      for (let i = 0; i < stats.repeatCount; i++) this.schedule('bombard', target!.x, target!.y, stats.explosionDelay + i * stats.repeatInterval, radius, 0, 0, stats, context, weapon.visual.color, player.x, player.y, stats.explosionDelay);
    } else if (weapon.behavior === 'chain') {
      this.hitIds.clear();
      let current: Enemy | undefined = target, x = player.x, y = player.y;
      for (let i = 0; i < stats.projectileCount && current; i++) {
        hit(current); this.hitIds.add(current.id);
        effect('chain', x, y, current.x, current.y, 0);
        x = current.x; y = current.y;
        const range = stats.chainRange;
        this.collision.nearby(x, y, range, this.candidates);
        current = undefined; let best = range * range;
        for (const enemy of this.candidates) {
          const distance = (enemy.x - x) ** 2 + (enemy.y - y) ** 2;
          if (enemy.hp > 0 && !this.hitIds.has(enemy.id) && distance <= best) { current = enemy; best = distance; }
        }
      }
    }
    this.clearReferences();
  }
  /** Sweep every visible shuriken along its orbit; each blade has its own rehit timer. */
  updateOrbit(run: RunState, weapon: Weapon, stats: ResolvedWeaponStats, dt: number): boolean {
    const now = run.stageCombatTime;
    const previous = this.orbitPrevious.get(weapon.id);
    const startTime = previous && previous.time <= now && now - previous.time <= Math.max(dt * 2, 0.1)
      ? previous.time : Math.max(0, now - dt);
    const startX = previous && startTime === previous.time ? previous.x : run.player.x;
    const startY = previous && startTime === previous.time ? previous.y : run.player.y;
    const angleTravel = (now - startTime) * WEAPON_CONFIG.orbitAngularSpeed;
    const segments = Math.max(1, Math.ceil(angleTravel / 0.2));
    const hitRadius = WEAPON_CONFIG.orbitHitRadius * stats.areaScale;
    const context = attackContext(stats, run.player.maxHp, weapon.id);
    let hit = false;
    for (let blade = 0; blade < stats.projectileCount; blade++) {
      const offset = blade * Math.PI * 2 / stats.projectileCount;
      for (let step = 0; step < segments; step++) {
        const a = step / segments, b = (step + 1) / segments;
        const angleA = (startTime + (now - startTime) * a) * WEAPON_CONFIG.orbitAngularSpeed + offset;
        const angleB = (startTime + (now - startTime) * b) * WEAPON_CONFIG.orbitAngularSpeed + offset;
        const x1 = startX + (run.player.x - startX) * a + Math.cos(angleA) * stats.range;
        const y1 = startY + (run.player.y - startY) * a + Math.sin(angleA) * stats.range;
        const x2 = startX + (run.player.x - startX) * b + Math.cos(angleB) * stats.range;
        const y2 = startY + (run.player.y - startY) * b + Math.sin(angleB) * stats.range;
        this.candidates.length = 0;
        this.collision.nearby((x1 + x2) / 2, (y1 + y2) / 2,
          Math.hypot(x2 - x1, y2 - y1) / 2 + hitRadius, this.candidates);
        for (const enemy of this.candidates) {
          if (enemy.hp <= 0) continue;
          const key = `${weapon.id}:${blade}:${enemy.id}`;
          if (now - (this.orbitLastHit.get(key) ?? -Infinity) < stats.cooldown) continue;
          if (!Number.isFinite(segmentCircleHit(x1, y1, x2, y2, enemy.x, enemy.y, hitRadius + enemy.radius))) continue;
          this.collision.hit(enemy, stats.damage, run, context, weapon.visual.color);
          this.orbitLastHit.set(key, now);
          hit = true;
        }
      }
    }
    this.orbitPrevious.set(weapon.id, { x: run.player.x, y: run.player.y, time: now });
    this.candidates.length = 0;
    return hit;
  }
  private schedule(kind: 'slash' | 'bombard', x: number, y: number, delay: number, radius: number, angle: number, arc: number, stats: ResolvedWeaponStats, context: AttackContext, color: number, startX = x, startY = y, flightDuration = 0): void {
    if (this.pending.length >= WEAPON_CONFIG.maxEffects) return;
    this.pending.push({ kind, x, y, startX, startY, delay, flightDuration, projectileSpawned: false, radius, angle, arc, damage: stats.damage, context, color, duration: stats.duration });
  }
  update(run: RunState, dt: number): void {
    let kept = 0;
    for (const p of this.pending) {
      p.delay -= dt;
      if (p.kind === 'bombard' && !p.projectileSpawned && p.delay <= p.flightDuration) {
        p.projectileSpawned = true;
        spawnRunEffect(run, 'bombardProjectile', {
          x: p.startX,
          y: p.startY,
          endX: p.x,
          endY: p.y,
          radius: Math.max(12, p.radius * 0.17),
          color: p.color,
          duration: Math.max(0.12, p.flightDuration),
        });
      }
      if (p.delay > 0) { this.pending[kept++] = p; continue; }
      let targetDistance = p.radius;
      if (p.kind === 'bombard') {
        this.area(p.x, p.y, p.radius, p.damage, run, p.context);
        this.emit('bombardAttack');
      }
      else {
        this.collision.nearby(p.x, p.y, p.radius, this.candidates);
        for (const e of this.candidates) {
          const dx = e.x - p.x, dy = e.y - p.y;
          const angle = Math.atan2(Math.sin(Math.atan2(dy, dx) - p.angle), Math.cos(Math.atan2(dy, dx) - p.angle));
          const distance = Math.hypot(dx, dy);
          if (e.hp > 0 && distance <= p.radius && Math.abs(angle) <= p.arc / 2) {
            targetDistance = Math.min(targetDistance, distance);
            this.collision.hit(e, p.damage, run, p.context, p.color);
          }
        }
      }
      const shift = p.kind === 'slash' ? targetDistance - p.radius : 0;
      spawnRunEffect(run, p.kind, {
        x: p.x + Math.cos(p.angle) * shift,
        y: p.y + Math.sin(p.angle) * shift,
        radius: p.radius,
        angle: p.angle,
        arc: p.arc,
        color: p.color,
      });
    }
    this.pending.length = kept; this.clearReferences();
  }
  cancel(): void { this.pending.length = 0; this.orbitPrevious.clear(); this.orbitLastHit.clear(); this.clearReferences(); }
  clearReferences(): void { this.candidates.length = 0; this.hitIds.clear(); }
  private area(x: number, y: number, radius: number, damage: number, run: RunState, context: AttackContext): void {
    this.collision.nearby(x, y, radius, this.candidates);
    for (const enemy of this.candidates) if ((enemy.x - x) ** 2 + (enemy.y - y) ** 2 <= radius ** 2) this.collision.hit(enemy, damage, run, context);
  }
}
