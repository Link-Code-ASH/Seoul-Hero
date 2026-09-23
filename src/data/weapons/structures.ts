import type { Weapon } from '../types';
import { expandWeaponProgression } from './progression';
export const structureWeapons: Record<string, Weapon> = {};
const definitions = [
  { id: 'autoTurret', name: '자동 포탑', kind: 'turret' as const, capabilities: ['STRUCTURE','TURRET','RANGED','PROJECTILE','CAN_CRIT','HAS_RANGE'] as Weapon['capabilities'], damage: 16, cooldown: 0.82, range: 312, duration: 12, maxCount: 2, placementInterval: 6, radius: 0, color: 0x70dfff },
  { id: 'mineLayer', name: '지뢰 살포기', kind: 'mine' as const, capabilities: ['STRUCTURE','TRAP','MINE','AREA','EXPLOSIVE'] as Weapon['capabilities'], damage: 68, cooldown: 2.1, range: 1, duration: 20, maxCount: 6, placementInterval: 2.1, radius: 110, color: 0xffbd65 },
  { id: 'manaField', name: '마력장 발생기', kind: 'aura' as const, capabilities: ['STRUCTURE','AURA','AREA','DURATION'] as Weapon['capabilities'], damage: 12, cooldown: 0.85, range: 1, duration: 7, maxCount: 2, placementInterval: 6, radius: 130, color: 0xb99bff },
];
for (const d of definitions) structureWeapons[d.id] = expandWeaponProgression({
  id: d.id, name: d.name, description: d.kind === 'turret' ? '고정 위치에서 자동 조준 발사' : d.kind === 'mine' ? '적 접촉으로 폭발하는 지뢰 설치' : '고정된 마력장에서 주기적으로 범위 피해',
  targeting: 'nearest', behavior: 'structure', capabilities: d.capabilities, maxLevel: 6, branchAtLevel: 3,
  structure: { kind: d.kind, maxCount: d.maxCount, placementInterval: d.placementInterval, triggerRadius: 30, sprite: d.kind === 'turret' ? 'turret' : d.kind === 'mine' ? 'mine' : 'field' },
  base: { damage: d.damage, cooldown: d.cooldown, range: d.range, duration: d.duration, projectileCount: 1, projectileSpeed: 600, penetration: 0, projectileRadius: 6, blastRadius: d.radius },
  levels: [{damage:d.damage*1.18},{},{damage:d.damage*1.35},{damage:d.damage*1.55},{damage:d.damage*1.75}],
  branches: [
    {id:'A',name:d.kind === 'turret' ? '다중 발사' : '광역 강화',description:d.kind === 'turret' ? '동시 발사 탄 수 증가' : '피해 영역 확대',levels:d.kind === 'turret' ? [{projectileCount:2},{},{},{projectileCount:2,damage:d.damage*1.65}] : [{blastRadius:d.radius*1.25},{},{},{blastRadius:d.radius*1.5,damage:d.damage*1.65}]},
    {id:'B',name:'고속 작동',description:'공격 또는 지뢰 설치 주기 단축',levels:[{cooldown:d.cooldown*0.78},{},{},{cooldown:d.cooldown*0.6,damage:d.damage*1.65}]},
  ], visual:{sprite:d.kind === 'turret' ? 'turretBolt' : undefined,color:d.color,shape:d.kind === 'mine' ? 'diamond' : 'hexagon'},
});

structureWeapons.autoTurret!.requiresUnlock=true;
