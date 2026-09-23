import { items } from '../data/items';
import type { RunState } from '../state/RunState';
import { replaceModifiers, type StatModifier } from '../stats/PlayerStats';
export function itemCount(run:RunState,id:string):number{return run.runItems.find(i=>i.id===id)?.count??0;}
export function canAddItem(run:RunState,id:string):boolean {const item=items[id];return !!item && (item.maxStacks===null||itemCount(run,id)<item.maxStacks);}
export function applyItems(run:RunState):void {
 const modifiers:Omit<StatModifier,'source'>[]=[];
 run.itemEffects=[];
 run.structureEffects=run.structureEffects.filter(e=>!e.sourceId.startsWith('item:'));
 for(const owned of run.runItems){const item=items[owned.id];if(!item)continue;for(let i=0;i<owned.count;i++){
  modifiers.push(...item.statModifiers.map((m,index)=>({...m,id:'item:'+item.id+':'+i+':'+index})));
  for(const effect of item.specialEffects){run.itemEffects.push({...effect});if(effect.type==='structureLimit')run.structureEffects.push({sourceId:'item:'+item.id,tag:effect.tag,type:'maxCount',value:effect.value});}
 }}
 run.combatPermissions.indirectLifesteal=run.itemEffects.some(e=>e.type==='indirectLifesteal');
 replaceModifiers(run,'item',modifiers);
}
export function addItem(run:RunState,id:string):boolean {if(!canAddItem(run,id))return false;const owned=run.runItems.find(i=>i.id===id);if(owned)owned.count++;else run.runItems.push({id,count:1});applyItems(run);return true;}
