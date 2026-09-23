import {items,type ItemData,type Rarity} from '../data/items';
import {SHOP_CONFIG} from '../data/shopConfig';
import {WEAPON_CONFIG} from '../data/weaponConfig';
import {weapons} from '../data/weapons';
import type {RunState} from '../state/RunState';
import {addItem,canAddItem} from './ItemSystem';
import {chooseWeaponBranch} from './UpgradeSystem';

export interface WeaponShopOffer { weaponId:string; targetLevel:number }

export function rarityWeight(rarity:Rarity,wave:number,luck:number):number {const r=SHOP_CONFIG.rarities[rarity];return wave<r.wave?0:r.weight*(1+r.luckBoost*Math.max(0,luck)/(Math.max(0,luck)+SHOP_CONFIG.luckScale));}
export function itemAvailable(run:RunState,item:ItemData):boolean{return canAddItem(run,item.id)&&run.currentWave>=(item.unlockCondition?.wave??1)&&(!item.unlockCondition?.metaItemId||run.unlockedItemIds.includes(item.unlockCondition.metaItemId))&&rarityWeight(item.rarity,run.currentWave,run.calculatedStats.luck)>0;}
function drawItem(run:RunState,random:()=>number,excluded:Set<string>):string|null {
 const pool=Object.values(items).filter(i=>itemAvailable(run,i)&&!excluded.has(i.id));
 const counts:Partial<Record<Rarity,number>>={};for(const i of pool)counts[i.rarity]=(counts[i.rarity]??0)+1;
 const weight=(i:ItemData)=>rarityWeight(i.rarity,run.currentWave,run.calculatedStats.luck)/counts[i.rarity]!;
 let roll=Math.min(0.999999999,Math.max(0,random()))*pool.reduce((n,i)=>n+weight(i),0);
 for(const i of pool){roll-=weight(i);if(roll<0)return i.id;}return pool[0]?.id??null;
}
function refreshItems(run:RunState,random:()=>number):void {
 const stock=run.shop.itemStock,excluded=new Set(stock.slots.filter(s=>s.locked&&s.itemId).map(s=>s.itemId!));
 for(const slot of stock.slots){if(slot.locked&&slot.itemId&&items[slot.itemId]&&itemAvailable(run,items[slot.itemId]!))continue;slot.itemId=drawItem(run,random,excluded);slot.locked=false;if(slot.itemId)excluded.add(slot.itemId);}
}

export function eligibleWeaponOffers(run:RunState):WeaponShopOffer[] {
 const canAdd=run.ownedWeapons.length<WEAPON_CONFIG.maxSlots;
 const result:WeaponShopOffer[]=[];
 for(const id of run.availableWeaponIds){const definition=weapons[id];if(!definition)continue;const owned=run.ownedWeapons.find(slot=>slot.id===id);if(owned){if(owned.level<definition.maxLevel)result.push({weaponId:id,targetLevel:owned.level+1});continue;}if(canAdd&&!definition.signatureOwnerId)result.push({weaponId:id,targetLevel:1});}
 return result;
}
export function weaponOfferAvailable(run:RunState,offer:WeaponShopOffer):boolean{return eligibleWeaponOffers(run).some(candidate=>candidate.weaponId===offer.weaponId&&candidate.targetLevel===offer.targetLevel);}
export function weaponPrice(offer:WeaponShopOffer):number {const definition=weapons[offer.weaponId];if(!definition)return Infinity;if(offer.targetLevel===1)return definition.structure?SHOP_CONFIG.weaponPrices.newStructure:SHOP_CONFIG.weaponPrices.newWeapon;return SHOP_CONFIG.weaponPrices.upgrade[offer.targetLevel]??Infinity;}
function drawWeapon(run:RunState,random:()=>number,excluded:Set<string>):WeaponShopOffer|null {const pool=eligibleWeaponOffers(run).filter(offer=>!excluded.has(offer.weaponId));if(!pool.length)return null;return pool[Math.min(pool.length-1,Math.floor(Math.min(0.999999999,Math.max(0,random()))*pool.length))]??null;}
function refreshWeapons(run:RunState,random:()=>number):void {
 const stock=run.shop.weaponStock,excluded=new Set(stock.slots.filter(s=>s.locked&&s.weaponId).map(s=>s.weaponId!));
 for(const slot of stock.slots){const current=slot.weaponId?{weaponId:slot.weaponId,targetLevel:slot.targetLevel}:null;if(slot.locked&&current&&weaponOfferAvailable(run,current))continue;const offer=drawWeapon(run,random,excluded);slot.weaponId=offer?.weaponId??null;slot.targetLevel=offer?.targetLevel??0;slot.locked=false;if(slot.weaponId)excluded.add(slot.weaponId);}
}

