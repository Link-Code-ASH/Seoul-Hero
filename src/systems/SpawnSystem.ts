import { createEnemy, curseBonuses } from './EnemyFactory';
import type { EliteModifierId } from '../data/eliteModifiers';
import { enemies } from '../data/enemies';
import { SIMULATION_CONFIG } from '../data/simulationConfig';
import type { MapData, Wave } from '../data/types';
import type { Enemy } from '../entities/types';
import type { RunState } from '../state/RunState';
import { arenaSpawn } from '../world/Arena';
import { weightedIndex } from '../utils/math';
import { ignoreGameEvent } from '../core/GameEvents';
import type { GameEventSink } from '../core/GameEvents';
import { resolveGateWave } from '../data/gateProgression';

export interface Viewport { width: number; height: number }

export function currentWave(stage: MapData, number: number): Wave | undefined { return stage.waveDefinitions.find(w => w.waveNumber === number); }

export class SpawnSystem {
  private nextSpawn = 0;
  private readonly triggeredElites = new Set<number>();
  private readonly waveCache = new Map<number, Wave>();

  constructor(private readonly stage: MapData, private readonly random: () => number, private readonly nextId: () => number, private readonly emit: GameEventSink = ignoreGameEvent) {}

  reset(): void { this.nextSpawn = 0; this.triggeredElites.clear(); }

  update(state: RunState, dt: number, viewport: Viewport): void {
    if (state.phase !== 'waveActive') return;
    const wave = this.wave(state.currentWave, state.gateDepth);
    if (!wave) return;
    state.waveId = wave.id;
    if (state.currentWave === this.stage.bossWave) { this.boss(state, viewport); return; }
    (wave.elites ?? []).forEach((event, index) => {
      if (state.waveElapsedTime < event.at || this.triggeredElites.has(index)) return;
      this.triggeredElites.add(index);
      this.spawn(state, event.enemyId, viewport, false, event.hpMultiplier, event.rewardMultiplier, event.modifiers);
    });
    if (!wave) return;
    this.nextSpawn -= dt;
    if (this.nextSpawn > 0) return;
    this.nextSpawn = Math.max(0, this.nextSpawn) + wave.interval / (curseBonuses(state.calculatedStats.curse).spawn * state.enemyDifficulty.spawn);
    const weights = wave.enemies.map((entry) => entry.weight);
    const amount = Math.min(wave.batch, wave.maxEnemies - state.enemies.length);
    for (let i = 0; i < amount; i++) {
      const entry = wave.enemies[weightedIndex(weights, this.random)];
      if (entry) {
        const chance = Math.min(0.75, curseBonuses(state.calculatedStats.curse).eliteChance + state.enemyDifficulty.eliteChance);
        const pool: EliteModifierId[] = state.enemyDifficulty.eliteModifiers.length ? state.enemyDifficulty.eliteModifiers : ['FAST'];
        this.spawn(state, entry.enemyId, viewport, false, 1, 1, chance > 0 && this.random() < chance ? [pool[Math.floor(this.random() * pool.length)]!] : []);
      }
    }
  }

  spawn(state: RunState, enemyId: string, viewport: Viewport, boss = false, hpMultiplier = 1, rewardMultiplier = 1, modifiers: readonly EliteModifierId[] = []): Enemy | undefined {
    const definition = Object.hasOwn(enemies, enemyId) ? enemies[enemyId] : undefined;
    if (!definition || (!boss && state.enemies.length >= SIMULATION_CONFIG.maxDebugEnemies)) return undefined;
    const entity = createEnemy(this.nextId(), enemyId, { x: 0, y: 0 }, state.calculatedStats.curse, modifiers, boss, hpMultiplier, rewardMultiplier, state.enemyDifficulty);
    if (!entity) return undefined;
    const position = arenaSpawn(state.player, viewport, entity.radius, this.stage, this.random);
    if (!position) return undefined;
    entity.x = position.x; entity.y = position.y;
    state.enemies.push(entity);
    if(entity.elite && !entity.boss) this.emit('eliteSpawned');
    return entity;
  }

  boss(state: RunState, viewport: Viewport): void {
    if (state.bossSpawned || state.currentWave !== this.stage.bossWave) return;
    const boss = this.wave(state.currentWave, state.gateDepth)?.boss;
    if (boss && this.spawn(state, boss.enemyId, viewport, true)) { state.bossSpawned = true; this.emit('bossSpawned'); }
  }
  private wave(number: number, depth: number): Wave | undefined {
    const cached = this.waveCache.get(number);
    if (cached) return cached;
    const base = currentWave(this.stage, number);
    if (!base) return undefined;
    const resolved = resolveGateWave(base, depth, this.stage.bossWave);
    this.waveCache.set(number, resolved);
    return resolved;
  }
}
