import { GATE_CONFIG } from '../data/gateProgression';
import type {RunState} from '../state/RunState';
export interface StageReward {
  gateDepth: number; reachedWave: number; completedWaves: number;
  firstClearDepths: number; firstClearReward: number; failureReward: number; total: number;
}
export function calculateStageReward(run:RunState):StageReward {
 const clear=run.phase==='stageClear';
 const reachedWave=Math.max(1,Math.min(run.totalWaves,run.currentWave));
 const completedWaves=clear?run.totalWaves:Math.max(0,reachedWave-1);
 const firstClearDepths=clear?Math.max(0,run.gateDepth-run.characterRewardedThroughDepth):0;
 const firstClearReward=firstClearDepths*GATE_CONFIG.firstClearReward;
 const gateWasUncleared=run.gateDepth>run.characterHighestClearedDepth;
 const failureReward=!clear&&gateWasUncleared?completedWaves*GATE_CONFIG.failureRewardPerCompletedWave:0;
 return {gateDepth:run.gateDepth,reachedWave,completedWaves,firstClearDepths,firstClearReward,failureReward,total:firstClearReward+failureReward};
}
