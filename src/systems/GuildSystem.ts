import { GUILD_ROOM, guildCafeFootprints, guildFacilities, guildPoints, type GuildFacilityId, type GuildPoint, type GuildPointId } from '../data/guild';
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

/** The top-down café uses the same footprint for keyboard and tap movement. */
export function isGuildWalkable(x: number, y: number): boolean {
  if (x < GUILD_ROOM.minX || x > GUILD_ROOM.maxX || y < GUILD_ROOM.minY || y > GUILD_ROOM.maxY) return false;
  if (guildPoints.some(point => Math.hypot(x - point.x, y - point.y) < point.radius + 18)) return false;
  return !guildCafeFootprints.some(furniture => x > furniture.minX - 18 && x < furniture.maxX + 18 &&
    y > furniture.minY - 18 && y < furniture.maxY + 18);
}

/** Coordinates follow the overhead floor. The avatar slides along furniture edges. */
export function moveInGuild(position: GuildPosition, direction: GuildPosition, dt: number): GuildPosition {
  const length = Math.hypot(direction.x, direction.y);
  const scale = length > 1 ? 1 / length : 1;
  const x = Math.max(GUILD_ROOM.minX, Math.min(GUILD_ROOM.maxX, position.x + direction.x * scale * GUILD_ROOM.speed * dt));
  const nextX = isGuildWalkable(x, position.y) ? x : position.x;
  const y = Math.max(GUILD_ROOM.minY, Math.min(GUILD_ROOM.maxY, position.y + direction.y * scale * GUILD_ROOM.speed * dt));
  return { x: nextX, y: isGuildWalkable(nextX, y) ? y : position.y };
}

/** A short route around café furniture, computed only when the player taps. */
export function guildWalkPath(from: GuildPosition, target: GuildPosition): GuildPosition[] {
  const clearLine = (a: GuildPosition, b: GuildPosition): boolean => {
    const steps = Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) / 16);
    for (let i = 1; i <= steps; i++) {
      const t = i / steps;
      if (!isGuildWalkable(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)) return false;
    }
    return true;
  };
  if (isGuildWalkable(target.x, target.y) && clearLine(from, target)) return [target];

  const cell = 40;
  const columns = Math.floor((GUILD_ROOM.maxX - GUILD_ROOM.minX) / cell) + 1;
  const rows = Math.floor((GUILD_ROOM.maxY - GUILD_ROOM.minY) / cell) + 1;
  const count = columns * rows;
  const point = (index: number): GuildPosition => ({
    x: GUILD_ROOM.minX + index % columns * cell,
    y: GUILD_ROOM.minY + Math.floor(index / columns) * cell,
  });
  const closestOpen = (position: GuildPosition): number => {
    let best = -1, bestDistance = Infinity;
    for (let index = 0; index < count; index++) {
      const candidate = point(index);
      const distance = (candidate.x - position.x) ** 2 + (candidate.y - position.y) ** 2;
      if (distance < bestDistance && isGuildWalkable(candidate.x, candidate.y)) {
        best = index; bestDistance = distance;
      }
    }
    return best;
  };
  const start = closestOpen(from), end = closestOpen(target);
  if (start < 0 || end < 0) return [];
  const previous = new Int32Array(count).fill(-1);
  const queue = [start];
  previous[start] = start;
  for (let head = 0; head < queue.length && previous[end] === -1; head++) {
    const current = queue[head]!;
    const x = current % columns, y = Math.floor(current / columns);
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      if (!dx && !dy) continue;
      const nx = x + dx, ny = y + dy;
      if (nx < 0 || nx >= columns || ny < 0 || ny >= rows) continue;
      const next = ny * columns + nx;
      if (previous[next] !== -1) continue;
      const nextPoint = point(next);
      if (!isGuildWalkable(nextPoint.x, nextPoint.y)) continue;
      if (dx && dy && (!isGuildWalkable(point(y * columns + nx).x, point(y * columns + nx).y) ||
        !isGuildWalkable(point(ny * columns + x).x, point(ny * columns + x).y))) continue;
      previous[next] = current;
      queue.push(next);
    }
  }
  if (previous[end] === -1) return [];
  const cells: GuildPosition[] = [];
  for (let current = end; current !== start; current = previous[current]!) cells.push(point(current));
  cells.reverse();
  if (isGuildWalkable(target.x, target.y) && clearLine(cells.at(-1) ?? from, target)) cells.push(target);
  const route: GuildPosition[] = [];
  let cursor = from;
  for (let i = 0; i < cells.length;) {
    let furthest = i;
    for (let j = i + 1; j < cells.length && clearLine(cursor, cells[j]!); j++) furthest = j;
    route.push(cells[furthest]!);
    cursor = cells[furthest]!;
    i = furthest + 1;
  }
  return route;
}
