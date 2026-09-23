import { DEFAULT_STATS } from '../data/stats';
import { calculateStats } from '../stats/PlayerStats';
import type { MetaState } from '../state/MetaState';
import { describe, expect, it } from 'vitest';
import { metaUpgrades } from '../data/meta';
import { createDefaultMeta } from '../state/MetaState';
import { applyRunResult, getMetaModifiers, getUpgradeCost, purchaseUpgrade } from './progression';

const getMetaBonuses = (meta: MetaState) => calculateStats(DEFAULT_STATS, getMetaModifiers(meta));

describe('협회 코인샵', () => {
  it('재화가 부족하거나 존재하지 않는 강화는 상태를 바꾸지 않는다', () => {
    const meta = createDefaultMeta();
    const before = structuredClone(meta);
    expect(purchaseUpgrade(meta, 'vitality')).toBe(false);
    expect(purchaseUpgrade(meta, '__proto__')).toBe(false);
    expect(meta).toEqual(before);
  });

  it('구매한 능력만 다음 판 시작 보너스에 반영하고 가격과 상한을 지킨다', () => {
    const meta = createDefaultMeta();
    meta.wallet.associationCoins = 10_000;
    expect(getMetaBonuses(meta)).toEqual(DEFAULT_STATS);
    const initialCost = getUpgradeCost(meta, 'vitality');
    expect(purchaseUpgrade(meta, 'vitality')).toBe(true);
    expect(meta.wallet.associationCoins).toBe(10_000 - initialCost);
    expect(getUpgradeCost(meta, 'vitality')).toBeGreaterThan(initialCost);
    expect(getMetaBonuses(meta).maxHp).toBe(115);
    expect(purchaseUpgrade(meta, 'power')).toBe(true);
    expect(purchaseUpgrade(meta, 'mobility')).toBe(true);
    expect(getMetaBonuses(meta).damage).toBeCloseTo(1.08);
    expect(getMetaBonuses(meta).moveSpeed).toBeCloseTo(210 * 1.03);
    const cap = metaUpgrades.vitality!.maxLevel;
    for (let level = 1; level < cap; level += 1) expect(purchaseUpgrade(meta, 'vitality')).toBe(true);
    const before = meta.wallet.associationCoins;
    expect(purchaseUpgrade(meta, 'vitality')).toBe(false);
    expect(meta.wallet.associationCoins).toBe(before);
    expect(getUpgradeCost(meta, 'vitality')).toBe(Infinity);
  });

  it('해금 구매는 콘텐츠 목록을 갱신하고 두 번 지불하지 않는다', () => {
    const meta = createDefaultMeta();
    meta.wallet.associationCoins = 200;
    expect(purchaseUpgrade(meta, 'reroll')).toBe(true);
    expect(meta.account.unlockedFeatureIds).toEqual(['reroll']);
    expect(purchaseUpgrade(meta, 'reroll')).toBe(false);
    expect(meta.wallet.associationCoins).toBe(120);
  });

  it('끝난 판의 보상과 통계만 정산하며 가장 오래 생존한 기록을 유지한다', () => {
    const meta = createDefaultMeta();
    applyRunResult(meta, { phase: 'waveActive', runCurrency: 0, earnedMetaCurrency: 30, kills: 20, stageCombatTime: 200 });
    expect(meta.statistics.runs).toBe(0);
    applyRunResult(meta, { phase: 'gameOver', runCurrency: 0, earnedMetaCurrency: 30, kills: 20, stageCombatTime: 200 });
    applyRunResult(meta, { phase: 'stageClear', runCurrency: 30, earnedMetaCurrency: 100, kills: 40, stageCombatTime: 100 });
    expect(meta.wallet.associationCoins).toBe(160);
    expect(meta.statistics).toEqual({ bestWave:0,totalMetaEarned:0, runs: 2, clears: 1, totalKills: 60, bestTime: 200 });
  });
});

