import { calculateStageReward } from '../meta/StageReward';
import { applyRunResult } from '../meta/progression';
import type { MetaState } from '../state/MetaState';
import type { RunState } from '../state/RunState';

/** One application-owned instance prevents repeated UI callbacks from awarding a run twice. */
export class RunSettlement {
  private readonly settledRuns = new WeakSet<RunState>();

  settle(meta: MetaState, run: RunState): boolean {
    if ((run.phase !== 'gameOver' && run.phase !== 'stageClear') || this.settledRuns.has(run)) return false;
    run.reward=calculateStageReward(run);
    run.earnedMetaCurrency=0;
    run.earnedAssociationCoins=run.reward.total;
    meta.wallet.associationCoins += run.reward.total;
    const progress = meta.gateProgression.characters[run.characterId] ?? { highestClearedDepth: 0, rewardedThroughDepth: 0, bestWaveByDepth: {} };
    progress.bestWaveByDepth[String(run.gateDepth)] = Math.max(progress.bestWaveByDepth[String(run.gateDepth)] ?? 0, run.currentWave);
    if (run.phase === 'stageClear') {
      progress.highestClearedDepth = Math.max(progress.highestClearedDepth, run.gateDepth);
      progress.rewardedThroughDepth = Math.max(progress.rewardedThroughDepth, run.gateDepth);
      meta.gateProgression.highestUnlockedDepth = Math.max(meta.gateProgression.highestUnlockedDepth, run.gateDepth + 1);
    }
    meta.gateProgression.characters[run.characterId] = progress;
    applyRunResult(meta, run);
    const updateAggregate = (record: import('../state/MetaState').AggregateStats): void => {
      record.runs++; if (run.phase === 'stageClear') record.clears++;
      record.kills += run.kills; record.bestWave = Math.max(record.bestWave, run.currentWave);
      record.bestTime = Math.max(record.bestTime, run.stageCombatTime);
    };
    const empty = (): import('../state/MetaState').AggregateStats => ({ runs: 0, clears: 0, kills: 0, bestWave: 0, bestTime: 0 });
    const characterStats = meta.statistics.byCharacter[run.characterId] ?? empty();
    const mapStats = meta.statistics.byMap[run.mapId] ?? empty();
    updateAggregate(characterStats); updateAggregate(mapStats);
    meta.statistics.byCharacter[run.characterId] = characterStats; meta.statistics.byMap[run.mapId] = mapStats;
    meta.statistics.bestWave = Math.max(meta.statistics.bestWave, run.currentWave);
    meta.statistics.lastRun = { recordedAt: new Date().toISOString(), outcome: run.phase, mapId: run.mapId,
      characterId: run.characterId, gateDepth: run.gateDepth, reachedWave: run.currentWave, kills: run.kills,
      combatSeconds: run.stageCombatTime, associationCoins: run.reward.total };
    this.settledRuns.add(run);
    return true;
  }
}
