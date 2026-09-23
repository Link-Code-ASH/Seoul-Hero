import type { Vec2 } from '../data/types';

export function distanceSquared(a: Vec2, b: Vec2): number {
  const x = a.x - b.x;
  const y = a.y - b.y;
  return x * x + y * y;
}

/** Returns the first intersection along the segment, or Infinity when there is none. */
export function segmentCircleHit(
  startX: number, startY: number, endX: number, endY: number,
  centerX: number, centerY: number, radius: number,
): number {
  const dx = endX - startX;
  const dy = endY - startY;
  const fx = startX - centerX;
  const fy = startY - centerY;
  const c = fx * fx + fy * fy - radius * radius;
  if (c <= 0) return 0;
  const a = dx * dx + dy * dy;
  if (a === 0) return Infinity;
  const b = 2 * (fx * dx + fy * dy);
  const discriminant = b * b - 4 * a * c;
  if (discriminant < 0) return Infinity;
  const t = (-b - Math.sqrt(discriminant)) / (2 * a);
  return t >= 0 && t <= 1 ? t : Infinity;
}

export function weightedIndex(weights: readonly number[], random: () => number): number {
  const total = weights.reduce((sum, weight) => sum + Math.max(0, weight), 0);
  if (total <= 0 || weights.length === 0) return -1;
  let roll = Math.max(0, Math.min(1 - Number.EPSILON, random())) * total;
  for (let i = 0; i < weights.length; i++) {
    roll -= Math.max(0, weights[i] ?? 0);
    if (roll < 0) return i;
  }
  return weights.length - 1;
}
