import { characters } from '../data/characters';
import { SUPPLY_BOX_CONFIG } from '../data/metaFacilities';
import { dangunBlessings } from '../data/weeklyGate';
import { weapons } from '../data/weapons';
import type { MetaState } from '../state/MetaState';

export type MetaRewardType = 'associationCoins'|'supplyTicket'|'characterFragment'|'weaponFragment'|'blessingFragment';
export interface MetaReward { type: MetaRewardType; amount: number; contentId?: string }
const pick = (values: string[], rng: () => number): string => values[Math.min(values.length - 1, Math.floor(rng() * values.length))]!;
const amount = (min:number,max:number,rng:()=>number):number => min + Math.floor(rng() * (max-min+1));
export function grantMetaReward(meta:MetaState,reward:MetaReward):void {
  if(reward.type==='associationCoins')meta.wallet.associationCoins+=reward.amount;
  else if(reward.type==='supplyTicket')meta.wallet.supplyTickets+=reward.amount;
  else if(reward.type==='characterFragment'&&reward.contentId){const p=meta.characters[reward.contentId]??{unlocked:false,fragments:0,breakthrough:0};p.fragments+=reward.amount;meta.characters[reward.contentId]=p;}
  else if(reward.type==='weaponFragment'&&reward.contentId){const p=meta.sharedWeapons[reward.contentId]??{unlocked:false,fragments:0,level:0};p.fragments+=reward.amount;meta.sharedWeapons[reward.contentId]=p;}
  else if(reward.type==='blessingFragment'&&reward.contentId){const p=meta.blessings[reward.contentId]??{unlocked:false,fragments:0,level:0};p.fragments+=reward.amount;meta.blessings[reward.contentId]=p;}
}
function rollReward(rng:()=>number,forceFragment=false):MetaReward {
  const defs=SUPPLY_BOX_CONFIG.rewards.filter(r=>!forceFragment||r.type.endsWith('Fragment'));
  const total=defs.reduce((sum,r)=>sum+r.weight,0);let roll=rng()*total;let def=defs[defs.length-1]!;
  for(const candidate of defs){roll-=candidate.weight;if(roll<0){def=candidate;break;}}
  const reward:MetaReward={type:def.type,amount:amount(def.min,def.max,rng)};
  if(def.type==='characterFragment')reward.contentId=pick(Object.keys(characters),rng);
  else if(def.type==='weaponFragment')reward.contentId=pick(Object.keys(weapons),rng);
  else if(def.type==='blessingFragment')reward.contentId=pick(Object.keys(dangunBlessings),rng);
  return reward;
}
export function openSupplyBox(meta:MetaState,count:1|10,rng:()=>number=Math.random):MetaReward[]|null {
  const cost=count*SUPPLY_BOX_CONFIG.ticketCost;if(meta.wallet.supplyTickets<cost)return null;
  meta.wallet.supplyTickets-=cost;const state=meta.supply.boxes[SUPPLY_BOX_CONFIG.id]??{opened:0,pity:0};const results:MetaReward[]=[];
  for(let i=0;i<count;i++){const reward=rollReward(rng,state.pity>=SUPPLY_BOX_CONFIG.pityLimit-1);const fragment=reward.type.endsWith('Fragment');state.pity=fragment?0:state.pity+1;state.opened++;grantMetaReward(meta,reward);results.push(reward);}
  meta.supply.boxes[SUPPLY_BOX_CONFIG.id]=state;return results;
}