export function enterShop(run:RunState,random:()=>number):void {
 if(run.phase!=='shop'||run.shop.wave===run.currentWave)return;
 const previousItems=run.shop.itemStock.slots,previousWeapons=run.shop.weaponStock.slots;
 // Reroll inflation lasts for the whole Gate. A new Run creates fresh counters,
 // while entering the next Wave's shop only refreshes unlocked merchandise.
 run.shop.itemStock={rerolls:run.shop.itemStock.rerolls,slots:Array.from({length:SHOP_CONFIG.itemSlots},(_,i)=>previousItems[i]?.locked?{...previousItems[i]!}:{itemId:null,locked:false})};
 run.shop.weaponStock={rerolls:run.shop.weaponStock.rerolls,slots:Array.from({length:SHOP_CONFIG.weaponSlots},(_,i)=>previousWeapons[i]?.locked?{...previousWeapons[i]!}:{weaponId:null,targetLevel:0,locked:false})};
 run.shop.wave=run.currentWave;refreshItems(run,random);refreshWeapons(run,random);
}

export function itemRerollCost(run:RunState):number{return SHOP_CONFIG.itemRerollBase+run.shop.itemStock.rerolls*SHOP_CONFIG.itemRerollStep;}
export function weaponRerollCost(run:RunState):number{return SHOP_CONFIG.weaponRerollBase+run.shop.weaponStock.rerolls*SHOP_CONFIG.weaponRerollStep;}
export function buyItem(run:RunState,index:number):boolean {const slot=run.shop.itemStock.slots[index],item=items[slot?.itemId??''];if(run.phase!=='shop'||run.pendingBranchWeaponId||!Number.isInteger(index)||!item||!itemAvailable(run,item)||run.runCurrency<item.basePrice)return false;if(!addItem(run,item.id))return false;run.runCurrency-=item.basePrice;slot!.itemId=null;slot!.locked=false;return true;}
export function buyWeapon(run:RunState,index:number):boolean {
 const slot=run.shop.weaponStock.slots[index];if(run.phase!=='shop'||run.pendingBranchWeaponId||!Number.isInteger(index)||!slot?.weaponId)return false;
 const offer={weaponId:slot.weaponId,targetLevel:slot.targetLevel},price=weaponPrice(offer);if(!weaponOfferAvailable(run,offer)||run.runCurrency<price)return false;
 const owned=run.ownedWeapons.find(weapon=>weapon.id===offer.weaponId);if(owned)owned.level=offer.targetLevel;else run.ownedWeapons.push({id:offer.weaponId,level:1,cooldownRemaining:0});
 run.runCurrency-=price;slot.weaponId=null;slot.targetLevel=0;slot.locked=false;
 const purchased=run.ownedWeapons.find(weapon=>weapon.id===offer.weaponId)!;if(purchased.level===weapons[offer.weaponId]!.branchAtLevel&&!purchased.branchId)run.pendingBranchWeaponId=offer.weaponId;
 return true;
}
export function chooseShopWeaponBranch(run:RunState,id:string):boolean{return run.phase==='shop'&&chooseWeaponBranch(run,id);}
export function rerollItems(run:RunState,random:()=>number):boolean {const stock=run.shop.itemStock,cost=itemRerollCost(run);if(run.phase!=='shop'||run.pendingBranchWeaponId||run.runCurrency<cost||stock.slots.every(s=>s.locked))return false;run.runCurrency-=cost;stock.rerolls++;refreshItems(run,random);return true;}
export function rerollWeapons(run:RunState,random:()=>number):boolean {const stock=run.shop.weaponStock,cost=weaponRerollCost(run);if(run.phase!=='shop'||run.pendingBranchWeaponId||run.runCurrency<cost||stock.slots.every(s=>s.locked))return false;run.runCurrency-=cost;stock.rerolls++;refreshWeapons(run,random);return true;}
export function toggleItemLock(run:RunState,index:number):boolean {const slot=run.shop.itemStock.slots[index];if(run.phase!=='shop'||run.pendingBranchWeaponId||!Number.isInteger(index)||!slot?.itemId)return false;slot.locked=!slot.locked;return true;}
export function toggleWeaponLock(run:RunState,index:number):boolean {const slot=run.shop.weaponStock.slots[index];if(run.phase!=='shop'||run.pendingBranchWeaponId||!Number.isInteger(index)||!slot?.weaponId)return false;slot.locked=!slot.locked;return true;}

/** Development helpers keep test actions out of the paid purchase path. */
export function grantWeapon(run:RunState,id:string,upgrade:boolean):boolean {const definition=weapons[id],owned=run.ownedWeapons.find(slot=>slot.id===id);if(!definition||run.pendingBranchWeaponId)return false;if(upgrade){if(!owned||owned.level>=definition.maxLevel)return false;owned.level++;if(owned.level===definition.branchAtLevel&&!owned.branchId)run.pendingBranchWeaponId=id;return true;}if(owned||definition.signatureOwnerId||!run.availableWeaponIds.includes(id)||run.ownedWeapons.length>=WEAPON_CONFIG.maxSlots)return false;run.ownedWeapons.push({id,level:1,cooldownRemaining:0});return true;}
