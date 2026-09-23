import { describe, expect, it } from 'vitest';
import { GameLoop } from './GameLoop';
describe('fixed game clock', () => {
  it('moves equal simulated time at different frame rates', () => {
    const simulate = (fps: number): number => {
      let elapsed = 0;
      const loop = new GameLoop(dt => { elapsed += dt; return true; }, () => {});
      loop.paused = false;
      for (let i = 0; i < fps * 10; i++) loop.advance(1000 / fps);
      return elapsed;
    };
    expect(simulate(30)).toBeCloseTo(simulate(144), 4);
    expect(simulate(60)).toBeCloseTo(10, 4);
  });
  it('bounds tab gaps, pauses, and handles 10x without large steps', () => {
    let elapsed = 0;
    let maxStep = 0;
    const loop = new GameLoop(dt => { elapsed += dt; maxStep = Math.max(maxStep, dt); return true; }, () => {});
    loop.advance(60000);
    expect(elapsed).toBe(0);
    loop.paused = false;
    loop.timeScale = 10;
    loop.advance(60000);
    expect(elapsed).toBeCloseTo(1, 4);
    expect(maxStep).toBe(1 / 60);
  });
  it('stops immediately when a level-up interrupts a fast frame', () => {
    let calls = 0;
    const loop = new GameLoop(() => { calls++; return false; }, () => {});
    loop.paused = false;
    loop.timeScale = 10;
    loop.advance(100);
    expect(calls).toBe(1);
  });
});
