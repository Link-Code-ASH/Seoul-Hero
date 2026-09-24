import type { Vec2 } from '../data/types';
import type { InputSource } from './InputManager';
/** Pointer input implements the same movement contract as a keyboard. */
export class TouchInput implements InputSource {
  private pointerId: number | null = null;
  private originX = 0;
  private originY = 0;
  private readonly direction: Vec2 = { x: 0, y: 0 };
  constructor(private readonly element: HTMLElement, private readonly active: () => boolean = () => true) {
    element.addEventListener('pointerdown', this.down);
    element.addEventListener('pointermove', this.move);
    element.addEventListener('pointerup', this.up);
    element.addEventListener('pointercancel', this.up);
    element.addEventListener('lostpointercapture', this.clear);
  }
  private down = (event: PointerEvent): void => {
    if (this.pointerId !== null || !this.active() || event.pointerType === 'mouse') return;
    this.pointerId = event.pointerId;
    this.originX = event.clientX;
    this.originY = event.clientY;
    this.element.setPointerCapture(event.pointerId);
    this.direction.x = 0; this.direction.y = 0;
  };
  private move = (event: PointerEvent): void => {
    if (event.pointerId !== this.pointerId) return;
    const dx = event.clientX - this.originX, dy = event.clientY - this.originY;
    if (Math.hypot(dx, dy) < 5) { this.direction.x = 0; this.direction.y = 0; return; }
    let x = dx / 56, y = dy / 56;
    const length = Math.hypot(x, y);
    if (length > 1) { x /= length; y /= length; }
    this.direction.x = x; this.direction.y = y;
  };
  private up = (event: PointerEvent): void => { if (event.pointerId === this.pointerId) this.clear(); };
  clear = (): void => {
    this.pointerId = null; this.direction.x = 0; this.direction.y = 0;
  };
  read(): Vec2 { return this.direction; }
  destroy(): void {
    this.element.removeEventListener('pointerdown', this.down);
    this.element.removeEventListener('pointermove', this.move);
    this.element.removeEventListener('pointerup', this.up);
    this.element.removeEventListener('pointercancel', this.up);
    this.element.removeEventListener('lostpointercapture', this.clear);
  }
}
