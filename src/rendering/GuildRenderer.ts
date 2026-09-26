import { Application, Assets, BlurFilter, Container, Graphics, Sprite, Texture } from 'pixi.js';
import { characters } from '../data/characters';
import { GUILD_ROOM, guildPoints, type GuildPointId } from '../data/guild';
import { images, type ImageId } from '../data/images';
import { drawGroundedOvalShadow } from './ProjectedShadow';
import type { MetaState } from '../state/MetaState';
import type { GuildPosition } from '../systems/GuildSystem';

interface Member { id: string; rider: GuildRider; x: number; y: number; previousX: number; previousY: number }

const propSize: Record<GuildPointId, { width: number; height: number }> = {
  training: { width: 278, height: 232 },
  recovery: { width: 288, height: 190 },
  supply: { width: 286, height: 180 },
  gate: { width: 168, height: 160 },
  roster: { width: 183, height: 158 },
};

/** The guild reuses the same illustrated riders as combat. */
class GuildRider {
  readonly root = new Container();
  private readonly body = new Container();
  private readonly shadow = new Graphics();
  private readonly truck: boolean;
  private readonly artId: ImageId;
  private facing = 1;

  constructor(characterId: string) {
    this.truck = characterId === 'kangTaehoon';
    this.artId = this.truck ? 'kangTaehoonTruck' : 'player';
    const sprite = new Sprite(Texture.from(images[this.artId].url));
    sprite.anchor.set(0.5, this.truck ? .93 : .95);
    sprite.width = 142;
    sprite.height = 142;
    this.body.addChild(sprite);
    this.shadow.filters = [new BlurFilter({ strength: 4 })];
    this.root.addChild(this.shadow, this.body);
  }

  update(x: number, y: number, dx: number, dy: number, dt: number): void {
    this.root.position.set(Math.round(x), Math.round(y));
    this.root.zIndex = y;
    void dy;
    void dt;
    if (Math.abs(dx) > 0.05) this.facing = Math.sign(dx);
    this.body.scale.x = this.facing;
    this.body.rotation = 0;
    this.body.position.set(0, 0);
    this.shadow.clear();
    drawGroundedOvalShadow(this.shadow, this.artId, 0, 0, 142, 142,
      this.truck ? .93 : .95, 0x0d1319, .29, this.facing);
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
    const ids = ['guildHall', 'player', 'kangTaehoonTruck',
      'guildTraining', 'guildRecovery', 'guildSupply', 'guildRoster', 'guildGate'] as const;
    await Promise.all(ids.map(id => Assets.load(images[id].url)));
    this.app.canvas.className = 'guild-canvas';
    this.app.canvas.setAttribute('aria-label', '수탐자 길드 본부');
    host.appendChild(this.app.canvas);
    this.room.addChild(this.makeBackground());
    this.actors.sortableChildren = true;
    this.makeProps();
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

  private makeProps(): void {
    for (const point of guildPoints) {
      const size = propSize[point.id];
      const prop = new Container();
      prop.position.set(point.x, point.y);
      prop.zIndex = point.y;
      const contact = new Graphics();
      drawGroundedOvalShadow(contact, point.art, 0, 0, size.width, size.height,
        1, 0x0d1319, .23);
      contact.filters = [new BlurFilter({ strength: 5 })];
      const sprite = new Sprite(Texture.from(images[point.art].url));
      sprite.anchor.set(.5, 1);
      sprite.width = size.width;
      sprite.height = size.height;
      prop.addChild(contact, sprite);
      this.actors.addChild(prop);
    }
  }

  private makeMembers(meta: MetaState): void {
    const unlocked = Object.values(characters).filter(character => meta.characters[character.id]?.unlocked);
    unlocked.forEach((character, index) => {
      const x = 670 + index * 330;
      const y = 485 + index % 2 * 30;
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
    // Show part of the room at a time so the headquarters has navigable space.
    this.scale = Math.max(width / (GUILD_ROOM.width * .78), height / (GUILD_ROOM.height * .78));
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
    // Keep the rear workstations in view on short landscape phone screens.
    const cameraY = Math.max(visibleHeight / 2, Math.min(GUILD_ROOM.height - visibleHeight / 2, position.y - 155));
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
