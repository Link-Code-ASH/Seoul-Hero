import { describe, expect, it } from 'vitest';
import { BALANCE_CONFIG } from './balanceConfig';
import { characters } from './characters';
import { gateDifficulty } from './gateProgression';
import { maps } from './maps';
import { DEFAULT_STATS } from './stats';
import { weapons } from './weapons';
import { weaponBranches } from './weapons/branches';
import { resolveWeaponStats } from '../stats/WeaponStats';
import { WEAPON_CONFIG } from './weaponConfig';

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
    expect(waves[9]).toMatchObject({ interval: 0.86, maxEnemies: 161 });
    expect(waves[19]).toMatchObject({ interval: 0.64, maxEnemies: 224 });
    expect([5, 10, 15].map(number => waves[number - 1]!.elites?.length)).toEqual([1, 1, 1]);
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

