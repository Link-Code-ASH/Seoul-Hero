import type { EliteModifierId } from './eliteModifiers';
import { enemies as enemyDefinitions } from './enemies';
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
  /** Added to every featured elite of the Wave table. */
  featuredEliteModifiers?: EliteModifierId[];
  eliteModifiers?: EliteModifierId[];
  spawnMultiplier?: number;
}

/** Ten-depth difficulty beats are cumulative. The cast of a map never changes with depth. */
export const GATE_MILESTONES: readonly GateMilestone[] = [
  { depth: 10, eliteModifiers: ['ARMORED'], featuredEliteModifiers: ['CURSED_AURA'], spawnMultiplier: 1.08 },
  { depth: 20, eliteModifiers: ['BERSERK', 'REGENERATING'], spawnMultiplier: 1.08 },
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

const WEEK_SECONDS = 604_800;
/** Weeks since the first Sunday 05:00 KST (Saturday 20:00 UTC) of the Unix epoch; the weekly gate rule resets on the same boundary. */
export const weekNumber = (unixSeconds: number): number => Math.floor((unixSeconds - 244_800) / WEEK_SECONDS);

/**
 * One weekly monster for every map: it leads the listed Waves with `share` of the Wave weight
 * and the authored slots shrink to fit. The pool is a shuffle bag: every pool.length weeks each
 * monster comes up once in a random order, and no monster comes up two weeks in a row.
 *
 * `enabled` is the one switch for the whole feature (web and Godot). While it is false no Wave gets a
 * weekly lead, the gate screen shows no weekly monster and the map's archive lists no weekly-only monster.
 */
export const WEEKLY_MONSTER = {
  enabled: true as boolean,
  // One monster per weekly pattern: 소환, 분열, 자폭.
  pool: ['summoner', 'splitter', 'lampFirefly'],
  // Former weekly monsters. Their data and art stay; no week, Wave lead or map archive uses them.
  reserve: ['swarm', 'ironBoar', 'chainWarden', 'sentinel', 'paperCrane', 'tileTortoise', 'fenceSerpent', 'riverEel', 'lampDrop', 'borderDrop'],
  waves: [3, 6, 9, 12, 15, 18],
  share: 0.35,
} as const;

/** The pool in the order one bag deals it. */
function weeklyBag(bag: number, pool: readonly string[]): string[] {
  // Park–Miller steps stay below 2^53, so GDScript and JS draw the same numbers.
  // The xorshift between two steps breaks the straight line that neighbouring bag numbers would otherwise draw along.
  let state = ((bag * 131) % 2_147_483_646 + 2_147_483_646) % 2_147_483_646 + 1;
  const next = () => {
    state = state * 48_271 % 2_147_483_647;
    state = (state ^ (state >>> 15)) % 2_147_483_646 + 1;
    return (state = state * 48_271 % 2_147_483_647);
  };
  next();
  const order = [...pool];
  for (let index = order.length - 1; index > 0; index -= 1) {
    const other = next() % (index + 1);
    [order[index], order[other]] = [order[other]!, order[index]!];
  }
  return order;
}

/** This week's monster. Mirrors HeroRoster.weekly_monster in godot/scripts/systems/roster.gd. */
export function weeklyMonster(week: number, pool: readonly string[] = WEEKLY_MONSTER.pool): string {
  const size = pool.length, bag = Math.floor(week / size);
  const order = weeklyBag(bag, pool);
  // A bag never opens with the monster that closed the one before; swapping the first two slots leaves its own last slot alone.
  if (size > 2 && order[0] === weeklyBag(bag - 1, pool)[size - 1]) [order[0], order[1]] = [order[1]!, order[0]!];
  return order[((week % size) + size) % size]!;
}

/** The elite a Run meets on every elite Wave; roll is the Run's one random draw in [0, 1). */
export const runElite = (pool: readonly string[] | undefined, roll: number): string | undefined =>
  pool?.length ? pool[Math.min(pool.length - 1, Math.floor(roll * pool.length))] : undefined;

/** Wave as one Run plays it: the weekly lead, the Run's elite body and the depth's elite modifiers. */
export function resolveGateWave(wave: Wave, depth: number, run: { week?: number; eliteId?: string } = {}): Wave {
  const milestones = GATE_MILESTONES.filter(entry => entry.depth <= depth);
  let enemies = [...wave.enemies];
  const weekly = run.week === undefined || !WEEKLY_MONSTER.enabled ? undefined : weeklyMonster(run.week);
  if (weekly && (WEEKLY_MONSTER.waves as readonly number[]).includes(wave.waveNumber) && !enemies.some(entry => entry.enemyId === weekly)) {
    const total = enemies.reduce((sum, entry) => sum + entry.weight, 0);
    enemies = [{ enemyId: weekly, weight: total * WEEKLY_MONSTER.share }, ...enemies.map(entry => ({ ...entry, weight: entry.weight * (1 - WEEKLY_MONSTER.share) }))];
  }
  const featuredModifiers = milestones.flatMap(entry => entry.featuredEliteModifiers ?? []);
  const elites = wave.elites?.filter(elite => (elite.minDepth ?? 1) <= depth).map(elite => {
    if (!elite.featured) return elite;
    const enemyId = run.eliteId ?? elite.enemyId, body = enemyDefinitions[enemyId];
    return { ...elite, enemyId, hpMultiplier: elite.hp && body ? elite.hp / body.maxHp : elite.hpMultiplier,
      modifiers: [...new Set([...(elite.modifiers ?? []), ...featuredModifiers])] };
  });
  return { ...wave, enemies, ...(elites ? { elites } : {}) };
}