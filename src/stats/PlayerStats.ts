import { DEFAULT_STATS, STAT_RULES, type PlayerStats, type StatKey } from '../data/stats';
import type { RunState } from '../state/RunState';
export type ModifierSource = 'meta' | 'item' | 'run' | 'blessing';
export interface StatModifier { id: string; source: ModifierSource; stat: StatKey; operation: 'add' | 'multiply'; value: number }
export function calculateStats(base: PlayerStats, modifiers: readonly StatModifier[]): PlayerStats {
  const stats = { ...base };
  for (const key of Object.keys(DEFAULT_STATS) as StatKey[]) {
    let add = 0, multiplierBonus = 0;
    for (const mod of modifiers) {
      if (mod.stat !== key || !Number.isFinite(mod.value)) continue;
      if (mod.operation === 'add') add += mod.value;
      else multiplierBonus += Math.max(0, mod.value) - 1;
    }
    const value = (base[key] + add) * Math.max(0, 1 + multiplierBonus);
    stats[key] = Number.isFinite(value) ? Math.max(0, Math.min(STAT_RULES.maximumStat, value)) : DEFAULT_STATS[key];
  }
  stats.maxHp = Math.max(1, stats.maxHp);
  stats.attackSpeed = Math.max(STAT_RULES.minimumAttackSpeed, Math.min(STAT_RULES.maximumAttackSpeed, stats.attackSpeed));
  stats.criticalChance = Math.min(1, stats.criticalChance);
  stats.criticalDamage = Math.max(1, stats.criticalDamage);
  stats.dodge = Math.min(STAT_RULES.dodgeCap, stats.dodge);
  stats.lifesteal = Math.min(STAT_RULES.lifestealRateCap, stats.lifesteal);
  return stats;
}
/** Call only when equipment/modifiers change, never in the frame loop. */
export function recalculateStats(run: RunState): void {
  const previousMax = run.player.maxHp;
  run.calculatedStats = calculateStats(run.baseStats, run.statModifiers);
  const stats = run.calculatedStats;
  run.player.maxHp = stats.maxHp;
  // Preserve health ratio so repeated equipment changes cannot create free healing.
  run.player.hp = Math.max(0, Math.min(stats.maxHp, run.player.hp / previousMax * stats.maxHp));
  run.player.moveSpeed = stats.moveSpeed; run.player.pickupRadius = stats.pickupRange;
}
/** Replace one source atomically; item removal cannot erase permanent bonuses. */
export function replaceModifiers(run: RunState, source: ModifierSource, modifiers: readonly Omit<StatModifier, 'source'>[]): void {
  run.statModifiers = run.statModifiers.filter(mod => mod.source !== source);
  run.statModifiers.push(...modifiers.map(mod => ({ ...mod, source })));
  recalculateStats(run);
}
