import type { Graphics } from 'pixi.js';
import type { ImageId } from '../data/images';
import { actorShadowProfiles } from './ActorShadowProfiles';
import { shadowFootprints } from './ShadowFootprints';

/** Draw one grounded prop shadow following the image's lower silhouette. */
export function drawImageContactShadow(
  graphics: Graphics, imageId: ImageId,
  x: number, y: number, width: number, height: number, anchorY: number,
  color: number, alpha: number, facing = 1,
): void {
  const contour = shadowFootprints[imageId];
  if (!contour?.length) {
    drawProjectedShadow(graphics, x, y + height * (1 - anchorY), width * .32, height * .045, 0, color, alpha);
    return;
  }
  // Transform the PNG's bottom alpha contour into the same coordinates as its sprite.
  const points = contour.map(([px, py]) => ({
    x: x + (px - .5) * width * 1.045 * facing,
    y: y + (py - anchorY) * height,
  })).sort((a, b) => a.x - b.x);
  const first = points[0];
  if (!first) return;
  // A shallow curved underside keeps every contact attached without a broad,
  // disconnected oval. This is one filled path, including the end caps.
  const depth = Math.max(2.5, Math.min(height * .042, width * .053));
  graphics.moveTo(first.x, first.y + .5);
  for (const point of points.slice(1)) graphics.lineTo(point.x, point.y + .5);
  for (let i = points.length - 1; i >= 0; i--) {
    const point = points[i];
    if (!point) continue;
    const t = i / (points.length - 1);
    const bulge = .55 + .45 * Math.sin(t * Math.PI);
    graphics.lineTo(point.x, point.y + depth * bulge);
  }
  graphics.closePath().fill({ color, alpha });
}

/** A single soft oval fitted to this actor's feet or wheels. */
export function drawGroundedOvalShadow(
  graphics: Graphics, imageId: ImageId,
  x: number, y: number, width: number, height: number, anchorY: number,
  color: number, alpha: number, facing = 1,
): void {
  const profile = actorShadowProfiles[imageId];
  if (profile) {
    drawProjectedShadow(graphics,
      x + (profile.x - .5) * width * facing,
      y + (profile.y - anchorY) * height,
      width * profile.halfWidth,
      Math.max(3, height * profile.depth),
      0, color, alpha);
    return;
  }
  const contour = shadowFootprints[imageId];
  if (!contour?.length) {
    drawProjectedShadow(graphics, x, y + height * (1 - anchorY), width * .34, height * .07, 0, color, alpha);
    return;
  }
  const lowest = Math.max(...contour.map(([, py]) => py));
  const contact = contour.filter(([, py]) => py >= lowest - .1);
  const minX = Math.min(...contact.map(([px]) => px));
  const maxX = Math.max(...contact.map(([px]) => px));
  const centerX = x + ((minX + maxX) / 2 - .5) * width * facing;
  const groundY = y + (lowest - anchorY) * height;
  drawProjectedShadow(graphics, centerX, groundY, width * .34, Math.max(3, height * .065),
    0, color, alpha);
}

/** One compact contact patch, centered on the object's actual ground point. */
export function drawProjectedShadow(
  graphics: Graphics, footX: number, footY: number,
  halfWidth: number, depth: number, castLength: number,
  color: number, alpha: number, facing = 1,
): void {
  // Keep the legacy arguments for callers, but never cast a second detached oval.
  void castLength;
  void facing;
  graphics
    .ellipse(footX, footY, halfWidth, depth)
    .fill({ color, alpha });
}
