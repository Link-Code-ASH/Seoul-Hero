import { describe, expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { RunSettlement } from './RunSettlement';
import { Simulation } from './Simulation';
import { collectMagicStone } from '../systems/MagicStoneSystem';

describe('run settlement', () => {
  it('keeps missed stones unavailable in the Shop, then releases one beside each next-Wave pickup', () => {
    const meta = createDefaultMeta();
    const sim = new Simulation('awakener', 'seoul', meta);
    sim.state.pickups.push(
      { id: 90, kind: 'magicStone', x: 500, y: 200, radius: 9, value: 3, age: 2 },
      { id: 91, kind: 'magicStone', x: -300, y: 150, radius: 9, value: 5, age: 4 },
    );
    sim.completeWave();
    for (let frame = 0; frame < 240 && sim.state.pickups.length > 0; frame++) {
      sim.sweepPickupsToWallet(1 / 60, { x: -600, y: -300 });
    }
    expect(sim.state.pickups).toHaveLength(0);
    expect(sim.state.walletStoredThisRun).toBe(8);
    expect(sim.state.runCurrency).toBe(0);
    expect(sim.continuePostWave()).toBe(true);
    expect(sim.state.phase).toBe('shop');
    expect(sim.state.runCurrency).toBe(0);
    expect(sim.state.walletBonusRemaining).toBe(0);
    expect(sim.nextWave()).toBe(true);
    expect(sim.state.walletStoredThisRun).toBe(0);
    expect(sim.state.walletBonusRemaining).toBe(8);
    expect(collectMagicStone(sim.state, 1, 1)).toEqual({ currency: 2 });
    expect(sim.state.walletBonusRemaining).toBe(7);
  });

  it('starts every run with an empty wallet and does not persist Wave wallet value', () => {
    const meta = createDefaultMeta();
    meta.wallet.associationCoins = 50; meta.offlineReward.pendingRewards.associationCoins = 2;
    const sim = new Simulation('awakener', 'seoul', meta);
    expect(sim.state.runCurrency).toBe(0);
    expect(sim.state.walletBonusRemaining).toBe(0);
    expect(collectMagicStone(sim.state, 1)).toEqual({ currency: 1 });
    sim.state.pickups.push({ id: 99, kind: 'magicStone', x: 0, y: 0, radius: 9, value: 3, age: 0 });
    sim.endRun();
    new RunSettlement().settle(meta, sim.state);
    expect(meta.offlineReward.pendingRewards.associationCoins).toBe(2);
    expect(meta.wallet.associationCoins).toBe(51);
    const next = new Simulation('awakener', 'seoul', meta);
    expect(next.state.runCurrency).toBe(0);
    expect(next.state.walletBonusRemaining).toBe(0);
  });
  it('awards a ended run once even when multiple UI callbacks submit it', () => {
    const meta = createDefaultMeta();
    const sim = new Simulation('awakener', 'seoul', meta);
    const settlement = new RunSettlement();
    sim.state.earnedMetaCurrency = 999; sim.state.currentWave=3;
    sim.state.kills = 9;
    sim.state.stageCombatTime = 120;
    sim.endRun();
    expect(settlement.settle(meta, sim.state)).toBe(true);
    const settled = structuredClone(meta);
    expect(settlement.settle(meta, sim.state)).toBe(false);
    expect(settlement.settle(meta, sim.state)).toBe(false);
    expect(meta).toEqual(settled);
    expect(meta.wallet.associationCoins).toBe(16);
    expect(meta.statistics).toEqual({ bestWave:3,totalMetaEarned:16,runs: 1, clears: 0, totalKills: 9, bestTime: 120 });
  });

  it('does not award active or paused runs and allows later settlement', () => {
    const meta = createDefaultMeta();
    const sim = new Simulation('awakener', 'seoul', meta);
    const settlement = new RunSettlement();
    sim.state.earnedMetaCurrency = 10;
    expect(settlement.settle(meta, sim.state)).toBe(false);
    sim.pause();
    expect(settlement.settle(meta, sim.state)).toBe(false);
    expect(meta.wallet.associationCoins).toBe(0);
    expect(meta.statistics.runs).toBe(0);
    sim.endRun();
    expect(settlement.settle(meta, sim.state)).toBe(true);
    expect(meta.wallet.associationCoins).toBe(0);
  });

  it('awards full boss completion once and independently settles the next run', () => {
    const meta = createDefaultMeta();
    const settlement = new RunSettlement();
    const first = new Simulation('awakener', 'seoul', meta);
    first.spawnBoss();
    first.clearEnemies();
    first.endRun();
    expect(first.state.phase).toBe('stageClear');
    expect(settlement.settle(meta, first.state)).toBe(true);
    expect(settlement.settle(meta, first.state)).toBe(false);
    expect(meta.wallet.associationCoins).toBe(320);
    expect(meta.statistics.clears).toBe(1);
    const second = new Simulation('awakener', 'seoul', meta);
    second.state.earnedMetaCurrency = 5;
    second.endRun();
    expect(settlement.settle(meta, second.state)).toBe(true);
    expect(meta.wallet.associationCoins).toBe(320);
    expect(meta.statistics.runs).toBe(2);
    expect(meta.statistics.clears).toBe(1);
  });
});

