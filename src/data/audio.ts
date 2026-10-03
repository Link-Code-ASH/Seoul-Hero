import type { GameEvent } from '../core/GameEvents';
import { sourcedSfxPaths, sourcedSfxSettings, sourcedAudioPolicy, sourcedAudioConnections } from './sourcedAudio';

// Only the adopted revision enters the game bundle; rollback WAVs stay outside this glob.
const audioFiles = import.meta.glob<string>(['../../assets/audio/bgm/provided/*.mp3', '../../assets/audio/sfx/reborn-01/**/*.wav'], { eager: true, query: '?url', import: 'default' });
const file = (path: string): string => audioFiles[`../../assets/audio/${path}`] || '';

export type SfxGroup = 'combat' | 'ui' | 'ambience';
export interface SfxDefinition {
  readonly urls: readonly string[];
  readonly label: string;
  readonly group: SfxGroup;
  readonly gain: number;
  readonly interval: number;
  readonly concurrency: number;
  readonly priority: 1 | 2 | 3 | 4 | 5;
  readonly pitch: readonly [number, number];
  readonly volumeVariation: number;
  readonly protected: boolean;
  readonly loop: boolean;
}
type CueDefinitions = { -readonly [K in keyof typeof sourcedSfxPaths]: SfxDefinition };
function createCues(): Readonly<CueDefinitions> {
  const definitions = {} as CueDefinitions;
  for (const id of Object.keys(sourcedSfxPaths) as (keyof typeof sourcedSfxPaths)[]) {
    definitions[id] = { ...sourcedSfxSettings[id], urls: sourcedSfxPaths[id].map(file) };
  }
  return definitions;
}
export const sfx = createCues() satisfies
  Record<GameEvent | 'buttonClick' | 'supplyLatch' | 'supplyFanfare' | 'walletSweep' | 'waveCountdownTick', SfxDefinition>;
export type SfxId = keyof typeof sfx;
export const audioConnections = sourcedAudioConnections;

export interface BgmTrack { readonly url: string; readonly label: string }
export const bgm = {
  menu: { tracks: [
    { url: file('bgm/provided/menu_01.mp3'), label: 'BGM 1' },
    { url: file('bgm/provided/menu_02.mp3'), label: 'BGM 2' },
    { url: file('bgm/provided/menu_03.mp3'), label: 'BGM 3' },
  ], gain: 0.65 },
  guild: { tracks: [
    { url: file('bgm/provided/guild_01.mp3'), label: 'Guild 1' },
  ], gain: 0.48 },
  combat: { tracks: [
    { url: file('bgm/provided/combat_01.mp3'), label: 'Ingame 1' },
    { url: file('bgm/provided/combat_02.mp3'), label: 'Ingame 2' },
  ], gain: 0.12 },
} satisfies Record<string, { tracks: BgmTrack[]; gain: number }>;
export type BgmId = keyof typeof bgm;
// BGM streams on demand and is intentionally absent from the startup preload.
export const preloadedAudioUrls = (): string[] => [...new Set(Object.values(sfx).flatMap(sound => sound.urls))];
export const AUDIO_CONFIG = {
  ...sourcedAudioPolicy, volumeFade: 0.035, pausedMusicGain: sourcedAudioPolicy.pauseGain,
} as const;
