import { StructureSystem } from './StructureSystem';
import { resolveWeaponStats, type ResolvedWeaponStats } from '../stats/WeaponStats';
import { attackContext } from '../stats/Damage';
import { maps } from '../data/maps';
import { ARENA_RULES } from '../world/Arena';
import { GAME_CONFIG } from '../data/config';
import { weapons } from '../data/weapons';
import type { Weapon } from '../data/types';
import type { Enemy, Projectile } from '../entities/types';
import type { RunState } from '../state/RunState';
import { ObjectPool } from '../utils/ObjectPool';
import { CollisionSystem, type DamageObserver } from './CollisionSystem';
import type { PickupSystem } from './PickupSystem';
import { ignoreGameEvent } from '../core/GameEvents';
import type { GameEventSink } from '../core/GameEvents';
import { WeaponBehaviors } from './WeaponBehaviors';
import { transitionRun } from '../state/RunPhase';
import { spawnRunEffect } from './RunEffectSystem';

export function calculateDamage(base: number, multiplier: number): number {
  return Math.max(0, Math.round(base * multiplier));
}

export function weaponStats(definition: Weapon, level: number, state: RunState): ResolvedWeaponStats {
  return resolveWeaponStats(definition, level, state.calculatedStats, state.combatPermissions.indirectLifesteal, state.ownedWeapons.find(w => w.id === definition.id)?.branchId, state.itemEffects);
}

export class CombatSystem {
  readonly structures: StructureSystem;
  readonly collisions: CollisionSystem;
  private readonly behaviors: WeaponBehaviors;
  private readonly projectilePool = new ObjectPool<Projectile>(() => ({
    id: 0, x: 0, y: 0, vx: 0, vy: 0, radius: 0, damage: 0,
    remaining: 0, penetration: 0, hitIds: new Set(), visual: { color: 0, shape: 'circle' },
  }));

  constructor(private readonly nextId: () => number, private readonly pickups: PickupSystem, _clearReward: number, private readonly emit: GameEventSink = ignoreGameEvent, random: () => number = Math.random, private readonly onDeath: (state: RunState, enemy: Enemy) => void = () => {}, observeDamage: DamageObserver = () => {}, observePlayerHit: (enemyId:string)=>void = () => {}) {
    this.collisions = new CollisionSystem(emit, random, observeDamage, observePlayerHit);
    this.behaviors = new WeaponBehaviors(this.collisions, emit);
    this.structures = new StructureSystem(this.collisions, nextId, emit, random);
  }

  clearWave(state: RunState): void {
    this.behaviors.cancel();
    for (const projectile of state.projectiles) { projectile.hitIds.clear(); projectile.attack = undefined; this.projectilePool.release(projectile); }
    state.projectiles.length = 0; state.enemies.length = 0; state.effects.length = 0;
    this.collisions.rebuild(state.enemies);
  }
  update(state: RunState, dt: number): void {
    const arena = maps[state.mapId]!;
    let effectsKept = 0;
    for (const effect of state.effects) { effect.remaining -= dt; if (effect.remaining > 0) state.effects[effectsKept++] = effect; }
    state.effects.length = effectsKept;
    this.collisions.rebuild(state.enemies);
    this.behaviors.update(state, dt);
    this.attack(state, dt);
    this.structures.update(state, dt, (w,s,t,o) => this.fireProjectiles(state,w,s,t,o));
    let kept = 0;
    for (const projectile of state.projectiles) {
      const activeDelta = Math.min(projectile.remaining, dt);
      const endX = projectile.x + projectile.vx * activeDelta;
      const endY = projectile.y + projectile.vy * activeDelta;
      const consumed = this.collisions.projectile(projectile, endX, endY, state);
      projectile.remaining -= dt;
      projectile.x = endX;
      projectile.y = endY;
      if (consumed || projectile.remaining <= 0 || Math.abs(endX) > arena.arenaWidth / 2 + ARENA_RULES.projectileMargin || Math.abs(endY) > arena.arenaHeight / 2 + ARENA_RULES.projectileMargin) {
        projectile.hitIds.clear();
        projectile.attack = undefined; this.projectilePool.release(projectile);
      } else state.projectiles[kept++] = projectile;
    }
    state.projectiles.length = kept;
    this.resolveDeaths(state);
    if (state.phase === 'waveActive') this.collisions.player(state);
  }

