import type { Graphics } from 'pixi.js';
import { VFX_CONFIG, VFX_PRESETS } from '../data/vfx';
import type { Projectile } from '../entities/types';
import type { RunEffect } from '../state/RunEffect';
import type { EntitySprites } from './EntitySprites';

const clamp01 = (value: number): number => Math.max(0, Math.min(1, value));
const easeOut = (value: number): number => 1 - (1 - clamp01(value)) ** 3;
const easeInOut = (value: number): number => value < 0.5 ? 4 * value ** 3 : 1 - (-2 * value + 2) ** 3 / 2;
const fadeTail = (progress: number, start = 0.35): number => 1 - clamp01((progress - start) / (1 - start));

function random(seed: number, index: number): number {
  let value = (seed + Math.imul(index + 1, 0x9e3779b1)) >>> 0;
  value ^= value >>> 16; value = Math.imul(value, 0x7feb352d); value ^= value >>> 15;
  value = Math.imul(value, 0x846ca68b); value ^= value >>> 16;
  return (value >>> 0) / 4294967296;
}

function brighten(color: number, amount: number): number {
  const r = Math.min(255, (color >> 16 & 255) + amount);
  const g = Math.min(255, (color >> 8 & 255) + amount);
  const b = Math.min(255, (color & 255) + amount);
  return r << 16 | g << 8 | b;
}

function darken(color: number, factor: number): number {
  return Math.round((color >> 16 & 255) * factor) << 16
    | Math.round((color >> 8 & 255) * factor) << 8
    | Math.round((color & 255) * factor);
}

/** Presentation-only VFX timelines. Combat rules only create short RunEffect records. */
export class CombatVfx {
  constructor(private readonly back: Graphics, private readonly glow: Graphics, private readonly front: Graphics) {}

  begin(): void {
    this.back.clear();
    this.glow.clear();
    this.front.clear();
  }

  draw(effect: RunEffect, sprites: EntitySprites): boolean {
    const progress = clamp01(1 - effect.remaining / Math.max(0.001, effect.duration));
    switch (effect.kind) {
      case 'muzzle': this.muzzle(effect, progress, sprites); return true;
      case 'impact': this.impact(effect, progress, false, sprites); return true;
      case 'criticalImpact': this.impact(effect, progress, true, sprites); return true;
      case 'enemyDeath': this.death(effect, progress, sprites); return true;
      case 'slash': this.slash(effect, progress, sprites); return true;
      case 'chain': this.chain(effect, progress, sprites); return true;
      case 'bombardProjectile': this.bombardProjectile(effect, progress, sprites); return true;
      case 'bombard': this.explosion(effect, progress, false, sprites); return true;
      case 'mineBlast': this.explosion(effect, progress, true, sprites); return true;
      default: return false;
    }
  }

  private bombardProjectile(effect: RunEffect, progress: number, sprites: EntitySprites): void {
    const dx = effect.endX - effect.x;
    const dy = effect.endY - effect.y;
    const distance = Math.hypot(dx, dy);
    const arcHeight = Math.min(150, Math.max(58, distance * 0.23));
    const positionAt = (value: number): { x: number; y: number; groundY: number } => {
      const time = clamp01(value);
      const travel = easeInOut(time);
      const groundY = effect.y + dy * travel;
      return {
        x: effect.x + dx * travel,
        y: groundY - Math.sin(time * Math.PI) * arcHeight,
        groundY,
      };
    };

    const current = positionAt(progress);
    const previous = positionAt(progress - 0.045);
    const older = positionAt(progress - 0.1);
    const next = positionAt(progress + 0.045);
    const directionX = next.x - previous.x;
    const directionY = next.y - previous.y;
    // The shell art points right. Rotate the whole sprite from the actual
    // curve tangent; replacing a zero component separately can reverse it.
    const angle = Math.hypot(directionX, directionY) > 0.001
      ? Math.atan2(directionY, directionX) : Math.atan2(dy, dx);
    const heightRatio = Math.sin(progress * Math.PI);
    const scale = 0.86 + heightRatio * 0.3;

    // The shadow follows the ground route while the projectile rises above it.
    this.back.ellipse(
      current.x,
      current.groundY,
      effect.radius * (0.7 + heightRatio * 0.22),
      effect.radius * 0.27,
    ).fill({ color: 0x07101a, alpha: 0.12 + heightRatio * 0.13 });

    sprites.drawImage(
      current.x,
      current.y,
      effect.radius * 2.35 * scale,
      effect.radius * 1.28 * scale,
      'bombardShell',
      0.92,
      angle,
    );
    this.glow.moveTo(older.x, older.y).lineTo(previous.x, previous.y).lineTo(current.x, current.y)
      .stroke({ color: effect.color, width: Math.max(2, effect.radius * 0.28), alpha: 0.22, cap: 'round' });
  }

