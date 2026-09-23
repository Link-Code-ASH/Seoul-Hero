import { STAT_RULES } from '../data/stats';
import type { RunState } from '../state/RunState';
import type { ResolvedWeaponStats } from './WeaponStats';
/** Shared by every projectile/target in one attack, including piercing and AoE. */
export interface AttackContext { criticalChance: number; criticalDamage: number; lifesteal: number; healingRemaining: number; sourceWeaponId?: string }
export function attackContext(stats: ResolvedWeaponStats, maxHp: number, sourceWeaponId?: string): AttackContext {
  return { criticalChance: stats.criticalChance, criticalDamage: stats.criticalDamage, lifesteal: stats.lifesteal,
    healingRemaining: Math.min(STAT_RULES.lifestealPerAttack, maxHp * STAT_RULES.lifestealMaxHpFraction), sourceWeaponId };
}
export function outgoingDamage(base: number, context: AttackContext | undefined, random: () => number): number {
  return Math.max(0, base * (context && context.criticalChance > 0 && random() < context.criticalChance ? context.criticalDamage : 1));
}
export function armorDamage(damage: number, armor: number): number {
  return Math.max(0, damage) * STAT_RULES.armorScale / (STAT_RULES.armorScale + Math.max(0, armor));
}
export function dodges(chance: number, random: () => number): boolean {
  return chance > 0 && random() < Math.min(STAT_RULES.dodgeCap, Math.max(0, chance));
}
export function applyLifesteal(run: RunState, actualDamage: number, context?: AttackContext): number {
  if (!context || run.player.hp <= 0) return 0;
  const healed = Math.max(0, Math.min(actualDamage * context.lifesteal, context.healingRemaining, run.player.maxHp - run.player.hp));
  run.player.hp += healed; context.healingRemaining -= healed; return healed;
}
