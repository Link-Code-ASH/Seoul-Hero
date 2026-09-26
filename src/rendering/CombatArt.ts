import type { ImageId } from '../data/images';
import type { Enemy } from '../entities/types';

export interface GroundProfile {
  anchorY: number;
  groundOffset: number;
  shadowWidth: number;
  shadowDepth: number;
  shadowAlpha: number;
  shadowColor: number;
}

const groundProfiles: Partial<Record<ImageId, GroundProfile>> = {
  player:           { anchorY: .89, groundOffset: 1.17, shadowWidth: 1.65, shadowDepth: .38, shadowAlpha: .38, shadowColor: 0x08242a },
  kangTaehoonTruck: { anchorY: .88, groundOffset: 1.22, shadowWidth: 1.83, shadowDepth: .43, shadowAlpha: .44, shadowColor: 0x121b1a },
  brute:            { anchorY: .88, groundOffset: .91, shadowWidth: 1.04, shadowDepth: .34, shadowAlpha: .48, shadowColor: 0x170d14 },
  hound:            { anchorY: .88, groundOffset: .86, shadowWidth: 1.16, shadowDepth: .27, shadowAlpha: .36, shadowColor: 0x21140e },
  bulwark:          { anchorY: .89, groundOffset: .91, shadowWidth: 1.17, shadowDepth: .37, shadowAlpha: .55, shadowColor: 0x111820 },
  spitter:          { anchorY: .87, groundOffset: .86, shadowWidth: .92, shadowDepth: .28, shadowAlpha: .37, shadowColor: 0x1c1024 },
  swarm:            { anchorY: .86, groundOffset: .79, shadowWidth: .91, shadowDepth: .27, shadowAlpha: .29, shadowColor: 0x201b0e },
  charger:          { anchorY: .89, groundOffset: .91, shadowWidth: 1.25, shadowDepth: .34, shadowAlpha: .48, shadowColor: 0x20100d },
  bomber:           { anchorY: .87, groundOffset: .86, shadowWidth: .97, shadowDepth: .31, shadowAlpha: .40, shadowColor: 0x21180c },
  splitter:         { anchorY: .85, groundOffset: .80, shadowWidth: 1.28, shadowDepth: .27, shadowAlpha: .35, shadowColor: 0x162209 },
  mender:           { anchorY: .87, groundOffset: .84, shadowWidth: .87, shadowDepth: .25, shadowAlpha: .32, shadowColor: 0x102016 },
  summoner:         { anchorY: .88, groundOffset: .87, shadowWidth: .91, shadowDepth: .26, shadowAlpha: .33, shadowColor: 0x1a1424 },
  sentinel:         { anchorY: .89, groundOffset: .91, shadowWidth: 1.15, shadowDepth: .35, shadowAlpha: .52, shadowColor: 0x121a24 },
  lurker:           { anchorY: .87, groundOffset: .83, shadowWidth: 1.02, shadowDepth: .25, shadowAlpha: .28, shadowColor: 0x1d1020 },
  boss:             { anchorY: .88, groundOffset: .91, shadowWidth: 1.35, shadowDepth: .42, shadowAlpha: .60, shadowColor: 0x160d24 },
  riftQueen:        { anchorY: .89, groundOffset: .88, shadowWidth: 1.31, shadowDepth: .36, shadowAlpha: .45, shadowColor: 0x210f23 },
};

const fallback: GroundProfile = { anchorY: .87, groundOffset: .85, shadowWidth: 1, shadowDepth: .3, shadowAlpha: .38, shadowColor: 0x10151b };

export function groundProfileFor(sprite: ImageId | undefined): GroundProfile {
  return sprite ? groundProfiles[sprite] ?? fallback : fallback;
}

/** Pose selection is visual only; enemy actions and timers remain game-owned. */
export function enemyPose(enemy: Pick<Enemy, 'definitionId' | 'action' | 'timer' | 'visual'>, lift = 0): ImageId | undefined {
  if (enemy.definitionId === 'splitter' && enemy.action === 'move' && lift > 1.5) return 'splitterAir';
  if (enemy.definitionId === 'spitter' && enemy.action === 'warning' && enemy.timer < .24) return 'spitterFire';
  if (enemy.definitionId === 'charger' && enemy.action === 'warning') return 'chargerBrace';
  if (enemy.definitionId === 'gatekeeper' && enemy.action === 'warning') return 'bossAttack';
  if (enemy.definitionId === 'riftQueen' && enemy.action === 'warning') return 'riftQueenCast';
  return enemy.visual.sprite;
}
