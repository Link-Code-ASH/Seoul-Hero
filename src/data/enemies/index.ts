import type { EnemyDefinition } from '../types';

const common = { magicStoneDrop: 0.99, tags: ['NORMAL'] as EnemyDefinition['tags'] };

export const enemies: Record<string, EnemyDefinition> = {
  crawler: { ...common, id: 'crawler', name: '균열체', description: '균열에서 가장 먼저 쏟아지는 근접 추적형 괴물. 단순하지만 꾸준히 플레이어를 압박합니다.', maxHp: 32, moveSpeed: 64, contactDamage: 10, radius: 18, behavior: 'chase', visual: { sprite: 'brute', color: 0xe47880, shape: 'hexagon' } },
  runner: { ...common, id: 'runner', name: '질주체', description: '붉게 달아오른 뒤 빠르게 돌진하는 경량 포식자. 예고 동작을 보고 옆으로 피해야 합니다.', maxHp: 20, moveSpeed: 104, contactDamage: 7, radius: 12, behavior: 'charge', charge: { triggerRange: 290, warning: 0.95, duration: 0.36, speed: 608, cooldown: 2.6 }, visual: { sprite: 'hound', motif: 'charge', color: 0xe9ac77, shape: 'triangle' } },
  bulwark: { ...common, id: 'bulwark', name: '철각 거인', description: '느리지만 체력과 충격력이 높은 중장형 괴물. 가까워지면 넓은 충격 공격으로 공간을 장악합니다.', maxHp: 150, moveSpeed: 36, contactDamage: 17, magicStoneDrop: 3.96, radius: 33, behavior: 'tank', visual: { sprite: 'bulwark', motif: 'tank', color: 0xa0b4c0, shape: 'hexagon' } },
  spitter: { ...common, id: 'spitter', name: '마탄 사수', description: '거리를 유지하며 적대 마력탄을 발사하는 원거리형 괴물입니다.', maxHp: 42, moveSpeed: 65, contactDamage: 8, magicStoneDrop: 1.98, radius: 17, behavior: 'ranged', visual: { sprite: 'spitter', motif: 'ranged', color: 0xff6aaf, shape: 'diamond' } },
  swarm: { ...common, id: 'swarm', name: '군집 벌레', description: '약하지만 빠르고 수가 많은 군집형 생물. 다른 개체의 소환물로도 등장합니다.', maxHp: 12, moveSpeed: 108, contactDamage: 4, radius: 14, behavior: 'swarm', visual: { sprite: 'swarm', motif: 'swarm', color: 0xe8cc75, shape: 'triangle' } },
  charger: { ...common, id: 'charger', name: '돌진 뿔짐승', description: '목표를 겨눈 뒤 직선으로 돌진하는 중형 짐승. 돌진 경로를 벗어나면 빈틈이 생깁니다.', maxHp: 65, moveSpeed: 66, contactDamage: 15, magicStoneDrop: 1.98, radius: 21, behavior: 'charge', charge: { triggerRange: 380, warning: 0.8, duration: 0.45, speed: 520, cooldown: 3 }, visual: { sprite: 'charger', motif: 'charge', color: 0xff744d, shape: 'triangle' } },
  bomber: { ...common, id: 'bomber', name: '폭렬 포자', description: '플레이어에게 접근한 뒤 자폭하는 포자형 괴물. 폭발 범위에서 빠르게 벗어나야 합니다.', maxHp: 25, moveSpeed: 90, contactDamage: 22, magicStoneDrop: 1.98, radius: 16, behavior: 'bomber', visual: { sprite: 'bomber', motif: 'bomber', color: 0xffc349, shape: 'circle' } },
  splitter: { ...common, id: 'splitter', name: '분열 점액', description: '쓰러질 때 작은 군집체로 나뉘는 점액형 괴물. 처치 직후에도 방심할 수 없습니다.', maxHp: 75, moveSpeed: 55, contactDamage: 9, magicStoneDrop: 1.98, radius: 23, behavior: 'splitter', childId: 'swarm', visual: { sprite: 'splitter', motif: 'splitter', color: 0x9ad065, shape: 'circle' } },
  mender: { ...common, id: 'mender', name: '치유 사제', description: '주변 괴물의 체력을 회복시키는 지원형 개체. 전투가 길어지기 전에 우선 제거하는 편이 좋습니다.', maxHp: 50, moveSpeed: 58, contactDamage: 5, magicStoneDrop: 2.97, radius: 18, behavior: 'support', visual: { sprite: 'mender', motif: 'support', color: 0x71e7a5, shape: 'diamond' } },
  summoner: { ...common, id: 'summoner', name: '틈새 소환사', description: '균열을 열어 군집 벌레를 계속 불러내는 소환형 개체입니다.', maxHp: 85, moveSpeed: 36, contactDamage: 6, magicStoneDrop: 3.96, radius: 22, behavior: 'summoner', childId: 'swarm', visual: { sprite: 'summoner', motif: 'summoner', color: 0xb493ef, shape: 'hexagon' } },
  sentinel: { ...common, id: 'sentinel', name: '수문 방패병', description: '일정 주기로 방어 태세를 취해 방어력이 높아지는 수비형 괴물입니다.', maxHp: 65, moveSpeed: 50, contactDamage: 12, magicStoneDrop: 2.97, radius: 25, behavior: 'defender', visual: { sprite: 'sentinel', motif: 'defender', color: 0x87a5ed, shape: 'hexagon' } },
  lurker: { ...common, id: 'lurker', name: '그림자 잠복자', description: '희미한 모습으로 접근하다 갑자기 파고드는 기습형 괴물입니다.', maxHp: 32, moveSpeed: 105, contactDamage: 13, magicStoneDrop: 1.98, radius: 14, behavior: 'ambush', visual: { sprite: 'lurker', motif: 'ambush', color: 0xce8aba, shape: 'diamond' } },
  gatekeeper: { ...common, id: 'gatekeeper', name: '게이트 파수꾼', description: '게이트 전면을 지키는 대형 보스. 돌진·광역 공격·탄막·소환을 차례로 사용합니다.', maxHp: 5200, moveSpeed: 75, contactDamage: 25, magicStoneDrop: 79.2, radius: 48, behavior: 'boss', tags: ['BOSS'], visual: { sprite: 'boss', color: 0xbe96f6, shape: 'hexagon' }, bossPatterns: [
    { type: 'aoe', warning: 1.3, cooldown: 3, radius: 170, damageMultiplier: 1, count: 1 },
    { type: 'charge', warning: 1.1, cooldown: 3, radius: 0, damageMultiplier: 1, count: 1 },
    { type: 'volley', warning: 0.9, cooldown: 3, radius: 0, damageMultiplier: 0.7, count: 5 },
    { type: 'summon', warning: 1.2, cooldown: 4, radius: 90, damageMultiplier: 0, count: 3, childId: 'swarm' },
  ] },
  riftQueen: { ...common, id: 'riftQueen', name: '균열 여왕', description: '소환과 대규모 탄막으로 전장을 잠식하는 지휘형 보스입니다.', maxHp: 6500, moveSpeed: 65, contactDamage: 22, magicStoneDrop: 108.9, radius: 45, behavior: 'boss', tags: ['BOSS'], visual: { sprite: 'riftQueen', motif: 'queen', color: 0xf087d2, shape: 'diamond' }, bossPatterns: [
    { type: 'summon', warning: 1.2, cooldown: 4, radius: 100, damageMultiplier: 0, count: 4, childId: 'runner' },
    { type: 'volley', warning: 1, cooldown: 2.5, radius: 0, damageMultiplier: 0.8, count: 8 },
    { type: 'aoe', warning: 1.5, cooldown: 3, radius: 230, damageMultiplier: 1.2, count: 1 },
  ] },
};