  projectileTrail(projectile: Projectile): void {
    const speed = Math.hypot(projectile.vx, projectile.vy);
    if (speed <= 0) return;
    const nx = projectile.vx / speed, ny = projectile.vy / speed;
    const length = Math.max(10, projectile.radius * VFX_CONFIG.projectileTrailLength);
    const color = projectile.visual.color;
    this.glow.moveTo(projectile.x - nx * length, projectile.y - ny * length)
      .lineTo(projectile.x, projectile.y)
      .stroke({ color, width: Math.max(2, projectile.radius * 1.4), alpha: VFX_CONFIG.projectileTrailAlpha, cap: 'round' });
    this.front.circle(projectile.x - nx * length * 0.22, projectile.y - ny * length * 0.22, Math.max(1.2, projectile.radius * 0.3))
      .fill({ color: brighten(color, 90), alpha: 0.65 });
  }

  hazardBlast(x: number, y: number, radius: number, remaining: number, sprites: EntitySprites): void {
    const progress = clamp01(1 - remaining / 0.25);
    const effect: RunEffect = { kind: 'bombard', x, y, endX: x, endY: y, radius, angle: 0, arc: 0,
      remaining: 0.25 - progress * 0.25, duration: 0.25, color: 0xff715c, seed: Math.round(x * 31 + y * 17) >>> 0 };
    this.explosion(effect, progress, false, sprites);
  }

  private muzzle(effect: RunEffect, progress: number, sprites: EntitySprites): void {
    const seed = effect.seed ?? 1;
    const radius = effect.radius * (0.35 + easeOut(progress) * 0.9);
    const fade = fadeTail(progress, 0.18);
    const frontX = effect.x + Math.cos(effect.angle) * radius * 0.9;
    const frontY = effect.y + Math.sin(effect.angle) * radius * 0.9;
    const textureScale = 0.7 + easeOut(progress) * 0.3;
    sprites.drawImage(frontX, frontY, radius * 3.1 * textureScale, radius * 1.68 * textureScale, 'vfxMuzzle', fade * 0.64, effect.angle);
    this.glow.circle(frontX, frontY, radius * 0.62).fill({ color: effect.color, alpha: fade * 0.16 });
    this.front.circle(frontX, frontY, radius * 0.22).fill({ color: brighten(effect.color, 100), alpha: fade * 0.92 });
    const count = VFX_PRESETS.muzzle!.particleCount;
    for (let i = 0; i < count; i++) {
      const spread = (random(seed, i) - 0.5) * 1.15;
      const distance = radius * (0.6 + random(seed, i + 9) * 1.4) * easeOut(progress);
      const angle = effect.angle + spread;
      this.front.circle(frontX + Math.cos(angle) * distance, frontY + Math.sin(angle) * distance,
        Math.max(0.8, radius * (0.08 + random(seed, i + 20) * 0.05)) * fade)
        .fill({ color: brighten(effect.color, 65), alpha: fade * 0.72 });
    }
  }

  private impact(effect: RunEffect, progress: number, critical: boolean, sprites: EntitySprites): void {
    const seed = effect.seed ?? 2;
    const strength = critical ? 1.55 : 1;
    const radius = effect.radius * strength;
    const flash = 1 - clamp01(progress / (critical ? 0.26 : 0.2));
    const tail = fadeTail(progress, critical ? 0.26 : 0.2);
    const ringRadius = radius * (0.25 + easeOut(progress) * 1.1);
    const imageScale = 0.66 + easeOut(progress) * 0.34;
    sprites.drawImage(effect.x, effect.y, radius * (critical ? 2.7 : 2.25) * imageScale, radius * (critical ? 2.25 : 2.1) * imageScale,
      critical ? 'vfxCritical' : 'vfxImpact', tail * (critical ? 0.64 : 0.52), progress * (critical ? 0.18 : -0.12));
    this.glow.circle(effect.x, effect.y, radius * (0.45 + progress * 0.55)).fill({ color: effect.color, alpha: flash * (critical ? 0.55 : 0.34) });
    this.front.circle(effect.x, effect.y, Math.max(1, radius * 0.24 * flash)).fill({ color: 0xffffff, alpha: flash * 0.94 });
    this.front.circle(effect.x, effect.y, ringRadius).stroke({ color: brighten(effect.color, critical ? 105 : 65), width: Math.max(1, radius * 0.075 * tail), alpha: tail * 0.3 });
    const count = critical ? VFX_PRESETS.criticalImpact!.particleCount : VFX_PRESETS.impact!.particleCount;
    for (let i = 0; i < count; i++) {
      const angle = random(seed, i) * Math.PI * 2;
      const distance = radius * (0.3 + random(seed, i + 20) * 1.55) * easeOut(progress);
      const length = radius * (0.2 + random(seed, i + 40) * 0.35) * tail;
      const x = effect.x + Math.cos(angle) * distance, y = effect.y + Math.sin(angle) * distance;
      this.front.moveTo(x, y).lineTo(x + Math.cos(angle) * length, y + Math.sin(angle) * length)
        .stroke({ color: i % 3 === 0 ? 0xffffff : brighten(effect.color, 75), width: critical ? 1.8 : 1.15, alpha: tail * 0.48, cap: 'round' });
    }
    if (critical) {
      const cross = radius * (0.35 + easeOut(progress) * 0.5);
      this.front.moveTo(effect.x - cross, effect.y).lineTo(effect.x + cross, effect.y)
        .moveTo(effect.x, effect.y - cross).lineTo(effect.x, effect.y + cross)
        .stroke({ color: 0xfff4bd, width: 1.8 * tail, alpha: tail * 0.4, cap: 'round' });
    }
  }

