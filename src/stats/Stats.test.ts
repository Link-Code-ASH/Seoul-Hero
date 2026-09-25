import { describe, expect, it } from 'vitest';
import { DEFAULT_STATS, STAT_RULES, type WeaponCapability } from '../data/stats';
import { weapons } from '../data/weapons';
import { calculateStats, replaceModifiers } from './PlayerStats';
import { resolveWeaponStats } from './WeaponStats';
import { armorDamage, attackContext, applyLifesteal, dodges, outgoingDamage } from './Damage';
import { createDefaultMeta } from '../state/MetaState';
import { Simulation } from '../core/Simulation';
import { CollisionSystem } from '../systems/CollisionSystem';
import { PickupSystem } from '../systems/PickupSystem';
import { collectMagicStone } from '../systems/MagicStoneSystem';

const make = () => new Simulation('awakener', 'seoul', createDefaultMeta(), () => 0.1);
const resolve = (capabilities: WeaponCapability[], changes = {}) => resolveWeaponStats(
  { ...weapons.manaBolt!, capabilities }, 1, { ...DEFAULT_STATS, ...changes });

describe('20 shared stats and source isolation', () => {
  it('has exactly 20 stats without experience gain, cooldown reduction or projectile count', () => {
    expect(Object.keys(DEFAULT_STATS)).toHaveLength(20);
    expect(DEFAULT_STATS).not.toHaveProperty('experienceGain');
    expect(DEFAULT_STATS).not.toHaveProperty('cooldownMultiplier');
    expect(DEFAULT_STATS).not.toHaveProperty('projectileBonus');
  });
  it('adds flat and percentage bonuses from the original baseline regardless of source order', () => {
    const mods = [
      { id: 'power', source: 'meta', stat: 'damage', operation: 'add', value: 0.08 },
      { id: 'item', source: 'item', stat: 'damage', operation: 'multiply', value: 1.2 },
      { id: 'item-2', source: 'item', stat: 'damage', operation: 'multiply', value: 1.1 },
      { id: 'buff', source: 'run', stat: 'damage', operation: 'add', value: 0.1 },
    ] as const;
    expect(calculateStats(DEFAULT_STATS, mods).damage).toBeCloseTo(1.48);
    expect(calculateStats(DEFAULT_STATS, [...mods].reverse())).toEqual(calculateStats(DEFAULT_STATS, mods));
  });
  it('treats two 8% bonuses as 16% of the base even when flat bonuses are present', () => {
    const base = { ...DEFAULT_STATS, maxHp: 80 };
    const mods = [
      { id: 'flat', source: 'meta', stat: 'maxHp', operation: 'add', value: 10 },
      { id: 'first', source: 'item', stat: 'maxHp', operation: 'multiply', value: 1.08 },
      { id: 'second', source: 'item', stat: 'maxHp', operation: 'multiply', value: 1.08 },
    ] as const;
    expect(calculateStats(base, mods).maxHp).toBeCloseTo(102.8);
  });
  it('recalculates on source changes, updates player values and retains Meta modifiers when items are removed', () => {
    const meta = createDefaultMeta(); meta.association.upgrades.vitality = 1;
    const sim = new Simulation('awakener', 'seoul', meta);
    sim.state.player.hp = 60;
    replaceModifiers(sim.state, 'item', [{ id: 'health', stat: 'maxHp', operation: 'add', value: 20 }]);
    expect(sim.state.player.maxHp).toBe(135);
    expect(sim.state.player.hp).toBeCloseTo(60 / 115 * 135);
    const cached = sim.state.calculatedStats;
    sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(sim.state.calculatedStats).toBe(cached);
    replaceModifiers(sim.state, 'item', []);
    expect(sim.state.player.maxHp).toBe(115);
    expect(sim.state.player.hp).toBeCloseTo(60);
    expect(meta.association.upgrades.vitality).toBe(1);
    expect(sim.state.statModifiers.map(m => m.source)).toEqual(['meta']);
  });
  it('keeps malformed and excessive modifiers within configured safety limits', () => {
    const stats = calculateStats(DEFAULT_STATS, [
      { id: 'bad', source: 'run', stat: 'damage', operation: 'add', value: NaN },
      { id: 'dodge', source: 'run', stat: 'dodge', operation: 'add', value: 100 },
      { id: 'speed', source: 'run', stat: 'attackSpeed', operation: 'add', value: -10 },
    ]);
    expect(stats.damage).toBe(1); expect(stats.dodge).toBe(STAT_RULES.dodgeCap);
    expect(stats.attackSpeed).toBe(STAT_RULES.minimumAttackSpeed);
  });
});

