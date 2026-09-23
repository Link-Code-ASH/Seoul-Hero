import type { RunEffectKind } from '../state/RunEffect';

export interface VfxPreset {
  duration: number;
  particleCount: number;
  glowAlpha: number;
}

export const VFX_PRESETS: Partial<Record<RunEffectKind, VfxPreset>> = {
  muzzle: { duration: 0.18, particleCount: 4, glowAlpha: 0.42 },
  impact: { duration: 0.24, particleCount: 6, glowAlpha: 0.5 },
  criticalImpact: { duration: 0.38, particleCount: 10, glowAlpha: 0.72 },
  enemyDeath: { duration: 0.5, particleCount: 8, glowAlpha: 0.34 },
  slash: { duration: 0.34, particleCount: 5, glowAlpha: 0.48 },
  chain: { duration: 0.2, particleCount: 3, glowAlpha: 0.46 },
  bombardProjectile: { duration: 0.9, particleCount: 2, glowAlpha: 0.38 },
  bombard: { duration: 0.58, particleCount: 12, glowAlpha: 0.66 },
  mineBlast: { duration: 0.58, particleCount: 12, glowAlpha: 0.62 },
};

export const VFX_CONFIG = {
  maxActive: 180,
  projectileTrailLength: 3.2,
  projectileTrailAlpha: 0.34,
  deathSmokeCount: 5,
} as const;
