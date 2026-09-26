import { Application, Assets, Container, Graphics, Sprite, Texture } from 'pixi.js';
import { characters } from '../data/characters';
import { GUILD_ROOM } from '../data/guild';
import { images } from '../data/images';
import type { MetaState } from '../state/MetaState';
import type { GuildPosition } from '../systems/GuildSystem';

interface Member { id: string; rider: GuildRider; x: number; y: number; previousX: number; previousY: number }

/** The guild uses compact pixel riders; combat retains its separate full-size art. */
class GuildRider {
  readonly root = new Container();
  private readonly body = new Container();
  private readonly shadow = new Graphics();
  private readonly truck: boolean;
  private phase = 0;
  private movement = 0;
  private facing = 1;

  constructor(characterId: string) {
    this.truck = characterId === 'kangTaehoon';
    const art = this.truck ? images.guildKangPixel : images.guildSongPixel;
    const sprite = new Sprite(Texture.from(art.url));
    sprite.anchor.set(0.5, 0.95);
    sprite.width = 132;
    sprite.height = 132;
    sprite.texture.source.scaleMode = 'nearest';
    this.body.addChild(sprite);
    this.root.addChild(this.shadow, this.body);
  }

  update(x: number, y: number, dx: number, dy: number, dt: number): void {
    // Pixel art needs a stable screen-space baseline: fractional positions and
    // sprite rotation make nearest-neighbour edges look like a trailing ghost.
    this.root.position.set(Math.round(x), Math.round(y));
    this.root.zIndex = y;
    const speed = Math.min(1, Math.hypot(dx, dy));
    this.movement += (speed - this.movement) * Math.min(1, dt * 7);
    if (Math.abs(dx) > 0.05) this.facing = Math.sign(dx);
    if (speed > 0.02) this.phase += dt * (5.2 + speed);
    this.body.scale.x = this.facing;
    this.body.rotation = 0;
    this.body.position.set(0, -Math.round(Math.abs(Math.sin(this.phase)) * this.movement));
    const lift = Math.max(0, -this.body.position.y);
    const width = (this.truck ? 43 : 32) * (1 - lift * 0.025);
    const depth = (this.truck ? 11 : 8) * (1 - lift * 0.035);
    this.shadow.clear()
      .ellipse(0, -4, width * 1.18, depth * 1.55)
      .fill({ color: 0x57463a, alpha: .24 })
      .ellipse(0, -4, width, depth)
      .fill({ color: 0x35271e, alpha: .46 - lift * .035 });
  }
}

/** Image-layered headquarters; combat keeps its existing Pixi renderer. */
export class GuildRenderer {
  private readonly app = new Application();
  private readonly room = new Container();
  private readonly actors = new Container();
  private readonly members: Member[] = [];
  private host: HTMLElement | null = null;
  private observer: ResizeObserver | null = null;
  private ready = false;
  private scale = 1;

  async init(host: HTMLElement, meta: MetaState): Promise<void> {
    if (this.ready) return;
    this.host = host;
    await this.app.init({ preference: 'webgl', antialias: true, autoStart: false,
      autoDensity: true, resolution: Math.min(window.devicePixelRatio || 1, 1.75),
      width: Math.max(1, host.clientWidth), height: Math.max(1, host.clientHeight),
      background: 0xe6d5be });
    this.app.ticker.stop();
    const ids = ['guildHall', 'guildSongPixel', 'guildKangPixel'] as const;
    await Promise.all(ids.map(id => Assets.load(images[id].url)));
    this.app.canvas.className = 'guild-canvas';
    this.app.canvas.setAttribute('aria-label', '수탐자 길드 본부');
    host.appendChild(this.app.canvas);
    this.room.addChild(this.makeBackground());
    this.actors.sortableChildren = true;
    this.room.addChild(this.actors);
    this.app.stage.addChild(this.room);
    this.makeMembers(meta);
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

  private makeMembers(meta: MetaState): void {
    const unlocked = Object.values(characters).filter(character => meta.characters[character.id]?.unlocked);
    unlocked.forEach((character, index) => {
      const x = 460 + index * 360;
      const y = 520 + index % 2 * 15;
      const rider = new GuildRider(character.id);
      rider.update(x, y, 0, 0, 0);
      this.actors.addChild(rider.root);
      this.members.push({ id: character.id, rider, x, y, previousX: x, previousY: y });
    });
  }

  private resize(): void {
    if (!this.ready || !this.host) return;
    const width = Math.max(1, this.host.clientWidth), height = Math.max(1, this.host.clientHeight);
    this.app.renderer.resize(width, height);
    this.scale = Math.max(width / GUILD_ROOM.width, height / GUILD_ROOM.height);
    this.room.scale.set(this.scale);
  }

  render(position: GuildPosition, meta: MetaState, dt: number): void {
    if (!this.ready || !this.host) return;
    const delta = Math.min(0.05, Math.max(0, dt));
    for (const member of this.members) {
      const controlled = member.id === meta.guild.avatarCharacterId;
      const x = controlled ? position.x : member.x;
      const y = controlled ? position.y : member.y;
      const dx = controlled && delta > 0 ? (x - member.previousX) / (GUILD_ROOM.speed * delta) : 0;
      const dy = controlled && delta > 0 ? (y - member.previousY) / (GUILD_ROOM.speed * delta) : 0;
      member.rider.update(x, y, dx, dy, delta);
      member.previousX = x; member.previousY = y;
    }
    const visibleWidth = this.host.clientWidth / this.scale;
    const visibleHeight = this.host.clientHeight / this.scale;
    const cameraX = Math.max(visibleWidth / 2, Math.min(GUILD_ROOM.width - visibleWidth / 2, position.x));
    const cameraY = Math.max(visibleHeight / 2, Math.min(GUILD_ROOM.height - visibleHeight / 2, position.y));
    this.room.position.set(Math.round(this.host.clientWidth / 2 - cameraX * this.scale),
      Math.round(this.host.clientHeight / 2 - cameraY * this.scale));
    this.app.render();
  }

  setVisible(visible: boolean): void { if (this.ready) this.app.canvas.style.display = visible ? 'block' : 'none'; }
  destroy(): void {
    this.observer?.disconnect();
    if (this.ready) this.app.destroy({ removeView: true }, { children: true, context: true, style: true });
    this.ready = false;
  }
}
