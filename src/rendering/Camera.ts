import type { Vec2 } from '../data/types';
import { cameraPosition, type WorldViewport } from '../world/Arena';
import type { ArenaSize } from '../data/types';

/** World coordinates do not depend on browser pixels or pixel density. */
export class Camera implements Vec2 {
  x = 0;
  y = 0;

  follow(position: Vec2, viewport: WorldViewport, arena: ArenaSize): void {
    const center = cameraPosition(position, viewport, arena);
    this.x = center.x;
    this.y = center.y;
  }

  sees(position: Vec2, radius: number, viewport: WorldViewport): boolean {
    return Math.abs(position.x - this.x) < viewport.width / 2 + radius
      && Math.abs(position.y - this.y) < viewport.height / 2 + radius;
  }
}
