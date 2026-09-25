import { DEFAULT_STATS } from '../stats';
import type { Character, CharacterStatAdjustment } from '../types';
import type { PlayerStats } from '../stats';

/** Build future characters as explicit differences from Song Jinwoo's neutral baseline. */
export function characterStatsFromBaseline(adjustments: readonly CharacterStatAdjustment[]): PlayerStats {
  const result = { ...DEFAULT_STATS };
  for (const adjustment of adjustments) {
    const current = result[adjustment.stat];
    result[adjustment.stat] = adjustment.operation === 'add' ? current + adjustment.value : current * adjustment.value;
  }
  return result;
}
export const characters: Record<string, Character> = {
  awakener: {
    id: 'awakener', name: '송진우', description: '현장에서 얻은 장비를 빠르게 익혀 자신의 방식으로 활용하는 각성자.',
    background: '게이트 사태 전에는 서울에서 평범하게 살아가던 청년. 각성 후 엘리트 코스보다 붕괴 지대의 실전을 택했고, 수많은 현장 작전을 거쳤다.',
    personality: '겉으로는 무심하고 크게 동요하지 않는다. 치밀한 계획보다 위험 속의 즉각적인 판단과 생존에 강하며, 서울 사람다운 현실적인 생활 습관이 남아 있다.',
    baseStats: { ...DEFAULT_STATS }, radius: 15, portraitSprite: 'songJinwooPortrait', visual: { sprite: 'player', color: 0x6ff4dd, shape: 'diamond', motionStyle: 'scooter' },
  },
  kangTaehoon: {
    id: 'kangTaehoon', name: '강태훈', description: '초기 게이트 진압 작전을 거친 전직 특수임무요원. 공용 장비와 생존 전술에 능하다.',
    background: '게이트 사태 초기 군의 진압 작전에 참가해 기존 무기가 통하지 않는 괴물과 싸우다 각성했다. 여러 게이트 작전 후 전역했으며 현재 각성자 협회의 현장 작전에 참가한다. 초기 진압 중 공식 기록에 없는 사건을 직접 겪었다.',
    personality: '화려한 능력보다 침착한 상황 판단과 생존 능력을 믿는다. 환경과 장비를 빠르게 파악해 실용적인 해법을 고른다.',
    baseStats: characterStatsFromBaseline([
      { stat: 'maxHp', operation: 'add', value: 10 },
      { stat: 'armor', operation: 'add', value: 5 },
      { stat: 'moveSpeed', operation: 'multiply', value: 0.95 },
    ]),
    radius: 15, portraitSprite: 'kangTaehoonPortrait',
    visual: { sprite: 'kangTaehoonTruck', color: 0x8fa7ae, shape: 'diamond', motionStyle: 'truck' },
  },
};

