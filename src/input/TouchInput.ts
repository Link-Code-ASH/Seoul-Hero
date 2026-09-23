import type { Vec2 } from '../data/types';
import type { InputSource } from './InputManager';
/** Pointer input implements the same movement contract as a keyboard. */
export class TouchInput implements InputSource {
  private pointerId: number | null = null;
  private readonly direction: Vec2 = { x: 0, y: 0 };
  constructor(private readonly element: HTMLElement) {
    element.addEventListener('pointerdown', this.down);
    element.addEventListener('pointermove', this.move);
    element.addEventListener('pointerup', this.up);
    element.addEventListener('pointercancel', this.up);
    element.addEventListener('lostpointercapture', this.clear);
  }
  private down = (event: PointerEvent): void => {
    if (this.pointerId !== null) return;
    this.pointerId = event.pointerId;
    this.element.setPointerCapture(event.pointerId);
    this.move(event);
  };
  private move = (event: PointerEvent): void => {
    if (event.pointerId !== this.pointerId) return;
    const bounds = this.element.getBoundingClientRect();
    let x = (event.clientX - bounds.left - bounds.width / 2) / (bounds.width * 0.32);
    let y = (event.clientY - bounds.top - bounds.height / 2) / (bounds.height * 0.32);
    const length = Math.hypot(x, y);
    if (length > 1) { x /= length; y /= length; }
    this.direction.x = x; this.direction.y = y;
    this.element.style.setProperty('--stick-x', `${x * 28}px`);
    this.element.style.setProperty('--stick-y', `${y * 28}px`);
  };
  private up = (event: PointerEvent): void => { if (event.pointerId === this.pointerId) this.clear(); };
  clear = (): void => {
    this.pointerId = null; this.direction.x = 0; this.direction.y = 0;
    this.element.style.setProperty('--stick-x', '0px'); this.element.style.setProperty('--stick-y', '0px');
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
