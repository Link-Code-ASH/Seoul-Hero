import type { Weapon, WeaponStats } from '../types';

const CONTINUOUS_KEYS = [
  'damage', 'cooldown', 'projectileSpeed', 'range', 'duration', 'projectileRadius',
  'areaMultiplier', 'attackAngle', 'blastRadius', 'repeatInterval', 'explosionDelay', 'spreadAngle',
] as const satisfies readonly (keyof WeaponStats)[];

function midpoint(from: Partial<WeaponStats>, to: Partial<WeaponStats>): Partial<WeaponStats> {
  const result: Partial<WeaponStats> = { ...from };
  for (const key of CONTINUOUS_KEYS) {
    const a = from[key], b = to[key];
    if (typeof b !== 'number') continue;
    result[key] = typeof a === 'number' ? (a + b) / 2 : b;
  }
  return result;
}

function softenFinal(stats: Partial<WeaponStats>): Partial<WeaponStats> {
  return typeof stats.damage === 'number' ? { ...stats, damage: stats.damage * 0.85 } : { ...stats };
}

/**
 * Converts the proven Lv.1-6 progression into the current Lv.1-10 cadence.
 * Mechanical milestones remain intact while the extra levels split continuous growth.
 * The capstone keeps the old mechanics at 85% of the former final damage output.
 */
export function expandWeaponProgression(legacy: Weapon): Weapon {
  if (legacy.maxLevel !== 6 || legacy.branchAtLevel !== 3) return legacy;
  const common = legacy.levels;
  const levels: Partial<WeaponStats>[] = [
    midpoint(legacy.base, common[0] ?? {}),
    { ...(common[0] ?? {}) },
    midpoint(common[0] ?? {}, common[1] ?? {}),
    { ...(common[1] ?? {}) },
    midpoint(common[1] ?? {}, common[2] ?? {}),
    { ...(common[2] ?? {}) },
    { ...(common[3] ?? {}) },
    midpoint(common[3] ?? {}, common[4] ?? {}),
    softenFinal(common[4] ?? {}),
  ];
  const branches = legacy.branches.map(branch => {
    const old = branch.levels;
    return {
      ...branch,
      levels: [
        { ...(old[0] ?? {}) },
        midpoint(old[0] ?? {}, old[1] ?? {}),
        { ...(old[1] ?? {}) },
        { ...(old[2] ?? {}) },
        midpoint(old[2] ?? {}, old[3] ?? {}),
        softenFinal(old[3] ?? {}),
      ],
    };
  });
  return { ...legacy, maxLevel: 10, branchAtLevel: 5, levels, branches };
}
