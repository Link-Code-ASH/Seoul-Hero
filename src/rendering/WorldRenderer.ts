import { Application, Container, Graphics, Sprite } from 'pixi.js';
import { ENEMY_RULES } from '../data/enemyConfig';
import { enemies } from '../data/enemies';
import { GAME_CONFIG } from '../data/config';
import { maps } from '../data/maps';
import { WORLD_THEME } from '../data/worldTheme';
import type { Visual } from '../data/types';
import type { RunState } from '../state/RunState';
import type { WorldViewport } from '../world/Arena';
import { Camera } from './Camera';
import { EntitySprites } from './EntitySprites';
import { ImageAssets } from './ImageAssets';
import { PlayerMotion } from './PlayerMotion';
import { drawWeaponEffects } from './WeaponEffects';
import { drawAreaIndicator } from './AreaIndicator';
import { weapons } from '../data/weapons';
import { weaponStats } from '../systems/CombatSystem';
import { WEAPON_CONFIG } from '../data/weaponConfig';
import type { Enemy } from '../entities/types';
import { CombatVfx } from './CombatVfx';
import { enemyPose, groundProfileFor } from './CombatArt';
import { MAGIC_STONE_TIERS } from '../data/magicStoneConfig';
import { enemyPresentation, fallbackEnemyPresentation } from '../data/enemyPresentation';

const magicStoneVisual: Visual = { color: 0xcbb8ff, shape: 'diamond', sprite: 'magicStone' };
const hostileVisual: Visual = { color: 0xff5967, shape: 'triangle', sprite: 'hostileBolt' };
const theme = WORLD_THEME.neighborhood;

/** Pixi is an output layer only: it reads game state but never changes game rules. */
export class WorldRenderer {
  readonly camera = new Camera();
  readonly viewport: WorldViewport = { width: GAME_CONFIG.world.referenceWidth, height: GAME_CONFIG.world.referenceHeight };
  private readonly app = new Application();
  private readonly world = new Container();
  private readonly arenaBase = new Container();
  private readonly backgrounds = new Container();
  private readonly shadows = new Graphics();
  private readonly vfxBack = new Graphics();
  private readonly actors = new Container();
  private readonly markings = new Graphics();
  private readonly vfxGlow = new Graphics();
  private readonly vfxFront = new Graphics();
  private readonly combatVfx = new CombatVfx(this.vfxBack, this.vfxGlow, this.vfxFront);
  readonly art = new ImageAssets();
  readonly playerMotion = new PlayerMotion();
  private sceneryKey = '';
  private readonly arenaMask = new Graphics();
  private readonly boundary = new Graphics();
  private sprites: EntitySprites | null = null;
  private host: HTMLElement | null = null;
  private resizeObserver: ResizeObserver | null = null;
  private highResolution = true;
  private initialized = false;
  private displayTime = 0;
  private scale = 1;
  private currentMapId = 'seoul';
  private readonly enemyFacing = new Map<number, { x: number; facing: -1 | 1 }>();


  async init(host: HTMLElement): Promise<void> {
    this.host = host;
    await this.app.init({
      preference: 'webgl',
      preferWebGLVersion: 2,
      background: theme.ground,
      autoStart: false,
      antialias: true,
      autoDensity: true,
      resolution: this.resolution,
      width: Math.max(1, host.clientWidth),
      height: Math.max(1, host.clientHeight),
      powerPreference: 'high-performance',
    });
    this.app.ticker.stop();
    await this.art.load();
    host.appendChild(this.app.canvas);
    this.app.canvas.setAttribute('aria-label', '서울 히어로 게임 월드');
    this.app.canvas.style.display = 'block';
    this.app.stage.addChild(this.world);
    this.vfxGlow.blendMode = 'add';
    this.actors.sortableChildren = true;
    this.world.addChild(this.arenaBase, this.backgrounds, this.arenaMask, this.boundary, this.shadows, this.vfxBack, this.actors, this.markings, this.vfxGlow, this.vfxFront);
    this.arenaBase.mask = this.arenaMask;
    this.backgrounds.mask = this.arenaMask;
    this.actors.mask = this.arenaMask;
    this.shadows.mask = this.arenaMask;
    this.vfxBack.mask = this.arenaMask;
    this.markings.mask = this.arenaMask;
    this.vfxGlow.mask = this.arenaMask;
    this.vfxFront.mask = this.arenaMask;
    this.sprites = new EntitySprites(this.app.renderer, this.actors, this.art);
    this.initialized = true;
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(host);
    this.resize();
    this.render(null, 0);
  }

