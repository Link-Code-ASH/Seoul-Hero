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
export const GUILD_ROOM = { width: 1672, height: 940, minX: 155, maxX: 1515, minY: 265, maxY: 805,
  spawnX: 835, spawnY: 475, speed: 185, interactionRadius: 170 } as const;

export const guildFacilities: Record<GuildFacilityId, GuildFacility> = {
  training: { id: 'training', name: '훈련실', x: 355, y: 345, radius: 92, art: 'guildTraining',
    description: '각성자의 기본 체력을 단련합니다.', effect: '기본 최대 체력 +2%', maxLevel: 3, costs: [40, 80, 160] },
  recovery: { id: 'recovery', name: '회수실', x: 1060, y: 430, radius: 90, art: 'guildRecovery',
    description: '현장 회수반의 정산 효율을 높입니다.', effect: '오프라인 30분마다 협회 코인 +1', maxLevel: 3, costs: [40, 80, 160] },
  supply: { id: 'supply', name: '보급 정비대', x: 1300, y: 550, radius: 86, art: 'guildSupply',
    description: '보급 상자의 코인 회수량을 높입니다.', effect: '보급 상자마다 협회 코인 +1', maxLevel: 3, costs: [40, 80, 160] },
};

export const guildPoints: readonly GuildPoint[] = [
  guildFacilities.training, guildFacilities.recovery, guildFacilities.supply,
  { id: 'gate', name: '출동 단말', x: 310, y: 550, radius: 68, art: 'guildGate' },
  { id: 'roster', name: '길드 명부', x: 830, y: 255, radius: 56, art: 'guildRoster' },
];
