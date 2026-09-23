import type { Vec2 } from '../data/types';
import type { InputSource } from './InputManager';
const movementKeys = new Set(['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight']);
export class KeyboardInput implements InputSource {
  enabled = false;
  private readonly held = new Set<string>();
  private readonly direction: Vec2 = { x: 0, y: 0 };
  constructor() {
    window.addEventListener('keydown', this.keydown);
    window.addEventListener('keyup', this.keyup);
    window.addEventListener('blur', this.clear);
  }
  private keydown = (event: KeyboardEvent): void => {
    if (!this.enabled || event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement) return;
    if (movementKeys.has(event.code)) { event.preventDefault(); this.held.add(event.code); }
  };
  private keyup = (event: KeyboardEvent): void => { this.held.delete(event.code); };
  read(): Vec2 {
    this.direction.x = Number(this.held.has('KeyD') || this.held.has('ArrowRight')) - Number(this.held.has('KeyA') || this.held.has('ArrowLeft'));
    this.direction.y = Number(this.held.has('KeyS') || this.held.has('ArrowDown')) - Number(this.held.has('KeyW') || this.held.has('ArrowUp'));
    return this.direction;
  }
  clear = (): void => { this.held.clear(); };
  destroy(): void {
    window.removeEventListener('keydown', this.keydown);
    window.removeEventListener('keyup', this.keyup);
    window.removeEventListener('blur', this.clear);
  }
}
