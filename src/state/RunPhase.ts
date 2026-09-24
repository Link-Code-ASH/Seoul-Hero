export type RunPhase = 'preparing' | 'waveActive' | 'revivalChoice' | 'postWave' | 'shop' | 'paused' | 'stageClear' | 'gameOver';
export const isTerminal = (phase: RunPhase): boolean => phase === 'stageClear' || phase === 'gameOver';
const allowed: Record<RunPhase, readonly RunPhase[]> = {
  preparing: ['waveActive', 'gameOver'],
  waveActive: ['revivalChoice', 'postWave', 'paused', 'stageClear', 'gameOver', 'preparing'],
  revivalChoice: ['waveActive', 'gameOver'],
  postWave: ['shop', 'gameOver', 'preparing'],
  shop: ['preparing', 'gameOver'],
  paused: ['waveActive', 'gameOver', 'preparing'],
  stageClear: [], gameOver: [],
};
/** One explicit transition policy; rejected transitions never mutate the run. */
export function transitionRun(state: { phase: RunPhase }, next: RunPhase): boolean {
  if (!allowed[state.phase].includes(next)) return false;
  state.phase = next; return true;
}
