import { expect, it } from 'vitest';
import { parseSave } from './migrations';
import { SAVE_VERSION } from './SaveData';
it('migrates v1 audio controls without losing permanent progress', () => {
  const save = parseSave(JSON.stringify({ saveVersion: 1, meta: { currency: 456, upgrades: { power: 2 }, settings: { masterVolume: 0.2, soundVolume: 0.4, musicVolume: 0.1, developerMode: true } } }));
  expect(save.saveVersion).toBe(6);
  expect(save.meta.wallet.associationCoins).toBe(456);
  expect(save.meta.association.upgrades.power).toBe(2);
  expect(save.meta.settings).toMatchObject({ masterVolume: 0.2, soundVolume: 0.4, combatVolume: 0.4, uiVolume: 0.4, musicVolume: 0.1, developerMode: true, muted: false });
});
it('round-trips mute and clamps corrupted settings in the current version', () => {
  const saved = parseSave(JSON.stringify({ saveVersion: SAVE_VERSION, meta: { settings: { muted: true, musicVolume: 0.25 } } }));
  expect(parseSave(JSON.stringify(saved)).meta.settings).toMatchObject({ muted: true, musicVolume: 0.25 });
  const corrupt = parseSave(JSON.stringify({ saveVersion: SAVE_VERSION, meta: { settings: { muted: 'yes', masterVolume: -2, soundVolume: 300 } } }));
  expect(corrupt.meta.settings).toMatchObject({ muted: false, masterVolume: 0, soundVolume: 1 });
});
it('migrates the old combined SFX slider into combat and UI groups', () => {
  const save = parseSave(JSON.stringify({ saveVersion: 5, meta: { settings: { soundVolume: 0.35 } } }));
  expect(save.meta.settings).toMatchObject({ soundVolume: 0.35, combatVolume: 0.35, uiVolume: 0.35 });
});

