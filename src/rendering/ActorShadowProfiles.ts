import type { ImageId } from '../data/images';

/**
 * One soft ground patch per actor. Coordinates are relative to the transparent
 * image canvas, not its bounding box. Each centre sits between the visible
 * supporting feet/wheels; a low hanging claw or cape must not move the whole
 * shadow to that single pixel.
 */
export interface ActorShadowProfile {
  x: number;
  y: number;
  halfWidth: number;
  depth: number;
}

export const actorShadowProfiles: Partial<Record<ImageId, ActorShadowProfile>> = {
  guildTraining: { x: .52, y: .855, halfWidth: .35, depth: .045 },
  guildRecovery: { x: .50, y: .91, halfWidth: .36, depth: .055 },
  guildSupply: { x: .50, y: .94, halfWidth: .37, depth: .05 },
  guildGate: { x: .50, y: .91, halfWidth: .34, depth: .055 },
  guildRoster: { x: .53, y: .89, halfWidth: .30, depth: .05 },
  turret: { x: .50, y: .91, halfWidth: .39, depth: .065 },
  // Riders: a single elongated patch connects the rear and front wheels.
  player: { x: .55, y: .835, halfWidth: .32, depth: .115 },
  kangTaehoonTruck: { x: .51, y: .855, halfWidth: .35, depth: .09 },

  // Each monster is fitted to its own stance, including alternate poses.
  brute: { x: .49, y: .845, halfWidth: .36, depth: .09 },
  hound: { x: .57, y: .805, halfWidth: .32, depth: .08 },
  bulwark: { x: .51, y: .855, halfWidth: .38, depth: .07 },
  spitter: { x: .51, y: .78, halfWidth: .36, depth: .07 },
  spitterFire: { x: .51, y: .805, halfWidth: .36, depth: .07 },
  swarm: { x: .56, y: .735, halfWidth: .35, depth: .085 },
  charger: { x: .56, y: .775, halfWidth: .36, depth: .08 },
  chargerBrace: { x: .57, y: .80, halfWidth: .38, depth: .08 },
  bomber: { x: .50, y: .825, halfWidth: .29, depth: .07 },
  splitter: { x: .51, y: .81, halfWidth: .34, depth: .055 },
  splitterAir: { x: .52, y: .825, halfWidth: .27, depth: .065 },
  mender: { x: .47, y: .835, halfWidth: .26, depth: .065 },
  summoner: { x: .52, y: .82, halfWidth: .29, depth: .065 },
  sentinel: { x: .56, y: .825, halfWidth: .33, depth: .075 },
  lurker: { x: .58, y: .745, halfWidth: .29, depth: .075 },
  boss: { x: .53, y: .835, halfWidth: .41, depth: .075 },
  bossAttack: { x: .52, y: .875, halfWidth: .43, depth: .065 },
  riftQueen: { x: .50, y: .915, halfWidth: .43, depth: .06 },
  riftQueenCast: { x: .51, y: .925, halfWidth: .43, depth: .06 },
};
