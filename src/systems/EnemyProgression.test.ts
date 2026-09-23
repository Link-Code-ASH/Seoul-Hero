import { describe, expect, it } from 'vitest';
import { Simulation } from '../core/Simulation';
import { createDefaultMeta } from '../state/MetaState';
import { enemies } from '../data/enemies';
import { eliteModifiers } from '../data/eliteModifiers';
import { ENEMY_RULES, CURSE_RULES, DROP_RULES } from '../data/enemyConfig';
import { createEnemy, curseBonuses } from './EnemyFactory';
import { EnemySystem } from './EnemySystem';
import { PickupSystem } from './PickupSystem';
import { CollisionSystem } from './CollisionSystem';
import { HostileAttackSystem } from './HostileAttackSystem';

const make = (random = () => 0.99) => new Simulation('awakener', 'seoul', createDefaultMeta(), random);
const behaviorRun = (id: string, x = 200) => {
  const sim = make(); let seq = 100;
  const system = new EnemySystem(() => ++seq, () => 0.99, () => {});
  const enemy = createEnemy(1, id, { x, y: 0 })!;
  sim.state.enemies.push(enemy);
  return { run: sim.state, enemy, system };
};

describe('ground rewards and queued progression', () => {
  it.each([0, 0.149, 0.15, 0.999])('always drops the unified magic stone at %s', roll => {
    const sim = make(() => roll); sim.spawnEnemy('crawler'); sim.clearEnemies();
    expect(sim.state.pickups).toHaveLength(1);
    expect(sim.state.pickups[0]!.kind).toBe('magicStone');
    expect(sim.state.runCurrency).toBe(0);
  });
  it('applies Currency Gain at collection without pausing combat', () => {
    const sim = make(), run = sim.state;
    const pickup = new PickupSystem(() => 1);
    run.calculatedStats.currencyGain = 1.5;
    const value = 10;
    pickup.drop(run, 0, 0, value);
    pickup.update(run, 0.1);
    expect(run.runCurrency).toBe(value * 1.5); expect(run.earnedMetaCurrency).toBe(0);
    expect(run.phase).toBe('waveActive');
  });
  it('attracts magic stones through Pickup Range and reuses cleared pickups without old value', () => {
    const { state: run } = make(); let id = 0; const pickup = new PickupSystem(() => ++id);
    run.player.pickupRadius = 150;
    pickup.drop(run, 140, 0, 10); const original = run.pickups[0];
    pickup.update(run, 0.1); expect(run.pickups[0]!.x).toBeLessThan(140);
    pickup.clear(run); pickup.drop(run, 140, 0, 2);
    expect(run.pickups[0]).toBe(original); expect(original!.value).toBe(2);
    pickup.update(run, 0.1); expect(run.pickups[0]!.x).toBeLessThan(140);
  });
  it('merges nearby magic stones and keeps missed value for end-of-stage wallet', () => {
    const { state: run } = make(); const pickup = new PickupSystem(() => 1);
    pickup.drop(run, 500, 0, 3); pickup.drop(run, 510, 0, 7);
    pickup.drop(run, 500, 0, 2);
    expect(run.pickups).toHaveLength(1);
    pickup.update(run, DROP_RULES.magicStoneLifetime);
    expect(run.runCurrency).toBe(0); expect(run.pickups).toHaveLength(1);
    expect(run.pickups[0]!.value).toBe(12);
  });
});

