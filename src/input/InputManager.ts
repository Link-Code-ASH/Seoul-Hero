import type { Vec2 } from '../data/types';
export interface InputSource { read(): Vec2; clear(): void; destroy(): void }
export class InputManager {
  private readonly direction: Vec2 = { x: 0, y: 0 };
  constructor(private readonly sources: InputSource[]) {}
  read(): Vec2 {
    this.direction.x = 0;
    this.direction.y = 0;
    for (const source of this.sources) {
      const value = source.read();
      this.direction.x += value.x;
      this.direction.y += value.y;
    }
    const length = Math.hypot(this.direction.x, this.direction.y);
    if (length > 1) { this.direction.x /= length; this.direction.y /= length; }
    return this.direction;
  }
  clear(): void { for (const source of this.sources) source.clear(); }
  destroy(): void { for (const source of this.sources) source.destroy(); }
}
