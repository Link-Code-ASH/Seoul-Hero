import { describe, expect, it } from 'vitest';
import { InputManager } from './InputManager';
import type { InputSource } from './InputManager';
import type { Vec2 } from '../data/types';

function source(direction: Vec2): InputSource {
  return { read: () => direction, clear: () => { direction.x = 0; direction.y = 0; }, destroy: () => {} };
}
describe('platform-independent movement input', () => {
  it('normalizes combined keyboard and pointer diagonals without extra speed', () => {
    const manager = new InputManager([source({ x: 1, y: 0 }), source({ x: 0, y: 1 })]);
    const direction = manager.read();
    expect(Math.hypot(direction.x, direction.y)).toBeCloseTo(1);
    expect(direction.x).toBeCloseTo(direction.y);
  });
  it('preserves slow analog motion and clears all inputs when paused', () => {
    const manager = new InputManager([source({ x: 0.25, y: 0.1 })]);
    expect(manager.read()).toEqual({ x: 0.25, y: 0.1 });
    manager.clear();
    expect(manager.read()).toEqual({ x: 0, y: 0 });
  });
});
