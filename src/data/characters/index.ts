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
  awakener: { id: 'awakener', name: '송진우', description: '서울의 붕괴 지대를 순찰하는 각성자. 출동 전 임무에 맞는 전투 무기를 선택합니다.', baseStats: { ...DEFAULT_STATS }, radius: 15, visual: { sprite: 'player', color: 0x6ff4dd, shape: 'diamond' } },
};

