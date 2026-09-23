import { CAPABILITY_STATS, STAT_RULES, type PlayerStats } from '../data/stats';
import { WEAPON_CONFIG } from '../data/weaponConfig';
import type { Weapon, WeaponStats } from '../data/types';
export interface ResolvedWeaponStats extends WeaponStats { repeatCount: number; repeatInterval: number; explosionDelay: number; attackAngle: number; areaScale: number; chainRange: number; blastRadius: number; criticalChance: number; criticalDamage: number; lifesteal: number }
export function resolveWeaponStats(weapon: Weapon, level: number, player: PlayerStats, allowIndirectLifesteal = false, branchId?: string, effects: readonly import('../data/items').ItemEffect[] = []): ResolvedWeaponStats {
  const base = { ...weapon.base };
  for (let i = 0; i < Math.min(level, weapon.maxLevel) - 1 && i < weapon.levels.length; i++) Object.assign(base, weapon.levels[i]);
  const branch = weapon.branches.find(b => b.id === branchId);
  if (branch) for (let i = 0; i <= Math.min(level, weapon.maxLevel) - weapon.branchAtLevel && i < branch.levels.length; i++) Object.assign(base, branch.levels[i]);
  const gated = (stat: keyof typeof CAPABILITY_STATS, fallback = 1) => weapon.capabilities.includes(CAPABILITY_STATS[stat]) ? player[stat] : fallback;
  const indirect = weapon.capabilities.includes('STRUCTURE') || weapon.capabilities.includes('SUMMON');
  return {
    ...base,
    projectileCount: base.projectileCount + effects.reduce((n,e)=>n+(e.type==='projectileCount' && weapon.capabilities.includes(e.tag)?e.value:0),0),
    repeatCount: base.repeatCount ?? 1, repeatInterval: base.repeatInterval ?? 0.15, explosionDelay: base.explosionDelay ?? 0,
    attackAngle: base.attackAngle ?? weapon.attackAngle ?? Math.PI,
    damage: Math.max(0, Math.round(base.damage * player.damage * gated('meleeDamage') * gated('rangedDamage') * WEAPON_CONFIG.playerDamageMultiplier)),
    cooldown: Math.max(STAT_RULES.minimumAttackInterval, base.cooldown / Math.max(STAT_RULES.minimumAttackSpeed, Math.min(STAT_RULES.maximumAttackSpeed, player.attackSpeed))),
    range: base.range * gated('range'), duration: base.duration * gated('duration'),
    projectileRadius: base.projectileRadius * gated('area') * (base.areaMultiplier ?? 1),
    chainRange: (weapon.chainRange ?? 200) * gated('range'), blastRadius: (base.blastRadius ?? weapon.blastRadius ?? 100) * gated('area'),
    projectileSpeed: base.projectileSpeed * gated('projectileSpeed'), areaScale: gated('area') * (base.areaMultiplier ?? 1),
    criticalChance: gated('criticalChance', 0), criticalDamage: gated('criticalDamage'),
    lifesteal: !indirect || allowIndirectLifesteal ? Math.min(STAT_RULES.lifestealRateCap, player.lifesteal) : 0,
  };
}
