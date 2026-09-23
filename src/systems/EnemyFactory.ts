import { enemies } from '../data/enemies';
import { eliteModifiers, type EliteModifierId } from '../data/eliteModifiers';
import { CURSE_RULES, ENEMY_RULES } from '../data/enemyConfig';
import type { Enemy } from '../entities/types';
import type { Vec2 } from '../data/types';
import type { EnemyDifficulty } from '../data/gateProgression';
const BASE_DIFFICULTY: EnemyDifficulty = { hp: 1, damage: 1, speed: 1, spawn: 1, reward: 1, eliteChance: 0, eliteModifiers: [] };
export function curseBonuses(value: number) {
  const curse = Number.isFinite(value) ? Math.max(0, value) : 0;
  const scale = (rate: number) => Math.min(CURSE_RULES.maxIntensity, 1 + curse * rate);
  return { hp: scale(CURSE_RULES.hpPerPoint), damage: scale(CURSE_RULES.damagePerPoint), speed: scale(CURSE_RULES.speedPerPoint),
    spawn: scale(CURSE_RULES.spawnPerPoint), eliteChance: Math.min(CURSE_RULES.maxEliteChance, curse * CURSE_RULES.eliteChancePerPoint) };
}
export function createEnemy(id: number, definitionId: string, position: Vec2, curse = 0, modifiers: readonly EliteModifierId[] = [], boss = false, hpMultiplier = 1, rewardMultiplier = 1, gate: EnemyDifficulty = BASE_DIFFICULTY): Enemy | undefined {
  const def = Object.hasOwn(enemies, definitionId) ? enemies[definitionId] : undefined;
  if (!def) return undefined;
  const unique = [...new Set(modifiers)];
  let hp = hpMultiplier, speed = 1, damage = 1, size = 1, reward = rewardMultiplier, armor = 0, regeneration = 0, aura = false;
  for (const id of unique) {
    const mod = eliteModifiers[id]; if (!mod) continue;
    hp *= mod.hp; speed *= mod.speed; damage *= mod.damage; size *= mod.size; reward *= mod.reward;
    armor += mod.armor; regeneration += mod.regeneration; aura ||= mod.aura;
  }
  const elite = !boss && (unique.length > 0 || hpMultiplier > 1), c = curseBonuses(curse);
  const maxHp = def.maxHp * hp * c.hp * gate.hp;
  return { id, definitionId, ...position, hp: maxHp, maxHp, radius: def.radius * size,
    moveSpeed: def.moveSpeed * speed * c.speed * gate.speed, contactDamage: def.contactDamage * damage * c.damage * gate.damage,
    magicStoneDrop: def.magicStoneDrop * reward * gate.reward, visual: def.visual, elite, boss, hitFlash: 0,
    armor, baseArmor: armor, regeneration, cursedAura: aura, eliteModifiers: unique,
    age: 0, timer: 0, action: 'move', aimX: 0, aimY: 0, pattern: 0, summonCount: 0, auraTimer: ENEMY_RULES.auraInterval, alpha: 1, rewardEligible: true };
}
