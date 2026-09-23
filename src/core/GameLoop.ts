import { GAME_CONFIG } from '../data/config';

/** Fixed simulation steps keep collisions and cooldowns stable at 0.5–10×. */
export class GameLoop {
  timeScale = 1;
  paused = true;
  fps = 60;
  frameTime = 16.67;
  private lastTime: number | null = null;
  private accumulator = 0;
  private requestId = 0;
  private running = false;

  constructor(private readonly update: (dt: number) => boolean, private readonly render: (dt: number) => void) {}

  advance(milliseconds: number): void {
    const raw = Math.max(0, milliseconds / 1000);
    if (raw > 0) {
      this.frameTime += (raw * 1000 - this.frameTime) * 0.08;
      this.fps = 1000 / this.frameTime;
    }
    const dt = Math.min(raw, GAME_CONFIG.time.maxFrameDelta);
    if (this.paused) this.accumulator = 0;
    else {
      this.accumulator += dt * this.timeScale;
      let steps = 0;
      while (this.accumulator + GAME_CONFIG.time.fixedStep * 1e-9 >= GAME_CONFIG.time.fixedStep && steps < GAME_CONFIG.time.maxStepsPerFrame) {
        this.accumulator = Math.max(0, this.accumulator - GAME_CONFIG.time.fixedStep);
        steps++;
        if (!this.update(GAME_CONFIG.time.fixedStep)) {
          this.accumulator = 0;
          break;
        }
      }
      // Drop excess backlog under overload; never advance the clock without simulation.
      if (steps === GAME_CONFIG.time.maxStepsPerFrame) this.accumulator = 0;
    }
    this.render(dt);
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.lastTime = null;
    this.requestId = requestAnimationFrame(this.frame);
  }
  resetClock(): void { this.lastTime = null; this.accumulator = 0; }
  stop(): void { this.running = false; cancelAnimationFrame(this.requestId); this.resetClock(); }
  private frame = (now: number): void => {
    if (!this.running) return;
    const elapsed = this.lastTime === null ? 0 : now - this.lastTime;
    this.lastTime = now;
    this.advance(elapsed);
    this.requestId = requestAnimationFrame(this.frame);
  };
}
