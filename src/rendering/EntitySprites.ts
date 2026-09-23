import { Graphics, Rectangle, Sprite, Texture } from 'pixi.js';
import type { Container, Renderer } from 'pixi.js';
import type { Visual } from '../data/types';
import { WORLD_THEME } from '../data/worldTheme';
import { images } from '../data/images';
import type { ImageId } from '../data/images';
import type { ImageAssets } from './ImageAssets';

export type SpriteRole = 'enemy' | 'player' | 'projectile' | 'pickup' | 'elite';
export interface SpriteTransform {
  offsetX?: number;
  offsetY?: number;
  scaleX?: number;
  scaleY?: number;
  skewX?: number;
  tint?: number;
}

/** Shares small generated textures and reuses display objects across entity lifetimes. */
export class EntitySprites {
  private readonly textures = new Map<string, Texture>();
  private readonly sprites: Sprite[] = [];
  private readonly masks: Graphics[] = [];
  private used = 0;
  private masksUsed = 0;

  constructor(private readonly renderer: Renderer, private readonly container: Container, private readonly art: ImageAssets) {}

  begin(): void { this.used = 0; this.masksUsed = 0; }

  draw(x: number, y: number, radius: number, visual: Visual, role: SpriteRole, alpha = 1, rotation = 0, flash = false, animatedTexture?: Texture, facing = 1, heightRatio?: number, transform: SpriteTransform = {}): void {
    const key = `${visual.shape}:${role}:${visual.motif??''}`;
    const imageTexture = animatedTexture ?? (visual.sprite ? this.art.get(visual.sprite) : undefined);
    let texture = imageTexture ?? this.textures.get(key);
    if (!texture) {
      texture = this.createTexture(visual.shape, role, visual.motif);
      this.textures.set(key, texture);
    }
    let sprite = this.sprites[this.used];
    if (!sprite) {
      sprite = new Sprite(texture);
      sprite.anchor.set(0.5);
      this.sprites.push(sprite);
      this.container.addChild(sprite);
    }
    this.used++;
    sprite.mask = null;
    sprite.texture = texture;
    sprite.position.set(x + (transform.offsetX ?? 0), y + (transform.offsetY ?? 0));
    if (imageTexture && visual.sprite) {
      const height = radius * (heightRatio ?? images[visual.sprite].heightRatio);
      sprite.scale.set(height / imageTexture.height * facing * (transform.scaleX ?? 1), height / imageTexture.height * (transform.scaleY ?? 1));
    } else sprite.scale.set(radius / 20);
    sprite.rotation = rotation;
    sprite.skew.set(transform.skewX ?? 0, 0);
    sprite.tint = flash ? (imageTexture ? 0xffcaca : 0xffffff) : (transform.tint ?? (imageTexture ? 0xffffff : visual.color));
    sprite.alpha = alpha;
    sprite.visible = true;
  }

  drawImage(x: number, y: number, width: number, height: number, imageId: ImageId, alpha = 1, rotation = 0): void {
    const texture = this.art.get(imageId);
    if (!texture) return;
    let sprite = this.sprites[this.used];
    if (!sprite) {
      sprite = new Sprite(texture);
      sprite.anchor.set(0.5);
      this.sprites.push(sprite);
      this.container.addChild(sprite);
    }
    this.used++;
    sprite.mask = null;
    sprite.texture = texture;
    sprite.position.set(x, y);
    sprite.width = width;
    sprite.height = height;
    sprite.rotation = rotation;
    sprite.skew.set(0, 0);
    sprite.tint = 0xffffff;
    sprite.alpha = alpha;
    sprite.visible = true;
  }

  /** Reveals an image through an invisible clockwise sector mask. */
  drawImageSector(x: number, y: number, width: number, height: number, imageId: ImageId,
    alpha: number, rotation: number, arc: number, reveal: number): void {
    const texture = this.art.get(imageId);
    if (!texture || reveal <= 0) return;
    let sprite = this.sprites[this.used];
    if (!sprite) {
      sprite = new Sprite(texture);
      sprite.anchor.set(0.5);
      this.sprites.push(sprite);
      this.container.addChild(sprite);
    }
    this.used++;
    sprite.texture = texture;
    sprite.position.set(x, y);
    sprite.width = width;
    sprite.height = height;
    sprite.rotation = rotation;
    sprite.skew.set(0, 0);
    sprite.tint = 0xffffff;
    sprite.alpha = alpha;
    sprite.visible = true;

    let mask = this.masks[this.masksUsed];
    if (!mask) {
      mask = new Graphics();
      this.masks.push(mask);
      this.container.addChild(mask);
    }
    this.masksUsed++;
    mask.clear();
    mask.visible = true;
    const safeArc = Math.max(0.01, Math.min(Math.PI * 2, arc));
    const shownArc = safeArc * Math.max(0, Math.min(1, reveal));
    const start = rotation - safeArc * 0.5;
    const radius = Math.max(width, height) * 0.72;
    const steps = Math.max(2, Math.ceil(28 * shownArc / safeArc));
    const points = [x, y];
    for (let i = 0; i <= steps; i++) {
      const angle = start + shownArc * i / steps;
      points.push(x + Math.cos(angle) * radius, y + Math.sin(angle) * radius);
    }
    mask.poly(points).fill(0xffffff);
    sprite.mask = mask;
  }

