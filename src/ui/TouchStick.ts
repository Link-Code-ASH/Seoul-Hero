export interface TouchStickPosition { originX: number; originY: number; x: number; y: number }

/** Client coordinates are converted to the scaled mobile game surface. */
export class TouchStick {
  private readonly element = document.createElement('div');
  private readonly knob = document.createElement('span');
  constructor(private readonly host: HTMLElement) {
    this.element.className = 'touch-stick';
    this.element.setAttribute('aria-hidden', 'true');
    this.element.hidden = true;
    this.element.append(this.knob);
    host.append(this.element);
  }
  update = (position: TouchStickPosition | null): void => {
    this.element.hidden = !position;
    if (!position) return;
    const bounds = this.host.getBoundingClientRect();
    if (!bounds.width || !bounds.height) return;
    const scaleX = this.host.clientWidth / bounds.width;
    const scaleY = this.host.clientHeight / bounds.height;
    this.element.style.left = `${(position.originX - bounds.left) * scaleX}px`;
    this.element.style.top = `${(position.originY - bounds.top) * scaleY}px`;
    const dx = (position.x - position.originX) * scaleX;
    const dy = (position.y - position.originY) * scaleY;
    const limit = Math.min(1, 23 / Math.max(1, Math.hypot(dx, dy)));
    this.knob.style.transform = `translate(${dx * limit}px,${dy * limit}px)`;
  };
  destroy(): void { this.element.remove(); }
}
