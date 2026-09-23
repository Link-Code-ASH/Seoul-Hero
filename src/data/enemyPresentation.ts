export type EnemyMotionMode = 'crawl' | 'pounce' | 'stomp' | 'aim' | 'skitter' | 'charge' | 'pulse' | 'ooze' | 'float' | 'brace' | 'stalk' | 'bossStomp' | 'queenFloat';

export interface EnemyPresentation {
  mode: EnemyMotionMode;
  frequency: number;
  bob: number;
  sway: number;
  roll: number;
  squash: number;
  shadowAlpha: number;
  ambientTint: number;
}

/** Presentation-only motion and color grading. Combat behavior remains in EnemyBehaviors. */
export const enemyPresentation: Record<string, EnemyPresentation> = {
  crawler:    { mode:'crawl',      frequency:4.0, bob:1.2, sway:.8, roll:.018, squash:.025, shadowAlpha:.38, ambientTint:0xd5dce0 },
  runner:     { mode:'pounce',     frequency:6.8, bob:2.1, sway:.5, roll:.03,  squash:.045, shadowAlpha:.34, ambientTint:0xd8d8d2 },
  bulwark:    { mode:'stomp',      frequency:1.9, bob:1.0, sway:.35,roll:.008, squash:.05,  shadowAlpha:.52, ambientTint:0xd0d5d7 },
  spitter:    { mode:'aim',        frequency:2.7, bob:.65, sway:1.2,roll:.014, squash:.012, shadowAlpha:.34, ambientTint:0xd7d9df },
  swarm:      { mode:'skitter',    frequency:11,  bob:1.5, sway:2.1,roll:.055, squash:.03,  shadowAlpha:.27, ambientTint:0xdad8ca },
  charger:    { mode:'charge',     frequency:3.0, bob:1.4, sway:.4, roll:.018, squash:.038, shadowAlpha:.43, ambientTint:0xd7d5d1 },
  bomber:     { mode:'pulse',      frequency:4.8, bob:.85, sway:.55,roll:.02,  squash:.055, shadowAlpha:.33, ambientTint:0xdad8cd },
  splitter:   { mode:'ooze',       frequency:2.5, bob:.5,  sway:1.0,roll:.012, squash:.06,  shadowAlpha:.31, ambientTint:0xd3d9d2 },
  mender:     { mode:'float',      frequency:1.8, bob:3.0, sway:.7, roll:.01,  squash:.008, shadowAlpha:.23, ambientTint:0xd4dedb },
  summoner:   { mode:'float',      frequency:1.35,bob:3.8, sway:.45,roll:.008, squash:.006, shadowAlpha:.18, ambientTint:0xd4d7df },
  sentinel:   { mode:'brace',      frequency:2.1, bob:.75, sway:.2, roll:.005, squash:.045, shadowAlpha:.48, ambientTint:0xd1d9dd },
  lurker:     { mode:'stalk',      frequency:6.1, bob:.8,  sway:1.5,roll:.04,  squash:.025, shadowAlpha:.21, ambientTint:0xd2d2d8 },
  gatekeeper: { mode:'bossStomp',  frequency:1.4, bob:1.4, sway:.25,roll:.006, squash:.04,  shadowAlpha:.58, ambientTint:0xd0d7dc },
  riftQueen:  { mode:'queenFloat', frequency:1.2, bob:4.2, sway:.55,roll:.012, squash:.01,  shadowAlpha:.24, ambientTint:0xd5d5df },
};

export const fallbackEnemyPresentation: EnemyPresentation = {
  mode:'crawl',frequency:4,bob:1,sway:.5,roll:.01,squash:.02,shadowAlpha:.35,ambientTint:0xd8dde0,
};