  private get resolution(): number {
    return this.highResolution ? Math.min(window.devicePixelRatio || 1, theme.maxDpr) : 1;
  }

  setHighResolution(enabled: boolean): void {
    this.highResolution = enabled;
    if (this.initialized) this.resize();
  }

  private resize(): void {
    if (!this.host) return;
    const width = Math.max(1, this.host.clientWidth);
    const height = Math.max(1, this.host.clientHeight);
    this.app.renderer.resize(width, height, this.resolution);
    const stage = maps[this.currentMapId] ?? maps.seoul!;
    this.scale = Math.max(width / stage.arenaWidth, height / stage.arenaHeight) * GAME_CONFIG.world.combatZoom;
    this.viewport.width = width / this.scale;
    this.viewport.height = height / this.scale;
    this.world.scale.set(this.scale);
  }

  render(state: RunState | null, delta: number): void {
    if (!this.initialized || !this.sprites) return;
    this.displayTime += Math.min(delta, GAME_CONFIG.time.maxFrameDelta);
    const stage = maps[state?.mapId ?? 'seoul']!;
    this.currentMapId = stage.id;
    const width = this.app.screen.width, height = this.app.screen.height;
    // Fill the display and zoom into the fight. The camera follows the player,
    // so cropping the larger arena never hides an unreachable part of the map.
    this.scale = Math.max(width / stage.arenaWidth, height / stage.arenaHeight) * GAME_CONFIG.world.combatZoom;
    this.viewport.width = width / this.scale; this.viewport.height = height / this.scale; this.world.scale.set(this.scale);
    if (state) this.camera.follow(state.player, this.viewport, stage);
    else { this.camera.x = 0; this.camera.y = 0; }
    const sceneryKey = [stage.id, stage.arenaWidth, stage.arenaHeight, stage.seed, stage.backgroundTheme].join(':');
    if (this.sceneryKey !== sceneryKey) { this.sceneryKey = sceneryKey; this.createArena(stage); }
    this.world.position.set(
      this.app.screen.width / 2 - this.camera.x * this.scale,
      this.app.screen.height / 2 - this.camera.y * this.scale,
    );
    this.markings.clear();
    this.combatVfx.begin();
    this.sprites.begin();
    if (state) { this.playerMotion.update(state, delta); this.drawEntities(state); }
    this.sprites.end();
    this.app.render();
  }

  getWalletWorldTarget(): { x: number; y: number } {
    return {
      x: -this.viewport.width / 2 + 178 / Math.max(this.scale, 0.001),
      y: -this.viewport.height / 2 + 92 / Math.max(this.scale, 0.001),
    };
  }

  clientToWorld(point: { x: number; y: number }): { x: number; y: number } {
    const bounds = this.app.canvas.getBoundingClientRect();
    return {
      x: (point.x - bounds.left - this.world.position.x) / Math.max(this.scale, 0.001),
      y: (point.y - bounds.top - this.world.position.y) / Math.max(this.scale, 0.001),
    };
  }

  worldToClient(point: { x: number; y: number }): { x: number; y: number } {
    const bounds = this.app.canvas.getBoundingClientRect();
    return {
      x: bounds.left + this.world.position.x + point.x * this.scale,
      y: bounds.top + this.world.position.y + point.y * this.scale,
    };
  }

