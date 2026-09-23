import { damagePlayer } from './PlayerDamageSystem';
import { outgoingDamage, applyLifesteal, armorDamage, type AttackContext } from '../stats/Damage';
import { GAME_CONFIG } from '../data/config';
import { SIMULATION_CONFIG } from '../data/simulationConfig';
import type { Enemy, Projectile } from '../entities/types';
import type { RunState } from '../state/RunState';
import { SpatialGrid } from '../utils/SpatialGrid';
import { distanceSquared, segmentCircleHit } from '../utils/math';
import { ignoreGameEvent } from '../core/GameEvents';
import type { GameEventSink } from '../core/GameEvents';
import { spawnRunEffect } from './RunEffectSystem';

export type DamageObserver = (weaponId: string | undefined, damage: number, critical: boolean, killed: boolean) => void;
export class CollisionSystem {
  private readonly grid = new SpatialGrid<Enemy>(GAME_CONFIG.combat.gridCellSize);
  private readonly candidates: Enemy[] = [];
  private largestRadius = 0;
  private enemyCount = 0;

  constructor(private readonly emit: GameEventSink = ignoreGameEvent, private readonly random: () => number = Math.random, private readonly observeDamage: DamageObserver = () => {}, private readonly observePlayerHit: (enemyId:string)=>void = () => {}) {}

  rebuild(enemies: readonly Enemy[]): void {
    this.candidates.length = 0;
    this.enemyCount = enemies.length;
    this.largestRadius = 0;
    for (const enemy of enemies) this.largestRadius = Math.max(this.largestRadius, enemy.radius);
    this.grid.rebuild(enemies);
  }

  nearest(x: number, y: number, range: number): Enemy | undefined {
    if (this.enemyCount === 0) return undefined;
    this.grid.query(x - range, y - range, x + range, y + range, this.candidates);
    let nearest: Enemy | undefined;
    let minimum = range * range;
    for (const enemy of this.candidates) {
      if (enemy.hp <= 0) continue;
      const distance = (enemy.x - x) ** 2 + (enemy.y - y) ** 2;
      if (distance <= minimum) { minimum = distance; nearest = enemy; }
    }
    return nearest;
  }

  /** A swept circle catches thin targets even when a projectile crosses them in one step. */
  nearby(x: number, y: number, radius: number, output: Enemy[]): void {
    const margin = radius + this.largestRadius;
    this.grid.query(x - margin, y - margin, x + margin, y + margin, output);
  }
  hit(enemy: Enemy, damage: number, run?: RunState, context?: AttackContext, color = 0x8fdcff): void {
    if (enemy.hp <= 0) return;
    const rolled = outgoingDamage(damage, context, this.random);
    const critical = rolled > damage;
    if (critical) this.emit('critical');
    const actual = Math.min(enemy.hp, armorDamage(rolled, enemy.armor));
    enemy.hp -= actual;
    this.observeDamage(context?.sourceWeaponId, actual, critical, enemy.hp <= 0);
    if (run) applyLifesteal(run, actual, context);
    if (run) spawnRunEffect(run, critical ? 'criticalImpact' : 'impact', {
      x: enemy.x,
      y: enemy.y,
      radius: Math.max(12, Math.min(34, enemy.radius * (critical ? 0.82 : 0.56))),
      color,
    });
    enemy.hitFlash = SIMULATION_CONFIG.hitFlashSeconds; this.emit('enemyHit');
  }

  projectile(projectile: Projectile, endX: number, endY: number, run?: RunState): boolean {
    const margin = this.largestRadius + projectile.radius;
    this.grid.query(Math.min(projectile.x, endX) - margin, Math.min(projectile.y, endY) - margin,
      Math.max(projectile.x, endX) + margin, Math.max(projectile.y, endY) + margin, this.candidates);
    while (true) {
      let first: Enemy | undefined;
      let firstTime = Infinity;
      for (const enemy of this.candidates) {
        if (enemy.hp <= 0 || projectile.hitIds.has(enemy.id)) continue;
        const time = segmentCircleHit(projectile.x, projectile.y, endX, endY,
          enemy.x, enemy.y, projectile.radius + enemy.radius);
        if (time < firstTime) { firstTime = time; first = enemy; }
      }
      if (!first) return false;
      this.hit(first, projectile.damage, run, projectile.attack, projectile.visual.color);
      projectile.hitIds.add(first.id);
      if (projectile.penetration <= 0) return true;
      projectile.penetration--;
    }
  }

  player(state: RunState): void {
    const player = state.player;
    if (state.invincible || player.invulnerability > 0) return;
    const margin = this.largestRadius + player.radius;
    this.grid.query(player.x - margin, player.y - margin, player.x + margin, player.y + margin, this.candidates);
    for (const enemy of this.candidates) {
      if (enemy.hp <= 0 || distanceSquared(enemy, player) > (enemy.radius + player.radius) ** 2) continue;
      if(damagePlayer(state, enemy.contactDamage, this.random, this.emit))this.observePlayerHit(enemy.definitionId);
      return;
    }
  }
}
