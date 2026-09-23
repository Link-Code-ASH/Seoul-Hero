import { describe, expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { createRun } from '../state/createRun';
import { eligibleWeaponOffers } from '../systems/ShopSystem';
import { characters } from './characters';
import { enemies } from './enemies';
import { metaUpgrades } from './meta';
import { maps } from './maps';
import { weapons } from './weapons';
import { WORLD_THEME } from './worldTheme';
import type { WeaponStats } from './types';

function positive(value: number, label: string): void {
  expect(Number.isFinite(value), `${label} must be finite`).toBe(true);
  expect(value, `${label} must be positive`).toBeGreaterThan(0);
}

function nonnegative(value: number, label: string): void {
  expect(Number.isFinite(value), `${label} must be finite`).toBe(true);
  expect(value, `${label} cannot be negative`).toBeGreaterThanOrEqual(0);
}

function positiveInteger(value: number, label: string): void {
  positive(value, label);
  expect(Number.isSafeInteger(value), `${label} must be a safe integer`).toBe(true);
}

function knownId(record: object, id: string, label: string): void {
  expect(Object.hasOwn(record, id), `${label} references unknown ID '${id}'`).toBe(true);
}

function validWeaponStats(stats: WeaponStats, label: string): void {
  for (const key of ['damage', 'cooldown', 'projectileSpeed', 'range', 'duration', 'projectileRadius'] as const) {
    positive(stats[key], `${label}.${key}`);
  }
  positiveInteger(stats.projectileCount, `${label}.projectileCount`);
  nonnegative(stats.penetration, `${label}.penetration`);
  expect(Number.isSafeInteger(stats.penetration), `${label}.penetration must be an integer`).toBe(true);
}

describe('shipped content integrity', () => {
  it('keeps each registry key equal to its unique stable content ID', () => {
    const registries = { characters, enemies, weapons, maps, metaUpgrades };
    for (const [name, registry] of Object.entries(registries)) {
      const ids = new Set<string>();
      expect(Object.keys(registry).length, `${name} cannot be empty`).toBeGreaterThan(0);
      for (const [key, value] of Object.entries(registry)) {
        expect(value.id, `${name}.${key} ID mismatch`).toBe(key);
        expect(value.id.trim(), `${name}.${key} ID cannot be empty`).not.toBe('');
        expect(ids.has(value.id), `${name} duplicates '${value.id}'`).toBe(false);
        expect(['__proto__', 'constructor', 'prototype']).not.toContain(value.id);
        ids.add(value.id);
      }
    }
  });

  it('gives every character an optional valid signature and usable body stats', () => {
    for (const character of Object.values(characters)) {
      if(character.signatureWeaponId) knownId(weapons, character.signatureWeaponId, `character ${character.id} signature weapon`);
      positive(character.radius, 'body radius');
      for (const key of ['maxHp', 'moveSpeed', 'pickupRange'] as const) positive(character.baseStats[key], `${character.id}.${key}`);
    }
    for (const enemy of Object.values(enemies)) {
      for (const key of ['maxHp', 'moveSpeed', 'radius'] as const) positive(enemy[key], `${enemy.id}.${key}`);
      for (const key of ['contactDamage', 'magicStoneDrop'] as const) nonnegative(enemy[key], `${enemy.id}.${key}`);
    }
  });

  it('keeps base and every cumulative weapon level valid for firing and collision', () => {
    for (const weapon of Object.values(weapons)) {
      const stats = { ...weapon.base };
      validWeaponStats(stats, `${weapon.id} level 1`);
      weapon.levels.forEach((patch, index) => {
        Object.assign(stats, patch);
        validWeaponStats(stats, `${weapon.id} level ${index + 2}`);
      });
    }
  });

  it('links finite arenas and ordered wave definitions to real enemies', () => {
    for (const stage of Object.values(maps)) {
      positive(stage.arenaWidth, 'width'); positive(stage.arenaHeight, 'height');
      expect(stage.waveDefinitions).toHaveLength(stage.totalWaves);
      expect(stage.bossWave).toBe(stage.totalWaves);
      knownId(WORLD_THEME, stage.backgroundTheme, 'theme');
      nonnegative(stage.clearReward, 'clear reward');
      stage.waveDefinitions.forEach((wave, i) => {
        expect(wave.waveNumber).toBe(i + 1); positive(wave.duration, 'duration');
        positive(wave.interval, 'interval'); positiveInteger(wave.batch, 'batch');
        positiveInteger(wave.maxEnemies, 'cap');
        expect(wave.batch).toBeLessThanOrEqual(wave.maxEnemies);
        for (const entry of wave.enemies) { knownId(enemies, entry.enemyId, 'enemy'); positive(entry.weight, 'weight'); }
        for (const elite of wave.elites ?? []) { knownId(enemies, elite.enemyId, 'elite'); expect(elite.at).toBeLessThan(wave.duration); nonnegative(elite.at, 'at'); positive(elite.hpMultiplier, 'hp'); positive(elite.rewardMultiplier, 'reward'); }
        if (wave.waveNumber === stage.bossWave) knownId(enemies, wave.boss!.enemyId, 'boss');
        else expect(wave.boss).toBeUndefined();
      });
    }
  });

  it('validates permanent upgrade prices and unlock targets', () => {
    for (const upgrade of Object.values(metaUpgrades)) {
      positiveInteger(upgrade.maxLevel, `meta ${upgrade.id}.maxLevel`);
      positive(upgrade.baseCost, `meta ${upgrade.id}.baseCost`);
      positive(upgrade.costGrowth, `meta ${upgrade.id}.costGrowth`);
      const effect = upgrade.effect;
      if (effect.type === 'stat') expect(Number.isFinite(effect.value), `meta ${upgrade.id} stat value`).toBe(true);
      if (effect.type === 'unlock') {
        if (effect.target === 'character') knownId(characters, effect.contentId, `meta ${upgrade.id} unlock`);
        if (effect.target === 'weapon') knownId(weapons, effect.contentId, `meta ${upgrade.id} unlock`);
        expect(effect.contentId.trim(), `meta ${upgrade.id} unlock ID`).not.toBe('');
      }
    }
  });

  it('starts a fresh save with valid playable characters and their weapons unlocked', () => {
    const meta = createDefaultMeta();
    const unlockedCharacters=Object.keys(meta.characters).filter(id=>meta.characters[id]?.unlocked);
    const unlockedWeapons=Object.keys(meta.sharedWeapons).filter(id=>meta.sharedWeapons[id]?.unlocked);
    expect(unlockedCharacters.length).toBeGreaterThan(0);
    expect(unlockedWeapons.length).toBeGreaterThan(0);
    for (const id of unlockedWeapons) knownId(weapons, id, 'default unlocked weapon');
    for (const id of unlockedCharacters) {
      knownId(characters, id, 'default unlocked character');
      const signature=characters[id]?.signatureWeaponId;
      if(signature)expect(unlockedWeapons, `${id} signature weapon must be unlocked`).toContain(signature);
    }
  });

  it('never substitutes stat or recovery candidates when six maxed weapons exhaust the build', () => {
    const run = createRun('awakener', 'seoul', createDefaultMeta());
    run.ownedWeapons = Object.values(weapons).slice(0, 6).map(w => ({ id: w.id, level: w.levels.length + 1, cooldownRemaining: 0 }));
    expect(eligibleWeaponOffers(run)).toEqual([]);
  });
});

