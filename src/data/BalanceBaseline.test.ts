import { describe, expect, it } from 'vitest';
import { BALANCE_CONFIG } from './balanceConfig';
import { characters } from './characters';
import { enemies } from './enemies';
import { LIBRARY_MONSTERS } from './enemies/library';
import { ENEMY_RULES } from './enemyConfig';
import { GATE_MILESTONES, WEEKLY_MONSTER, gateDifficulty, resolveGateWave, runElite, weekNumber, weeklyMonster } from './gateProgression';
import { maps } from './maps';
import { DEFAULT_STATS } from './stats';
import { weapons } from './weapons';
import { weaponBranches } from './weapons/branches';
import { resolveWeaponStats } from '../stats/WeaponStats';
import { WEAPON_CONFIG } from './weaponConfig';

const WEEKLY_VECTORS = ['summoner', 'splitter', 'lampFirefly', 'splitter'];

describe('Song Jinwoo / Gwanghwamun / depth 1 baseline', () => {
  it('declares the canonical ids and neutral multipliers', () => {
    expect(BALANCE_CONFIG.baseline).toEqual({ characterId: 'awakener', mapId: 'seoul', gateDepth: 1 });
    expect(characters.awakener!.baseStats).toEqual(DEFAULT_STATS);
    expect(maps.seoul!.balanceModifiers).toEqual({ enemyHp: 1, enemyDamage: 1, enemySpeed: 1, spawnDensity: 1, rewards: 1 });
    expect(gateDifficulty(1)).toEqual({ hp: 1, damage: 1, speed: 1, spawn: 1, reward: 1, eliteChance: 0, eliteModifiers: [] });
  });

  it('uses the reduced Gwanghwamun density as the authored 100% data', () => {
    const waves = maps.seoul!.waveDefinitions;
    expect(waves[0]).toMatchObject({ interval: 1.57, maxEnemies: 63 });
    expect(waves[9]).toMatchObject({ interval: 1.43, maxEnemies: 140 });
    expect(waves[19]).toMatchObject({ interval: 1.11, maxEnemies: 225 });
  });

  it('fields only the four 광화문 regulars on every Wave, the boss Wave included', () => {
    const waves = maps.seoul!.waveDefinitions, regulars = ['crawler', 'spitter', 'runner', 'bulwark'];
    expect(regulars.map(id => enemies[id]!.behavior)).toEqual(['chase', 'ranged', 'charge', 'tank']);
    for (const wave of waves) {
      expect(wave.enemies.length).toBeGreaterThan(0);
      expect(wave.enemies.every(entry => regulars.includes(entry.enemyId))).toBe(true);
      expect(wave.enemies.reduce((sum, entry) => sum + entry.weight, 0)).toBe(100);
    }
    // The boss Wave spawns like Wave 19 beside the boss.
    expect(waves[19]).toMatchObject({ interval: waves[18]!.interval, batch: waves[18]!.batch, maxEnemies: waves[18]!.maxEnemies, boss: { enemyId: 'gatekeeper' } });
    expect(waves[19]!.enemies).toEqual(waves[18]!.enemies);
    expect(waves[13]!.surge).toMatchObject({ lastSeconds: 15, spawnMultiplier: 1.5, rewardMultiplier: 1.5 });
  });

  it('keeps the same cast at every depth and only scales difficulty', () => {
    const waves = maps.seoul!.waveDefinitions;
    for (const depth of [1, 10, 20, 37]) for (const wave of waves) {
      const resolved = resolveGateWave(wave, depth);
      expect(resolved.enemies).toEqual(wave.enemies);
      expect(resolved.boss).toEqual(wave.boss);
    }
    expect(GATE_MILESTONES.every(entry => !('enemyAdditions' in entry) && !('bossId' in entry))).toBe(true);
    expect(gateDifficulty(20).eliteModifiers).toEqual(['ARMORED', 'BERSERK', 'REGENERATING']);
    expect(resolveGateWave(waves[6]!, 9).elites![0]!.modifiers).toEqual([]);
    expect(resolveGateWave(waves[6]!, 10).elites![0]!.modifiers).toEqual(['CURSED_AURA']);
    // Archived art-library families stay registered but no Wave references them.
    expect(LIBRARY_MONSTERS).toHaveLength(20);
    expect(LIBRARY_MONSTERS.every(monster => Object.hasOwn(enemies, monster.id))).toBe(true);
  });

  it('draws one elite body per Run: 1 on Wave 7, 2 on Wave 14, 2 beside the boss', () => {
    const map = maps.seoul!, waves = map.waveDefinitions;
    expect(map.elitePool).toEqual(['charger', 'haetaeHead']);
    expect(enemies.charger!.charge).toMatchObject({ repeats: 2 });
    expect(enemies.haetaeHead).toMatchObject({ behavior: 'tank', quake: { repeats: 2 } });
    expect(enemies.haetaeHead!.quake!.radius!).toBeGreaterThan(ENEMY_RULES.tankRadius);
    expect(waves.filter(wave => wave.elites).map(wave => [wave.waveNumber, wave.elites!.length])).toEqual([[7, 1], [14, 2], [20, 2]]);
    expect(runElite(map.elitePool, 0)).toBe('charger');
    expect(runElite(map.elitePool, 0.999)).toBe('haetaeHead');
    for (const eliteId of map.elitePool!) for (const [index, hp] of [[6, [1560]], [13, [775, 775]], [19, [1000, 1000]]] as const) {
      const elites = resolveGateWave(waves[index]!, 1, { eliteId }).elites!;
      expect(elites.every(elite => elite.enemyId === eliteId && elite.featured)).toBe(true);
      expect(elites.map(elite => Math.round(elite.hpMultiplier * enemies[eliteId]!.maxHp))).toEqual(hp);
    }
  });

  it('gives the gatekeeper one dedicated bullet-scatter pattern and no summon', () => {
    expect(enemies.gatekeeper!.bossPatterns).toHaveLength(1);
    expect(enemies.gatekeeper!.bossPatterns![0]).toMatchObject({ type: 'spiral' });
  });

  it('adds one weekly monster as the lead of Waves 3/6/9/12/15/18, turning over Sunday 05:00 KST', () => {
    const waves = maps.seoul!.waveDefinitions;
    // 2026-10-10 20:00 UTC is Sunday 05:00 KST.
    const boundary = Date.UTC(2026, 9, 10, 20) / 1000;
    expect(weekNumber(boundary) - weekNumber(boundary - 1)).toBe(1);
    expect(weekNumber(boundary + 604_799)).toBe(weekNumber(boundary));
    const week = weekNumber(boundary);
    // One monster per weekly pattern; the ten former weekly monsters stay in data only.
    expect(WEEKLY_MONSTER.pool.map(id => enemies[id]!.behavior)).toEqual(['summoner', 'splitter', 'bomber']);
    expect(WEEKLY_MONSTER.reserve).toHaveLength(10);
    expect([...WEEKLY_MONSTER.pool, ...WEEKLY_MONSTER.reserve].every(id => Object.hasOwn(enemies, id) && !waves.some(wave => wave.enemies.some(entry => entry.enemyId === id)))).toBe(true);
    expect(WEEKLY_MONSTER.reserve.some(id => (WEEKLY_MONSTER.pool as readonly string[]).includes(id) || maps.seoul!.archiveContent!.enemyIds!.includes(id))).toBe(false);
    expect(enemies.summoner!.summon).toMatchObject({ interval: 4, count: 1 });
    expect(enemies.splitter!.split).toMatchObject({ count: 2, generations: 2 });
    expect(weeklyMonster(week)).toBe(weeklyMonster(week));
    // Shuffle bag: every bag of three weeks deals each monster once, in every order over time, and no week repeats the one before.
    const orders = new Set<string>();
    for (let bag = 0; bag < 1200; bag += 1) {
      const dealt = [0, 1, 2].map(offset => weeklyMonster(bag * 3 + offset));
      expect(new Set(dealt)).toEqual(new Set(WEEKLY_MONSTER.pool));
      expect(weeklyMonster(bag * 3 + 3)).not.toBe(dealt[2]);
      orders.add(dealt.join());
    }
    expect(orders.size).toBe(6);
    // Fixed vectors shared with godot/tools/run_structure_capture.gd.
    expect([2961, 2962, 2963, 2973].map(value => weeklyMonster(value))).toEqual(WEEKLY_VECTORS);
    // While the switch is off the map's archive lists no weekly-only monster and no Wave gets a lead.
    expect(WEEKLY_MONSTER.pool.some(id => maps.seoul!.archiveContent!.enemyIds!.includes(id))).toBe(WEEKLY_MONSTER.enabled);
    for (const wave of waves) {
      const resolved = resolveGateWave(wave, 1, { week });
      expect(resolved.enemies.reduce((sum, entry) => sum + entry.weight, 0)).toBeCloseTo(100);
      if (!WEEKLY_MONSTER.enabled || ![3, 6, 9, 12, 15, 18].includes(wave.waveNumber)) { expect(resolved.enemies).toEqual(wave.enemies); continue; }
      expect(resolved.enemies[0]).toEqual({ enemyId: weeklyMonster(week), weight: 35 });
      expect(resolved.enemies).toHaveLength(wave.enemies.length + 1);
    }
  });
  it('expands every weapon to Lv.10 with a Lv.5 irreversible branch', () => {
    for (const weapon of Object.values(weapons)) {
      expect(weapon.maxLevel).toBe(10);
      expect(weapon.branchAtLevel).toBe(5);
      expect(weapon.levels).toHaveLength(9);
      expect(weapon.branches.every(branch => branch.levels.length === 6)).toBe(true);
    }
  });

  it('targets 85% of the former capstone damage while preserving branch mechanics', () => {
    for (const [id, branches] of Object.entries(weaponBranches)) for (const branch of branches) {
      const oldFinalDamage = branch.levels.at(-1)?.damage;
      if (typeof oldFinalDamage !== 'number') continue;
      const current = resolveWeaponStats(weapons[id]!, 10, DEFAULT_STATS, false, branch.id);
      const former = Math.round(oldFinalDamage * WEAPON_CONFIG.playerDamageMultiplier);
      expect(current.damage / former).toBeGreaterThanOrEqual(0.8);
      expect(current.damage / former).toBeLessThanOrEqual(0.9);
    }
  });
});