describe('capability-gated attacks', () => {
  it('keeps mana sword collision angles at 60° or the 90° wide branch through Lv.10', () => {
    const weapon = weapons.manaSword!;
    expect(resolveWeaponStats(weapon, 1, DEFAULT_STATS).attackAngle).toBeCloseTo(Math.PI / 3);
    expect(resolveWeaponStats(weapon, 10, DEFAULT_STATS, false, 'B').attackAngle).toBeCloseTo(Math.PI / 3);
    expect(resolveWeaponStats(weapon, 5, DEFAULT_STATS, false, 'A').attackAngle).toBeCloseTo(Math.PI / 2);
    expect(resolveWeaponStats(weapon, 10, DEFAULT_STATS, false, 'A').attackAngle).toBeCloseTo(Math.PI / 2);
    expect(resolveWeaponStats(weapon, 1, { ...DEFAULT_STATS, area: 1.5 }).areaScale).toBeCloseTo(1.5);
  });
  it('applies global damage and inverse Attack Speed interval', () => {
    const stats = resolve([], { damage: 1.5, attackSpeed: 2 });
    expect(stats.damage).toBe(28); expect(stats.cooldown).toBeCloseTo(0.325);
  });
  it.each(['MELEE', 'RANGED'] as const)('applies only the %s damage channel', cap => {
    const stats = resolve([cap], { meleeDamage: 2, rangedDamage: 3 });
    expect(stats.damage).toBe(cap === 'MELEE' ? 37 : 56);
  });
  it('adds common and melee percentage damage instead of compounding them', () => {
    expect(resolve(['MELEE'], { damage: 1.08, meleeDamage: 1.08 }).damage).toBe(22);
  });
  it.each([
    ['PROJECTILE', 'projectileSpeed'], ['DURATION', 'duration'], ['HAS_RANGE', 'range'],
  ] as const)('gates %s to its supported field', (cap, stat) => {
    expect(resolve([cap], { [stat]: 2 })[stat]).toBe(weapons.manaBolt!.base[stat] * 2);
    expect(resolve([], { [stat]: 2 })[stat]).toBe(weapons.manaBolt!.base[stat]);
  });
  it('scales area geometry only for AREA weapons', () => {
    expect(resolve(['AREA'], { area: 2 }).blastRadius).toBe(200);
    expect(resolve([], { area: 2 }).blastRadius).toBe(100);
    expect(resolve(['AREA'], { area: 2 }).areaScale).toBe(2);
  });
  it('rolls critical hits only with CAN_CRIT', () => {
    const crit = attackContext(resolve(['CAN_CRIT'], { criticalChance: 1, criticalDamage: 2 }), 100);
    expect(outgoingDamage(22, crit, () => 0.9)).toBe(44);
    const normal = attackContext(resolve([], { criticalChance: 1, criticalDamage: 2 }), 100);
    expect(outgoingDamage(22, normal, () => 0)).toBe(22);
  });
  it('uses the same stats for a turret and excludes unsupported geometry, melee and automatic lifesteal', () => {
    const stats = resolve(['STRUCTURE', 'TURRET', 'RANGED', 'PROJECTILE', 'HAS_RANGE'], {
      damage: 2, rangedDamage: 2, meleeDamage: 10, projectileSpeed: 2, area: 9,
      duration: 9, criticalChance: 1, lifesteal: 0.5, armor: 100, moveSpeed: 900,
    });
    expect(stats.damage).toBe(56); expect(stats.projectileSpeed).toBe(1120);
    expect(stats.areaScale).toBe(1); expect(stats.duration).toBe(1.5);
    expect(stats.criticalChance).toBe(0); expect(stats.lifesteal).toBe(0);
    expect(stats).not.toHaveProperty('armor'); expect(stats).not.toHaveProperty('moveSpeed');
  });
  it.each(['STRUCTURE', 'SUMMON'] as const)('supports explicit future lifesteal permission for %s', cap => {
    const weapon = { ...weapons.manaBolt!, capabilities: [cap] };
    const player = { ...DEFAULT_STATS, lifesteal: 0.2 };
    expect(resolveWeaponStats(weapon, 1, player).lifesteal).toBe(0);
    expect(resolveWeaponStats(weapon, 1, player, true).lifesteal).toBe(0.2);
  });
});

