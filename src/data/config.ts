export const GAME_CONFIG = {
  world: { sceneryTileSize: 512, referenceWidth: 1280, referenceHeight: 720, combatZoom: 1.35, seed: 7319 },
  time: { fixedStep: 1 / 60, maxFrameDelta: 0.1, maxStepsPerFrame: 60 },
  combat: { invulnerabilitySeconds: 0.75, gridCellSize: 96, projectileSpread: 0.16, maxProjectiles: 1500, maxPickups: 1200, pickupRadius: 7, pickupAttractionSpeed: 400, pickupMergeDistance: 140 },
  ui: { refreshInterval: 0.1 },
} as const;
