export const META_GROWTH_CONFIG = {
  characterCosts: [20, 35, 55, 80, 110], weaponCosts: [12, 20, 30, 45, 65],
  blessingCosts: [18, 30, 45, 65, 90], maxLevel: 5,
} as const;

export const OFFLINE_REWARD_CONFIG = {
  capHours: 24, coinIntervalMinutes: 30,
  // 각 30분 구간마다 독립 판정. 오래 떠나 있을수록 구간별 확률도 조금씩 오른다.
  revivalStones: [
    { grade: 'low', baseChance: 0.0015, chancePerInterval: 0.00009 },
    { grade: 'mid', baseChance: 0.0005, chancePerInterval: 0.000025 },
    { grade: 'high', baseChance: 0.0001, chancePerInterval: 0.000005 },
  ],
  coinAmounts: [
    { amount: 3, weight: 45 }, { amount: 4, weight: 35 },
    { amount: 5, weight: 17 }, { amount: 7, weight: 3 },
  ],
} as const;

export const SUPPLY_BOX_CONFIG = {
  id: 'standard', ticketCost: 1, pityLimit: 10,
  coinAmounts: [
    { amount: 8, weight: 40 }, { amount: 10, weight: 30 },
    { amount: 12, weight: 20 }, { amount: 16, weight: 8 }, { amount: 24, weight: 2 },
  ],
  bonusRewards: [
    { type: 'weaponFragment', chance: 0.09, min: 1, max: 2 },
    { type: 'characterFragment', chance: 0.035, min: 1, max: 1 },
    { type: 'blessingFragment', chance: 0.035, min: 1, max: 2 },
    { type: 'supplyTicket', chance: 0.025, min: 1, max: 1 },
    { type: 'revivalStone', contentId: 'low', chance: 0.012, min: 1, max: 1 },
    { type: 'revivalStone', contentId: 'mid', chance: 0.004, min: 1, max: 1 },
    { type: 'revivalStone', contentId: 'high', chance: 0.001, min: 1, max: 1 },
  ],
} as const;
