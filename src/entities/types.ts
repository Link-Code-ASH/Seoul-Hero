import type { Vec2, Visual } from '../data/types';
export interface Player extends Vec2 { hp: number; maxHp: number; radius: number; moveSpeed: number; pickupRadius: number; invulnerability: number; visual: Visual }
export interface Enemy extends Vec2 {
  id: number; definitionId: string; hp: number; maxHp: number; radius: number; moveSpeed: number;
  contactDamage: number; magicStoneDrop: number; visual: Visual;
  elite: boolean; boss: boolean; hitFlash: number;
  armor: number; baseArmor: number; regeneration: number; cursedAura: boolean;
  eliteModifiers: import('../data/eliteModifiers').EliteModifierId[];
  age: number; timer: number; action: 'move' | 'warning' | 'dash'; aimX: number; aimY: number;
  pattern: number; summonCount: number; auraTimer: number; alpha: number; rewardEligible: boolean;
}
export interface Projectile extends Vec2 {
  fromStructure?: boolean;
  id: number; vx: number; vy: number; radius: number; damage: number; remaining: number;
  attack?: import('../stats/Damage').AttackContext;
  penetration: number; hitIds: Set<number>; visual: Visual;
}
export interface Pickup extends Vec2 { id: number; radius: number; value: number; age: number; kind: 'magicStone'; units?: number; tier?: import('../data/magicStoneConfig').MagicStoneTier }
export interface HostileProjectile extends Vec2 { vx: number; vy: number; damage: number; radius: number; remaining: number }
export interface HostileHazard extends Vec2 { damage: number; radius: number; warning: number; remaining: number; triggered: boolean }
