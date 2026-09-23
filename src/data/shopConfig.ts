import type { Rarity } from './items';
export const SHOP_CONFIG={
  itemSlots:4, weaponSlots:4,
  itemRerollBase:5, itemRerollStep:5,
  weaponRerollBase:6, weaponRerollStep:6,
  weaponPrices:{newWeapon:36,newStructure:44,upgrade:{2:14,3:18,4:23,5:28,6:33,7:38,8:43,9:48,10:54} as Record<number,number>},
  luckScale:100,
  rarities:{COMMON:{wave:1,weight:70,luckBoost:0},UNCOMMON:{wave:3,weight:23,luckBoost:1},RARE:{wave:7,weight:6,luckBoost:2},LEGENDARY:{wave:12,weight:1,luckBoost:4}} satisfies Record<Rarity,{wave:number;weight:number;luckBoost:number}>
} as const;
