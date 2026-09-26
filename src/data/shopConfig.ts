import type { Rarity } from './items';
export const SHOP_CONFIG={
  itemSlots:4, weaponSlots:4,
  itemRerollBase:5, itemRerollStep:5,
  weaponRerollBase:6, weaponRerollStep:6,
  weaponPrices:{newWeapon:36,newStructure:44,upgrade:{2:18,3:23,4:30,5:36,6:43,7:49,8:56,9:62,10:70} as Record<number,number>},
  luckScale:100,
  rarities:{COMMON:{wave:1,weight:70,luckBoost:0},UNCOMMON:{wave:3,weight:23,luckBoost:1},RARE:{wave:7,weight:6,luckBoost:2},LEGENDARY:{wave:12,weight:1,luckBoost:4}} satisfies Record<Rarity,{wave:number;weight:number;luckBoost:number}>
} as const;
