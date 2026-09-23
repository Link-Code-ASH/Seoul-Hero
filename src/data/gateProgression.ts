import type { EliteModifierId } from './eliteModifiers';
import type { Wave } from './types';

export const GATE_CONFIG = {
  firstClearReward: 100,
  failureRewardPerCompletedWave: 1,
  hpPerDepth: 0.06,
  damagePerDepth: 0.035,
  spawnPerDepth: 0.02,
  speedPerDepth: 0.001,
  speedMultiplierCap: 1.1,
  spawnMultiplierCap: 3,
  eliteChancePerDepth: 0.002,
  eliteChanceCap: 0.25,
} as const;

export interface GateMilestone {
  depth: number;
  enemyAdditions?: { enemyId: string; fromWave: number; weight: number }[];
  eliteModifiers?: EliteModifierId[];
  bossId?: string;
  spawnMultiplier?: number;
}

/** Ten-depth content beats are cumulative. Add future roster/boss changes here. */
export const GATE_MILESTONES: readonly GateMilestone[] = [
  { depth: 10, enemyAdditions: [{ enemyId: 'lurker', fromWave: 11, weight: 1 }], eliteModifiers: ['ARMORED'], spawnMultiplier: 1.08 },
  { depth: 20, bossId: 'riftQueen', eliteModifiers: ['BERSERK', 'REGENERATING'], spawnMultiplier: 1.08 },
];

export interface EnemyDifficulty {
  hp: number;
  damage: number;
  speed: number;
  spawn: number;
  reward: number;
  eliteChance: number;
  eliteModifiers: EliteModifierId[];
}

export function gateDifficulty(depth: number): EnemyDifficulty {
  const d = Math.max(1, Math.floor(depth));
  const offset = d - 1;
  const milestones = GATE_MILESTONES.filter(entry => entry.depth <= d);
  const milestoneSpawn = milestones.reduce((value, entry) => value * (entry.spawnMultiplier ?? 1), 1);
  return {
    hp: 1 + offset * GATE_CONFIG.hpPerDepth,
    damage: 1 + offset * GATE_CONFIG.damagePerDepth,
    speed: Math.min(GATE_CONFIG.speedMultiplierCap, 1 + offset * GATE_CONFIG.speedPerDepth),
    spawn: Math.min(GATE_CONFIG.spawnMultiplierCap, (1 + offset * GATE_CONFIG.spawnPerDepth) * milestoneSpawn),
    reward: 1,
    eliteChance: Math.min(GATE_CONFIG.eliteChanceCap, offset * GATE_CONFIG.eliteChancePerDepth),
    eliteModifiers: [...new Set(milestones.flatMap(entry => entry.eliteModifiers ?? []))],
  };
}

export function resolveGateWave(wave: Wave, depth: number, bossWave: number): Wave {
  const additions = GATE_MILESTONES.filter(entry => entry.depth <= depth).flatMap(entry => entry.enemyAdditions ?? []);
  const enemies = [...wave.enemies];
  for (const addition of additions) {
    if (wave.waveNumber < addition.fromWave || enemies.some(entry => entry.enemyId === addition.enemyId)) continue;
    enemies.push({ enemyId: addition.enemyId, weight: addition.weight });
  }
  const bossId = wave.waveNumber === bossWave
    ? [...GATE_MILESTONES].reverse().find(entry => entry.depth <= depth && entry.bossId)?.bossId
    : undefined;
  return { ...wave, enemies, boss: bossId ? { enemyId: bossId } : wave.boss };
}
