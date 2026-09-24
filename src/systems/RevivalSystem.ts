import { REVIVAL_CONFIG, REVIVAL_STONES, REVIVAL_STONE_GRADES, type RevivalStoneGrade } from '../data/revivalStones';
import type { MetaState } from '../state/MetaState';
import { transitionRun } from '../state/RunPhase';
import type { RunState } from '../state/RunState';

export const hasRevivalStone = (meta: MetaState): boolean => REVIVAL_STONE_GRADES.some(grade => meta.wallet.revivalStones[grade] > 0);

/** Consume one persistent stone only after the downed run is ready to resume. */
export function useRevivalStone(run: RunState, meta: MetaState, grade: RevivalStoneGrade): boolean {
  if (run.phase !== 'revivalChoice' || !Object.hasOwn(REVIVAL_STONES, grade) || meta.wallet.revivalStones[grade] < 1) return false;
  if (!transitionRun(run, 'waveActive')) return false;
  meta.wallet.revivalStones[grade]--;
  run.player.hp = Math.max(1, Math.ceil(run.player.maxHp * REVIVAL_STONES[grade].healthFraction));
  run.player.invulnerability = REVIVAL_CONFIG.invulnerabilitySeconds;
  return true;
}

export function declineRevival(run: RunState): boolean {
  return run.phase === 'revivalChoice' && transitionRun(run, 'gameOver');
}