describe('twelve distinct normal enemy behaviors', () => {
  it('registers twelve normals and two dedicated multi-pattern bosses', () => {
    const normal = Object.values(enemies).filter(e => e.tags.includes('NORMAL'));
    expect(normal).toHaveLength(12);
    expect(new Set(normal.map(e => e.behavior)).size).toBeGreaterThanOrEqual(11);
    for (const e of normal) expect(e.magicStoneDrop).toBeGreaterThan(0);
    const bosses = Object.values(enemies).filter(e => e.tags.includes('BOSS'));
    expect(bosses).toHaveLength(2);
    for (const boss of bosses) { expect(boss.bossPatterns!.length).toBeGreaterThan(2); expect(boss.magicStoneDrop).toBeGreaterThan(0); }
  });
  it.each(['crawler', 'swarm'])('%s approaches with its registered movement', id => {
    const { run, enemy, system } = behaviorRun(id);
    system.update(run, 0.1); expect(enemy.x).toBeLessThan(200);
  });
  it('runner enters its charge warning before moving', () => {
    const { run, enemy, system } = behaviorRun('runner');
    system.update(run, 0.1); expect(enemy.action).toBe('warning'); expect(enemy.x).toBe(200);
  });
  it('tank attacks with an area warning', () => {
    const { run, system } = behaviorRun('bulwark', 80); system.update(run, 0.1);
    expect(run.hazards[0]!.warning).toBeGreaterThan(0); expect(run.player.hp).toBe(100);
  });
  it('ranged enemies warn before firing an actual hostile projectile', () => {
    const { run, enemy, system } = behaviorRun('spitter', 330);
    system.update(run, 0.1); expect(enemy.action).toBe('warning'); expect(run.hostileProjectiles).toHaveLength(0);
    system.update(run, ENEMY_RULES.rangedWarning + 0.01); expect(run.hostileProjectiles).toHaveLength(1);
  });
  it.each(['charger', 'lurker'])('%s locks a position then dashes after warning', id => {
    const { run, enemy, system } = behaviorRun(id);
    system.update(run, 0.1); expect(enemy.action).toBe('warning'); const x = enemy.x;
    system.update(run, 1); expect(enemy.action).toBe('dash');
    system.update(run, 0.1); expect(enemy.x).toBeLessThan(x - enemy.moveSpeed * 0.1);
  });
  it('bomber waits for a fuse, then damages through the common defense path', () => {
    const { run, enemy, system } = behaviorRun('bomber', 60);
    system.update(run, 0.1); expect(enemy.hp).toBeGreaterThan(0); expect(run.player.hp).toBe(100);
    system.update(run, 1.01); expect(enemy.hp).toBe(0); expect(run.player.hp).toBeLessThan(100);
  });
  it('splitter death produces bounded children with reduced rewards', () => {
    const sim = make(); sim.spawnEnemy('splitter'); sim.clearEnemies();
    expect(sim.state.enemies).toHaveLength(ENEMY_RULES.splitCount);
    for (const child of sim.state.enemies) { expect(child.definitionId).toBe('swarm'); expect(child.magicStoneDrop).toBe(enemies.swarm!.magicStoneDrop * ENEMY_RULES.summonedRewardMultiplier); }
    expect(sim.state.kills).toBe(1);
  });
  it('support heals only living nearby allies', () => {
    const { run, system } = behaviorRun('mender', 200);
    const ally = createEnemy(2, 'crawler', { x: 220, y: 0 })!; ally.hp = 1;
    const far = createEnemy(3, 'crawler', { x: 600, y: 0 })!; far.hp = 1;
    run.enemies.push(ally, far); system.update(run, 0.1);
    expect(ally.hp).toBeGreaterThan(1); expect(far.hp).toBe(1);
  });
  it('summoner stops at its lifetime child cap', () => {
    const { run, enemy, system } = behaviorRun('summoner', 500);
    for (let i = 0; i < 20; i++) { enemy.timer = 0; system.update(run, 0.01); }
    expect(enemy.summonCount).toBe(ENEMY_RULES.maxSummonsPerEnemy);
    expect(run.enemies).toHaveLength(1 + ENEMY_RULES.maxSummonsPerEnemy);
  });
  it('defender cycles armor instead of permanently changing its base', () => {
    const { run, enemy, system } = behaviorRun('sentinel', 500);
    system.update(run, 0.1); expect(enemy.armor).toBe(ENEMY_RULES.defenderArmor);
    enemy.age = ENEMY_RULES.defenderGuard; system.update(run, 0.1);
    expect(enemy.armor).toBe(enemy.baseArmor);
  });
});

describe('elite, curse, hostile attacks and cleanup', () => {
  it.each(Object.keys(eliteModifiers) as (keyof typeof eliteModifiers)[])('composes %s without duplicate application', id => {
    const e = createEnemy(1, 'crawler', { x: 0, y: 0 }, 0, [id, id])!;
    expect(e.eliteModifiers).toEqual([id]); expect(e.elite).toBe(true);
    expect(e.maxHp).toBe(enemies.crawler!.maxHp * eliteModifiers[id].hp);
    expect(e.magicStoneDrop).toBe(enemies.crawler!.magicStoneDrop * eliteModifiers[id].reward);
  });
  it('combines giant and armored, and exposes bounded Curse scaling', () => {
    const base = createEnemy(1, 'crawler', { x: 0, y: 0 })!;
    const e = createEnemy(2, 'crawler', base, 100, ['GIANT', 'ARMORED'])!;
    expect(e.maxHp).toBeGreaterThan(base.maxHp); expect(e.armor).toBe(60);
    expect(e.contactDamage).toBeGreaterThan(base.contactDamage);
    const c = curseBonuses(1e9);
    expect(c.spawn).toBe(CURSE_RULES.maxIntensity); expect(c.eliteChance).toBe(CURSE_RULES.maxEliteChance);
    expect(curseBonuses(NaN)).toEqual(curseBonuses(0));
  });
  it('hostile projectile damage uses armor; clearing releases arrays and permits pool reuse', () => {
    const { state: run } = make(); const attacks = new HostileAttackSystem(() => 0.99, () => {});
    run.calculatedStats.armor = 100;
    attacks.shoot(run, -50, 0, 0, 20); const first = run.hostileProjectiles[0];
    attacks.update(run, 0.2); expect(run.player.hp).toBe(90); expect(run.hostileProjectiles).toHaveLength(0);
    attacks.shoot(run, 500, 0, 0, 20); expect(run.hostileProjectiles[0]).toBe(first);
    attacks.area(run, 0, 0, 100, 1, 30); attacks.clear(run);
    expect(run.hostileProjectiles).toHaveLength(0); expect(run.hazards).toHaveLength(0);
  });
  it('wave cleanup removes enemy queries and every hostile attack without death rewards', () => {
    const sim = make(); sim.spawnEnemy('summoner');
    const collision = new CollisionSystem(); collision.rebuild(sim.state.enemies);
    expect(collision.nearest(0, 0, 5000)).toBeDefined();
    sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    sim.completeWave(); collision.rebuild(sim.state.enemies);
    expect(collision.nearest(0, 0, 5000)).toBeUndefined();
    expect(sim.state.enemies).toHaveLength(0); expect(sim.state.hostileProjectiles).toHaveLength(0);
    expect(sim.state.hazards).toHaveLength(0); expect(sim.state.runCurrency).toBe(0);
  });
});
