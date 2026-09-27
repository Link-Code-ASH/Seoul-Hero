import type { Rarity } from './items';
export const SHOP_CONFIG={
  itemSlots:4, weaponSlots:4,
  itemRerollBase:5, itemRerollStep:5,
  weaponRerollBase:6, weaponRerollStep:6,
  weaponPrices:{newWeapon:40,newStructure:49,upgrade:{2:20,3:26,4:33,5:40,6:48,7:54,8:62,9:69,10:77} as Record<number,number>},
  luckScale:100,
  rarities:{COMMON:{wave:1,weight:70,luckBoost:0},UNCOMMON:{wave:3,weight:23,luckBoost:1},RARE:{wave:7,weight:6,luckBoost:2},LEGENDARY:{wave:12,weight:1,luckBoost:4}} satisfies Record<Rarity,{wave:number;weight:number;luckBoost:number}>
} as const;
