import type { GameEvent } from '../core/GameEvents';

const audioFiles = import.meta.glob<string>('../../assets/audio/**/*.wav', { eager: true, query: '?url', import: 'default' });
const file = (path: string): string => {
  const revised = path.startsWith('sfx/') ? `../../assets/audio/sfx/clear/${path.slice(4)}` : '';
  return (revised && audioFiles[revised]) || audioFiles[`../../assets/audio/${path}`] || '';
};

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
const cue = (paths: readonly string[], label: string, group: SfxGroup, gain: number, interval: number,
  concurrency: number, priority: SfxDefinition['priority'], pitch: readonly [number, number] = [0.97, 1.03], volumeVariation = 0.06): SfxDefinition =>
  ({ urls: paths.map(file), label, group, gain, interval, concurrency, priority, pitch, volumeVariation });

export const sfx = {
  purchase: cue(['sfx/ui_purchase_01.wav'], '구매', 'ui', 0.4, 0.1, 2, 4, [0.99, 1.01], 0.02),
  reroll: cue(['sfx/ui_reroll_01.wav'], '상품 교체', 'ui', 0.34, 0.12, 1, 3, [0.98, 1.02], 0.03),
  lock: cue(['sfx/ui_lock_01.wav'], '상품 잠금', 'ui', 0.34, 0.1, 2, 3, [0.99, 1.01], 0.02),
  weaponPurchase: cue(['sfx/ui_reward_01.wav'], '무기 구매', 'ui', 0.42, 0.12, 2, 4, [0.99, 1.01], 0.02),
  branchChoice: cue(['sfx/ui_branch_01.wav'], '무기 분기', 'ui', 0.45, 0.15, 2, 4, [0.99, 1.01], 0.02),
  critical: cue(['sfx/critical_01.wav','sfx/critical_02.wav'], '치명타', 'combat', 0.41, 0.1, 2, 4, [0.98, 1.02], 0.035),
  eliteSpawned: cue(['sfx/elite_warning_01.wav'], '엘리트 출현', 'combat', 0.42, 0.6, 1, 4, [1, 1], 0),
  waveStarted: cue(['sfx/wave_start_01.wav'], 'Wave 시작', 'ui', 0.4, 0.3, 1, 4, [1, 1], 0),
  waveCompleted: cue(['sfx/wave_clear_01.wav'], 'Wave 완료', 'ui', 0.4, 0.3, 1, 4, [1, 1], 0),
  slashAttack: cue(['sfx/slash_01.wav','sfx/slash_02.wav'], '검격', 'combat', 0.24, 0.095, 2, 2, [0.97, 1.03], 0.04),
  orbitAttack: cue(['sfx/orbit_blade_01.wav','sfx/orbit_blade_02.wav'], '회전 표창', 'combat', 0.055, 0.34, 1, 1, [0.97, 1.02], 0.04),
  chainAttack: cue(['sfx/chain_discharge_01.wav','sfx/chain_discharge_02.wav'], '연쇄 번개', 'combat', 0.19, 0.25, 1, 2, [0.98, 1.02], 0.035),
  bombardAttack: cue(['sfx/explosion_arcane_01.wav','sfx/explosion_arcane_02.wav'], '마력 폭격', 'combat', 0.35, 0.16, 2, 3, [0.97, 1.02], 0.04),
  piercingAttack: cue(['sfx/piercing_01.wav','sfx/piercing_02.wav'], '관통 사격', 'combat', 0.19, 0.1, 2, 2, [0.98, 1.02], 0.03),
  turretFired: cue(['sfx/turret_soft_01.wav','sfx/turret_soft_02.wav'], '포탑 발사', 'combat', 0.1, 0.14, 2, 1, [0.99, 1.015], 0.025),
  minePlaced: cue(['sfx/mine_arm_01.wav'], '지뢰 설치', 'combat', 0.16, 0.16, 1, 1, [0.98, 1.02], 0.035),
  mineExploded: cue(['sfx/explosion_mine_01.wav','sfx/explosion_mine_02.wav'], '지뢰 폭발', 'combat', 0.35, 0.16, 2, 3, [0.97, 1.02], 0.04),
  fieldActivated: cue(['sfx/field_pulse_01.wav'], '마력장 작동', 'combat', 0.14, 0.22, 1, 1, [0.98, 1.02], 0.035),
  weaponFired: cue(['sfx/mana_bolt_01.wav','sfx/mana_bolt_02.wav','sfx/mana_bolt_03.wav'], '마력탄 발사', 'combat', 0.19, 0.08, 2, 2, [0.98, 1.02], 0.03),
  enemyHit: cue(['sfx/hit_light_01.wav','sfx/hit_light_02.wav','sfx/hit_light_03.wav'], '적 피격', 'combat', 0.16, 0.065, 2, 2, [0.98, 1.02], 0.03),
  enemyKilled: cue(['sfx/enemy_death_01.wav','sfx/enemy_death_02.wav','sfx/enemy_death_03.wav'], '적 처치', 'combat', 0.23, 0.085, 2, 3, [0.98, 1.025], 0.04),
  magicStoneCollected: cue(['sfx/magic_stone_chime_01.wav','sfx/magic_stone_chime_02.wav','sfx/magic_stone_chime_03.wav'], '마력석 획득', 'ui', 0.075, 0.09, 1, 1, [0.985, 1.015], 0.025),
  walletSweep: cue(['sfx/wallet_sweep_01.wav'], '미회수 마력석 지갑 회수', 'ui', 0.16, 0.8, 1, 2, [1, 1], 0),
  buttonClick: cue(['sfx/ui_click_01.wav'], '버튼 클릭', 'ui', 0.24, 0.04, 2, 2, [1, 1], 0),
  supplyLatch: cue(['sfx/ui_supply_latch_01.wav'], '보급 상자 잠금 해제', 'ui', 0.34, 0.8, 1, 4, [0.99, 1.01], 0.01),
  supplyFanfare: cue(['sfx/ui_supply_fanfare_01.wav'], '보급 상자 보상 팡파르', 'ui', 0.38, 0.8, 1, 5, [1, 1], 0),
  playerHit: cue(['sfx/player_hit_01.wav','sfx/player_hit_02.wav'], '플레이어 피격', 'combat', 0.4, 0.18, 2, 5, [0.99, 1.015], 0.025),
  bossSpawned: cue(['sfx/boss_warning_arcade_01.wav'], '보스 경고', 'combat', 0.48, 1, 1, 5, [1, 1], 0),
  stageClear: cue(['sfx/stage_clear_01.wav'], '스테이지 클리어', 'ui', 0.56, 1, 1, 5, [1, 1], 0),
  gameOver: cue(['sfx/game_over_01.wav'], '게임 오버', 'ui', 0.5, 1, 1, 5, [1, 1], 0),
} satisfies Record<GameEvent | 'buttonClick' | 'supplyLatch' | 'supplyFanfare' | 'walletSweep', SfxDefinition>;
export type SfxId = keyof typeof sfx;

export const bgm = {
  menu: { url: file('bgm/seoul_after_dusk_01.wav'), label: '서울, 해가 진 뒤', gain: 0.65 },
  guild: { url: file('bgm/guild_daylight_01.wav'), label: '수탐자 길드', gain: 0.48 },
  combat: { url: file('bgm/gate_hunt_01.wav'), label: '게이트 교전', gain: 0.5 },
  boss: { url: file('bgm/the_gate_keeper_01.wav'), label: '게이트 파수꾼', gain: 0.6 },
};
export type BgmId = keyof typeof bgm;
export const allAudioUrls = (): string[] => [...new Set([...Object.values(sfx).flatMap(sound => sound.urls), ...Object.values(bgm).map(track => track.url)])];
export const AUDIO_CONFIG = { maxVoices: 16, reservedImportantVoices: 4, musicFade: 0.35, volumeFade: 0.035, pausedMusicGain: 0.25 } as const;
