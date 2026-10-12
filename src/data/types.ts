import type { PlayerStats, StatKey, WeaponCapability } from './stats';
export interface Vec2 { x: number; y: number }
export interface Visual {
  motif?: 'tank'|'ranged'|'swarm'|'charge'|'bomber'|'splitter'|'support'|'summoner'|'defender'|'ambush'|'queen'; color: number; shape: 'circle' | 'diamond' | 'triangle' | 'hexagon'; sprite?: import('./images').ImageId }
export interface Character {
  id: string; name: string; description: string; background: string; personality: string;
  baseStats: PlayerStats; radius: number; signatureWeaponId?: string; portraitSprite?: import('./images').ImageId; visual: Visual;
  trait?: { name: string; description: string; weaponDamageBonus: number; weaponFamily?: 'firearm'; weaponCapability?: WeaponCapability };
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
  /** repeats: dashes in a row after one warning; each later dash re-aims after repeatWarning seconds. */
  charge?: { triggerRange: number; warning: number; duration: number; speed: number; cooldown: number; repeats?: number; repeatWarning?: number };
  /** 땅울림 (behavior 'tank') overrides; omitted values use ENEMY_RULES. repeats: hop + blast count per attack. */
  quake?: { radius?: number; warning?: number; cooldown?: number; repeats?: number; repeatDelay?: number };
  childId?: string; bossPatterns?: BossPattern[];
  /** 소환 (behavior 'summoner') in Godot: `count` childId minions every `interval` seconds while fewer than `alive` of its own are living. */
  summon?: { interval: number; count: number; alive: number };
  /** 분열 (behavior 'splitter') in Godot: dies into `count` smaller copies of itself, `generations` times over; each factor applies per generation. */
  split?: { count: number; generations: number; hp: number; size: number; damage: number; reward: number };
}
export interface WeaponStats {
  areaMultiplier?: number; attackAngle?: number; blastRadius?: number; repeatCount?: number; repeatInterval?: number; explosionDelay?: number;
  spreadAngle?: number;
  damage: number; cooldown: number; projectileCount: number; projectileSpeed: number;
  range: number; duration: number; penetration: number; projectileRadius: number;
}
export interface WeaponBranch { id: 'A' | 'B'; name: string; description: string; levels: Partial<WeaponStats>[] }
export interface ShopCardText { summary: string; penalty: string }
export interface Weapon {
  shopCardText?: ShopCardText;
  maxLevel: number; branchAtLevel: number; branches: WeaponBranch[];
  id: string; name: string; description: string; targeting: 'nearest';
  signatureOwnerId?: string;
  family?: 'firearm';
  capabilities: WeaponCapability[];
  structure?: { kind: 'turret' | 'mine' | 'aura'; maxCount: number; placementInterval: number; triggerRadius: number; sprite?: import('./images').ImageId };
  behavior: 'structure' | 'projectile' | 'slash' | 'orbit' | 'chain' | 'bombard'; base: WeaponStats; levels: Partial<WeaponStats>[]; visual: Visual;
  attackAngle?: number; blastRadius?: number; chainRange?: number; requiresUnlock?: boolean;
}
export interface Wave {
  id: string; name: string; waveNumber: number; duration: number;
  interval: number; batch: number; maxEnemies: number;
  enemies: { enemyId: string; weight: number }[];
  /** featured elites are named on the HUD, flee at Wave end and pay an elite supply; minDepth gates deeper additions. */
  /** hp: depth-1 max HP whichever elite the Run drew; it replaces hpMultiplier once the elite is known. */
  elites?: { at: number; enemyId: string; hpMultiplier: number; hp?: number; rewardMultiplier: number; modifiers?: import('./eliteModifiers').EliteModifierId[]; featured?: boolean; title?: string; minDepth?: number }[];
  /** Final-seconds rush: faster spawns and richer magic stone drops. */
  surge?: { name: string; lastSeconds: number; spawnMultiplier: number; rewardMultiplier: number };
  boss?: { enemyId: string };
}
export interface ArenaSize { arenaWidth: number; arenaHeight: number }
export interface MapData extends ArenaSize {
  id: string; name: string; description: string; seed: number;
  thumbnail: import('./images').ImageId;
  backgroundTheme: 'neighborhood'; totalWaves: number; bossWave: number;
  waveDefinitions: Wave[]; clearReward: number;
  /** Featured elite bodies of this map; every Run draws one of them for all its elite Waves. */
  elitePool?: string[];
  /** Standalone scenery; blocksMovement:false makes the footprint visual only. */
  objects?: { id: string; position: Vec2; footprint: { width: number; height: number }; blocksMovement?: boolean }[];
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

/** spiral: the boss keeps circling at `radius` and fires `volleys` rings of `count` bullets, `interval` seconds apart, each ring turned by `turn` radians. */
export interface BossPattern { type: 'charge' | 'aoe' | 'summon' | 'volley' | 'spiral'; warning: number; cooldown: number; radius: number; damageMultiplier: number; count: number; childId?: string; volleys?: number; interval?: number; turn?: number }