describe('defense, healing and live damage path', () => {
  it('shares lifesteal across a real multi-projectile critical volley', () => {
    const sim = make(); sim.spawnEnemy('crawler');
    const enemy = sim.state.enemies[0]!;
    enemy.x = 40; enemy.y = 0; enemy.moveSpeed = 0; enemy.hp = 1000;
    sim.state.ownedWeapons[0]!.level = 4;
    sim.state.player.hp = 50;
    replaceModifiers(sim.state, 'run', [
      { id: 'crit', stat: 'criticalChance', operation: 'add', value: 1 },
      { id: 'critDamage', stat: 'criticalDamage', operation: 'add', value: 0.5 },
      { id: 'life', stat: 'lifesteal', operation: 'add', value: 0.5 },
    ]);
    sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(enemy.hp).toBeLessThan(1000);
    expect(sim.state.player.hp).toBe(55);
  });
  it('expands the actual bombardment hit area', () => {
    const sim = make(); sim.spawnEnemy('crawler'); sim.spawnEnemy('crawler');
    sim.state.enemies.forEach((e, i) => { e.x = 100 + i * 200; e.y = 0; e.moveSpeed = 0; e.hp = 500; });
    const targets = [...sim.state.enemies];
    sim.state.ownedWeapons = [{ id: 'manaBombard', level: 1, cooldownRemaining: 0 }];
    replaceModifiers(sim.state, 'run', [{ id: 'area', stat: 'area', operation: 'add', value: 1 }]);
    sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(targets.map(e => e.hp)).toEqual([500, 500]);
    for (let i = 0; i < 12; i++) sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(targets.map(e => e.hp)).toEqual([445, 445]);
  });
  it('applies currency gain without creating experience when collecting a magic stone', () => {
    const sim = make();
    replaceModifiers(sim.state, 'item', [{ id: 'coin', stat: 'currencyGain', operation: 'add', value: 0.5 }]);
    expect(collectMagicStone(sim.state, 10)).toEqual({currency:15});
    expect(sim.state).not.toHaveProperty('experience');
    expect(sim.state.runCurrency).toBe(15);
    expect(sim.state.collectedMagicStone).toBe(15);
    expect(sim.state.earnedMetaCurrency).toBe(0);
    sim.spawnEnemy('crawler');

    sim.clearEnemies();
    expect(sim.state.earnedMetaCurrency).toBe(0);
  });
  it('reduces damage smoothly with Armor and caps Dodge below 100%', () => {
    expect(armorDamage(100, 0)).toBe(100);
    expect(armorDamage(100, 100)).toBe(50);
    expect(armorDamage(100, 300)).toBe(25);
    expect(dodges(100, () => 0.99)).toBe(false);
    expect(dodges(100, () => 0.1)).toBe(true);
    expect(dodges(0, () => 0)).toBe(false);
  });
  it('shares the healing budget across all targets in an attack and never overheals', () => {
    const sim = make(); sim.state.player.hp = 50;
    const context = attackContext(resolve([], { lifesteal: 0.5 }), 100);
    expect(applyLifesteal(sim.state, 6, context)).toBe(3);
    expect(applyLifesteal(sim.state, 100, context)).toBe(2);
    expect(applyLifesteal(sim.state, 100, context)).toBe(0);
    sim.state.player.hp = 99;
    expect(applyLifesteal(sim.state, 100, attackContext(resolve([], { lifesteal: 0.5 }), 100))).toBe(1);
  });
  it('uses actual damage rather than overkill damage for lifesteal', () => {
    const sim = make(); sim.spawnEnemy('crawler');
    const enemy = sim.state.enemies[0]!; enemy.hp = 2;
    sim.state.player.hp = 50;
    new CollisionSystem().hit(enemy, 1000, sim.state, attackContext(resolve([], { lifesteal: 0.5 }), 100));
    expect(enemy.hp).toBe(0); expect(sim.state.player.hp).toBe(51);
  });
  it('applies Armor and Dodge to actual enemy contact', () => {
    const sim = make(); sim.spawnEnemy('crawler');
    const enemy = sim.state.enemies[0]!; enemy.x = 0; enemy.y = 0; enemy.contactDamage = 20;
    sim.state.calculatedStats.armor = 100;
    const collision = new CollisionSystem(undefined, () => 0.1); collision.rebuild(sim.state.enemies);
    collision.player(sim.state); expect(sim.state.player.hp).toBe(90);
    sim.state.player.invulnerability = 0; sim.state.calculatedStats.dodge = 0.5;
    collision.player(sim.state); expect(sim.state.player.hp).toBe(90);
    expect(sim.state.player.invulnerability).toBeGreaterThan(0);
  });
  it('regenerates only in combat and applies Currency Gain once on pickup', () => {
    const sim = make(); sim.state.player.hp = 50;
    replaceModifiers(sim.state, 'run', [
      { id: 'regen', stat: 'hpRegeneration', operation: 'add', value: 10 },
      { id: 'currency', stat: 'currencyGain', operation: 'add', value: 1 },
    ]);
    sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(sim.state.player.hp).toBe(51);
    sim.pause(); sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(sim.state.player.hp).toBe(51);
    const pickups = new PickupSystem(() => 1); pickups.drop(sim.state, 0, 0, 2); pickups.update(sim.state, 0.1);
    expect(sim.state.runCurrency).toBe(4);
  });
});

