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
export const GUILD_ROOM = { width: 1280, height: 720, minX: 105, maxX: 1175, minY: 290, maxY: 655,
  spawnX: 640, spawnY: 555, speed: 205, interactionRadius: 160 } as const;

export const guildFacilities: Record<GuildFacilityId, GuildFacility> = {
  training: { id: 'training', name: '훈련실', x: 300, y: 357, radius: 72, art: 'guildTraining',
    description: '각성자의 기본 체력을 단련합니다.', effect: '기본 최대 체력 +2%', maxLevel: 3, costs: [40, 80, 160] },
  recovery: { id: 'recovery', name: '회수실', x: 985, y: 350, radius: 72, art: 'guildRecovery',
    description: '현장 회수반의 정산 효율을 높입니다.', effect: '오프라인 30분마다 협회 코인 +1', maxLevel: 3, costs: [40, 80, 160] },
  supply: { id: 'supply', name: '보급 정비대', x: 985, y: 585, radius: 70, art: 'guildSupply',
    description: '보급 상자의 코인 회수량을 높입니다.', effect: '보급 상자마다 협회 코인 +1', maxLevel: 3, costs: [40, 80, 160] },
};

export const guildPoints: readonly GuildPoint[] = [
  guildFacilities.training, guildFacilities.recovery, guildFacilities.supply,
  { id: 'gate', name: '출동 단말', x: 225, y: 585, radius: 58, art: 'lobbyGate' },
  { id: 'roster', name: '길드 명부', x: 650, y: 325, radius: 56, art: 'lobbyAwakener' },
];
