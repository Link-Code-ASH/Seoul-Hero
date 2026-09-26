import type { GameEvent } from '../core/GameEvents';
import { sourcedSfxPaths } from './sourcedAudio';

// Only deployed sounds enter the bundle. The future library and legacy sources stay local.
const audioFiles = import.meta.glob<string>(['../../assets/audio/bgm/provided/*.mp3', '../../assets/audio/sfx/sourced/**/*.wav'], { eager: true, query: '?url', import: 'default' });
const file = (path: string): string => audioFiles[`../../assets/audio/${path}`] || '';

export type SfxGroup = 'combat' | 'ui';
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
}
const cue = (id: keyof typeof sourcedSfxPaths, label: string, group: SfxGroup, gain: number, interval: number,
  concurrency: number, priority: SfxDefinition['priority'], pitch: readonly [number, number] = [0.97, 1.03], volumeVariation = 0.06): SfxDefinition =>
  ({ urls: sourcedSfxPaths[id].map(file), label, group, gain, interval, concurrency, priority, pitch, volumeVariation });

export const sfx = {
  purchase: cue('purchase', '구매', 'ui', 0.4, 0.1, 2, 4, [0.99, 1.01], 0.02),
  reroll: cue('reroll', '상품 교체', 'ui', 0.34, 0.12, 1, 3, [0.98, 1.02], 0.03),
  lock: cue('lock', '상품 잠금', 'ui', 0.34, 0.1, 2, 3, [0.99, 1.01], 0.02),
  weaponPurchase: cue('weaponPurchase', '무기 구매', 'ui', 0.42, 0.12, 2, 4, [0.99, 1.01], 0.02),
  branchChoice: cue('branchChoice', '무기 분기', 'ui', 0.45, 0.15, 2, 4, [0.99, 1.01], 0.02),
  critical: cue('critical', '치명타', 'combat', 0.41, 0.1, 2, 4, [0.98, 1.02], 0.035),
  eliteSpawned: cue('eliteSpawned', '엘리트 출현', 'combat', 0.48, 0.6, 1, 4, [1, 1], 0),
  waveStarted: cue('waveStarted', 'Wave 시작', 'ui', 0.4, 0.3, 1, 4, [1, 1], 0),
  waveCompleted: cue('waveCompleted', 'Wave 완료', 'ui', 0.4, 0.3, 1, 4, [1, 1], 0),
  slashAttack: cue('slashAttack', '검격', 'combat', 0.28, 0.095, 2, 2, [0.97, 1.03], 0.04),
  orbitAttack: cue('orbitAttack', '회전 표창', 'combat', 0.07, 0.34, 1, 1, [0.97, 1.02], 0.04),
  chainAttack: cue('chainAttack', '연쇄 번개', 'combat', 0.23, 0.25, 1, 2, [0.98, 1.02], 0.035),
  bombardAttack: cue('bombardAttack', '마력 폭격', 'combat', 0.4, 0.16, 2, 3, [0.97, 1.02], 0.04),
  piercingAttack: cue('piercingAttack', '관통 사격', 'combat', 0.23, 0.1, 2, 2, [0.98, 1.02], 0.03),
  turretFired: cue('turretFired', '포탑 발사', 'combat', 0.13, 0.14, 2, 1, [0.99, 1.015], 0.025),
  minePlaced: cue('minePlaced', '지뢰 설치', 'combat', 0.18, 0.16, 1, 1, [0.98, 1.02], 0.035),
  mineExploded: cue('mineExploded', '지뢰 폭발', 'combat', 0.4, 0.16, 2, 3, [0.97, 1.02], 0.04),
  fieldActivated: cue('fieldActivated', '마력장 작동', 'combat', 0.16, 0.22, 1, 1, [0.98, 1.02], 0.035),
  weaponFired: cue('weaponFired', '마력탄 발사', 'combat', 0.23, 0.08, 2, 2, [0.98, 1.02], 0.03),
  enemyHit: cue('enemyHit', '적 피격', 'combat', 0.19, 0.065, 2, 2, [0.98, 1.02], 0.03),
  enemyKilled: cue('enemyKilled', '적 처치', 'combat', 0.26, 0.085, 2, 3, [0.98, 1.025], 0.04),
  magicStoneCollected: cue('magicStoneCollected', '마력석 획득', 'ui', 0.075, 0.09, 1, 1, [0.985, 1.015], 0.025),
  walletSweep: cue('walletSweep', '미회수 마력석 지갑 회수', 'ui', 0.16, 0.8, 1, 2, [1, 1], 0),
  buttonClick: cue('buttonClick', '버튼 클릭', 'ui', 0.24, 0.04, 2, 2, [1, 1], 0),
  supplyLatch: cue('supplyLatch', '보급 상자 잠금 해제', 'ui', 0.34, 0.8, 1, 4, [0.99, 1.01], 0.01),
  supplyFanfare: cue('supplyFanfare', '보급 상자 보상 팡파르', 'ui', 0.38, 0.8, 1, 5, [1, 1], 0),
  playerHit: cue('playerHit', '플레이어 피격', 'combat', 0.46, 0.18, 2, 5, [0.99, 1.015], 0.025),
  bossSpawned: cue('bossSpawned', '보스 경고', 'combat', 0.55, 1, 1, 5, [1, 1], 0),
  stageClear: cue('stageClear', '스테이지 클리어', 'ui', 0.56, 1, 1, 5, [1, 1], 0),
  gameOver: cue('gameOver', '게임 오버', 'ui', 0.5, 1, 1, 5, [1, 1], 0),
} satisfies Record<GameEvent | 'buttonClick' | 'supplyLatch' | 'supplyFanfare' | 'walletSweep', SfxDefinition>;
export type SfxId = keyof typeof sfx;

export interface BgmTrack { readonly url: string; readonly label: string }
export const bgm = {
  menu: { tracks: [
    { url: file('bgm/provided/menu_01.mp3'), label: 'BGM 1' },
    { url: file('bgm/provided/menu_02.mp3'), label: 'BGM 2' },
    { url: file('bgm/provided/menu_03.mp3'), label: 'BGM 3' },
  ], gain: 0.65 },
  guild: { tracks: [
    { url: file('bgm/provided/guild_01.mp3'), label: 'Guild 1' },
    { url: file('bgm/provided/menu_02.mp3'), label: 'Guild 2' },
  ], gain: 0.48 },
  combat: { tracks: [
    { url: file('bgm/provided/combat_01.mp3'), label: 'Ingame 1' },
    { url: file('bgm/provided/combat_02.mp3'), label: 'Ingame 2' },
  ], gain: 0.5 },
} satisfies Record<string, { tracks: BgmTrack[]; gain: number }>;
export type BgmId = keyof typeof bgm;
// BGM streams on demand and is intentionally absent from the startup preload.
export const preloadedAudioUrls = (): string[] => [...new Set(Object.values(sfx).flatMap(sound => sound.urls))];
export const AUDIO_CONFIG = { maxVoices: 16, reservedImportantVoices: 4, musicFade: 0.35, volumeFade: 0.035, pausedMusicGain: 0.25 } as const;
