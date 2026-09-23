import { describe, expect, it } from 'vitest';
import { Simulation } from '../core/Simulation';
import { createDefaultMeta } from '../state/MetaState';
import { weapons } from '../data/weapons';
import { WEAPON_CONFIG } from '../data/weaponConfig';
import { weaponStats } from './CombatSystem';
import { WeaponBehaviors } from './WeaponBehaviors';
import { CollisionSystem } from './CollisionSystem';

const make = () => new Simulation('awakener', 'seoul', createDefaultMeta(), () => 0.5);

describe('guardian shuriken collision', () => {
  it('lets all three starting blades damage separate enemies', () => {
    const sim = make();
    const weapon = weapons.guardianDaggers!;
    const stats = weaponStats(weapon, 1, sim.state);
    const collisions = new CollisionSystem();
    const behavior = new WeaponBehaviors(collisions);
    for (let blade = 0; blade < 3; blade++) {
      sim.spawnEnemy('crawler');
      const enemy = sim.state.enemies.at(-1)!;
      const angle = blade * Math.PI * 2 / 3;
      enemy.x = Math.cos(angle) * stats.range;
      enemy.y = Math.sin(angle) * stats.range;
      enemy.hp = 1000;
    }
    collisions.rebuild(sim.state.enemies);
    behavior.updateOrbit(sim.state, weapon, stats, 0.02);
    expect(sim.state.enemies).toHaveLength(3);
    expect(sim.state.enemies.every(enemy => enemy.hp < 1000)).toBe(true);
  });

  it('hits an enemy crossed between two displayed blade positions', () => {
    const sim = make();
    const weapon = weapons.guardianDaggers!;
    const stats = weaponStats(weapon, 1, sim.state);
    const collisions = new CollisionSystem();
    const behavior = new WeaponBehaviors(collisions);
    sim.spawnEnemy('crawler');
    const enemy = sim.state.enemies[0]!;
    const crossedAngle = WEAPON_CONFIG.orbitAngularSpeed * 0.5 / 2;
    enemy.x = Math.cos(crossedAngle) * stats.range;
    enemy.y = Math.sin(crossedAngle) * stats.range;
    enemy.hp = 1000;
    collisions.rebuild(sim.state.enemies);
    behavior.updateOrbit(sim.state, weapon, stats, 0);
    expect(enemy.hp).toBe(1000);
    sim.state.stageCombatTime = 0.5;
    behavior.updateOrbit(sim.state, weapon, stats, 0.5);
    expect(enemy.hp).toBeLessThan(1000);
  });
});
