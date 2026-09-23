import { characters } from '../data/characters';
import { OFFLINE_REWARD_CONFIG } from '../data/metaFacilities';
import { dangunBlessings } from '../data/weeklyGate';
import { weapons } from '../data/weapons';
import { emptyOfflineRewards, type MetaState, type PendingOfflineRewards } from '../state/MetaState';
import { grantMetaReward, type MetaReward } from './SupplySystem';

const randomId=(record:Record<string,unknown>,rng:()=>number):string=>{const ids=Object.keys(record);return ids[Math.min(ids.length-1,Math.floor(rng()*ids.length))]!;};
const add=(record:Record<string,number>,id:string,value:number):void=>{record[id]=(record[id]??0)+value;};
export function accrueOfflineRewards(meta:MetaState,now=new Date(),rng:()=>number=Math.random):boolean {
  const previous=Date.parse(meta.offlineReward.lastExitAt);if(!Number.isFinite(previous)){meta.offlineReward.lastExitAt=now.toISOString();return true;}
  const elapsed=Math.min(OFFLINE_REWARD_CONFIG.capHours*3600000,now.getTime()-previous);if(elapsed<OFFLINE_REWARD_CONFIG.coinIntervalMinutes*60000)return false;
  const pending=meta.offlineReward.pendingRewards;pending.associationCoins+=Math.floor(elapsed/(OFFLINE_REWARD_CONFIG.coinIntervalMinutes*60000))*OFFLINE_REWARD_CONFIG.coinsPerInterval;
  const hours=Math.floor(elapsed/3600000);for(let i=0;i<hours;i++){
    if(rng()<OFFLINE_REWARD_CONFIG.hourlyChances.weaponFragment)add(pending.weaponFragments,randomId(weapons,rng),1);
    if(rng()<OFFLINE_REWARD_CONFIG.hourlyChances.characterFragment)add(pending.characterFragments,randomId(characters,rng),1);
    if(rng()<OFFLINE_REWARD_CONFIG.hourlyChances.blessingFragment)add(pending.blessingFragments,randomId(dangunBlessings,rng),1);
    if(rng()<OFFLINE_REWARD_CONFIG.hourlyChances.supplyTicket)pending.supplyTickets+=1;
  }
  meta.offlineReward.lastExitAt=now.toISOString();return true;
}

/** Developer-only clock shift. It reuses normal accrual and never changes the system clock. */
export function advanceOfflineForDebug(meta:MetaState,hours:number,forceBonus=false):boolean {
  const now=new Date();
  const previous=Date.parse(meta.offlineReward.lastExitAt);
  const anchor=Number.isFinite(previous)?Math.min(previous,now.getTime()):now.getTime();
  meta.offlineReward.lastExitAt=new Date(anchor-Math.max(0,hours)*3_600_000).toISOString();
  return accrueOfflineRewards(meta,now,forceBonus?()=>0:Math.random);
}
export function hasOfflineRewards(rewards:PendingOfflineRewards):boolean{return rewards.associationCoins>0||rewards.supplyTickets>0||[rewards.characterFragments,rewards.weaponFragments,rewards.blessingFragments].some(r=>Object.values(r).some(v=>v>0));}
export function claimOfflineRewards(meta:MetaState,now=new Date()):boolean {
  const p=meta.offlineReward.pendingRewards;if(!hasOfflineRewards(p))return false;
  const rewards:MetaReward[]=[{type:'associationCoins',amount:p.associationCoins},{type:'supplyTicket',amount:p.supplyTickets}];
  for(const [contentId,amount] of Object.entries(p.characterFragments))rewards.push({type:'characterFragment',contentId,amount});
  for(const [contentId,amount] of Object.entries(p.weaponFragments))rewards.push({type:'weaponFragment',contentId,amount});
  for(const [contentId,amount] of Object.entries(p.blessingFragments))rewards.push({type:'blessingFragment',contentId,amount});
  rewards.filter(r=>r.amount>0).forEach(r=>grantMetaReward(meta,r));meta.offlineReward.pendingRewards=emptyOfflineRewards();meta.offlineReward.lastClaimedAt=now.toISOString();return true;
}
