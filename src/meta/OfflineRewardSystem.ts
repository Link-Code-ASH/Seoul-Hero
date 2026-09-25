import { OFFLINE_REWARD_CONFIG } from '../data/metaFacilities';
import type { RevivalStoneGrade } from '../data/revivalStones';
import { emptyOfflineRewards, type MetaState, type PendingOfflineRewards } from '../state/MetaState';
import { grantMetaReward, type MetaReward } from './SupplySystem';
import { guildFacilityLevel } from '../systems/GuildSystem';

function rollCoins(rng:()=>number):number {
  const amounts=OFFLINE_REWARD_CONFIG.coinAmounts;
  const total=amounts.reduce((sum,tier)=>sum+tier.weight,0);
  let roll=Math.min(Math.max(rng(),0),1-Number.EPSILON)*total;
  for(const tier of amounts){roll-=tier.weight;if(roll<0)return tier.amount;}
  return amounts[amounts.length-1]!.amount;
}
export function accrueOfflineRewards(meta:MetaState,now=new Date(),rng:()=>number=Math.random):boolean {
  const previous=Date.parse(meta.offlineReward.lastExitAt);if(!Number.isFinite(previous)){meta.offlineReward.lastExitAt=now.toISOString();return true;}
  const elapsed=Math.min(OFFLINE_REWARD_CONFIG.capHours*3600000,now.getTime()-previous);if(elapsed<OFFLINE_REWARD_CONFIG.coinIntervalMinutes*60000)return false;
  const intervals=Math.floor(elapsed/(OFFLINE_REWARD_CONFIG.coinIntervalMinutes*60000));
  for(let i=0;i<intervals;i++){
    meta.offlineReward.pendingRewards.associationCoins+=rollCoins(rng)+guildFacilityLevel(meta,'recovery');
    for(const stone of OFFLINE_REWARD_CONFIG.revivalStones)
      if(rng()<stone.baseChance+stone.chancePerInterval*i)
        meta.offlineReward.pendingRewards.revivalStones[stone.grade as RevivalStoneGrade]++;
  }
  meta.offlineReward.lastExitAt=now.toISOString();return true;
}

/** Developer-only clock shift. It reuses normal accrual and never changes the system clock. */
export function advanceOfflineForDebug(meta:MetaState,hours:number):boolean {
  const now=new Date();
  const previous=Date.parse(meta.offlineReward.lastExitAt);
  const anchor=Number.isFinite(previous)?Math.min(previous,now.getTime()):now.getTime();
  meta.offlineReward.lastExitAt=new Date(anchor-Math.max(0,hours)*3_600_000).toISOString();
  return accrueOfflineRewards(meta,now);
}
export function hasOfflineRewards(rewards:PendingOfflineRewards):boolean{return rewards.associationCoins>0||rewards.supplyTickets>0||Object.values(rewards.revivalStones).some(v=>v>0)||[rewards.characterFragments,rewards.weaponFragments,rewards.blessingFragments].some(r=>Object.values(r).some(v=>v>0));}
export function claimOfflineRewards(meta:MetaState,now=new Date()):boolean {
  const p=meta.offlineReward.pendingRewards;if(!hasOfflineRewards(p))return false;
  const rewards:MetaReward[]=[{type:'associationCoins',amount:p.associationCoins},{type:'supplyTicket',amount:p.supplyTickets}];
  for(const [contentId,amount] of Object.entries(p.characterFragments))rewards.push({type:'characterFragment',contentId,amount});
  for(const [contentId,amount] of Object.entries(p.weaponFragments))rewards.push({type:'weaponFragment',contentId,amount});
  for(const [contentId,amount] of Object.entries(p.blessingFragments))rewards.push({type:'blessingFragment',contentId,amount});
  for(const [contentId,amount] of Object.entries(p.revivalStones))rewards.push({type:'revivalStone',contentId,amount});
  rewards.filter(r=>r.amount>0).forEach(r=>grantMetaReward(meta,r));meta.offlineReward.pendingRewards=emptyOfflineRewards();meta.offlineReward.lastClaimedAt=now.toISOString();return true;
}
