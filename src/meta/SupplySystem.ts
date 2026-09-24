import { characters } from '../data/characters';
import { SUPPLY_BOX_CONFIG } from '../data/metaFacilities';
import { dangunBlessings } from '../data/weeklyGate';
import { weapons } from '../data/weapons';
import { REVIVAL_STONES, type RevivalStoneGrade } from '../data/revivalStones';
import type { MetaState } from '../state/MetaState';

export type MetaRewardType = 'associationCoins'|'supplyTicket'|'characterFragment'|'weaponFragment'|'blessingFragment'|'revivalStone';
export interface MetaReward { type: MetaRewardType; amount: number; contentId?: string }
const pick = (values: string[], rng: () => number): string => values[Math.min(values.length - 1, Math.floor(rng() * values.length))]!;
const amount = (min:number,max:number,rng:()=>number):number => Math.min(max,min + Math.floor(rng() * (max-min+1)));
function weightedChoice<T>(values:readonly T[],weight:(value:T)=>number,rng:()=>number):T {
  const total=values.reduce((sum,value)=>sum+weight(value),0);
  let roll=Math.min(rng(),0.999999999)*total;
  for(const value of values){roll-=weight(value);if(roll<0)return value;}
  return values[values.length-1]!;
}
export function grantMetaReward(meta:MetaState,reward:MetaReward):void {
  if(reward.type==='associationCoins')meta.wallet.associationCoins+=reward.amount;
  else if(reward.type==='supplyTicket')meta.wallet.supplyTickets+=reward.amount;
  else if(reward.type==='characterFragment'&&reward.contentId){const p=meta.characters[reward.contentId]??{unlocked:false,fragments:0,breakthrough:0};p.fragments+=reward.amount;meta.characters[reward.contentId]=p;}
  else if(reward.type==='weaponFragment'&&reward.contentId){const p=meta.sharedWeapons[reward.contentId]??{unlocked:false,fragments:0,level:0};p.fragments+=reward.amount;meta.sharedWeapons[reward.contentId]=p;}
  else if(reward.type==='blessingFragment'&&reward.contentId){const p=meta.blessings[reward.contentId]??{unlocked:false,fragments:0,level:0};p.fragments+=reward.amount;meta.blessings[reward.contentId]=p;}
  else if(reward.type==='revivalStone'&&reward.contentId&&Object.hasOwn(REVIVAL_STONES,reward.contentId))meta.wallet.revivalStones[reward.contentId as RevivalStoneGrade]+=reward.amount;
}
function bonusReward(def:(typeof SUPPLY_BOX_CONFIG.bonusRewards)[number],rng:()=>number):MetaReward {
  const reward:MetaReward={type:def.type,amount:amount(def.min,def.max,rng)};
  if(def.type==='characterFragment')reward.contentId=pick(Object.keys(characters),rng);
  else if(def.type==='weaponFragment')reward.contentId=pick(Object.keys(weapons),rng);
  else if(def.type==='blessingFragment')reward.contentId=pick(Object.keys(dangunBlessings),rng);
  else if(def.type==='revivalStone')reward.contentId=def.contentId;
  return reward;
}
export function openSupplyBox(meta:MetaState,count:1|10,rng:()=>number=Math.random):MetaReward[]|null {
  const cost=count*SUPPLY_BOX_CONFIG.ticketCost;if(meta.wallet.supplyTickets<cost)return null;
  meta.wallet.supplyTickets-=cost;const state=meta.supply.boxes[SUPPLY_BOX_CONFIG.id]??{opened:0,pity:0};const results:MetaReward[]=[];
  const addReward=(reward:MetaReward):void=>{
    grantMetaReward(meta,reward);
    const existing=results.find(value=>value.type===reward.type&&value.contentId===reward.contentId);
    if(existing)existing.amount+=reward.amount;else results.push(reward);
  };
  for(let i=0;i<count;i++){
    const coin=weightedChoice(SUPPLY_BOX_CONFIG.coinAmounts,tier=>tier.weight,rng);
    addReward({type:'associationCoins',amount:coin.amount});
    let hasFragment=false;
    for(const def of SUPPLY_BOX_CONFIG.bonusRewards){
      if(rng()>=def.chance)continue;
      addReward(bonusReward(def,rng));
      hasFragment ||= def.type.endsWith('Fragment');
    }
    if(!hasFragment&&state.pity>=SUPPLY_BOX_CONFIG.pityLimit-1){
      const fragmentDefs=SUPPLY_BOX_CONFIG.bonusRewards.filter(def=>def.type.endsWith('Fragment'));
      addReward(bonusReward(weightedChoice(fragmentDefs,def=>def.chance,rng),rng));
      hasFragment=true;
    }
    state.pity=hasFragment?0:state.pity+1;
    state.opened++;
  }
  meta.supply.boxes[SUPPLY_BOX_CONFIG.id]=state;return results;
}
