export type MagicStoneTier = 1 | 2 | 3 | 4 | 5;

/**
 * Reward value and field readability stay coupled here. New enemies only need
 * an appropriate magicStoneDrop; stronger drops automatically receive a
 * deeper purple tier, including elite reward multipliers.
 */
export const MAGIC_STONE_TIERS: Record<MagicStoneTier, { minValue: number; tint: number; scale: number }> = {
  1: { minValue: 1, tint: 0xeee8ff, scale: 0.92 },
  2: { minValue: 2, tint: 0xd6c2ff, scale: 1 },
  3: { minValue: 3, tint: 0xb58aef, scale: 1.08 },
  4: { minValue: 8, tint: 0x8d55cf, scale: 1.16 },
  5: { minValue: 20, tint: 0x63309e, scale: 1.26 },
};

export function magicStoneTier(value: number): MagicStoneTier {
  let result: MagicStoneTier = 1;
  for (const tier of [1, 2, 3, 4, 5] as const) if (value >= MAGIC_STONE_TIERS[tier].minValue) result = tier;
  return result;
}
