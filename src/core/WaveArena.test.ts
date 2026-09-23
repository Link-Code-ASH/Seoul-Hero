import { describe, expect, it } from 'vitest';
import { Simulation } from './Simulation';
import { maps } from '../data/maps';
import { createDefaultMeta } from '../state/MetaState';
import { arenaSpawn, cameraPosition, clampToArena } from '../world/Arena';
import { PickupSystem } from '../systems/PickupSystem';

const stage = maps.seoul!;
const view = { width: 1280, height: 720 }, still = { x: 0, y: 0 };
const make = (): Simulation => new Simulation('awakener', 'seoul', createDefaultMeta(), () => 0);
const tick = (sim: Simulation, count = 1): void => { for (let i = 0; i < count; i++) sim.update(.1, still, view); };

describe('finite arena and wave lifecycle', () => {
  it('defines 20 waves with about 15 minutes of nominal combat', () => {
    expect(stage.totalWaves).toBe(20); expect(stage.bossWave).toBe(20);
    expect(stage.arenaWidth).toBe(1280); expect(stage.arenaHeight).toBe(720);
    const duration = stage.waveDefinitions.reduce((sum, w) => sum + w.duration, 0);
    expect(duration).toBeGreaterThanOrEqual(840); expect(duration).toBeLessThanOrEqual(960);
  });
  it('supports different arena sizes and wave counts through stage data alone', () => {
    for (const count of [10, 25]) {
      maps.testArena = { ...stage, id: 'testArena', arenaWidth: 2000, arenaHeight: 1400, totalWaves: count, bossWave: count,
        waveDefinitions: Array.from({ length: count }, (_, i) => ({ ...stage.waveDefinitions[0]!, id: `test_${i}`, waveNumber: i + 1, duration: 2, ...(i === count - 1 ? { boss: { enemyId: 'gatekeeper' } } : {}) })) };
      try {
        const sim = new Simulation('awakener', 'testArena', createDefaultMeta());
        expect(sim.state.totalWaves).toBe(count);
        for (let i = 1; i < count; i++) { sim.completeWave(); expect(sim.continuePostWave()).toBe(true); expect(sim.nextWave()).toBe(true); }
        expect(sim.state.currentWave).toBe(count); expect(sim.state.bossSpawned).toBe(true);
        expect(Math.abs(sim.state.enemies[0]!.x)).toBeLessThanOrEqual(1000);
      } finally { delete maps.testArena; }
    }
  });
  it('ends on the timer, removes all combat entities without rewards and freezes intermission', () => {
    const natural = make(); natural.state.invincible = true; natural.state.ownedWeapons[0]!.cooldownRemaining = 1000;
    tick(natural, 300); expect(natural.state.phase).toBe('postWave');
    expect(natural.state.waveRemainingTime).toBe(0); expect(natural.state.waveElapsedTime).toBe(30);
    expect(natural.state.stageCombatTime).toBe(30);
    const sim = make(); sim.state.invincible = true;
    sim.spawnEnemy('crawler'); sim.state.enemies[0]!.x = 200; sim.state.enemies[0]!.y = 0;
    tick(sim); expect(sim.state.projectiles.length).toBeGreaterThan(0);
    new PickupSystem(() => 999).drop(sim.state, 400, 0, 3);
    sim.state.player.hp = 25;
    const kills = sim.state.kills, currency = sim.state.earnedMetaCurrency;
    sim.setTime(29.95); tick(sim);
    expect(sim.state.phase).toBe('postWave'); expect(sim.state.waveRemainingTime).toBe(0); expect(sim.state.waveElapsedTime).toBe(30);
    expect(sim.state.enemies).toHaveLength(0); expect(sim.state.projectiles).toHaveLength(0);
    expect(sim.state.effects).toHaveLength(0); expect(sim.state.pickups).toHaveLength(1);
    expect(sim.state.kills).toBe(kills); expect(sim.state.earnedMetaCurrency).toBe(currency);
    const snapshot = structuredClone(sim.state);
    tick(sim, 100); sim.resume(); sim.spawnEnemy('runner');
    expect(sim.state).toEqual(snapshot);
    expect(sim.continuePostWave()).toBe(true); expect(sim.nextWave()).toBe(true); expect(sim.state.currentWave).toBe(2);
    expect(sim.state.player.hp).toBe(sim.state.player.maxHp);
    expect(sim.state.waveElapsedTime).toBe(0); expect(sim.state.stageCombatTime).toBe(snapshot.stageCombatTime);
    tick(sim); expect(sim.state.enemies.length).toBeGreaterThan(0);
  });
  it('sequentially completes every ordinary wave and never timer-clears the boss', () => {
    const sim = make(); sim.state.invincible = true;
    for (let n = 1; n < stage.bossWave; n++) {
      expect(sim.state.currentWave).toBe(n);
      sim.setTime(stage.waveDefinitions[n - 1]!.duration - .05); tick(sim);
      expect(sim.state.phase).toBe('postWave'); expect(sim.continuePostWave()).toBe(true); expect(sim.nextWave()).toBe(true);
    }
    expect(sim.state.bossSpawned).toBe(true); expect(sim.state.enemies.filter(e => e.boss)).toHaveLength(1);
    sim.setTime(999); tick(sim); sim.completeWave();
    expect(sim.state.phase).toBe('waveActive'); expect(sim.state.enemies.some(e => e.boss)).toBe(true);
    sim.clearEnemies(); expect(sim.state.phase).toBe('stageClear');
    expect(sim.nextWave()).toBe(false); expect(sim.goToWave(1)).toBe(false);
  });
  it('resets spawn and elite bookkeeping on developer jumps without losing weapons', () => {
    const sim = make(); sim.state.invincible = true; sim.state.earnedMetaCurrency = 50;
    sim.completeWave(); sim.continuePostWave(); sim.debugWeapon('manaSword',false);
    const weapons = structuredClone(sim.state.ownedWeapons);
    for (const n of [10, 1, 10]) {
      expect(sim.goToWave(n)).toBe(true); expect(sim.state.enemies).toHaveLength(0);
      sim.setTime(10); tick(sim);
      expect(sim.state.enemies.filter(e => e.elite)).toHaveLength(n === 10 ? 1 : 0);
    }
    expect(sim.state.ownedWeapons.map(w => [w.id, w.level])).toEqual(weapons.map(w => [w.id, w.level])); expect(sim.state.earnedMetaCurrency).toBe(50);
    const before = structuredClone(sim.state);
    for (const n of [0, 21, 1.5, NaN, Infinity]) expect(sim.goToWave(n)).toBe(false);
    expect(sim.state).toEqual(before);
  });
  it('keeps both combat clocks frozen in pause and the shop', () => {
    const sim = make(); tick(sim); sim.pause(); const t = sim.state.stageCombatTime;
    tick(sim, 50); expect(sim.state.stageCombatTime).toBe(t);
    sim.resume(); sim.completeWave(); sim.continuePostWave(); const waveTime = sim.state.waveElapsedTime;
    tick(sim, 50); expect(sim.state.waveElapsedTime).toBe(waveTime);
    sim.nextWave(); tick(sim);
    expect(sim.state.stageCombatTime).toBeCloseTo(t + .1);
  });
  it('does not simulate future reward/shop/preparation phases', () => {
    const sim = make();
    for (const phase of ['preparing', 'shop'] as const) {
      sim.state.phase = phase; const before = structuredClone(sim.state); tick(sim, 10);
      expect(sim.state).toEqual(before);
    }
  });
  it('clamps actors and camera on all edges and handles oversized viewports', () => {
    for (const x of [-10000, 10000]) for (const y of [-10000, 10000]) {
      const sim = make(); sim.state.player.x = x; sim.state.player.y = y; tick(sim);
      expect(Math.abs(sim.state.player.x)).toBeLessThanOrEqual(stage.arenaWidth / 2 - sim.state.player.radius);
      expect(Math.abs(sim.state.player.y)).toBeLessThanOrEqual(stage.arenaHeight / 2 - sim.state.player.radius);
      for (const v of [view, { width: 720, height: 1280 }, { width: 5000, height: 3000 }]) {
        const camera = cameraPosition(sim.state.player, v, stage);
        expect(Math.abs(camera.x)).toBeLessThanOrEqual(Math.max(0, (stage.arenaWidth - v.width) / 2));
        expect(Math.abs(camera.y)).toBeLessThanOrEqual(Math.max(0, (stage.arenaHeight - v.height) / 2));
      }
    }
  });
  it('spawns inside the arena at safe distance even with corner campers and small arenas', () => {
    for (const arena of [stage, { arenaWidth: 800, arenaHeight: 600 }]) {
      for (const start of [{ x: 0, y: 0 }, { x: 10000, y: 10000 }, { x: -10000, y: -10000 }]) {
        clampToArena(start, 20, arena);
        for (let i = 0; i < 30; i++) {
          const p = arenaSpawn(start, view, 48, arena, () => i / 30)!;
          expect(Math.abs(p.x) + 48).toBeLessThanOrEqual(arena.arenaWidth / 2);
          expect(Math.abs(p.y) + 48).toBeLessThanOrEqual(arena.arenaHeight / 2);
          expect(Math.hypot(p.x - start.x, p.y - start.y)).toBeGreaterThanOrEqual(300);
        }
      }
    }
    expect(arenaSpawn(still, view, 48, { arenaWidth: 100, arenaHeight: 100 }, () => .5)).toBeUndefined();
  });
});