  private createArena(stage: import('../data/types').MapData): void {
    for (const child of this.arenaBase.removeChildren()) child.destroy({ children: true, context: true, style: true });
    for (const child of this.backgrounds.removeChildren()) child.destroy({ children: true, context: true, style: true });
    const baseTexture = this.art.get('seoulIntersection');
    if (baseTexture) {
      this.arenaBase.addChild(new Graphics().rect(-stage.arenaWidth / 2, -stage.arenaHeight / 2, stage.arenaWidth, stage.arenaHeight).fill(0x69757d));
      const base = new Sprite(baseTexture);
      base.anchor.set(0.5);
      base.width = stage.arenaWidth;
      base.height = stage.arenaHeight;
      // Keep Seoul visible but deliberately subdued so combat silhouettes read first.
      base.alpha = 0.86;
      this.arenaBase.addChild(base);
    }
    // The new painted arena already contains the city scenery. Keep decoration data for
    // later maps, but do not layer stores, trees, or subway props over this map.
    if (!baseTexture) this.arenaBase.addChild(new Graphics().rect(-stage.arenaWidth / 2, -stage.arenaHeight / 2, stage.arenaWidth, stage.arenaHeight).fill(0x84939f));
    this.arenaMask.clear().rect(-stage.arenaWidth / 2, -stage.arenaHeight / 2, stage.arenaWidth, stage.arenaHeight).fill(0xffffff);
    this.boundary.clear().rect(-stage.arenaWidth / 2 + 5, -stage.arenaHeight / 2 + 5, stage.arenaWidth - 10, stage.arenaHeight - 10).stroke({ color: 0x75e6df, width: 10, alpha: 0.5 });
  }

