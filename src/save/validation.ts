import { characters } from '../data/characters';
import { items } from '../data/items';
import { maps } from '../data/maps';
import { metaUpgrades } from '../data/meta';
import { dangunBlessings, weeklyGateRules } from '../data/weeklyGate';
import { weapons } from '../data/weapons';
import { createDefaultMeta, type AggregateStats, type MetaState } from '../state/MetaState';

export function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null && !Array.isArray(value); }
const unsafeKeys = new Set(['__proto__', 'constructor', 'prototype']);
const MAX_COUNTER = 1_000_000_000_000;
const safeId = (value: unknown): value is string => typeof value === 'string' && /^[a-zA-Z][a-zA-Z0-9_-]{0,79}$/.test(value) && !unsafeKeys.has(value);
function bounded(value: unknown, fallback: number, max: number, integer = true): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  const number = Math.max(0, Math.min(max, value)); return integer ? Math.floor(number) : number;
}
function knownList(value: unknown, registry: Record<string, unknown>, defaults: string[]): string[] {
  if (!Array.isArray(value)) return [...defaults];
  return [...new Set([...defaults, ...value.filter((id): id is string => safeId(id) && Object.hasOwn(registry, id))])];
}
function aggregate(value: unknown): AggregateStats {
  if (!isRecord(value)) return { runs: 0, clears: 0, kills: 0, bestWave: 0, bestTime: 0 };
  const runs = bounded(value.runs, 0, MAX_COUNTER);
  return { runs, clears: bounded(value.clears, 0, runs), kills: bounded(value.kills, 0, MAX_COUNTER),
    bestWave: bounded(value.bestWave, 0, 100_000), bestTime: bounded(value.bestTime, 0, MAX_COUNTER, false) };
}
function progressRecords<T>(value: unknown, registry: Record<string, unknown>, make: (raw: Record<string, unknown>) => T): Record<string, T> {
  const result: Record<string, T> = {};
  if (!isRecord(value)) return result;
  for (const [id, raw] of Object.entries(value)) if (safeId(id) && Object.hasOwn(registry, id) && isRecord(raw)) result[id] = make(raw);
  return result;
}

