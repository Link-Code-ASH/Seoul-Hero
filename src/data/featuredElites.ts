import { enemies } from './enemies';
import type { Rarity } from './items';

/** Rules shared by every featured (named) elite in the Wave tables. */
export const FEATURED_ELITE_RULES = {
  // Ordinary spawns slow down while a featured elite is alive.
  spawnRateWhileAlive: 0.7,
  announceSeconds: 2.6,
  // Kill reward: a scattered shower worth about 30 ordinary kills.
  showerStones: 12,
  showerValue: 30 * enemies.crawler!.magicStoneDrop,
  showerRadius: 95,
  // Elite supply: one free item in the next shop. A Wave with several featured
  // elites upgrades the supply when every one of them is killed.
  supplyRarities: ['RARE', 'EPIC', 'LEGENDARY'] as Rarity[],
  sweepRarities: ['EPIC', 'LEGENDARY'] as Rarity[],
} as const;
