import type { RevivalStoneGrade } from '../data/revivalStones';

export type RevivalStoneInventory = Record<RevivalStoneGrade, number>;
export const emptyRevivalStones = (): RevivalStoneInventory => ({ low: 0, mid: 0, high: 0 });

export interface Settings {
  masterVolume: number; soundVolume: number; combatVolume: number; uiVolume: number; musicVolume: number;
  muted: boolean; highResolution: boolean; developerMode: boolean;
}
export interface CharacterGateProgress { highestClearedDepth: number; rewardedThroughDepth: number; bestWaveByDepth: Record<string, number> }
export interface GateProgressionState { highestUnlockedDepth: number; characters: Record<string, CharacterGateProgress> }
export interface WeeklyGateState { weekKey: string; ruleId: string; remainingRuleIds: string[] }
export interface CharacterProgress { unlocked: boolean; fragments: number; breakthrough: number }
export interface SharedWeaponProgress { unlocked: boolean; fragments: number; level: number }
export interface BlessingProgress { unlocked: boolean; fragments: number; level: number }
export interface PendingOfflineRewards {
  associationCoins: number; supplyTickets: number;
  characterFragments: Record<string, number>; weaponFragments: Record<string, number>; blessingFragments: Record<string, number>;
  revivalStones: RevivalStoneInventory;
}
export interface RunResultSummary {
  recordedAt: string; outcome: 'stageClear' | 'gameOver'; mapId: string; characterId: string;
  gateDepth: number; reachedWave: number; kills: number; combatSeconds: number; associationCoins: number;
}
export interface AggregateStats { runs: number; clears: number; kills: number; bestWave: number; bestTime: number }
export interface MetaStatistics extends AggregateStats { byCharacter: Record<string, AggregateStats>; byMap: Record<string, AggregateStats>; lastRun?: RunResultSummary }

/** Persists between runs. Active combat and Run currency never belong here. */
export interface MetaState {
  account: { unlockedMapIds: string[]; unlockedItemIds: string[]; unlockedFeatureIds: string[] };
  wallet: { associationCoins: number; supplyTickets: number; revivalStones: RevivalStoneInventory };
  association: { upgrades: Record<string, number> };
  gateProgression: GateProgressionState;
  characters: Record<string, CharacterProgress>;
  sharedWeapons: Record<string, SharedWeaponProgress>;
  blessings: Record<string, BlessingProgress>;
  weeklyGate: WeeklyGateState;
  supply: { boxes: Record<string, { opened: number; pity: number }> };
  offlineReward: { lastExitAt: string; lastClaimedAt: string; pendingRewards: PendingOfflineRewards };
  statistics: MetaStatistics;
  settings: Settings;
}

const emptyStats = (): AggregateStats => ({ runs: 0, clears: 0, kills: 0, bestWave: 0, bestTime: 0 });
export function createDefaultMeta(): MetaState {
  return {
    account: { unlockedMapIds: ['seoul'], unlockedItemIds: [], unlockedFeatureIds: [] },
    wallet: { associationCoins: 0, supplyTickets: 0, revivalStones: emptyRevivalStones() }, association: { upgrades: {} },
    gateProgression: { highestUnlockedDepth: 1, characters: {} },
    characters: { awakener: { unlocked: true, fragments: 0, breakthrough: 0 }, kangTaehoon: { unlocked: true, fragments: 0, breakthrough: 0 } },
    sharedWeapons: { manaBolt: { unlocked: true, fragments: 0, level: 0 }, manaShotgun: { unlocked: true, fragments: 0, level: 0 } }, blessings: {},
    weeklyGate: { weekKey: '', ruleId: '', remainingRuleIds: [] },
    supply: { boxes: {} }, offlineReward: { lastExitAt: '', lastClaimedAt: '', pendingRewards: emptyOfflineRewards() },
    statistics: { ...emptyStats(), byCharacter: {}, byMap: {} },
    settings: { masterVolume: 0.8, soundVolume: 0.8, combatVolume: 0.72, uiVolume: 0.78, musicVolume: 0.5,
      muted: false, highResolution: true, developerMode: false },
  };
}

export const emptyOfflineRewards = (): PendingOfflineRewards => ({ associationCoins: 0, supplyTickets: 0,
  characterFragments: {}, weaponFragments: {}, blessingFragments: {}, revivalStones: emptyRevivalStones() });

export const isCharacterUnlocked = (meta: MetaState, id: string): boolean => meta.characters[id]?.unlocked === true;
export const isWeaponUnlocked = (meta: MetaState, id: string): boolean => meta.sharedWeapons[id]?.unlocked === true;
export const isItemUnlocked = (meta: MetaState, id: string): boolean => meta.account.unlockedItemIds.includes(id);
export const isMapUnlocked = (meta: MetaState, id: string): boolean => meta.account.unlockedMapIds.includes(id);
export const isFeatureUnlocked = (meta: MetaState, id: string): boolean => meta.account.unlockedFeatureIds.includes(id);
