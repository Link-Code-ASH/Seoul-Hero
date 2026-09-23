export const META_GROWTH_CONFIG = {
  characterCosts: [20, 35, 55, 80, 110], weaponCosts: [12, 20, 30, 45, 65],
  blessingCosts: [18, 30, 45, 65, 90], maxLevel: 5,
} as const;

export const OFFLINE_REWARD_CONFIG = {
  capHours: 12, coinIntervalMinutes: 30, coinsPerInterval: 1,
  hourlyChances: { weaponFragment: 0.04, characterFragment: 0.01, blessingFragment: 0.01, supplyTicket: 0.005 },
} as const;

export const SUPPLY_BOX_CONFIG = {
  id: 'standard', ticketCost: 1, pityLimit: 10,
  rewards: [
    { type: 'associationCoins', weight: 58, min: 15, max: 30 },
    { type: 'weaponFragment', weight: 24, min: 3, max: 6 },
    { type: 'characterFragment', weight: 8, min: 2, max: 4 },
    { type: 'blessingFragment', weight: 7, min: 2, max: 4 },
    { type: 'supplyTicket', weight: 3, min: 1, max: 1 },
  ],
} as const;
