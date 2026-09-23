import { ignoreGameEvent, type GameEventSink } from '../core/GameEvents';
import { STRUCTURE_CONFIG } from '../data/structureConfig';
import { weapons } from '../data/weapons';
import { maps } from '../data/maps';
import type { Weapon } from '../data/types';
import type { Enemy } from '../entities/types';
import type { RunState } from '../state/RunState';
import { resolveWeaponStats, type ResolvedWeaponStats } from '../stats/WeaponStats';
import { attackContext } from '../stats/Damage';
import type { CollisionSystem } from './CollisionSystem';
import { spawnRunEffect } from './RunEffectSystem';
export const STRUCTURE_LIMIT = STRUCTURE_CONFIG.hardLimit;
export function structureLimit(run: RunState, weapon: Weapon): number {
  return Math.min(STRUCTURE_LIMIT, Math.max(1, Math.floor((weapon.structure?.maxCount ?? 1) + run.structureEffects.reduce((n,e) => n + (weapon.capabilities.includes(e.tag) ? e.value : 0),0))));
}
export class StructureSystem {
  private readonly candidates: Enemy[] = [];
  constructor(private readonly collision: CollisionSystem, private readonly nextId: () => number, private readonly emit: GameEventSink = ignoreGameEvent, private readonly random: () => number = Math.random) {}
  private safePosition(run: RunState, ignoreId = -1, avoid?: { x: number; y: number }): { x: number; y: number } {
    const arena = maps[run.mapId]!;
    const halfWidth = Math.max(0, arena.arenaWidth / 2 - STRUCTURE_CONFIG.boundaryMargin);
    const halfHeight = Math.max(0, arena.arenaHeight / 2 - STRUCTURE_CONFIG.boundaryMargin);
    let best = { x: 0, y: 0 }, bestClearance = -1;
    for (let attempt = 0; attempt < 24; attempt++) {
      const candidate = { x: (this.random() * 2 - 1) * halfWidth, y: (this.random() * 2 - 1) * halfHeight };
      const playerDistance = Math.hypot(candidate.x - run.player.x, candidate.y - run.player.y);
      let clearance = playerDistance - 160;
      if (avoid) clearance = Math.min(clearance, Math.hypot(candidate.x - avoid.x, candidate.y - avoid.y) - 80);
      for (const structure of run.structures) {
        if (structure.id === ignoreId) continue;
        clearance = Math.min(clearance, Math.hypot(candidate.x - structure.x, candidate.y - structure.y) - 60);
      }
      if (clearance > bestClearance) { best = candidate; bestClearance = clearance; }
      if (clearance >= 0) return candidate;
    }
    if (avoid && Math.hypot(best.x - avoid.x, best.y - avoid.y) < 80) return {
      x: (ignoreId % 2 === 0 ? -1 : 1) * halfWidth * 0.72,
      y: (Math.floor(ignoreId / 2) % 2 === 0 ? -1 : 1) * halfHeight * 0.72,
    };
    return best;
  }
  place(run: RunState, weapon: Weapon, _stats: ResolvedWeaponStats): void {
    if (!weapon.structure) return;
    const count = run.structures.filter(s => s.weaponId === weapon.id).length;
    if (count >= structureLimit(run, weapon) || run.structures.length >= STRUCTURE_LIMIT) return;
    if(weapon.structure.kind==='mine') this.emit('minePlaced');
    if(weapon.structure.kind==='aura') this.emit('fieldActivated');
    const position = this.safePosition(run);
    run.structures.push({id:this.nextId(),weaponId:weapon.id,x:position.x,y:position.y,remaining:Number.POSITIVE_INFINITY,cooldown:0});
  }
  /** Structures persist for the Run, but each Wave receives a fresh tactical layout. */
  relocateForWave(run: RunState): void {
    for (let index = 0; index < run.structures.length; index++) {
      const structure = run.structures[index]!;
      const position = this.safePosition(run, structure.id, structure);
      structure.x = position.x; structure.y = position.y;
      structure.cooldown = index * 0.08;
    }
  }
  update(run: RunState, dt: number, fire: (w: Weapon,s: ResolvedWeaponStats,t: Enemy,origin:{x:number;y:number})=>void): void {
    let kept=0;
    for (const entity of run.structures) {
      const slot=run.ownedWeapons.find(s=>s.id===entity.weaponId), w=weapons[entity.weaponId];
      entity.remaining-=dt;
      if (!slot || !w?.structure || entity.remaining<=0) continue;
      const stats=resolveWeaponStats(w,slot.level,run.calculatedStats,run.combatPermissions.indirectLifesteal,slot.branchId,run.itemEffects);
      entity.cooldown-=dt;
      if (entity.cooldown<=0) {
        const kind=w.structure.kind;
        if (kind==='turret') {
          const target=this.collision.nearest(entity.x,entity.y,stats.range);
          if (target) { fire(w,stats,target,entity); entity.cooldown=stats.cooldown; }
        } else {
          this.collision.nearby(entity.x,entity.y,kind==='mine'?w.structure.triggerRadius:stats.blastRadius,this.candidates);
          const triggered=kind==='aura'||this.candidates.some(e=>e.hp>0 && Math.hypot(e.x-entity.x,e.y-entity.y)<=w.structure!.triggerRadius+e.radius);
          if (triggered) {
            this.collision.nearby(entity.x,entity.y,stats.blastRadius,this.candidates);
            const context=attackContext(stats,run.player.maxHp,w.id);
            for (const e of this.candidates) if (Math.hypot(e.x-entity.x,e.y-entity.y)<=stats.blastRadius) this.collision.hit(e,stats.damage,run,context,w.visual.color);
            if (kind==='mine') {
              this.emit('mineExploded');
              entity.remaining=0;
              spawnRunEffect(run, 'mineBlast', { x: entity.x, y: entity.y, radius: stats.blastRadius, color: w.visual.color });
            }
            entity.cooldown=stats.cooldown;
          }
        }
      }
      if(entity.remaining>0) run.structures[kept++]=entity;
    }
    run.structures.length=kept; this.candidates.length=0;
  }
}

