import { Application, Assets, Container, Graphics, Sprite, Texture } from 'pixi.js';
import { characters } from '../data/characters';
import { GUILD_ROOM, guildPoints, type GuildFacilityId, type GuildPointId } from '../data/guild';
import { images } from '../data/images';
import type { MetaState } from '../state/MetaState';
import type { GuildPosition } from '../systems/GuildSystem';

interface Member { id: string; rider: GuildRider; x: number; y: number; previousX: number; previousY: number }
interface Fixture { id: string; sprite: Sprite }

const fixtureVisuals: Record<GuildPointId, { width: number; anchorY: number; shadowX: number; shadowY: number; shadowWidth: number; shadowDepth: number }> = {
  training: { width: 174, anchorY: 1, shadowX: 0, shadowY: -7, shadowWidth: 76, shadowDepth: 10 },
  recovery: { width: 174, anchorY: 1, shadowX: 13, shadowY: -6, shadowWidth: 54, shadowDepth: 8 },
  supply: { width: 174, anchorY: 1, shadowX: 4, shadowY: -5, shadowWidth: 58, shadowDepth: 8 },
  gate: { width: 120, anchorY: 0.94, shadowX: -12, shadowY: -4, shadowWidth: 39, shadowDepth: 6 },
  roster: { width: 104, anchorY: 0.96, shadowX: -4, shadowY: -4, shadowWidth: 40, shadowDepth: 6 },
};

/** The guild uses compact pixel riders; combat retains its separate full-size art. */
class GuildRider {
  readonly root = new Container();
  private readonly body = new Container();
  private readonly shadow = new Graphics().ellipse(0, 0, 31, 9).fill({ color: 0x02080e, alpha: 0.34 });
  private readonly wake = new Graphics();
  private phase = 0;
  private movement = 0;
  private facing = 1;

  constructor(characterId: string) {
    const art = characterId === 'kangTaehoon' ? images.guildKangPixel : images.guildSongPixel;
    const sprite = new Sprite(Texture.from(art.url));
    sprite.anchor.set(0.5, 0.95);
    sprite.width = 132;
    sprite.height = 132;
    sprite.texture.source.scaleMode = 'nearest';
    this.body.addChild(sprite);
    this.root.addChild(this.shadow, this.wake, this.body);
  }

  update(x: number, y: number, dx: number, dy: number, dt: number): void {
    this.root.position.set(x, y);
    this.root.zIndex = y;
    const speed = Math.min(1, Math.hypot(dx, dy));
    this.movement += (speed - this.movement) * Math.min(1, dt * 10);
    if (Math.abs(dx) > 0.05) this.facing = Math.sign(dx);
    if (speed > 0.02) this.phase += dt * (6.5 + speed * 2.3);
    this.body.scale.x = this.facing;
    this.body.rotation = dx * 0.032 + Math.sin(this.phase) * 0.012 * this.movement;
    this.body.position.set(Math.sin(this.phase) * 0.9 * this.movement,
      -Math.abs(Math.sin(this.phase)) * 2.2 * this.movement);
    this.shadow.scale.x = 1 + Math.abs(Math.sin(this.phase)) * 0.05 * this.movement;
    this.shadow.alpha = 1 - Math.abs(Math.sin(this.phase)) * 0.16 * this.movement;
    this.wake.clear();
    if (this.movement > 0.12) {
      const drift = 9 + Math.sin(this.phase * 2) * 3;
      const behind = dx < -0.05 ? 29 : -29;
      this.wake.rect(behind, -2, 5, 3).fill({ color: 0x88bdca, alpha: 0.4 * this.movement });
      this.wake.rect(behind - this.facing * drift, 2, 3, 2)
        .fill({ color: 0xa3c6d0, alpha: 0.22 * this.movement });
    }
  }
}

/** Image-layered headquarters; combat keeps its existing Pixi renderer. */
export class GuildRenderer {
  private readonly app = new Application();
  private readonly room = new Container();
  private readonly actors = new Container();
  private readonly members: Member[] = [];
  private readonly fixtures: Fixture[] = [];
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
      background: 0x14212b });
    this.app.ticker.stop();
    const ids = ['guildHall', 'guildForeground', 'guildTraining', 'guildRecovery', 'guildSupply',
      'lobbyGate', 'lobbyAwakener', 'guildSongPixel', 'guildKangPixel'] as const;
    await Promise.all(ids.map(id => Assets.load(images[id].url)));
    this.app.canvas.className = 'guild-canvas';
    this.app.canvas.setAttribute('aria-label', '수탐자 길드 본부');
    host.appendChild(this.app.canvas);
    this.room.addChild(this.makeBackground());
    this.actors.sortableChildren = true;
    this.room.addChild(this.actors);
    const railing = new Sprite(Texture.from(images.guildForeground.url));
    railing.width = GUILD_ROOM.width;
    railing.height = GUILD_ROOM.height;
    this.room.addChild(railing);
    this.app.stage.addChild(this.room);
    this.makeFixtures();
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

  private makeFixtures(): void {
    for (const point of guildPoints) {
      const art = new Container();
      const visual = fixtureVisuals[point.id];
      const shadow = new Graphics()
        .ellipse(visual.shadowX, visual.shadowY, visual.shadowWidth + 5, visual.shadowDepth + 3)
        .fill({ color: 0x020810, alpha: 0.07 })
        .ellipse(visual.shadowX, visual.shadowY, visual.shadowWidth, visual.shadowDepth)
        .fill({ color: 0x020810, alpha: 0.18 });
      const sprite = new Sprite(Texture.from(images[point.art].url));
      sprite.anchor.set(0.5, visual.anchorY);
      sprite.width = visual.width;
      sprite.height = visual.width * sprite.texture.height / sprite.texture.width;
      art.position.set(point.x, point.y);
      art.zIndex = point.y;
      art.addChild(shadow, sprite);
      this.actors.addChild(art);
      this.fixtures.push({ id: point.id, sprite });
    }
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
    for (const fixture of this.fixtures) {
      const level = meta.guild.facilityLevels[fixture.id as GuildFacilityId] ?? 0;
      fixture.sprite.tint = level > 0 ? 0xffffff : 0xb6c3c8;
    }
    const visibleWidth = this.host.clientWidth / this.scale;
    const visibleHeight = this.host.clientHeight / this.scale;
    const cameraX = Math.max(visibleWidth / 2, Math.min(GUILD_ROOM.width - visibleWidth / 2, position.x));
    const cameraY = Math.max(visibleHeight / 2, Math.min(GUILD_ROOM.height - visibleHeight / 2, position.y));
    this.room.position.set(this.host.clientWidth / 2 - cameraX * this.scale,
      this.host.clientHeight / 2 - cameraY * this.scale);
    this.app.render();
  }

  setVisible(visible: boolean): void { if (this.ready) this.app.canvas.style.display = visible ? 'block' : 'none'; }
  destroy(): void {
    this.observer?.disconnect();
    if (this.ready) this.app.destroy({ removeView: true }, { children: true, context: true, style: true });
    this.ready = false;
  }
}
