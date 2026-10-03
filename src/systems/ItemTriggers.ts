import type { RunState } from '../state/RunState';
import type { Enemy, Player } from '../entities/types';
import { recalculateStats, type StatModifier } from '../stats/PlayerStats';

export interface ItemRuntime {
 wave:number; idle:number; lastPickup:number; shieldSpent:boolean; lastStandSpent:boolean;
 retaliated:number; kills:number; pickups:number; signature:string;
 bursts:{x:number;y:number;radius:number;damage:number}[];
}
export function itemRuntime(run:RunState):ItemRuntime {
 const state=run.itemRuntime??= {wave:run.currentWave,idle:0,lastPickup:-999,shieldSpent:false,lastStandSpent:false,retaliated:-999,kills:0,pickups:0,signature:'',bursts:[]};
 if(state.wave!==run.currentWave){state.wave=run.currentWave;state.shieldSpent=false;state.idle=0;}
 return state;
}
export function updateItemTriggers(run:RunState,dt:number,moving:boolean):void {
 const state=itemRuntime(run);state.idle=moving?0:state.idle+dt;
 const modifiers:StatModifier[]=[];
 run.itemEffects.forEach((effect,index)=>{
  if(effect.type!=='conditionalStat')return;
  let value=0;
  switch(effect.condition){
   case 'stationary':value=state.idle>=effect.threshold?effect.value:0;break;
   case 'moving':value=moving?effect.value:0;break;
   case 'injured':value=Math.min(effect.limit??Infinity,Math.floor((1-run.player.hp/run.player.maxHp)/effect.threshold)*effect.value);break;
   case 'wealth':value=Math.min(effect.limit??Infinity,Math.floor(run.runCurrency/effect.threshold)*effect.value);break;
   case 'dawn':value=run.waveElapsedTime<effect.threshold?effect.value:0;break;
   case 'pickupSprint':value=run.stageCombatTime-state.lastPickup<effect.threshold?effect.value:0;break;
  }
  if(value)modifiers.push({id:'item-trigger:'+index,source:'run',stat:effect.stat,operation:'add',value});
 });
 const signature=JSON.stringify(modifiers);
 if(signature!==state.signature){state.signature=signature;run.statModifiers=run.statModifiers.filter(m=>!m.id.startsWith('item-trigger:')).concat(modifiers);recalculateStats(run);}
}
export function itemDamageMultiplier(run:RunState,enemy:Enemy):number {
 let bonus=0;const distance=Math.hypot(enemy.x-run.player.x,enemy.y-run.player.y);
 for(const effect of run.itemEffects){
  if(effect.type!=='conditionalDamage')continue;
  const active=effect.condition==='opening'?enemy.hp>=enemy.maxHp:effect.condition==='execute'?enemy.hp/enemy.maxHp<=effect.threshold:effect.condition==='close'?distance<=effect.threshold:distance>=effect.threshold;
  if(active)bonus+=effect.value;
 }return 1+bonus;
}
function heal(player:Player,value:number):void {if(player.hp>0)player.hp=Math.min(player.maxHp,player.hp+value);}
export function itemKill(run:RunState):void {
 const state=itemRuntime(run);state.kills++;
 for(const effect of run.itemEffects)if(effect.type==='killHeal'&&state.kills%effect.every===0)heal(run.player,effect.value);
}
export function itemPickup(run:RunState,units:number):void {
 const state=itemRuntime(run),before=state.pickups;state.pickups+=units;state.lastPickup=run.stageCombatTime;
 for(const effect of run.itemEffects)if(effect.type==='pickupHeal')heal(run.player,effect.value*(Math.floor(state.pickups/effect.every)-Math.floor(before/effect.every)));
}
export function itemIncoming(run:RunState,damage:number):number {
 const state=itemRuntime(run);
 for(const effect of run.itemEffects)if(effect.type==='firstShield'&&!state.shieldSpent){state.shieldSpent=true;damage*=1-effect.value;}
 return damage;
}
export function itemHurt(run:RunState):void {
 const state=itemRuntime(run);
 for(const effect of run.itemEffects){
  if(effect.type==='lastStand'&&run.player.hp<=0&&!state.lastStandSpent){state.lastStandSpent=true;run.player.hp=1;run.player.invulnerability=effect.value;}
  if(effect.type==='retaliate'&&run.stageCombatTime-state.retaliated>=effect.cooldown){state.retaliated=run.stageCombatTime;state.bursts.push({x:run.player.x,y:run.player.y,radius:effect.radius,damage:effect.value});}
 }
}
export function clearItemWave(run:RunState):void {
 const state=itemRuntime(run);state.bursts.length=0;state.signature='';state.idle=0;
 const kept=run.statModifiers.filter(m=>!m.id.startsWith('item-trigger:'));
 if(kept.length!==run.statModifiers.length){run.statModifiers=kept;recalculateStats(run);}
}
