import { META_GROWTH_CONFIG } from '../data/metaFacilities';
import type { MetaState } from '../state/MetaState';

export type GrowthKind = 'character' | 'weapon' | 'blessing';
export function growthCost(meta: MetaState, kind: GrowthKind, id: string): number {
  const progress = kind === 'character' ? meta.characters[id] : kind === 'weapon' ? meta.sharedWeapons[id] : meta.blessings[id];
  if(kind==='blessing'&&!progress)return META_GROWTH_CONFIG.blessingCosts[0]??Infinity;
  if (!progress || (kind!=='blessing'&&!progress.unlocked)) return Infinity;
  const level = kind === 'character' ? meta.characters[id]!.breakthrough : kind === 'weapon' ? meta.sharedWeapons[id]!.level : meta.blessings[id]!.level;
  const costs=kind==='character'?META_GROWTH_CONFIG.characterCosts:kind==='weapon'?META_GROWTH_CONFIG.weaponCosts:META_GROWTH_CONFIG.blessingCosts;
  return costs[level] ?? Infinity;
}
export function upgradeGrowth(meta: MetaState, kind: GrowthKind, id: string): boolean {
  if(kind==='blessing'&&!meta.blessings[id])meta.blessings[id]={unlocked:false,fragments:0,level:0};
  const progress = kind === 'character' ? meta.characters[id] : kind === 'weapon' ? meta.sharedWeapons[id] : meta.blessings[id];
  const cost = growthCost(meta, kind, id);
  if (!progress || !Number.isFinite(cost) || progress.fragments < cost) return false;
  progress.fragments -= cost;
  if (kind === 'character') meta.characters[id]!.breakthrough += 1;
  else if(kind==='weapon')meta.sharedWeapons[id]!.level+=1;
  else {
    const blessing=meta.blessings[id]!;
    if(!blessing.unlocked){blessing.unlocked=true;blessing.level=1;}
    else blessing.level+=1;
  }
  return true;
}
