import { expect, it } from 'vitest';
import { createRun } from '../state/createRun';
import { createDefaultMeta } from '../state/MetaState';
import { PlayerMotion } from './PlayerMotion';

it('eases into procedural movement and retains horizontal facing', () => {
  const run = createRun('awakener', 'seoul', createDefaultMeta());
  run.phase = 'waveActive';
  const motion = new PlayerMotion();
  motion.update(run, 1 / 60);
  run.player.x = 30; run.stageCombatTime = 0.1; motion.update(run, 1 / 60);
  expect(motion.moving).toBe(true);
  expect(motion.facing).toBe(1);
  expect(motion.intensity).toBeGreaterThan(0);
  run.player.x = 0; run.stageCombatTime = 0.2; motion.update(run, 1 / 60);
  expect(motion.facing).toBe(-1);
});

it('advances the subtle motion rhythm by travelled distance without animation frames', () => {
  const run = createRun('awakener', 'seoul', createDefaultMeta());
  run.phase = 'waveActive';
  const motion = new PlayerMotion();
  motion.update(run, 1 / 60);
  run.player.x = 30; run.stageCombatTime = 0.2; motion.update(run, 1 / 60);
  const firstBob = motion.bobY;
  run.player.x = 60; run.stageCombatTime = 0.4; motion.update(run, 1 / 60);
  expect(motion.bobY).not.toBe(firstBob);
});

it('eases to idle instead of snapping when movement stops', () => {
  const run = createRun('awakener', 'seoul', createDefaultMeta());
  run.phase = 'waveActive';
  const motion = new PlayerMotion();
  motion.update(run, 1 / 60);
  run.player.x = 30; run.stageCombatTime = 0.1; motion.update(run, 1 / 60);
  const movingIntensity = motion.intensity;
  run.stageCombatTime = 0.2; motion.update(run, 1 / 60);
  expect(motion.intensity).toBeLessThan(movingIntensity);
  expect(motion.intensity).toBeGreaterThan(0);
  for (let i = 0; i < 80; i++) motion.update(run, 1 / 60);
  expect(motion.moving).toBe(false);
});