  private drawEntities(state: RunState): void {
    const sprites = this.sprites!;
    const player = state.player;
    const motion = this.playerMotion;
    this.shadows.clear();
    const activeEnemyIds = new Set(state.enemies.map(enemy => enemy.id));
    for (const id of this.enemyFacing.keys()) if (!activeEnemyIds.has(id)) this.enemyFacing.delete(id);
    const visibleEnemies = state.enemies.filter(enemy => this.camera.sees(enemy, enemy.radius * 3, this.viewport));
    const enemyDraw = visibleEnemies.map(enemy => {
      const appearance = this.enemyMotion(enemy, state.stageCombatTime);
      const ground = groundProfileFor(enemy.visual.sprite);
      const previous = this.enemyFacing.get(enemy.id);
      let facing: -1 | 1 = previous?.facing ?? (player.x < enemy.x ? -1 : 1);
      const dx = enemy.x - (previous?.x ?? enemy.x);
      if (Math.abs(dx) > .08) facing = dx < 0 ? -1 : 1;
      if (enemy.action === 'warning' && Math.abs(enemy.aimX - enemy.x) > .5) facing = enemy.aimX < enemy.x ? -1 : 1;
      this.enemyFacing.set(enemy.id, { x: enemy.x, facing });
      const footY = enemy.y + enemy.radius * ground.groundOffset;
      const lift = Math.max(0, -appearance.bobY);
      const liftRatio = Math.min(1, lift / Math.max(1, enemy.radius * .6));
      const dashStretch = enemy.action === 'dash' ? 1.18 : 1;
      const width = enemy.radius * ground.shadowWidth * appearance.shadowScale * dashStretch;
      const depth = enemy.radius * ground.shadowDepth * appearance.shadowScale / dashStretch;
      const alpha = ground.shadowAlpha * enemy.alpha * (1 - liftRatio * .48);
      this.shadows.ellipse(enemy.x, footY, width * 1.25, depth * 1.55)
        .fill({ color: ground.shadowColor, alpha: alpha * .3 });
      this.shadows.ellipse(enemy.x, footY, width, depth)
        .fill({ color: ground.shadowColor, alpha });
      return { enemy, appearance, ground, footY, facing };
    });
    for (const structure of state.structures) {
      const kind = weapons[structure.weaponId]?.structure?.kind;
      if (!kind) continue;
      if (kind === 'turret') {
        // The turret sprite has a centered pedestal. One tight contact shadow keeps it
        // grounded without the offset/doubled silhouette used by the older tripod art.
        this.shadows.ellipse(structure.x, structure.y + 24, 23, 6.5)
          .fill({ color: 0x020306, alpha: 0.34 });
        continue;
      }
      if (kind === 'mine') {
        this.shadows.ellipse(structure.x, structure.y + 10, 18, 4.5)
          .fill({ color: 0x020306, alpha: 0.4 });
        continue;
      }
      this.shadows.ellipse(structure.x + 3, structure.y + 15, 31, 9)
        .fill({ color: 0x030407, alpha: 0.4 });
      this.shadows.ellipse(structure.x + 2, structure.y + 14, 31 * 0.68, 9 * 0.6)
        .fill({ color: 0x010203, alpha: 0.3 });
    }
    for (const pickup of state.pickups) {
      const tier = MAGIC_STONE_TIERS[pickup.tier ?? 1];
      this.shadows.ellipse(pickup.x + 1.5, pickup.y + pickup.radius * 1.12,
        pickup.radius * 0.82 * tier.scale, pickup.radius * 0.28 * tier.scale)
        .fill({ color: 0x080611, alpha: 0.3 });
    }
    const truck = player.visual.motionStyle === 'truck';
    const playerGround = groundProfileFor(player.visual.sprite);
    const playerFootY = player.y + player.radius * playerGround.groundOffset;
    const playerShadowWidth = player.radius * playerGround.shadowWidth * motion.shadowScale;
    const playerShadowDepth = player.radius * playerGround.shadowDepth * motion.shadowScale;
    this.shadows.ellipse(player.x, playerFootY, playerShadowWidth * 1.24, playerShadowDepth * 1.55)
      .fill({ color: playerGround.shadowColor, alpha: motion.shadowAlpha * .35 });
    this.shadows.ellipse(player.x, playerFootY, playerShadowWidth, playerShadowDepth)
      .fill({ color: playerGround.shadowColor, alpha: motion.shadowAlpha });
    if (motion.magicLag > .08) {
      const trail = Math.min(18, 6 + motion.magicLag * 12);
      const back = player.x - motion.facing * player.radius * .55;
      const color = truck ? 0x72969d : 0x55b9b3;
      for (const track of truck ? [-5, 5] : [0]) {
        this.shadows.moveTo(back, playerFootY + track)
          .lineTo(back - motion.facing * trail, playerFootY + track + 1.5)
          .stroke({ color, alpha: motion.magicLag * (truck ? .23 : .3), width: truck ? 1.8 : 1.3 });
      }
    }
    drawWeaponEffects(this.markings, state);
    for (const structure of state.structures) {
      const weapon = weapons[structure.weaponId];
      const sprite = weapon?.structure?.sprite;
      if (sprite && this.camera.sees(structure, 40, this.viewport)) {
        if (weapon.structure?.kind === 'aura') {
          const slot = state.ownedWeapons.find(entry => entry.id === weapon.id);
          const radius = (slot ? weaponStats(weapon, slot.level, state).blastRadius : weapon.base.blastRadius) ?? 0;
          const pulse = 0.5 + Math.sin(state.stageCombatTime * 2.1 + structure.id) * 0.5;
          sprites.drawImage(structure.x, structure.y, radius * 2.08, radius * 2.08, 'manaFieldAura', 0.23 + pulse * 0.08, state.stageCombatTime * 0.165);
          sprites.drawImage(structure.x, structure.y, radius * 1.62, radius * 1.62, 'manaFieldAura', 0.12 + (1 - pulse) * 0.06, -state.stageCombatTime * 0.27);
        }
        const size = weapon?.structure?.kind === 'turret' ? 70 : weapon?.structure?.kind === 'aura' ? 66 : 54;
        sprites.drawImage(structure.x, structure.y, size, size, sprite, 0.92);
      }
    }
    for (const effect of state.effects) {
      if (this.combatVfx.draw(effect, sprites)) continue;
    }
    for (const slot of state.ownedWeapons) {
      const weapon = weapons[slot.id];
      if (!weapon?.visual.sprite || weapon.behavior !== 'orbit') continue;
      const stats = weaponStats(weapon, slot.level, state);
      for (let i = 0; i < stats.projectileCount; i++) {
        const angle = state.stageCombatTime * WEAPON_CONFIG.orbitAngularSpeed + i * Math.PI * 2 / stats.projectileCount;
        const x = state.player.x + Math.cos(angle) * stats.range;
        const y = state.player.y + Math.sin(angle) * stats.range;
        // Each four-bladed shuriken spins while its center follows the orbit.
        sprites.drawImage(x, y, 33 * stats.areaScale, 33 * stats.areaScale, weapon.visual.sprite,
          1, state.stageCombatTime * WEAPON_CONFIG.shurikenSpinSpeed + angle);
      }
    }
    for (const pickup of state.pickups) {
      if (this.camera.sees(pickup, pickup.radius, this.viewport)) {
        const tier = MAGIC_STONE_TIERS[pickup.tier ?? 1];
        sprites.draw(pickup.x, pickup.y, pickup.radius, magicStoneVisual, 'pickup', 1, 0, false, undefined, 1, undefined, {
          scaleX: tier.scale,
          scaleY: tier.scale,
          tint: tier.tint,
        });
      }
    }
    for (const { enemy, appearance: enemyMotion, ground, footY, facing } of enemyDraw) {
      const behavior = enemies[enemy.definitionId]?.behavior;
      const charging = behavior === 'charge' && enemy.action === 'warning';
      const healing = enemy.definitionId === 'mender' && enemy.timer > ENEMY_RULES.supportInterval - .28;
      const summoning = enemy.definitionId === 'summoner' && enemy.timer > ENEMY_RULES.summonInterval - .36;
      const chargePulse = 0.5 + Math.sin(this.displayTime * 18 + enemy.id) * 0.5;
      const castPulse = 1 + (healing || summoning ? .045 * (1 + Math.sin(this.displayTime * 21)) : 0);
      sprites.draw(enemy.x, enemy.y, enemy.radius, enemy.visual, 'enemy', enemy.alpha, enemyMotion.rotation, enemy.hitFlash > 0, undefined, facing, undefined, {
        spriteId: enemyPose(enemy, -enemyMotion.bobY),
        groundY: footY,
        anchorY: ground.anchorY,
        offsetX: enemyMotion.swayX,
        offsetY: enemyMotion.bobY,
        scaleX: enemyMotion.scaleX * castPulse,
        scaleY: enemyMotion.scaleY * castPulse,
        tint: charging ? (chargePulse > 0.52 ? 0xffe0d8 : 0xffac9a)
          : healing ? 0xc7ffe0 : summoning ? 0xe3caff : 0xffffff,
      });
      if (enemy.action === 'warning' && behavior !== 'ranged' && behavior !== 'charge') {
        if (behavior === 'bomber') {
          const pulse = 0.5 + Math.sin(this.displayTime * 7) * 0.5;
          this.markings.circle(enemy.x, enemy.y, ENEMY_RULES.bomberRadius).fill({ color: 0xff604d, alpha: 0.11 + pulse * 0.07 });
          this.markings.circle(enemy.x, enemy.y, ENEMY_RULES.bomberRadius * 0.68).fill({ color: 0xff8a62, alpha: 0.035 + pulse * 0.025 });
        }
      }
      if (enemy.boss || enemy.elite) {
        const width = enemy.radius * 2;
        const y = enemy.y - enemy.radius - 19;
        this.markings.roundRect(enemy.x - width / 2, y, width, 5, 2).fill({ color: 0x0d151a, alpha: 0.9 });
        const hpWidth = width * Math.max(0, enemy.hp / enemy.maxHp);
        if (hpWidth > 0) this.markings.rect(enemy.x - width / 2, y, hpWidth, 5).fill(enemy.elite && !enemy.boss ? 0xd8ae58 : enemy.visual.color);
        if (enemy.elite && !enemy.boss) this.markings.poly([
          enemy.x, y - 8, enemy.x + 4, y - 4, enemy.x, y, enemy.x - 4, y - 4,
        ]).fill({ color: 0xf0ca73, alpha: 0.92 });
      }
    }
    for (const projectile of state.projectiles) {
      if (this.camera.sees(projectile, projectile.radius, this.viewport)) {
        this.combatVfx.projectileTrail(projectile);
        if(projectile.fromStructure){const a=Math.atan2(projectile.vy,projectile.vx);this.markings.moveTo(projectile.x-Math.cos(a)*18,projectile.y-Math.sin(a)*18).lineTo(projectile.x,projectile.y).stroke({color:0xa7efff,width:3});}
        sprites.draw(projectile.x, projectile.y, projectile.radius, projectile.visual, 'projectile', 1, Math.atan2(projectile.vy, projectile.vx));
      }
    }
    for (const p of state.hostileProjectiles) if (this.camera.sees(p, p.radius, this.viewport)) sprites.draw(p.x, p.y, p.radius, hostileVisual, 'projectile', 1, Math.atan2(p.vy, p.vx));
    for (const h of state.hazards) {
      if (!this.camera.sees(h, h.radius, this.viewport)) continue;
      drawAreaIndicator(this.markings,h.x,h.y,h.radius,0xff846c,state.stageCombatTime,h.triggered);
      if(h.triggered) this.combatVfx.hazardBlast(h.x, h.y, h.radius, h.remaining, sprites);
    }
    if (motion.magicLag > 0 && !truck) {
      const railY = player.y + player.radius * 1.22;
      this.markings.moveTo(player.x - motion.facing * player.radius * 0.15, railY)
        .lineTo(player.x - motion.facing * player.radius * (1.25 + motion.magicLag * 0.55), railY + motion.dragY)
        .stroke({ color: 0x54f1cf, width: 3.2, alpha: motion.magicLag * 0.18 });
      this.markings.moveTo(player.x - motion.facing * player.radius * 0.45, railY + 3)
        .lineTo(player.x - motion.facing * player.radius * (1.05 + motion.magicLag * 0.35), railY + 4)
        .stroke({ color: 0xa4ffe8, width: 1.2, alpha: motion.magicLag * 0.22 });
      const handX = player.x - motion.facing * player.radius * 1.05;
      const handY = player.y - player.radius * 0.08;
      for (let i = 1; i <= 3; i++) {
        this.markings.circle(handX + motion.dragX * i * 2.2, handY + motion.dragY * i * 2.2, 3.2 - i * 0.55)
          .fill({ color: 0x72ffb1, alpha: motion.magicLag * (0.13 - i * 0.025) });
      }
    }
    const blink = player.invulnerability > 0 ? 0.55 + Math.sin(this.displayTime * 45) * 0.3 : 1;
    sprites.draw(player.x, player.y, player.radius, player.visual, 'player', blink, motion.lean * (truck ? 0.42 : 1), false, undefined, motion.facing, undefined, {
      groundY: playerFootY,
      anchorY: playerGround.anchorY,
      offsetX: (motion.swayX + motion.dragX) * (truck ? 0.45 : 1),
      offsetY: (motion.bobY + motion.dragY) * (truck ? 0.4 : 1),
      scaleX: 1 + (motion.scaleX - 1) * (truck ? 0.35 : 1),
      scaleY: 1 + (motion.scaleY - 1) * (truck ? 0.35 : 1),
      skewX: motion.dragSkew * (truck ? 0.3 : 1),
    });
  }

