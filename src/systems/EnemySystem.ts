import { maps } from '../data/maps';
import { enemies } from '../data/enemies';
import { ENEMY_RULES as R } from '../data/enemyConfig';
import { SIMULATION_CONFIG } from '../data/simulationConfig';
import { clampToArena } from '../world/Arena';
import type { Enemy } from '../entities/types';
import type { RunState } from '../state/RunState';
import { SpatialGrid } from '../utils/SpatialGrid';
import { HostileAttackSystem } from './HostileAttackSystem';
import { createEnemy } from './EnemyFactory';
import { enemyBehaviors, type EnemyContext } from './EnemyBehaviors';
import type { GameEventSink } from '../core/GameEvents';
export class EnemySystem {
  readonly attacks: HostileAttackSystem;
  private readonly grid = new SpatialGrid<Enemy>(160);
  private readonly candidates: Enemy[] = [];
  private readonly pending: Enemy[] = [];
  constructor(private readonly nextId: () => number, random: () => number, emit: GameEventSink) { this.attacks = new HostileAttackSystem(random, emit); }
  private nearby = (enemy: Enemy, radius: number): readonly Enemy[] => {
    this.grid.query(enemy.x - radius, enemy.y - radius, enemy.x + radius, enemy.y + radius, this.candidates);
    return this.candidates;
  };
  private summon(run: RunState, parent: Enemy, id: string, count: number): void {
    const cap = maps[run.mapId]!.waveDefinitions[run.currentWave - 1]!.maxEnemies;
    for (let i = 0; i < count && parent.summonCount < R.maxSummonsPerEnemy && run.enemies.length + this.pending.length < Math.min(cap, SIMULATION_CONFIG.maxDebugEnemies); i++) {
      const angle = parent.summonCount * 2.4;
      const child = createEnemy(this.nextId(), id, { x: parent.x + Math.cos(angle) * R.summonOffset, y: parent.y + Math.sin(angle) * R.summonOffset }, run.calculatedStats.curse, [], false, 1, 1, run.enemyDifficulty);
      if (!child) continue;
      child.magicStoneDrop *= R.summonedRewardMultiplier;
      clampToArena(child, child.radius, maps[run.mapId]!); this.pending.push(child); parent.summonCount++;
    }
  }
  update(run: RunState, dt: number): void {
    this.grid.rebuild(run.enemies);
    const context: EnemyContext = { run, dt, def: enemies.crawler!, attacks: this.attacks, nearby: this.nearby, summon: (parent, id, count) => this.summon(run, parent, id, count) };
    for (const e of run.enemies) {
      if (e.hp <= 0) continue;
      const def = enemies[e.definitionId]; if (!def) continue;
      context.def = def; e.age += dt; e.timer -= dt; e.hitFlash = Math.max(0, e.hitFlash - dt);
      if (e.regeneration > 0) e.hp = Math.min(e.maxHp, e.hp + e.maxHp * e.regeneration * dt);
      const arena = maps[run.mapId]!;
      const entering = Math.abs(e.x) > arena.arenaWidth / 2 - e.radius || Math.abs(e.y) > arena.arenaHeight / 2 - e.radius;
      if (entering) {
        const dx = run.player.x - e.x, dy = run.player.y - e.y;
        const distance = Math.hypot(dx, dy) || 1;
        const step = Math.min(distance, e.moveSpeed * dt);
        e.x += dx / distance * step; e.y += dy / distance * step;
      } else enemyBehaviors[def.behavior](e, context);
      if (e.cursedAura && (e.auraTimer -= dt) <= 0) { this.attacks.area(run, e.x, e.y, R.auraRadius, R.auraWarning, R.auraDamage); e.auraTimer = R.auraInterval; }
      if (!entering) clampToArena(e, e.radius, arena);
    }
    this.flush(run); this.releaseReferences(); this.attacks.update(run, dt);
  }
  onDeath = (run: RunState, enemy: Enemy): void => {
    const def = enemies[enemy.definitionId];
    if (def?.behavior === 'splitter' && def.childId) this.summon(run, enemy, def.childId, R.splitCount);
  };
  flush(run: RunState): void { if (run.phase === 'waveActive') run.enemies.push(...this.pending); this.pending.length = 0; }
  releaseReferences(): void { this.grid.rebuild([]); this.candidates.length = 0; }
  clear(run: RunState): void { this.pending.length = 0; this.releaseReferences(); this.attacks.clear(run); }
}

