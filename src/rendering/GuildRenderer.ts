import { Application, Assets, BlurFilter, Container, Graphics, Sprite, Texture } from 'pixi.js';
import { GUILD_ROOM } from '../data/guild';
import { images } from '../data/images';
import type { GuildPosition } from '../systems/GuildSystem';

type PogoDirection = 'down' | 'up' | 'left' | 'right';

const pogoUpperImage = {
  down: images.guildOperatorDownUpper.url,
  up: images.guildOperatorUpUpper.url,
  left: images.guildOperatorLeftUpper.url,
  right: images.guildOperatorRightUpper.url,
} satisfies Record<PogoDirection, string>;

const smooth = (value: number): number => {
  const t = Math.max(0, Math.min(1, value));
  return t * t * (3 - 2 * t);
};

/** Illustrated rider, helical spring and rubber tip move independently. */
class GuildOperatorRider {
  readonly root = new Container();
  private readonly rider = new Sprite(Texture.from(pogoUpperImage.down));
  private readonly spring = new Sprite(Texture.from(images.guildOperatorPogoSpring.url));
  private readonly tip = new Sprite(Texture.from(images.guildOperatorPogoTip.url));
  private readonly shadow = new Graphics();
  private readonly contact = new Graphics();
  private facing: PogoDirection = 'down';
  private phase = 0;
  private movement = 0;
  private impactTime = 0;

  constructor() {
    this.rider.anchor.set(.5, 1);
    this.spring.anchor.set(.5, 1);
    this.tip.anchor.set(.5, 1);
    this.tip.height = 16;
    this.tip.scale.x = this.tip.scale.y;
    this.spring.width = 24;
    this.shadow.ellipse(0, 2, 27, 12).fill({ color: 0x15212b, alpha: .31 });
    this.shadow.filters = [new BlurFilter({ strength: 4 })];
    this.root.addChild(this.shadow, this.contact, this.tip, this.spring, this.rider);
  }

  update(position: GuildPosition, previous: GuildPosition, dt: number): void {
    this.root.position.set(position.x, position.y);
    this.root.zIndex = position.y + 1;
    const dx = position.x - previous.x, dy = position.y - previous.y;
    const speed = dt > 0 ? Math.min(1, Math.hypot(dx, dy) / (GUILD_ROOM.speed * dt)) : 0;
    this.movement += (speed - this.movement) * (1 - Math.exp(-dt * 10));
    if (speed > .04) {
      const direction: PogoDirection = Math.abs(dx) > Math.abs(dy) * 1.12
        ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up');
      if (direction !== this.facing) {
        this.facing = direction;
        this.rider.texture = Texture.from(pogoUpperImage[direction]);
      }
      const lastPhase = this.phase;
      this.phase = (this.phase + dt * (1.8 + speed * .55)) % 1;
      if (this.phase < lastPhase) this.impactTime = .16;
    }
    const keys = [
      { t: 0, coil: 18, lift: 0, stretch: 1 },
      { t: .15, coil: 9, lift: 0, stretch: .965 },
      { t: .34, coil: 23, lift: 5, stretch: 1.025 },
      { t: .56, coil: 25, lift: 12, stretch: 1.02 },
      { t: .84, coil: 20, lift: 4, stretch: 1 },
      { t: 1, coil: 18, lift: 0, stretch: 1 },
    ];
    let from = keys[0]!, to = keys[1]!;
    for (let index = 1; index < keys.length; index++) {
      if (this.phase <= keys[index]!.t) { from = keys[index - 1]!; to = keys[index]!; break; }
    }
    const blend = smooth((this.phase - from.t) / (to.t - from.t));
    const interpolate = (field: 'coil' | 'lift' | 'stretch'): number => from[field] + (to[field] - from[field]) * blend;
    const coil = 18 + (interpolate('coil') - 18) * this.movement;
    const lift = interpolate('lift') * this.movement;
    const stretch = 1 + (interpolate('stretch') - 1) * this.movement;
    this.tip.position.y = -lift;
    this.spring.position.y = -lift - 13;
    this.spring.height = coil;
    this.rider.position.y = -lift - 13 - coil + 3;
    const riderScale = 126 / this.rider.texture.height;
    this.rider.scale.set(riderScale * (2 - stretch), riderScale * stretch);
    this.rider.rotation = Math.sin(this.phase * Math.PI * 2) * .018 * this.movement;
    this.shadow.scale.set(1 - lift / 44, 1 - lift / 58);
    this.shadow.alpha = 1 - lift / 26;
    this.contact.clear();
    this.impactTime = Math.max(0, this.impactTime - dt);
    if (this.impactTime > 0) {
      const progress = 1 - this.impactTime / .16;
      this.contact.ellipse(0, 2, 7 + progress * 19, 4 + progress * 8)
        .stroke({ color: 0xc5e0dc, alpha: .38 * (1 - progress), width: 2 - progress });
    }
  }
}

