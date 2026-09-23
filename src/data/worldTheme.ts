/** Decoration is visual only. Adding obstacles requires a separate gameplay system. */
export const WORLD_THEME = {
  neighborhood: {
    ground: 0x171a18,
    asphalt: 0x202421,
    pavement: 0x292d28,
    building: 0x343831,
    line: 0x62665a,
    lettering: 0xa4a58f,
    foliage: 0x354335,
    roadWidth: 112,
    tileSize: 64,
    storefronts: ['24 편의점', '서울 커피', '동네 식당', '해오름 빌라'],
    maxDpr: 2,
    spritePoolLimit: 600,
  },
} as const;