  private slash(effect: RunEffect, progress: number, sprites: EntitySprites): void {
    // Wind-up (0..0.10), clockwise sector reveal (0.10..0.62), impact, then fade.
    const sweep = easeInOut(clamp01((progress - 0.1) / 0.52));
    const tail = fadeTail(progress, 0.58);
    // The arc and image size follow the weapon. WeaponBehaviors shifts the effect
    // center toward nearby targets without shrinking the blade art.
    const attackArc = Math.max(0.05, Math.min(Math.PI * 2, effect.arc || 0.8));
    const outerRadius = effect.radius;
    // A thin painted blade trail follows the collision arc. Its transparent center keeps
    // the effect line-like instead of revealing a filled fan around the player.
    const wide = attackArc > 1.38;
    const referenceArc = wide ? Math.PI / 2 : Math.PI / 3;
    const textureReveal = easeOut(clamp01((progress - 0.075) / 0.16));
    const textureScale = 0.92 + sweep * 0.08;
    const angularScale = Math.max(0.82, Math.min(1.25, attackArc / referenceArc));
    const primaryAlpha = textureReveal * tail * 0.82;
    sprites.drawImageSector(effect.x, effect.y, effect.radius * 2.2 * textureScale,
      effect.radius * 2.2 * textureScale * angularScale,
      wide ? 'vfxSlashWide' : 'vfxSlashNarrow', primaryAlpha, effect.angle, attackArc, sweep);

    const impactPhase = clamp01((progress - 0.54) / 0.22);
    const impactAlpha = Math.sin(impactPhase * Math.PI) * tail;
    if (impactAlpha > 0.01) {
      const x = effect.x + Math.cos(effect.angle) * outerRadius;
      const y = effect.y + Math.sin(effect.angle) * outerRadius;
      this.glow.circle(x, y, effect.radius * (0.035 + impactPhase * 0.025))
        .fill({ color: 0x6079ab, alpha: impactAlpha * 0.18 });
      this.front.circle(x, y, Math.max(1.2, effect.radius * 0.014))
        .fill({ color: 0xc9d6ed, alpha: impactAlpha * 0.58 });
    }
  }

  private explosion(effect: RunEffect, progress: number, mine: boolean, sprites: EntitySprites): void {
    const seed = effect.seed ?? 4;
    const color = mine ? 0x9d73ff : 0xff8a48;
    const bright = mine ? 0xe5d8ff : 0xffe2a5;
    const ignition = 1 - clamp01(progress / 0.16);
    const corePhase = easeOut(Math.min(1, progress / 0.52));
    const tail = fadeTail(progress, 0.3);
    const coreRadius = effect.radius * (0.12 + corePhase * 0.48);
    const imageScale = 0.6 + corePhase * 0.34;
    sprites.drawImage(effect.x, effect.y, effect.radius * 2 * imageScale, effect.radius * 2 * imageScale,
      mine ? 'vfxMineExplosion' : 'vfxExplosion', tail * 0.64, (effect.seed ?? 0) % 7 * 0.025);
    this.back.circle(effect.x, effect.y, effect.radius * (0.28 + corePhase * 0.54)).fill({ color: darken(color, 0.42), alpha: tail * 0.28 });
    this.glow.circle(effect.x, effect.y, coreRadius * 1.25).fill({ color, alpha: (0.22 + ignition * 0.42) * tail });
    this.front.circle(effect.x, effect.y, Math.max(1, coreRadius * (0.62 + ignition * 0.3))).fill({ color: ignition > 0.25 ? bright : color, alpha: tail * 0.8 });
    const ring = effect.radius * (0.18 + easeOut(progress) * 0.82);
    this.front.circle(effect.x, effect.y, ring).stroke({ color: bright, width: Math.max(1.5, effect.radius * 0.045 * tail), alpha: tail * 0.28 });
    for (let i = 0; i < VFX_PRESETS.bombard!.particleCount; i++) {
      const angle = random(seed, i) * Math.PI * 2;
      const distance = effect.radius * (0.16 + random(seed, i + 20) * 0.9) * easeOut(progress);
      const size = effect.radius * (0.018 + random(seed, i + 40) * 0.035) * tail;
      this.front.circle(effect.x + Math.cos(angle) * distance, effect.y + Math.sin(angle) * distance, Math.max(0.8, size))
        .fill({ color: i % 3 ? color : bright, alpha: tail * 0.44 });
    }
    const smokeProgress = clamp01((progress - 0.2) / 0.8);
    for (let i = 0; i < 5; i++) {
      const angle = random(seed, i + 70) * Math.PI * 2;
      const distance = effect.radius * (0.08 + random(seed, i + 80) * 0.3) * smokeProgress;
      const size = effect.radius * (0.12 + random(seed, i + 90) * 0.09) * (0.45 + smokeProgress * 0.85);
      this.back.circle(effect.x + Math.cos(angle) * distance, effect.y + Math.sin(angle) * distance, size)
        .fill({ color: mine ? 0x332a4a : 0x4a342b, alpha: smokeProgress * tail * 0.24 });
    }
  }