/** Image-layered headquarters; combat keeps its existing Pixi renderer. */
export class GuildRenderer {
  private readonly app = new Application();
  private readonly room = new Container();
  private readonly destinationMarker = new Graphics();
  private readonly actors = new Container();
  private operator: GuildOperatorRider | null = null;
  private operatorPrevious: GuildPosition = { x: GUILD_ROOM.spawnX, y: GUILD_ROOM.spawnY };
  private host: HTMLElement | null = null;
  private observer: ResizeObserver | null = null;
  private ready = false;
  private scale = 1;
  private idleTime = 0;
  private onFloorTap: ((position: GuildPosition) => void) | null = null;

  async init(host: HTMLElement, onFloorTap: (position: GuildPosition) => void): Promise<void> {
    if (this.ready) return;
    this.host = host;
    await this.app.init({ preference: 'webgl', antialias: true, autoStart: false,
      autoDensity: true, resolution: Math.min(window.devicePixelRatio || 1, 2.25),
      width: Math.max(1, host.clientWidth), height: Math.max(1, host.clientHeight),
      background: 0x8795a7 });
    this.app.ticker.stop();
    const ids = ['guildHall', 'guildOperatorDownUpper', 'guildOperatorUpUpper',
      'guildOperatorLeftUpper', 'guildOperatorRightUpper', 'guildOperatorPogoSpring', 'guildOperatorPogoTip'] as const;
    await Promise.all(ids.map(id => Assets.load(images[id].url)));
    this.app.canvas.className = 'guild-canvas';
    this.app.canvas.setAttribute('aria-label', '길드 본부');
    this.app.canvas.style.touchAction = 'none';
    this.onFloorTap = onFloorTap;
    this.app.canvas.addEventListener('pointerdown', this.pointerDown);
    host.appendChild(this.app.canvas);
    this.room.addChild(this.makeBackground());
    this.destinationMarker.circle(0, 0, 16).stroke({ color: 0xffdfaa, width: 2, alpha: .75 });
    this.destinationMarker.circle(0, 0, 3).fill({ color: 0xffdfaa, alpha: .85 });
    this.destinationMarker.visible = false;
    this.room.addChild(this.destinationMarker);
    this.actors.sortableChildren = true;
    this.room.addChild(this.actors);
    this.operator = new GuildOperatorRider();
    this.actors.addChild(this.operator.root);
    this.app.stage.addChild(this.room);
    this.ready = true;
    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(host);
    this.resize();
  }

  private makeBackground(): Sprite {
    const background = new Sprite(Texture.from(images.guildHall.url));
    background.width = GUILD_ROOM.width;
    background.height = GUILD_ROOM.height;
    return background;
  }

  private resize(): void {
    if (!this.ready || !this.host) return;
    const width = Math.max(1, this.host.clientWidth), height = Math.max(1, this.host.clientHeight);
    this.app.renderer.resize(width, height);
    // Show part of the room at a time so the headquarters has navigable space.
    const roomFraction = width <= 1100 && height <= 500 ? .98 : 1;
    this.scale = Math.max(width / (GUILD_ROOM.width * roomFraction), height / (GUILD_ROOM.height * roomFraction));
    this.room.scale.set(this.scale);
  }

  private pointerDown = (event: PointerEvent): void => {
    if (!this.ready || !this.host || !this.onFloorTap) return;
    event.preventDefault();
    const bounds = this.app.canvas.getBoundingClientRect();
    const screenX = (event.clientX - bounds.left) * this.host.clientWidth / bounds.width;
    const screenY = (event.clientY - bounds.top) * this.host.clientHeight / bounds.height;
    this.onFloorTap({
      x: (screenX - this.room.position.x) / this.scale,
      y: (screenY - this.room.position.y) / this.scale,
    });
  };

  setDestination(position: GuildPosition | null): void {
    this.destinationMarker.visible = position !== null;
    if (position) this.destinationMarker.position.set(position.x, position.y);
  }

  render(position: GuildPosition, dt: number): void {
    if (!this.ready || !this.host) return;
    const delta = Math.min(0.05, Math.max(0, dt));
    this.idleTime += delta;
    if (this.destinationMarker.visible) {
      this.destinationMarker.scale.set(1 + Math.sin(this.idleTime * 5) * .08);
      this.destinationMarker.alpha = .7 + Math.sin(this.idleTime * 5) * .15;
    }
    this.operator?.update(position, this.operatorPrevious, delta);
    this.operatorPrevious = { ...position };
    const visibleWidth = this.host.clientWidth / this.scale;
    const visibleHeight = this.host.clientHeight / this.scale;
    const cameraX = Math.max(visibleWidth / 2, Math.min(GUILD_ROOM.width - visibleWidth / 2, position.x));
    const cameraY = Math.max(visibleHeight / 2, Math.min(GUILD_ROOM.height - visibleHeight / 2, position.y - 80));
    this.room.position.set(Math.round(this.host.clientWidth / 2 - cameraX * this.scale),
      Math.round(this.host.clientHeight / 2 - cameraY * this.scale));
    this.app.render();
  }

  setVisible(visible: boolean): void { if (this.ready) this.app.canvas.style.display = visible ? 'block' : 'none'; }
  destroy(): void {
    this.observer?.disconnect();
    if (this.ready) this.app.canvas.removeEventListener('pointerdown', this.pointerDown);
    if (this.ready) this.app.destroy({ removeView: true }, { children: true, context: true, style: true });
    this.ready = false;
  }
}