/** Salvages known progress while dropping invalid and unknown content IDs. */
export function validateMeta(value: unknown): MetaState {
  if (!isRecord(value)) throw new Error('영구 진행 데이터가 올바르지 않습니다.');
  const result = createDefaultMeta();
  if (isRecord(value.account)) {
    result.account.unlockedMapIds = knownList(value.account.unlockedMapIds, maps, result.account.unlockedMapIds);
    result.account.unlockedItemIds = knownList(value.account.unlockedItemIds, items, []);
    result.account.unlockedFeatureIds = Array.isArray(value.account.unlockedFeatureIds) ? value.account.unlockedFeatureIds.filter(safeId).slice(0, 1_000) : [];
  }
  if (isRecord(value.wallet)) {
    result.wallet.associationCoins = bounded(value.wallet.associationCoins, 0, MAX_COUNTER);
    result.wallet.supplyTickets = bounded(value.wallet.supplyTickets, 0, MAX_COUNTER);
  }
  if (isRecord(value.association) && isRecord(value.association.upgrades)) for (const [id, level] of Object.entries(value.association.upgrades)) {
    if (!safeId(id)) continue; const definition = Object.hasOwn(metaUpgrades, id) ? metaUpgrades[id] : undefined;
    result.association.upgrades[id] = bounded(level, 0, definition?.maxLevel ?? 10_000);
  }
  result.characters = { ...result.characters, ...progressRecords(value.characters, characters, raw => ({
    unlocked: raw.unlocked === true, fragments: bounded(raw.fragments, 0, MAX_COUNTER), breakthrough: bounded(raw.breakthrough, 0, 1_000),
  })) };
  result.sharedWeapons = { ...result.sharedWeapons, ...progressRecords(value.sharedWeapons, weapons, raw => ({
    unlocked: raw.unlocked === true, fragments: bounded(raw.fragments, 0, MAX_COUNTER), level: bounded(raw.level, 0, 1_000),
  })) };
  result.blessings = progressRecords(value.blessings, dangunBlessings, raw => ({
    unlocked: raw.unlocked === true, fragments: bounded(raw.fragments, 0, MAX_COUNTER), level: bounded(raw.level, 0, 1_000),
  }));
  // Reconstruct paid unlocks so an incomplete imported record cannot hide purchased content.
  for (const upgrade of Object.values(metaUpgrades)) {
    if (upgrade.effect.type !== 'unlock' || (result.association.upgrades[upgrade.id] ?? 0) < 1) continue;
    const { target, contentId } = upgrade.effect;
    if (target === 'character' && characters[contentId]) result.characters[contentId] = { ...(result.characters[contentId] ?? { fragments: 0, breakthrough: 0 }), unlocked: true };
    else if (target === 'weapon' && weapons[contentId]) result.sharedWeapons[contentId] = { ...(result.sharedWeapons[contentId] ?? { fragments: 0, level: 0 }), unlocked: true };
    else if (target === 'item' && items[contentId] && !result.account.unlockedItemIds.includes(contentId)) result.account.unlockedItemIds.push(contentId);
    else if (target === 'stage' && maps[contentId] && !result.account.unlockedMapIds.includes(contentId)) result.account.unlockedMapIds.push(contentId);
    else if (target === 'feature' && !result.account.unlockedFeatureIds.includes(contentId)) result.account.unlockedFeatureIds.push(contentId);
  }
  if (isRecord(value.gateProgression)) {
    result.gateProgression.highestUnlockedDepth = Math.max(1, bounded(value.gateProgression.highestUnlockedDepth, 1, 100_000));
    if (isRecord(value.gateProgression.characters)) for (const [id, raw] of Object.entries(value.gateProgression.characters)) {
      if (!Object.hasOwn(characters, id) || !isRecord(raw)) continue;
      const highestClearedDepth = bounded(raw.highestClearedDepth, 0, 100_000);
      const bestWaveByDepth: Record<string, number> = {};
      if (isRecord(raw.bestWaveByDepth)) for (const [depth, wave] of Object.entries(raw.bestWaveByDepth)) if (/^\d{1,6}$/.test(depth) && Number(depth) > 0) bestWaveByDepth[depth] = bounded(wave, 0, 20);
      result.gateProgression.characters[id] = { highestClearedDepth,
        rewardedThroughDepth: Math.min(highestClearedDepth, bounded(raw.rewardedThroughDepth, 0, 100_000)), bestWaveByDepth };
    }
  }
  if (isRecord(value.weeklyGate)) {
    result.weeklyGate = { weekKey: typeof value.weeklyGate.weekKey === 'string' ? value.weeklyGate.weekKey : '',
      ruleId: typeof value.weeklyGate.ruleId === 'string' && Object.hasOwn(weeklyGateRules, value.weeklyGate.ruleId) ? value.weeklyGate.ruleId : '',
      remainingRuleIds: Array.isArray(value.weeklyGate.remainingRuleIds) ? value.weeklyGate.remainingRuleIds.filter((id): id is string => typeof id === 'string' && Object.hasOwn(weeklyGateRules, id)) : [] };
  }
  if (isRecord(value.supply) && isRecord(value.supply.boxes)) for (const [id, raw] of Object.entries(value.supply.boxes)) if (safeId(id) && isRecord(raw)) result.supply.boxes[id] = { opened: bounded(raw.opened, 0, MAX_COUNTER), pity: bounded(raw.pity, 0, MAX_COUNTER) };
  if (isRecord(value.offlineReward)) {
    result.offlineReward.lastExitAt = typeof value.offlineReward.lastExitAt === 'string' ? value.offlineReward.lastExitAt : '';
    result.offlineReward.lastClaimedAt = typeof value.offlineReward.lastClaimedAt === 'string' ? value.offlineReward.lastClaimedAt : '';
    if (isRecord(value.offlineReward.pendingRewards)) {
      const pending=value.offlineReward.pendingRewards;
      result.offlineReward.pendingRewards.associationCoins=bounded(pending.associationCoins,0,MAX_COUNTER);
      result.offlineReward.pendingRewards.supplyTickets=bounded(pending.supplyTickets,0,MAX_COUNTER);
      const groups=[['characterFragments',characters],['weaponFragments',weapons],['blessingFragments',dangunBlessings]] as const;
      for(const [key,registry] of groups)if(isRecord(pending[key]))for(const [id,amount] of Object.entries(pending[key]))if(safeId(id)&&Object.hasOwn(registry,id))result.offlineReward.pendingRewards[key][id]=bounded(amount,0,MAX_COUNTER);
    }
  }
  if (isRecord(value.statistics)) {
    Object.assign(result.statistics, aggregate(value.statistics));
    if (isRecord(value.statistics.byCharacter)) for (const [id, raw] of Object.entries(value.statistics.byCharacter)) if (characters[id]) result.statistics.byCharacter[id] = aggregate(raw);
    if (isRecord(value.statistics.byMap)) for (const [id, raw] of Object.entries(value.statistics.byMap)) if (maps[id]) result.statistics.byMap[id] = aggregate(raw);
    if (isRecord(value.statistics.lastRun)) {
      const raw = value.statistics.lastRun;
      if ((raw.outcome === 'stageClear' || raw.outcome === 'gameOver') && typeof raw.mapId === 'string' && maps[raw.mapId] && typeof raw.characterId === 'string' && characters[raw.characterId])
        result.statistics.lastRun = { recordedAt: typeof raw.recordedAt === 'string' ? raw.recordedAt : '', outcome: raw.outcome, mapId: raw.mapId, characterId: raw.characterId,
          gateDepth: bounded(raw.gateDepth, 1, 100_000), reachedWave: bounded(raw.reachedWave, 1, 100_000), kills: bounded(raw.kills, 0, MAX_COUNTER),
          combatSeconds: bounded(raw.combatSeconds, 0, MAX_COUNTER, false), associationCoins: bounded(raw.associationCoins, 0, MAX_COUNTER) };
    }
  }
  if (isRecord(value.settings)) {
    for (const key of ['masterVolume','soundVolume','combatVolume','uiVolume','musicVolume'] as const) result.settings[key] = bounded(value.settings[key], result.settings[key], 1, false);
    for (const key of ['muted','highResolution','developerMode'] as const) if (typeof value.settings[key] === 'boolean') result.settings[key] = value.settings[key];
  }
  return result;
}
