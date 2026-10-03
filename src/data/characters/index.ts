import { DEFAULT_STATS } from '../stats';
import type { Character, CharacterStatAdjustment } from '../types';
import type { PlayerStats } from '../stats';

/** Build future characters as explicit differences from Song Jinwoo's neutral baseline. */
export function characterStatsFromBaseline(adjustments: readonly CharacterStatAdjustment[]): PlayerStats {
  const result = { ...DEFAULT_STATS };
  for (const stat of Object.keys(DEFAULT_STATS) as (keyof PlayerStats)[]) {
    const matching = adjustments.filter(adjustment => adjustment.stat === stat);
    const flat = matching.filter(adjustment => adjustment.operation === 'add').reduce((sum, adjustment) => sum + adjustment.value, 0);
    const percent = matching.filter(adjustment => adjustment.operation === 'multiply').reduce((sum, adjustment) => sum + adjustment.value - 1, 0);
    result[stat] = Math.max(0, DEFAULT_STATS[stat] + flat + DEFAULT_STATS[stat] * percent);
  }
  return result;
}
export const characters: Record<string, Character> = {
  awakener: {
    id: 'awakener', name: '송진우', description: '현장에서 얻은 장비를 빠르게 익혀 자신의 방식으로 활용하는 각성자.',
    background: '게이트 사태 전에는 서울에서 평범하게 살아가던 청년. 각성 후 엘리트 코스보다 붕괴 지대의 실전을 택했고, 수많은 현장 작전을 거쳤다.',
    personality: '겉으로는 무심하고 크게 동요하지 않는다. 치밀한 계획보다 위험 속의 즉각적인 판단과 생존에 강하며, 서울 사람다운 현실적인 생활 습관이 남아 있다.',
    trait: { name: '현장 적응', description: '모든 무기 피해 +5%', weaponDamageBonus: 0.05 },
    baseStats: { ...DEFAULT_STATS }, radius: 15, portraitSprite: 'songJinwooSD', visual: { sprite: 'songJinwooSD', color: 0x6ff4dd, shape: 'diamond' },
  },
  kangTaehoon: {
    id: 'kangTaehoon', name: '강태훈', description: '초기 게이트 진압 작전을 거친 전직 특수임무요원. 공용 장비와 생존 전술에 능하다.',
    background: '게이트 사태 초기 군의 진압 작전에 참가해 기존 무기가 통하지 않는 괴물과 싸우다 각성했다. 여러 게이트 작전 후 전역했으며 현재 각성자 협회의 현장 작전에 참가한다. 초기 진압 중 공식 기록에 없는 사건을 직접 겪었다.',
    personality: '화려한 능력보다 침착한 상황 판단과 생존 능력을 믿는다. 환경과 장비를 빠르게 파악해 실용적인 해법을 고른다.',
    trait: { name: '특수임무 사격술', description: '총기 무기 피해 +15%', weaponDamageBonus: 0.15, weaponFamily: 'firearm' },
    baseStats: characterStatsFromBaseline([
      { stat: 'maxHp', operation: 'add', value: 10 },
      { stat: 'armor', operation: 'add', value: 5 },
      { stat: 'moveSpeed', operation: 'multiply', value: 0.95 },
    ]),
    radius: 15, portraitSprite: 'kangTaehoonSD',
    visual: { sprite: 'kangTaehoonSD', color: 0x8fa7ae, shape: 'diamond' },
  },
  parkDojun: {
    id:'parkDojun',name:'박도준',description:'49세 전직 지하철 구조반장. 무너진 현장에서도 안전한 길을 찾아내는 각성자.',
    background:'서울 지하철에서 25년 동안 시설과 구조 업무를 맡았다. 게이트 사고 때 마지막 승객을 구하던 중 각성했고, 이제 붕괴 현장의 동료들을 지킨다.',
    personality:'말수가 적고 단단하다. 남의 장비부터 챙겨 주며, 위험할수록 차분하게 다음 수를 고른다.',
    trait:{name:'구조반장의 버팀목',description:'모든 무기 피해 +8%',weaponDamageBonus:0.08},
    baseStats:characterStatsFromBaseline([{stat:'maxHp',operation:'add',value:20},{stat:'armor',operation:'add',value:8},{stat:'moveSpeed',operation:'multiply',value:0.9}]),
    radius:15,portraitSprite:'parkDojunSD',visual:{sprite:'parkDojunSD',color:0xdca550,shape:'diamond'},
  },
  yoonHarin: {
    id:'yoonHarin',name:'윤하린',description:'24세 야간 배송기사. 서울 골목을 누비던 감각으로 균열 사이를 빠르게 돌파한다.',
    background:'통제 구역에도 생필품을 배달하다 균열에 갇힌 주민들을 발견했다. 그들을 이끌고 탈출하면서 각성했으며, 지금도 출동이 끝나면 익숙한 배송 가방을 챙긴다.',
    personality:'빠르게 판단하고 먼저 움직인다. 가벼운 농담으로 긴장을 풀지만, 약속한 도착 시간만큼은 끝까지 지킨다.',
    trait:{name:'골목길 선점',description:'모든 무기 피해 +3%',weaponDamageBonus:0.03},
    baseStats:characterStatsFromBaseline([{stat:'moveSpeed',operation:'multiply',value:1.12},{stat:'dodge',operation:'add',value:0.05},{stat:'maxHp',operation:'add',value:-10}]),
    radius:15,portraitSprite:'yoonHarinSD',visual:{sprite:'yoonHarinSD',color:0x9b82c5,shape:'diamond'},
  },
};

