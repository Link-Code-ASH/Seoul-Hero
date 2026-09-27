import type { ImageId } from './images';

export type GuildFacilityId = 'training' | 'recovery' | 'supply';
export type GuildPointId = GuildFacilityId | 'gate' | 'roster';

export interface GuildPoint {
  id: GuildPointId;
  name: string;
  x: number;
  y: number;
  radius: number;
  art: ImageId;
}

export interface GuildFacility extends GuildPoint {
  id: GuildFacilityId;
  description: string;
  effect: string;
  maxLevel: number;
  costs: readonly number[];
}

export const GUILD_NAME = '수탐자';
/** A guild-only operator, not an unlockable combat character or save-owned avatar. */
export const guildOperator = {
  id: 'hanSeoa', name: '한서아', role: '길드 오퍼레이터',
  description: '수탐자의 현장 통신과 본부 운영을 맡는다.',
  illustration: 'guildOperatorIllustration', sprite: 'guildOperatorTopdown',
} as const;
export const GUILD_ROOM = { width: 1850, height: 1045, minX: 105, maxX: 1745, minY: 100, maxY: 940,
  spawnX: 925, spawnY: 535, speed: 285, interactionRadius: 135 } as const;

/** Overhead footprints of the furniture painted into guild_cafe_topdown_01. */
export const guildCafeFootprints = [
  { minX: 660, maxX: 1360, minY: 70, maxY: 275 },
  { minX: 260, maxX: 435, minY: 145, maxY: 285 },
  { minX: 445, maxX: 620, minY: 85, maxY: 205 },
  { minX: 1540, maxX: 1720, minY: 135, maxY: 285 },
  { minX: 1540, maxX: 1720, minY: 305, maxY: 445 },
  { minX: 70, maxX: 455, minY: 710, maxY: 950 },
  { minX: 1490, maxX: 1770, minY: 705, maxY: 950 },
] as const;

export const guildFacilities: Record<GuildFacilityId, GuildFacility> = {
  training: { id: 'training', name: '훈련실', x: 270, y: 820, radius: 70, art: 'guildTraining',
    description: '각성자의 기본 체력을 단련합니다.', effect: '기본 최대 체력 +2%', maxLevel: 3, costs: [40, 80, 160] },
  recovery: { id: 'recovery', name: '회수실', x: 1630, y: 815, radius: 70, art: 'guildRecovery',
    description: '현장 회수반의 정산 효율을 높입니다.', effect: '오프라인 30분마다 협회 코인 +1', maxLevel: 3, costs: [40, 80, 160] },
  supply: { id: 'supply', name: '보급 정비대', x: 1160, y: 180, radius: 70, art: 'guildSupply',
    description: '보급 상자의 코인 회수량을 높입니다.', effect: '보급 상자마다 협회 코인 +1', maxLevel: 3, costs: [40, 80, 160] },
};

export const guildPoints: readonly GuildPoint[] = [
  guildFacilities.training, guildFacilities.recovery, guildFacilities.supply,
  { id: 'gate', name: '출동 단말', x: 130, y: 480, radius: 70, art: 'guildGate' },
  { id: 'roster', name: '길드 명부', x: 140, y: 110, radius: 54, art: 'guildRoster' },
];