  /** A presentation-only pulse: no position, collision, or enemy AI is changed. */
  private enemyMotion(enemy: Enemy, combatTime: number): { bobY: number; swayX: number; rotation: number; scaleX: number; scaleY: number; shadowScale: number } {
    const profile = enemyPresentation[enemy.definitionId] ?? fallbackEnemyPresentation;
    const active = enemy.action === 'move' || enemy.action === 'dash' ? 1 : 0.28;
    const dash = enemy.action === 'dash' ? 1.65 : 1;
    const phase = combatTime * (profile.frequency + Math.min(enemy.moveSpeed, 180) * 0.006) * dash + enemy.id * 1.71;
    const stride = Math.sin(phase);
    const contact = Math.max(0, Math.cos(phase * 2)) * active;
    let lift = Math.max(0, stride) * Math.min(profile.bob, enemy.radius * 0.12) * active;
    let sway = Math.sin(phase * .5) * Math.min(profile.sway, enemy.radius * .1) * active;
    let rotation = Math.sin(phase * .5) * profile.roll * active;
    let scaleX = 1 + contact * profile.squash;
    let scaleY = 1 - contact * profile.squash * .82;
    let shadowLift = Math.abs(stride) * Math.min(.16, profile.bob * .038) * active;

    if (profile.mode === 'crawl') { lift = Math.max(0,stride) * profile.bob * .55 * active; sway *= .65; rotation += Math.sin(phase) * .008; }
    if (profile.mode === 'pounce') { lift = Math.max(0,stride) * Math.min(4, enemy.radius * .3) * active; scaleX += Math.max(0,-stride) * .035; scaleY -= Math.max(0,-stride) * .025; }
    if (profile.mode === 'stomp' || profile.mode === 'bossStomp') { lift = Math.max(0,stride) * profile.bob * active; sway = Math.sin(phase) * profile.sway * active; rotation *= .35; shadowLift *= .45; }
    if (profile.mode === 'aim') { lift *= .45; sway = Math.sin(phase * .7) * profile.sway * active; rotation += enemy.action === 'warning' ? -.025 : 0; }
    if (profile.mode === 'skitter') { lift = Math.abs(stride) * profile.bob * active; sway += Math.sin(phase * 2.3) * .55 * active; rotation += Math.sin(phase * 1.7) * .018 * active; }
    if (profile.mode === 'charge') { rotation *= .45; scaleX += enemy.action === 'dash' ? .075 : 0; scaleY -= enemy.action === 'dash' ? .045 : enemy.action === 'warning' ? .055 : 0; lift *= enemy.action === 'warning' ? .2 : 1; }
    if (profile.mode === 'pulse') { lift *= .55; const pulse=Math.sin(phase*.8)*profile.squash*active; scaleX+=pulse;scaleY-=pulse*.7; }
    if (profile.mode === 'ooze') { lift = Math.max(0, Math.sin(phase)) * Math.min(6, enemy.radius * .3) * active; const ooze=Math.sin(phase*.72)*profile.squash*active; scaleX+=ooze;scaleY-=ooze*.8;sway+=Math.sin(phase*.31)*.65;shadowLift=Math.min(.27,lift/enemy.radius); }
    if (profile.mode === 'float' || profile.mode === 'queenFloat') { lift=1+Math.max(0,Math.sin(phase*.6))*(profile.mode === 'queenFloat' ? 1.5 : 1);sway=Math.sin(phase*.58)*profile.sway;rotation=Math.sin(phase*.42)*profile.roll;scaleX=1+Math.sin(phase*.6)*profile.squash;scaleY=1-Math.sin(phase*.6)*profile.squash*.5;shadowLift=Math.min(.2,lift/enemy.radius); }
    if (profile.mode === 'brace') { lift=Math.max(0,stride)*profile.bob*.45*active;rotation*=.25;sway*=.3;if(enemy.action==='warning'){scaleX+=.045;scaleY-=.025;} }
    if (profile.mode === 'stalk') { lift=Math.abs(stride)*profile.bob*.55*active;sway=Math.sin(phase*.36)*profile.sway*active;rotation+=Math.sin(phase*1.25)*.016*active; }
    return {
      bobY: -lift,
      swayX: sway,
      rotation: rotation + (enemy.action === 'dash' ? Math.sin(phase) * .018 : 0),
      scaleX,
      scaleY,
      shadowScale: 1 - shadowLift,
    };
  }

  destroy(): void {
    this.resizeObserver?.disconnect();
    this.sprites?.destroy();
    this.art.destroy();
    if (this.initialized) this.app.destroy({ removeView: true }, { children: true, context: true, style: true });
    this.initialized = false;
    this.host = null;
  }
}
