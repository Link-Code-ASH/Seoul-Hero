import type { PlayerStats, StatKey, WeaponCapability } from './stats';
export interface Vec2 { x: number; y: number }
export interface Visual {
  motif?: 'tank'|'ranged'|'swarm'|'charge'|'bomber'|'splitter'|'support'|'summoner'|'defender'|'ambush'|'queen'; color: number; shape: 'circle' | 'diamond' | 'triangle' | 'hexagon'; sprite?: import('./images').ImageId; motionStyle?: 'scooter' | 'truck' }
export interface Character {
  id: string; name: string; description: string; background: string; personality: string;
  baseStats: PlayerStats; radius: number; signatureWeaponId?: string; portraitSprite?: import('./images').ImageId; visual: Visual;
}
export interface CharacterStatAdjustment { stat: StatKey; operation: 'add' | 'multiply'; value: number }
export interface StageBalanceModifiers {
  enemyHp: number; enemyDamage: number; enemySpeed: number; spawnDensity: number; rewards: number;
}
export interface EnemyDefinition {
  id: string; name: string; description: string; maxHp: number; moveSpeed: number; contactDamage: number;
  magicStoneDrop: number; radius: number;
  behavior: 'chase' | 'skirmish' | 'tank' | 'ranged' | 'swarm' | 'charge' | 'bomber' | 'splitter' | 'support' | 'summoner' | 'defender' | 'ambush' | 'boss';
  visual: Visual; tags: ('NORMAL' | 'BOSS' | 'SUMMONED')[];
  charge?: { triggerRange: number; warning: number; duration: number; speed: number; cooldown: number };
  childId?: string; bossPatterns?: BossPattern[];
}
export interface WeaponStats {
  areaMultiplier?: number; attackAngle?: number; blastRadius?: number; repeatCount?: number; repeatInterval?: number; explosionDelay?: number;
  spreadAngle?: number;
  damage: number; cooldown: number; projectileCount: number; projectileSpeed: number;
  range: number; duration: number; penetration: number; projectileRadius: number;
}
export interface WeaponBranch { id: 'A' | 'B'; name: string; description: string; levels: Partial<WeaponStats>[] }
export interface Weapon {
  maxLevel: number; branchAtLevel: number; branches: WeaponBranch[];
  id: string; name: string; description: string; targeting: 'nearest';
  signatureOwnerId?: string;
  capabilities: WeaponCapability[];
  structure?: { kind: 'turret' | 'mine' | 'aura'; maxCount: number; placementInterval: number; triggerRadius: number; sprite?: import('./images').ImageId };
  behavior: 'structure' | 'projectile' | 'slash' | 'orbit' | 'chain' | 'bombard'; base: WeaponStats; levels: Partial<WeaponStats>[]; visual: Visual;
  attackAngle?: number; blastRadius?: number; chainRange?: number; requiresUnlock?: boolean;
}
export interface Wave {
  id: string; name: string; waveNumber: number; duration: number;
  interval: number; batch: number; maxEnemies: number;
  enemies: { enemyId: string; weight: number }[];
  elites?: { at: number; enemyId: string; hpMultiplier: number; rewardMultiplier: number; modifiers?: import('./eliteModifiers').EliteModifierId[] }[];
  boss?: { enemyId: string };
}
export interface ArenaSize { arenaWidth: number; arenaHeight: number }
export interface MapData extends ArenaSize {
  id: string; name: string; description: string; seed: number;
  thumbnail: import('./images').ImageId;
  backgroundTheme: 'neighborhood'; totalWaves: number; bossWave: number;
  waveDefinitions: Wave[]; clearReward: number;
  /** Relative to Song Jinwoo / Gwanghwamun / gate depth 1. Omitted values are 1.0. */
  balanceModifiers?: Partial<StageBalanceModifiers>;
  /** Optional archive roster. Omitted lists show all currently registered content. */
  archiveContent?: { enemyIds?: string[]; weaponIds?: string[]; itemIds?: string[] };
}
export type { StatKey } from './stats';
export type UpgradeEffect = { type: 'stat'; stat: StatKey; value: number } | { type: 'weaponLevel'; weaponId: string } | { type: 'heal'; amount: number };
export interface Upgrade {
  id: string; name: string; description: string; category: 'weapon' | 'passive' | 'recovery';
  rarity: 'common'; maxLevel: number; weight: number; effect: UpgradeEffect;
  requiresWeaponId?: string;
}

export interface BossPattern { type: 'charge' | 'aoe' | 'summon' | 'volley'; warning: number; cooldown: number; radius: number; damageMultiplier: number; count: number; childId?: string }
