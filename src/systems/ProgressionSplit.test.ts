import { describe, expect, it } from 'vitest';
import { Simulation } from '../core/Simulation';
import { createDefaultMeta } from '../state/MetaState';
import { weapons } from '../data/weapons';
const view = { width: 1280, height: 720 }, still = { x: 0, y: 0 };
const make = (): Simulation => new Simulation('awakener', 'seoul', createDefaultMeta(), () => .5);

describe('six weapon behaviors', () => {
  for (const id of Object.keys(weapons).filter(id => !weapons[id]!.structure)) it(`${id} deals damage using its own attack behavior`, () => {
    const sim = make(); sim.state.invincible = true;
    sim.state.ownedWeapons = [{ id, level: 1, cooldownRemaining: 0 }];
    sim.spawnEnemy('crawler'); const enemy = sim.state.enemies[0]!;
    enemy.x = id === 'guardianDaggers' ? 90 : 70; enemy.y = 0; enemy.hp = 1000;
    for (let i = 0; i < 40; i++) sim.update(0.02, still, view);
    expect(enemy.hp).toBeLessThan(1000);
  });
  it('chains to distinct targets and a bombardment hits multiple enemies', () => {
    for (const id of ['chainLightning', 'manaBombard']) {
      const sim = make(); sim.state.ownedWeapons = [{ id, level: 1, cooldownRemaining: 0 }];
      for (let i = 0; i < 3; i++) { sim.spawnEnemy('crawler'); const enemy = sim.state.enemies.at(-1)!; enemy.x = 90 + i * 20; enemy.y = 0; enemy.hp = 1000; }
      for (let i = 0; i < 35; i++) sim.update(0.02, still, view);
      expect(sim.state.enemies.slice(0, 3).every(enemy => enemy.hp < 1000)).toBe(true);
    }
  });
});
