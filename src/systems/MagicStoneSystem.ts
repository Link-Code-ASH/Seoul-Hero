import type { RunState } from '../state/RunState';
/** A collected magic stone funds the current Run and releases deferred wallet stones one-for-one. */
export function collectMagicStone(run: RunState, baseAmount: number, pickupUnits = 1): { currency: number } {
  if (!Number.isFinite(baseAmount) || baseAmount <= 0) return { currency: 0 };
  const recovered = Math.min(Math.max(0, pickupUnits), run.walletBonusRemaining);
  const currency = baseAmount * run.calculatedStats.currencyGain + recovered;
  run.walletBonusRemaining -= recovered;
  run.runCurrency += currency;
  run.collectedMagicStone += currency;
  return { currency };
}