  end(): void {
    for (let i = this.used; i < this.sprites.length; i++) { this.sprites[i]!.visible = false; this.sprites[i]!.mask = null; }
    for (let i = this.masksUsed; i < this.masks.length; i++) this.masks[i]!.visible = false;
    // Retain a modest reserve, without keeping a historic worst-case population forever.
    const retained = Math.max(this.used, WORLD_THEME.neighborhood.spritePoolLimit);
    while (this.sprites.length > retained) this.sprites.pop()!.destroy();
  }

  private createTexture(shape: Visual['shape'], role: SpriteRole, motif?: Visual['motif']): Texture {
    const g = new Graphics();
    if (role === 'elite') {
      g.circle(0, 0, 20).stroke({ color: 0xffffff, alpha: 0.8, width: 1.5 });
      g.circle(0, 0, 17).stroke({ color: 0xffffff, alpha: 0.22, width: 1 });
    } else {
      if(motif==='swarm') g.poly([-20,-18,-8,-10,0,-20,8,-10,20,-18,12,0,20,18,6,12,0,20,-6,12,-20,18,-12,0]);
      else if(motif==='charge')g.poly([-20,-22,-4,-12,0,-20,4,-12,20,-22,14,12,0,20,-14,12]);
      else if(motif==='ambush')g.poly([0,-22,22,10,8,7,0,20,-8,7,-22,10]);
      else if(motif==='queen')g.poly([-22,-22,-8,-12,0,-24,8,-12,22,-22,17,8,7,10,0,23,-7,10,-17,8]);
      else if(motif==='tank'||motif==='defender')g.poly([-20,-18,20,-18,20,9,0,23,-20,9]);
      else if(motif==='splitter')g.poly([-20,4,-17,-11,-6,-19,7,-16,20,-4,18,15,6,20,-12,17]);
      else if(motif==='summoner')g.poly([0,-22,19,-11,19,11,0,22,-19,11,-19,-11,0,-22]);
      else if (shape === 'circle') g.circle(0, 0, 20);
      else if (shape === 'diamond') g.poly([0, -20, 16, 0, 0, 20, -16, 0]);
      else if (shape === 'triangle') g.poly([0, -20, 18, 15, -18, 15]);
      else g.poly([-10, -17.3, 10, -17.3, 20, 0, 10, 17.3, -10, 17.3, -20, 0]);
      g.fill({ color: 0xffffff, alpha: role === 'enemy' ? 0.88 : 1 });
      g.stroke({ color: 0xffffff, alpha: 1, width: 1.5 });
      if (role === 'enemy') {
        if(motif==='support')g.rect(-3,-15,6,26).fill(0x193229).rect(-12,-5,24,6).fill(0x193229);
        if(motif==='bomber')g.circle(0,0,11).stroke({color:0x473419,width:4});
        if(motif==='ranged')g.circle(0,-9,7).fill(0x342536);
        if(motif==='summoner')g.circle(0,0,12).stroke({color:0x342536,width:3});
        g.poly([-9, -3, -3, 0, -9, 3]).fill(0x263039);
        g.poly([9, -3, 3, 0, 9, 3]).fill(0x263039);
      } else if (role === 'player') {
        g.poly([0, -12, 7, 0, 0, 9, -7, 0]).fill(0x24484c);
        g.circle(0, -1, 3).fill(0xffffff);
      } else if (role === 'pickup') {
        if(shape==='circle'){g.circle(0,0,14).stroke({color:0x73521a,width:2});g.rect(-3,-9,6,18).fill(0x73521a);}else g.poly([0,-10,6,0,0,10,-6,0]).fill(0xffffff);
      }
    }
    const texture = this.renderer.generateTexture({ target: g, frame: new Rectangle(-24, -24, 48, 48), resolution: 2, antialias: true });
    g.destroy({ context: true });
    return texture;
  }

  destroy(): void {
    for (const sprite of this.sprites) sprite.destroy();
    for (const texture of this.textures.values()) texture.destroy(true);
    this.sprites.length = 0;
    this.textures.clear();
  }
}
