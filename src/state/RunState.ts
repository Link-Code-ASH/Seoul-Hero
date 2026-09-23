import type { Enemy, Pickup, Player, Projectile } from '../entities/types';
import type { PlayerStats } from '../data/stats';
import type { StatModifier } from '../stats/PlayerStats';
export type { RunPhase } from './RunPhase';
import type { RunPhase } from './RunPhase';
import type { RunEffect } from './RunEffect';
export interface RunState {
  phase: RunPhase; characterId: string; mapId: string; startingWeaponId: string; player: Player;
  gateDepth: number; weeklyTraitId: string; blessingId: string;
  characterHighestClearedDepth: number; characterRewardedThroughDepth: number;
  enemyDifficulty: import('../data/gateProgression').EnemyDifficulty;
  currentWave: number; totalWaves: number; waveElapsedTime: number; waveRemainingTime: number; stageCombatTime: number; waveStartKills: number;
  curseExposure:number; reward?: import('../meta/StageReward').StageReward;
  kills: number; earnedMetaCurrency: number; earnedAssociationCoins: number;
  ownedWeapons: { id: string; level: number; cooldownRemaining: number; branchId?: 'A' | 'B' }[];
  structures: { id: number; weaponId: string; x: number; y: number; remaining: number; cooldown: number }[];
  structureEffects: { sourceId: string; tag: import('../data/stats').WeaponCapability; type: 'maxCount'; value: number }[];
  pendingBranchWeaponId?: string;
  baseStats: PlayerStats; statModifiers: StatModifier[]; calculatedStats: PlayerStats;
  combatPermissions: { indirectLifesteal: boolean };
  shop: {
    wave: number;
    itemStock: { rerolls: number; slots: { itemId: string | null; locked: boolean }[] };
    weaponStock: { rerolls: number; slots: { weaponId: string | null; targetLevel: number; locked: boolean }[] };
  };
  unlockedItemIds: string[]; itemEffects: import('../data/items').ItemEffect[];
  /** Stage spending money always starts at zero. Deferred stones unlock beside future field pickups. */
  runCurrency: number; startingCurrency: number; collectedMagicStone: number;
  /** Previous Stage wallet stones that can still be released beside collected stones. */
  walletBonusRemaining: number;
  /** Stones missed during this Stage. They stay locked until the next Stage. */
  walletStoredThisRun: number;
  runItems: { id: string; count: number }[];
  availableWeaponIds: string[];
  effects: RunEffect[];
  hostileProjectiles: import('../entities/types').HostileProjectile[]; hazards: import('../entities/types').HostileHazard[];
  enemies: Enemy[]; projectiles: Projectile[]; pickups: Pickup[];
  bossSpawned: boolean; waveId: string;
  invincible: boolean;
}

