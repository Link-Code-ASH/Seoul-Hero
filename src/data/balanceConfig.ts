export const BALANCE_CONFIG = {
  version: '2026.09-gwanghwamun-depth1-v2',
  /** Every authored value is measured from this neutral 100% reference. */
  baseline: {
    characterId: 'awakener',
    mapId: 'seoul',
    gateDepth: 1,
  },
  telemetryRuns: 50,
  target: {
    levelOneSingleTargetDps: { min: 28, max: 38 },
    levelOneThreeTargetDps: { min: 55, max: 80 },
    levelTenLegacyPowerRatio: { min: 0.8, target: 0.85, max: 0.9 },
    branchPowerDifference: 0.15,
  },
} as const;