  private death(effect: RunEffect, progress: number, sprites: EntitySprites): void {
    const seed = effect.seed ?? 5;
    const tail = fadeTail(progress, 0.22);
    const collapse = 1 - easeOut(progress);
    const imageScale = 0.72 + easeOut(progress) * 0.32;
    sprites.drawImage(effect.x, effect.y - progress * effect.radius * 0.18, effect.radius * 2.4 * imageScale, effect.radius * 2 * imageScale,
      'vfxDeath', tail * 0.48, (random(seed, 88) - 0.5) * 0.2);
    this.glow.circle(effect.x, effect.y, effect.radius * (0.35 + collapse * 0.5)).fill({ color: effect.color, alpha: tail * 0.25 });
    for (let i = 0; i < VFX_CONFIG.deathSmokeCount; i++) {
      const angle = random(seed, i) * Math.PI * 2;
      const distance = effect.radius * (0.15 + random(seed, i + 10) * 0.75) * easeOut(progress);
      const size = effect.radius * (0.13 + random(seed, i + 20) * 0.14) * (0.55 + progress * 0.75);
      this.back.circle(effect.x + Math.cos(angle) * distance, effect.y + Math.sin(angle) * distance - progress * effect.radius * 0.28, size)
        .fill({ color: darken(effect.color, 0.32), alpha: tail * 0.26 });
    }
    for (let i = 0; i < VFX_PRESETS.enemyDeath!.particleCount; i++) {
      const angle = random(seed, i + 40) * Math.PI * 2;
      const distance = effect.radius * (0.2 + random(seed, i + 50) * 1.1) * easeOut(progress);
      this.front.circle(effect.x + Math.cos(angle) * distance, effect.y + Math.sin(angle) * distance,
        Math.max(0.7, effect.radius * 0.045 * tail))
        .fill({ color: brighten(effect.color, 45), alpha: tail * 0.62 });
    }
  }

  private chain(effect: RunEffect, progress: number, sprites: EntitySprites): void {
    const dx = effect.endX - effect.x, dy = effect.endY - effect.y;
    const length = Math.hypot(dx, dy);
    if (length <= 0) return;
    const nx = -dy / length, ny = dx / length;
    const tail = fadeTail(progress, 0.2);
    sprites.drawImage((effect.x + effect.endX) / 2, (effect.y + effect.endY) / 2, length, Math.max(24, length * 0.16),
      'vfxChain', tail * 0.64, Math.atan2(dy, dx));
    const segments = 7;
    for (let i = 0; i <= segments; i++) {
      const portion = i / segments;
      const jitter = i === 0 || i === segments ? 0 : (random(effect.seed ?? 6, i) - 0.5) * 13 * tail;
      const x = effect.x + dx * portion + nx * jitter, y = effect.y + dy * portion + ny * jitter;
      if (i === 0) this.glow.moveTo(x, y); else this.glow.lineTo(x, y);
    }
    this.glow.stroke({ color: effect.color, width: 8, alpha: tail * 0.18, cap: 'round', join: 'round' });
    for (let i = 0; i <= segments; i++) {
      const portion = i / segments;
      const jitter = i === 0 || i === segments ? 0 : (random(effect.seed ?? 6, i) - 0.5) * 13 * tail;
      const x = effect.x + dx * portion + nx * jitter, y = effect.y + dy * portion + ny * jitter;
      if (i === 0) this.front.moveTo(x, y); else this.front.lineTo(x, y);
    }
    this.front.stroke({ color: brighten(effect.color, 95), width: 1.4, alpha: tail * 0.3, cap: 'round', join: 'round' });
  }
}
