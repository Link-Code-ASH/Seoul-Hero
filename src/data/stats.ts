/** Multipliers use 1 = 100%; probabilities use 0..1; other values are world units/HP. */
export const DEFAULT_STATS = {
  damage: 1, attackSpeed: 1, meleeDamage: 1, rangedDamage: 1,
  criticalChance: 0, criticalDamage: 1.5, range: 1, area: 1, duration: 1, projectileSpeed: 1,
  maxHp: 100, armor: 0, dodge: 0, lifesteal: 0, hpRegeneration: 0,
  moveSpeed: 210, currencyGain: 1, pickupRange: 100, luck: 0, curse: 0,
};
export type StatKey = keyof typeof DEFAULT_STATS;
export type PlayerStats = Record<StatKey, number>;
export const STAT_RULES = {
  armorScale: 100, dodgeCap: 0.75, lifestealRateCap: 0.5,
  lifestealPerAttack: 5, lifestealMaxHpFraction: 0.05,
  minimumAttackSpeed: 0.1, maximumAttackSpeed: 10, minimumAttackInterval: 0.05,
  maximumStat: 1000000,
} as const;
export const WEAPON_CAPABILITIES = ['MELEE', 'RANGED', 'PROJECTILE', 'AREA', 'ORBIT', 'BEAM', 'SUMMON', 'STRUCTURE', 'TURRET', 'TRAP', 'MINE', 'AURA', 'DURATION', 'PIERCING', 'CHAIN', 'EXPLOSIVE', 'CAN_CRIT', 'HAS_RANGE'] as const;
export type WeaponCapability = typeof WEAPON_CAPABILITIES[number];
/** Capability-gated stats. Damage and Attack Speed apply to every attack. */
export const CAPABILITY_STATS = {
  meleeDamage: 'MELEE', rangedDamage: 'RANGED', projectileSpeed: 'PROJECTILE',
  area: 'AREA', duration: 'DURATION', range: 'HAS_RANGE',
  criticalChance: 'CAN_CRIT', criticalDamage: 'CAN_CRIT',
} as const satisfies Partial<Record<StatKey, WeaponCapability>>;
