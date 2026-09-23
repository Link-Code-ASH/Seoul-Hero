import type { StatModifier } from '../stats/PlayerStats';
import { metaUpgrades } from '../data/meta';
import type { MetaEffect } from '../data/meta';
import { isCharacterUnlocked, isFeatureUnlocked, isItemUnlocked, isMapUnlocked, isWeaponUnlocked, type MetaState } from '../state/MetaState';
import type { RunState } from '../state/RunState';

function definition(id: string) {
  return Object.hasOwn(metaUpgrades, id) ? metaUpgrades[id] : undefined;
}

export function getUpgradeCost(meta: MetaState, id: string): number {
  const upgrade = definition(id);
  if (!upgrade) return Infinity;
  if(upgrade.effect.type==='unlock') {
    const checks={character:isCharacterUnlocked,weapon:isWeaponUnlocked,item:isItemUnlocked,stage:isMapUnlocked,feature:isFeatureUnlocked};
    if(checks[upgrade.effect.target](meta,upgrade.effect.contentId))return Infinity;
  }
  const level = meta.association.upgrades[id] ?? 0;
  if (level >= upgrade.maxLevel) return Infinity;
  return Math.ceil(upgrade.baseCost * upgrade.costGrowth ** level);
}

function applyUnlock(meta: MetaState, effect: Extract<MetaEffect, { type: 'unlock' }>): void {
  if (effect.target === 'character') meta.characters[effect.contentId] = { ...(meta.characters[effect.contentId] ?? { fragments: 0, breakthrough: 0 }), unlocked: true };
  else if (effect.target === 'weapon') meta.sharedWeapons[effect.contentId] = { ...(meta.sharedWeapons[effect.contentId] ?? { fragments: 0, level: 0 }), unlocked: true };
  else {
    const list = effect.target === 'item' ? meta.account.unlockedItemIds : effect.target === 'stage' ? meta.account.unlockedMapIds : meta.account.unlockedFeatureIds;
    if (!list.includes(effect.contentId)) list.push(effect.contentId);
  }
}

export function purchaseUpgrade(meta: MetaState, id: string): boolean {
  const upgrade = definition(id);
  const cost = getUpgradeCost(meta, id);
  if (!upgrade || !Number.isFinite(cost) || meta.wallet.associationCoins < cost) return false;
  meta.wallet.associationCoins -= cost;
  meta.association.upgrades[id] = (meta.association.upgrades[id] ?? 0) + 1;
  if (upgrade.effect.type === 'unlock') applyUnlock(meta, upgrade.effect);
  return true;
}

/** The application settles a completed run once, then saves this MetaState. */
export function applyRunResult(
  meta: MetaState,
  run: Pick<RunState, 'phase' | 'runCurrency' | 'earnedMetaCurrency' | 'kills' | 'stageCombatTime'>,
): void {
  if (run.phase !== 'gameOver' && run.phase !== 'stageClear') return;
  const stats = meta.statistics;
  stats.runs += 1; if (run.phase === 'stageClear') stats.clears += 1;
  stats.kills += run.kills; stats.bestTime = Math.max(stats.bestTime, run.stageCombatTime);
}

export function getMetaModifiers(meta: MetaState): StatModifier[] {
  const result: StatModifier[] = [];
  for (const upgrade of Object.values(metaUpgrades)) {
    if (upgrade.effect.type !== 'stat') continue;
    const level = Math.max(0, Math.min(upgrade.maxLevel, meta.association.upgrades[upgrade.id] ?? 0));
    if (!level) continue;
    const mapping = upgrade.effect;
    result.push({ id: upgrade.id, source: 'meta', stat: mapping.stat, operation: mapping.operation,
      value: upgrade.effect.value * level + (mapping.operation === 'multiply' ? 1 : 0) });
  }
  return result;
}