  resolveDeaths(state: RunState): void {
    let kept = 0;
    for (const enemy of state.enemies) {
      if (enemy.hp > 0) { state.enemies[kept++] = enemy; continue; }
      if (!enemy.rewardEligible) continue;
      state.kills++;
      this.emit('enemyKilled');

      spawnRunEffect(state, 'enemyDeath', {
        x: enemy.x,
        y: enemy.y,
        radius: Math.max(18, enemy.radius * 0.82),
        color: enemy.visual.color,
        seed: enemy.id,
      });

      this.pickups.drop(state, enemy.x, enemy.y, enemy.magicStoneDrop);
      this.onDeath(state, enemy);
      if (enemy.boss) {

        transitionRun(state, 'stageClear');
        this.emit('stageClear');
      }
    }
    state.enemies.length = kept;
    this.collisions.rebuild(state.enemies);
  }

  private attack(state: RunState, dt: number): void {
    for (const slot of state.ownedWeapons) {
      slot.cooldownRemaining = Math.max(0, slot.cooldownRemaining - dt);
      const definition = weapons[slot.id];
      if (!definition) continue;
      // Orbiting blades are visible every frame, so their collision path must
      // also be checked every frame instead of only at attack intervals.
      if (definition.behavior === 'orbit') {
        const stats = weaponStats(definition, slot.level, state);
        if (this.behaviors.updateOrbit(state, definition, stats, dt) && slot.cooldownRemaining === 0) {
          this.emit('orbitAttack');
          slot.cooldownRemaining = stats.cooldown;
        }
        continue;
      }
      if (slot.cooldownRemaining > 0) continue;
      const stats = weaponStats(definition, slot.level, state);
      if (definition.structure) {
        this.structures.place(state,definition,stats);
        slot.cooldownRemaining = definition.structure.kind === 'mine' ? stats.cooldown : definition.structure.placementInterval;
        continue;
      }
      const target = this.collisions.nearest(state.player.x, state.player.y, stats.range);
      if (!target) continue;
      if (definition.behavior === 'projectile') this.fireProjectiles(state, definition, stats, target!);
      else {
        this.behaviors.attack(state, definition, stats, target);
        if (definition.behavior !== 'bombard') this.emit(definition.behavior === 'slash' ? 'slashAttack' : 'chainAttack');
      }
      slot.cooldownRemaining += stats.cooldown;
    }
  }

  private fireProjectiles(state: RunState, definition: Weapon, stats: ResolvedWeaponStats, target: Enemy, origin: {x:number;y:number} = state.player): void {
    if (state.projectiles.length < GAME_CONFIG.combat.maxProjectiles) this.emit(definition.structure ? 'turretFired' : definition.base.penetration > 0 ? 'piercingAttack' : 'weaponFired');
    const context = attackContext(stats, state.player.maxHp, definition.id);
    const direction = Math.atan2(target.y - origin.y, target.x - origin.x);
    spawnRunEffect(state, 'muzzle', {
      x: origin.x,
      y: origin.y,
      radius: Math.max(12, stats.projectileRadius * 2.25),
      angle: direction,
      color: definition.visual.color,
    });
    for (let i = 0; i < stats.projectileCount && state.projectiles.length < GAME_CONFIG.combat.maxProjectiles; i++) {
      const angle = direction + (i - (stats.projectileCount - 1) / 2) * GAME_CONFIG.combat.projectileSpread;
      const projectile = this.projectilePool.acquire();
      projectile.id = this.nextId();
      projectile.x = origin.x;
      projectile.y = origin.y;
      projectile.vx = Math.cos(angle) * stats.projectileSpeed;
      projectile.vy = Math.sin(angle) * stats.projectileSpeed;
      projectile.radius = stats.projectileRadius;
      projectile.damage = stats.damage;
      projectile.attack = context;
      projectile.remaining = definition.structure ? stats.range / stats.projectileSpeed : Math.min(stats.duration, stats.range / stats.projectileSpeed);
      projectile.penetration = stats.penetration;
      projectile.visual = definition.visual; projectile.fromStructure = !!definition.structure;
      projectile.hitIds.clear();
      state.projectiles.push(projectile);
    }
  }
}

