import {calculateStageReward} from '../meta/StageReward';
import { expect, it } from 'vitest';
import { Simulation } from '../core/Simulation';
import { GAME_CONFIG } from '../data/config';
import { createDefaultMeta } from '../state/MetaState';

it.each([12345, 7319, 2026])('runs all waves and a full-health boss through the combined shop (seed %s)', initialSeed => {
  let seed = initialSeed;
  const random = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  const sim = new Simulation('awakener', 'seoul', createDefaultMeta(), random);
  sim.state.invincible = true;
  const viewport = { width: 1280, height: 720 };
  const direction = { x: 0, y: 0 };
  const visitedWaves = new Set<string>();
  let weaponPurchases = 0;
  for (let step = 0; step < 12000 && sim.state.phase !== 'stageClear'; step++) {
    if (sim.state.phase === 'postWave') expect(sim.continuePostWave()).toBe(true);
    if (sim.state.phase === 'shop') {
      for (let index=0;index<4;index++) if(sim.buyShopWeapon(index)){weaponPurchases++;if(sim.state.pendingBranchWeaponId)expect(sim.chooseBranch('A')).toBe(true);}
      expect(sim.nextWave()).toBe(true);
    }
    const pickup = sim.state.pickups[0];
    const boss = sim.state.enemies.find((enemy) => enemy.boss);
    const destination = boss ?? pickup;
    const distance = destination ? Math.hypot(destination.x - sim.state.player.x, destination.y - sim.state.player.y) : 0;
    direction.x = destination && distance > 0 ? (destination.x - sim.state.player.x) / distance : 0;
    direction.y = destination && distance > 0 ? (destination.y - sim.state.player.y) / distance : 0;
    sim.update(0.1, direction, viewport);
    visitedWaves.add(sim.state.waveId);
    expect(sim.state.enemies.length).toBeLessThanOrEqual(451);
    expect(sim.state.projectiles.length).toBeLessThanOrEqual(GAME_CONFIG.combat.maxProjectiles);
    expect(sim.state.pickups.length).toBeLessThanOrEqual(GAME_CONFIG.combat.maxPickups);
    expect(Number.isFinite(sim.state.player.x)).toBe(true);
  }
  expect(weaponPurchases).toBeGreaterThan(0);
  expect(visitedWaves.size).toBe(20);
  expect(sim.state.phase).toBe('stageClear');
  expect(sim.state.stageCombatTime).toBeGreaterThanOrEqual(835);
  expect(sim.state.kills).toBeGreaterThan(100);
  expect(sim.state.earnedMetaCurrency).toBe(0); expect(calculateStageReward(sim.state).total).toBe(320);
}, 15000);
