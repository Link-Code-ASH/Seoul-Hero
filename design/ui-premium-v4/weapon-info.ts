import { DEFAULT_STATS, type WeaponCapability } from '../../src/data/stats';
import type { Weapon } from '../../src/data/types';
import { resolveWeaponStats } from '../../src/stats/WeaponStats';

export const capabilityNames: Record<WeaponCapability,string> = {
  MELEE:'근접',RANGED:'원거리',PROJECTILE:'투사체',AREA:'범위',ORBIT:'회전',BEAM:'광선',SUMMON:'소환',STRUCTURE:'설치물',TURRET:'포탑',TRAP:'함정',MINE:'지뢰',AURA:'마력장',DURATION:'지속',PIERCING:'관통',CHAIN:'연쇄',EXPLOSIVE:'폭발',CAN_CRIT:'치명타',HAS_RANGE:'사거리',
};
export function tags(weapon: Weapon): string[] { return weapon.capabilities.map(tag=>capabilityNames[tag]); }
export function appliedStats(weapon: Weapon): string[] {
  const stats:Partial<Record<WeaponCapability,string[]>>={MELEE:['근접 피해'],RANGED:['원거리 피해'],AREA:['범위'],PROJECTILE:['투사체 속도'],DURATION:['지속시간'],HAS_RANGE:['사거리'],CAN_CRIT:['치명타 확률·피해']};
  return ['공통 피해','공격 속도', ...weapon.capabilities.flatMap(tag=>stats[tag]??[])];
}
export const resolved = (weapon: Weapon, level: number, branchId?: string) => resolveWeaponStats(weapon,level,DEFAULT_STATS,false,branchId);
export function growthRows(weapon: Weapon, branchId?: string) {
  const start = branchId ? weapon.branchAtLevel : 1;
  const end = branchId ? weapon.maxLevel : weapon.branchAtLevel-1;
  return Array.from({length:end-start+1},(_,i)=>{
    const level=start+i;
    return {level,stats:resolved(weapon,level,branchId),previous:level>1?resolved(weapon,level-1,level-1>=weapon.branchAtLevel?branchId:undefined):undefined};
  });
}
