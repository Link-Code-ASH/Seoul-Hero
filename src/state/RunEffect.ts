export type RunEffectKind =
  | 'muzzle'
  | 'impact'
  | 'criticalImpact'
  | 'enemyDeath'
  | 'slash'
  | 'orbit'
  | 'chain'
  | 'bombardProjectile'
  | 'bombard'
  | 'mineBlast'
  | 'warning';

export interface RunEffect {
  kind: RunEffectKind;
  x: number;
  y: number;
  endX: number;
  endY: number;
  radius: number;
  angle: number;
  arc: number;
  remaining: number;
  duration: number;
  color: number;
  value?: number;
  /** Stable procedural variation without changing simulation randomness. */
  seed?: number;
}
