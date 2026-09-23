import type { StatKey } from '../stats';
export type MetaEffect =
  | { type: 'stat'; stat: StatKey; operation: 'add' | 'multiply'; value: number }
  | { type: 'unlock'; target: 'character' | 'weapon' | 'item' | 'stage' | 'feature'; contentId: string };

export interface MetaUpgrade {
  id: string;
  name: string;
  description: string;
  maxLevel: number;
  baseCost: number;
  costGrowth: number;
  effect: MetaEffect;
}

/** Association Coin Shop prices and permanent benefits live here. */
export const metaUpgrades: Record<string, MetaUpgrade> = {
  vitality: {
    id: 'vitality', name: '기초 체력', description: '시작 최대 체력 +15',
    maxLevel: 5, baseCost: 25, costGrowth: 1.6,
    effect: { type: 'stat', stat: 'maxHp', operation: 'add', value: 15 },
  },
  power: {
    id: 'power', name: '마력 단련', description: '기본 공격력 +8%',
    maxLevel: 5, baseCost: 30, costGrowth: 1.6,
    effect: { type: 'stat', stat: 'damage', operation: 'add', value: 0.08 },
  },
  mobility: {
    id: 'mobility', name: '가벼운 발걸음', description: '기본 이동 속도 +3%',
    maxLevel: 5, baseCost: 25, costGrowth: 1.6,
    effect: { type: 'stat', stat: 'moveSpeed', operation: 'multiply', value: 0.03 },
  },
  turretLicense:{id:'turretLicense',name:'포탑 운용 허가',description:'일반 무기 자동 포탑을 상점에 해금',maxLevel:1,baseCost:100,costGrowth:1,effect:{type:'unlock',target:'weapon',contentId:'autoTurret'}},
  fortune:{id:'fortune',name:'행운 훈련',description:'기본 Luck +2',maxLevel:5,baseCost:40,costGrowth:1.7,effect:{type:'stat',stat:'luck',operation:'add',value:2}},
  circuit:{id:'circuit',name:'흡혈 회로 취급 허가',description:'전설 아이템 흡혈 회로 상점 해금',maxLevel:1,baseCost:120,costGrowth:1,effect:{type:'unlock',target:'item',contentId:'bloodCircuit'}},
  reroll: {
    id: 'reroll', name: '두 번째 기회', description: '한 판에 한 번 강화 후보 다시 뽑기 해금',
    maxLevel: 1, baseCost: 80, costGrowth: 1,
    effect: { type: 'unlock', target: 'feature', contentId: 'reroll' },
  },
};

