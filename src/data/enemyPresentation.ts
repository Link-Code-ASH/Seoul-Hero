// Legacy values stay valid for the web renderer; Godot uses the legless families.
export type EnemyMotionMode = 'hop' | 'fly' | 'slither' | 'bossFloat' | 'crawl' | 'pounce' | 'stomp' | 'aim' | 'skitter' | 'charge' | 'pulse' | 'ooze' | 'float' | 'brace' | 'stalk' | 'bossStomp' | 'queenFloat';

export interface EnemyPresentation {
  mode: EnemyMotionMode;
  frequency: number;
  bob: number;
  sway: number;
  roll: number;
  squash: number;
  shadowAlpha: number;
  ambientTint: number;
  /** Visual height only; never changes collision or movement. */
  displayScale?: number;
  bodyWave?: number;
  wingMotion?: number;
}

/** One PNG per enemy. Combat behavior and hit radius stay in EnemyBehaviors. */
export const enemyPresentation: Record<string, EnemyPresentation> = {
  copperCrab: {mode:'slither',frequency:4.2,bob:.5,sway:1.4,roll:.018,squash:.025,bodyWave:.027,shadowAlpha:.34,ambientTint:0xffffff},
  ironBoar: {mode:'slither',frequency:2.8,bob:.6,sway:1.1,roll:.012,squash:.045,bodyWave:.025,shadowAlpha:.45,ambientTint:0xffffff},
  signalMoth: {mode:'fly',frequency:6.2,bob:3.6,sway:.8,roll:.022,squash:.025,wingMotion:.12,shadowAlpha:.20,ambientTint:0xffffff},
  glassJelly: {mode:'float',frequency:2,bob:5,sway:.8,roll:.012,squash:.035,bodyWave:.012,shadowAlpha:.18,ambientTint:0xffffff},
  chainWarden: {mode:'float',frequency:1.8,bob:3.5,sway:.4,roll:.012,squash:.025,shadowAlpha:.38,ambientTint:0xffffff},
  crawler: {mode:'hop',frequency:3.8,bob:7,sway:.7,roll:.018,squash:.11,displayScale:1.05,shadowAlpha:.38,ambientTint:0xffffff},
  runner: {mode:'slither',frequency:5.2,bob:.5,sway:1.2,roll:.022,squash:.035,bodyWave:.035,shadowAlpha:.34,ambientTint:0xffffff},
  bulwark: {mode:'hop',frequency:2,bob:4.5,sway:.35,roll:.009,squash:.075,shadowAlpha:.52,ambientTint:0xffffff},
  spitter: {mode:'float',frequency:2.7,bob:4.2,sway:.9,roll:.022,squash:.03,shadowAlpha:.25,ambientTint:0xffffff},
  swarm: {mode:'fly',frequency:8.5,bob:3,sway:1.3,roll:.028,squash:.025,wingMotion:.15,shadowAlpha:.22,ambientTint:0xffffff},
  charger: {mode:'slither',frequency:3.7,bob:.7,sway:1,roll:.015,squash:.04,bodyWave:.03,shadowAlpha:.43,ambientTint:0xffffff},
  bomber: {mode:'float',frequency:4,bob:3.5,sway:.7,roll:.025,squash:.065,shadowAlpha:.26,ambientTint:0xffffff},
  splitter: {mode:'hop',frequency:2.7,bob:6,sway:.8,roll:.018,squash:.12,shadowAlpha:.31,ambientTint:0xffffff},
  mender: {mode:'float',frequency:1.8,bob:5,sway:.9,roll:.015,squash:.045,bodyWave:.016,shadowAlpha:.23,ambientTint:0xffffff},
  summoner: {mode:'float',frequency:1.5,bob:5.5,sway:.7,roll:.018,squash:.025,bodyWave:.02,shadowAlpha:.18,ambientTint:0xffffff},
  sentinel: {mode:'hop',frequency:2.3,bob:4.5,sway:.3,roll:.008,squash:.075,shadowAlpha:.48,ambientTint:0xffffff},
  lurker: {mode:'float',frequency:3.5,bob:3.6,sway:1.1,roll:.028,squash:.04,bodyWave:.022,shadowAlpha:.21,ambientTint:0xffffff},
  gatekeeper: {mode:'bossFloat',frequency:1.25,bob:7,sway:.5,roll:.009,squash:.02,shadowAlpha:.48,ambientTint:0xffffff},
  riftQueen: {mode:'bossFloat',frequency:1.5,bob:8,sway:.8,roll:.014,squash:.04,bodyWave:.016,shadowAlpha:.24,ambientTint:0xffffff},
};

export const fallbackEnemyPresentation: EnemyPresentation = {
  mode:'float',frequency:2.4,bob:4,sway:.5,roll:.012,squash:.03,shadowAlpha:.3,ambientTint:0xffffff,
};
