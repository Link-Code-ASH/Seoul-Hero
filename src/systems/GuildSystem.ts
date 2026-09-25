import { GUILD_ROOM, guildFacilities, guildPoints, type GuildFacilityId, type GuildPoint, type GuildPointId } from '../data/guild';
import { characters } from '../data/characters';
import type { MetaState } from '../state/MetaState';

export interface GuildPosition { x: number; y: number }
export const guildSpawn = (): GuildPosition => ({ x: GUILD_ROOM.spawnX, y: GUILD_ROOM.spawnY });
export const guildFacilityLevel = (meta: MetaState, id: GuildFacilityId): number => meta.guild.facilityLevels[id] ?? 0;
export const guildFacilityCost = (meta: MetaState, id: GuildFacilityId): number =>
  guildFacilities[id].costs[guildFacilityLevel(meta, id)] ?? Infinity;

export function upgradeGuildFacility(meta: MetaState, id: GuildFacilityId): boolean {
  const definition = guildFacilities[id];
  const level = guildFacilityLevel(meta, id);
  const cost = guildFacilityCost(meta, id);
  if (level >= definition.maxLevel || !Number.isFinite(cost) || meta.wallet.associationCoins < cost) return false;
  meta.wallet.associationCoins -= cost;
  meta.guild.facilityLevels[id] = level + 1;
  return true;
}

export function selectGuildAvatar(meta: MetaState, characterId: string): boolean {
  if (!characters[characterId] || meta.characters[characterId]?.unlocked !== true) return false;
  meta.guild.avatarCharacterId = characterId;
  return true;
}

export function closestGuildPoint(position: GuildPosition): GuildPoint | null {
  let closest: GuildPoint | null = null;
  let best = GUILD_ROOM.interactionRadius ** 2;
  for (const point of guildPoints) {
    const distance = (position.x - point.x) ** 2 + (position.y - point.y) ** 2;
    if (distance < best) { closest = point; best = distance; }
  }
  return closest;
}

export function guildPoint(id: string): GuildPoint | undefined {
  return guildPoints.find(point => point.id === id);
}

export function isGuildFacility(id: GuildPointId): id is GuildFacilityId {
  return Object.hasOwn(guildFacilities, id);
}

/** Coordinates follow the illustrated floor. Collision uses small feet-level footprints. */
export function moveInGuild(position: GuildPosition, direction: GuildPosition, dt: number): GuildPosition {
  const length = Math.hypot(direction.x, direction.y);
  const scale = length > 1 ? 1 / length : 1;
  const blocked = (x: number, y: number): boolean => guildPoints.some(point =>
    Math.hypot(x - point.x, y - point.y) < point.radius + 15);
  const x = Math.max(GUILD_ROOM.minX, Math.min(GUILD_ROOM.maxX, position.x + direction.x * scale * GUILD_ROOM.speed * dt));
  const nextX = blocked(x, position.y) ? position.x : x;
  const y = Math.max(GUILD_ROOM.minY, Math.min(GUILD_ROOM.maxY, position.y + direction.y * scale * GUILD_ROOM.speed * dt));
  return { x: nextX, y: blocked(nextX, y) ? position.y : y };
}
