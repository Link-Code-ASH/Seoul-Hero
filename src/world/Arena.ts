import type { ArenaSize, Vec2 } from '../data/types';
export interface WorldViewport { width: number; height: number }
import { ARENA_RULES } from '../data/arenaConfig';
export { ARENA_RULES } from '../data/arenaConfig';
const clamp = (n: number, limit: number): number => Math.max(-Math.max(0, limit), Math.min(Math.max(0, limit), n));
export function clampToArena(point: Vec2, radius: number, arena: ArenaSize): void {
  point.x = clamp(point.x, arena.arenaWidth / 2 - radius);
  point.y = clamp(point.y, arena.arenaHeight / 2 - radius);
}
export function cameraPosition(player: Vec2, view: WorldViewport, arena: ArenaSize): Vec2 {
  return { x: clamp(player.x, (arena.arenaWidth - view.width) / 2), y: clamp(player.y, (arena.arenaHeight - view.height) / 2) };
}
/** Prefer unseen perimeter points; fall back to the farthest safe point on small arenas. */
export function arenaSpawn(player: Vec2, view: WorldViewport, radius: number, arena: ArenaSize, random: () => number): Vec2 | undefined {
  const x = arena.arenaWidth / 2 - radius, y = arena.arenaHeight / 2 - radius;
  if (x <= 0 || y <= 0) return undefined;
  const camera = cameraPosition(player, view, arena);
  const fullArenaVisible = view.width >= arena.arenaWidth - radius * 2 && view.height >= arena.arenaHeight - radius * 2;
  let best = { x: player.x > 0 ? -x : x, y: player.y > 0 ? -y : y };
  let bestDistance = Math.hypot(best.x - player.x, best.y - player.y);
  for (let i = 0; i < ARENA_RULES.spawnAttempts; i++) {
    // Pick a continuous point along the full perimeter. Weighting by edge
    // length keeps every metre of the arena boundary equally likely.
    const perimeter = 4 * (x + y);
    let edge = random() * perimeter;
    let point: Vec2;
    if (edge < 2 * x) point = { x: -x + edge, y: -y };
    else if ((edge -= 2 * x) < 2 * y) point = { x, y: -y + edge };
    else if ((edge -= 2 * y) < 2 * x) point = { x: x - edge, y };
    else { edge -= 2 * x; point = { x: -x, y: y - edge }; }
    const distance = Math.hypot(point.x - player.x, point.y - player.y);
    if (distance >= ARENA_RULES.minimumSpawnDistance && (fullArenaVisible || Math.abs(point.x - camera.x) > view.width / 2 + radius || Math.abs(point.y - camera.y) > view.height / 2 + radius)) return point;
    if (distance > bestDistance) { best = point; bestDistance = distance; }
  }
  // Impossible arenas skip spawning instead of placing an enemy on the player.
  return bestDistance >= ARENA_RULES.minimumSpawnDistance ? best : undefined;
}
