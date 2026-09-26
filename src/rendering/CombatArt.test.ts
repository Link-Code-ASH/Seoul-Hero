import { describe, expect, it } from 'vitest';
import { enemies } from '../data/enemies';
import { groundProfileFor, enemyPose } from './CombatArt';

describe('combat art presentation', () => {
  it('defines a distinct positive ground footprint for every playable and enemy sprite', () => {
    const sprites = ['player', 'kangTaehoonTruck', ...Object.values(enemies).map(enemy => enemy.visual.sprite)] as const;
    for (const sprite of sprites) {
      const ground = groundProfileFor(sprite);
      expect(ground.anchorY).toBeGreaterThan(.75);
      expect(ground.shadowWidth).toBeGreaterThan(0);
      expect(ground.shadowDepth).toBeGreaterThan(0);
    }
    expect(groundProfileFor('splitter').shadowWidth).not.toBe(groundProfileFor('sentinel').shadowWidth);
  });

  it('selects special poses only for relevant actions', () => {
    const base = { id: 1, age: 0, timer: 1, action: 'move' as const };
    expect(enemyPose({ ...base, definitionId: 'charger', visual: enemies.charger!.visual })).toBe('charger');
    expect(enemyPose({ ...base, definitionId: 'charger', action: 'warning', visual: enemies.charger!.visual })).toBe('chargerBrace');
    expect(enemyPose({ ...base, definitionId: 'spitter', action: 'warning', timer: .1, visual: enemies.spitter!.visual })).toBe('spitterFire');
    expect(enemyPose({ ...base, definitionId: 'spitter', action: 'warning', timer: .5, visual: enemies.spitter!.visual })).toBe('spitter');
    expect(enemyPose({ ...base, definitionId: 'riftQueen', action: 'warning', visual: enemies.riftQueen!.visual })).toBe('riftQueenCast');
    expect(enemyPose({ ...base, definitionId: 'splitter', visual: enemies.splitter!.visual }, 0)).toBe('splitter');
    expect(enemyPose({ ...base, definitionId: 'splitter', visual: enemies.splitter!.visual }, 3)).toBe('splitterAir');
  });
});
