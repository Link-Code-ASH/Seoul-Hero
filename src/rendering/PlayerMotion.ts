import type { RunState } from '../state/RunState';

const MOTION_CYCLE_DISTANCE = 118;
const TAU = Math.PI * 2;

/** Presentation-only locomotion derived from world movement, never from keyboard events. */
export class PlayerMotion {
  private player: RunState['player'] | null = null;
  private x = 0;
  private y = 0;
  private stageCombatTime = 0;
  private phase = 0;
  private travelled = 0;
  private targetMoving = false;
  private directionX = 0;
  private directionY = 0;
  private speed = 0;
  moving = false;
  facing: -1 | 1 = 1;
  intensity = 0;

  update(run: RunState, renderDelta: number): void {
    if (this.player !== run.player) {
      this.player = run.player;
      this.x = run.player.x;
      this.y = run.player.y;
      this.stageCombatTime = run.stageCombatTime;
      this.phase = 0;
      this.travelled = 0;
      this.targetMoving = false;
      this.directionX = 0;
      this.directionY = 0;
      this.speed = 0;
      this.intensity = 0;
      this.moving = false;
      this.facing = 1;
      return;
    }

    const dt = Math.min(Math.max(renderDelta, 0), 0.05);
    if (run.phase !== 'waveActive') {
      this.targetMoving = false;
      this.speed = 0;
    }
    if (run.stageCombatTime !== this.stageCombatTime) {
      const simulationDelta = Math.max(0.001, run.stageCombatTime - this.stageCombatTime);
      const dx = run.player.x - this.x;
      const dy = run.player.y - this.y;
      const distance = Math.hypot(dx, dy);
      this.targetMoving = run.phase === 'waveActive' && distance > 0.001;
      if (this.targetMoving) {
        this.directionX = dx / distance;
        this.directionY = dy / distance;
        this.speed = distance / simulationDelta;
        if (Math.abs(dx) > 0.001) this.facing = dx < 0 ? -1 : 1;
        // Ignore teleport-sized jumps so developer controls do not jerk the presentation.
        const walked = Math.min(distance, MOTION_CYCLE_DISTANCE / 2);
        this.travelled += walked;
        this.phase = this.travelled / MOTION_CYCLE_DISTANCE * TAU;
      } else {
        this.speed = 0;
      }
      this.x = run.player.x;
      this.y = run.player.y;
      this.stageCombatTime = run.stageCombatTime;
    }

    const desired = this.targetMoving ? 1 : 0;
    const response = desired > this.intensity ? 12 : 8;
    this.intensity += (desired - this.intensity) * (1 - Math.exp(-response * dt));
    if (this.intensity < 0.002) this.intensity = 0;
    this.moving = this.intensity > 0.03;
  }

  get bobY(): number { return -Math.abs(Math.sin(this.phase)) * 1.7 * this.intensity; }
  get swayX(): number { return Math.sin(this.phase) * 0.65 * this.intensity; }
  get lean(): number { return Math.max(-0.045, Math.min(0.045, this.directionX * 0.035 * this.intensity)); }
  get dragSkew(): number { return -this.directionX * 0.012 * this.intensity; }
  get dragX(): number { return -this.directionX * Math.min(1.2, this.speed / 220) * this.intensity; }
  get dragY(): number { return -this.directionY * Math.min(0.8, this.speed / 300) * this.intensity; }
  get scaleX(): number {
    const contact = Math.max(0, Math.cos(this.phase * 2));
    return 1 + contact * 0.012 * this.intensity;
  }
  get scaleY(): number {
    const contact = Math.max(0, Math.cos(this.phase * 2));
    return 1 - contact * 0.014 * this.intensity;
  }
  get shadowScale(): number { return 1 - Math.abs(Math.sin(this.phase)) * 0.08 * this.intensity; }
  get shadowAlpha(): number { return 0.38 - Math.abs(Math.sin(this.phase)) * 0.09 * this.intensity; }
  get magicLag(): number { return Math.min(1, this.speed / 220) * this.intensity; }
}
