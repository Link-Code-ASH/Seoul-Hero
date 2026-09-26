export const ENEMY_RULES = {
  maxHostileProjectiles: 400, maxHazards: 100, projectileRadius: 7, projectileLifetime: 4,
  maxSummonsPerEnemy: 6, summonedRewardMultiplier: 0.25, splitCount: 2,
  supportRadius: 180, supportInterval: 2, supportHealFraction: 0.08,
  swarmRadius: 120, swarmNeighbors: 6, weaveAmplitude: 0.5,
  chargeTriggerRange: 380, chargeWarning: 0.8, chargeDuration: 0.45, chargeSpeed: 650, chargeCooldown: 3,
  bomberTrigger: 95, bomberWarning: 1, bomberRadius: 125,
  tankRadius: 100, tankCooldown: 3, tankWarning: 1,
  rangedDistance: 330, rangedCooldown: 2.4, rangedWarning: 0.6, bulletSpeed: 250,
  summonInterval: 6, summonOffset: 65, defenderArmor: 70, defenderCycle: 4, defenderGuard: 2.7,
  ambushCooldown: 4, ambushWarning: 0.65, ambushSpeed: 780,
  auraInterval: 3, auraRadius: 130, auraWarning: 0.8, auraDamage: 8,
} as const;
export const ENEMY_MOVE_SCALE = 0.86;
export const enemyBaseMoveSpeed = (id: string, speed: number): number =>
  speed * (id === 'swarm' ? 0.65 : ENEMY_MOVE_SCALE);
export const CURSE_RULES = { hpPerPoint: 0.01, damagePerPoint: 0.01, speedPerPoint: 0.002,
  spawnPerPoint: 0.005, eliteChancePerPoint: 0.001, maxIntensity: 5, maxEliteChance: 0.25 } as const;
export const DROP_RULES = { magicStoneRadius: 9, mergeDistance: 70, magicStoneLifetime: 30 } as const;

