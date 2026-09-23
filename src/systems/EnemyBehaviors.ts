import { ENEMY_RULES as R } from '../data/enemyConfig';
import type { EnemyDefinition } from '../data/types';
import type { Enemy } from '../entities/types';
import type { RunState } from '../state/RunState';
import type { HostileAttackSystem } from './HostileAttackSystem';
export interface EnemyContext { run: RunState; dt: number; def: EnemyDefinition; attacks: HostileAttackSystem;
  nearby: (enemy: Enemy, radius: number) => readonly Enemy[];
  summon: (parent: Enemy, id: string, count: number) => void;
}
export function moveToward(e: Enemy, x: number, y: number, dt: number, speed = e.moveSpeed): void {
  const dx = x - e.x, dy = y - e.y, d = Math.hypot(dx, dy); if (!d) return;
  const step = Math.min(d, speed * dt); e.x += dx / d * step; e.y += dy / d * step;
}
function chase(e: Enemy, c: EnemyContext): void { moveToward(e, c.run.player.x, c.run.player.y, c.dt); }
function aim(e: Enemy, c: EnemyContext): void { e.aimX = c.run.player.x; e.aimY = c.run.player.y; }
function distance(e: Enemy, c: EnemyContext): number { return Math.hypot(c.run.player.x - e.x, c.run.player.y - e.y); }
function charge(e: Enemy, c: EnemyContext, ambush = false): void {
  const tuning = c.def.charge ?? { triggerRange: R.chargeTriggerRange, warning: ambush ? R.ambushWarning : R.chargeWarning, duration: R.chargeDuration, speed: ambush ? R.ambushSpeed : R.chargeSpeed, cooldown: ambush ? R.ambushCooldown : R.chargeCooldown };
  if (e.action === 'warning') {
    if (e.timer <= 0) { e.action = 'dash'; e.timer = tuning.duration; }
  } else if (e.action === 'dash') {
    moveToward(e, e.aimX, e.aimY, c.dt, tuning.speed);
    if (e.timer <= 0) { e.action = 'move'; e.timer = tuning.cooldown; }
  } else if (e.timer <= 0 && distance(e, c) < tuning.triggerRange) {
    aim(e, c); e.action = 'warning'; e.timer = tuning.warning;
  } else if (ambush) {
    const a = Math.atan2(c.run.player.y - e.y, c.run.player.x - e.x) + 0.6;
    moveToward(e, e.x + Math.cos(a) * 200, e.y + Math.sin(a) * 200, c.dt);
  } else chase(e, c);
  e.alpha = ambush && e.action === 'move' ? 0.4 : 1;
}
function ranged(e: Enemy, c: EnemyContext): void {
  if (e.action === 'warning') {
    if (e.timer <= 0) { c.attacks.shoot(c.run, e.x, e.y, Math.atan2(e.aimY - e.y, e.aimX - e.x), e.contactDamage); e.action = 'move'; e.timer = R.rangedCooldown; }
    return;
  }
  const d = distance(e, c);
  if (d < R.rangedDistance * 0.7) moveToward(e, e.x * 2 - c.run.player.x, e.y * 2 - c.run.player.y, c.dt);
  else if (d > R.rangedDistance) chase(e, c);
  if (e.timer <= 0 && d < R.rangedDistance * 1.5) { aim(e, c); e.action = 'warning'; e.timer = R.rangedWarning; }
}
function boss(e: Enemy, c: EnemyContext): void {
  const patterns = c.def.bossPatterns; if (!patterns?.length) { chase(e, c); return; }
  const pattern = patterns[e.pattern % patterns.length]!;
  if (e.action === 'dash') {
    moveToward(e, e.aimX, e.aimY, c.dt, R.chargeSpeed);
    if (e.timer <= 0) { e.action = 'move'; e.timer = pattern.cooldown; e.pattern++; }
    return;
  }
  if (e.action === 'warning') {
    if (e.timer > 0) return;
    if (pattern.type === 'charge') { e.action = 'dash'; e.timer = R.chargeDuration; return; }
    if (pattern.type === 'volley') {
      const angle = Math.atan2(e.aimY - e.y, e.aimX - e.x);
      for (let i = 0; i < pattern.count; i++) c.attacks.shoot(c.run, e.x, e.y, angle + (i - (pattern.count - 1) / 2) * 0.22, e.contactDamage * pattern.damageMultiplier);
    }
    if (pattern.type === 'summon' && pattern.childId) c.summon(e, pattern.childId, pattern.count);
    e.action = 'move'; e.timer = pattern.cooldown; e.pattern++; return;
  }
  chase(e, c);
  if (e.timer <= 0) {
    aim(e, c); e.action = 'warning'; e.timer = pattern.warning;
    if (pattern.type === 'aoe') c.attacks.area(c.run, e.aimX, e.aimY, pattern.radius, pattern.warning, e.contactDamage * pattern.damageMultiplier);
  }
}
type Handler = (enemy: Enemy, context: EnemyContext) => void;
export const enemyBehaviors: Record<EnemyDefinition['behavior'], Handler> = {
  chase, splitter: chase,
  skirmish(e, c) {
    const a = Math.atan2(c.run.player.y - e.y, c.run.player.x - e.x) + Math.sin(e.age * 5 + e.id) * R.weaveAmplitude;
    moveToward(e, e.x + Math.cos(a) * 200, e.y + Math.sin(a) * 200, c.dt);
  },
  tank(e, c) { chase(e, c); if (e.timer <= 0 && distance(e, c) < R.tankRadius) { c.attacks.area(c.run, e.x, e.y, R.tankRadius, R.tankWarning, e.contactDamage); e.timer = R.tankCooldown; } },
  ranged,
  swarm(e, c) {
    const chaseX = c.run.player.x - e.x;
    const chaseY = c.run.player.y - e.y;
    const chaseLength = Math.hypot(chaseX, chaseY) || 1;
    let directionX = chaseX / chaseLength;
    let directionY = chaseY / chaseLength;
    let separationX = 0, separationY = 0, count = 0;
    for (const neighbor of c.nearby(e, R.swarmRadius)) {
      if (neighbor === e || neighbor.hp <= 0) continue;
      const dx = e.x - neighbor.x;
      const dy = e.y - neighbor.y;
      const distance = Math.hypot(dx, dy);
      if (distance > 0 && distance < R.swarmRadius) {
        const weight = 1 - distance / R.swarmRadius;
        separationX += dx / distance * weight;
        separationY += dy / distance * weight;
      }
      if (++count >= R.swarmNeighbors) break;
    }
    // 군집 회피가 추적 방향을 완전히 상쇄하면 거미가 멈칫해 보인다.
    // 회피는 제한적으로 섞고, 매 프레임 플레이어 방향의 전진 성분을 보존한다.
    directionX += separationX * 0.42;
    directionY += separationY * 0.42;
    const directionLength = Math.hypot(directionX, directionY);
    if (directionLength < 0.2) {
      directionX = chaseX / chaseLength;
      directionY = chaseY / chaseLength;
    } else {
      directionX /= directionLength;
      directionY /= directionLength;
    }
    moveToward(e, e.x + directionX * 200, e.y + directionY * 200, c.dt);
  },
  charge: (e, c) => charge(e, c), ambush: (e, c) => charge(e, c, true),
  bomber(e, c) {
    if (e.action === 'warning') {
      if (e.timer <= 0) { c.attacks.area(c.run, e.x, e.y, R.bomberRadius, 0, e.contactDamage); e.hp = 0; }
    } else if (distance(e, c) <= R.bomberTrigger) { e.action = 'warning'; e.timer = R.bomberWarning; }
    else chase(e, c);
  },
  support(e, c) {
    chase(e, c);
    if (e.timer <= 0) {
      for (const other of c.nearby(e, R.supportRadius)) if (other !== e && other.hp > 0 && Math.hypot(other.x - e.x, other.y - e.y) <= R.supportRadius) other.hp = Math.min(other.maxHp, other.hp + other.maxHp * R.supportHealFraction);
      e.timer = R.supportInterval;
    }
  },
  summoner(e, c) { rangedMovement(e, c); if (e.timer <= 0 && c.def.childId) { c.summon(e, c.def.childId, 2); e.timer = R.summonInterval; } },
  defender(e, c) { e.armor = e.baseArmor + (e.age % R.defenderCycle < R.defenderGuard ? R.defenderArmor : 0); chase(e, c); },
  boss,
};
function rangedMovement(e: Enemy, c: EnemyContext): void { if (distance(e, c) > R.rangedDistance) chase(e, c); }
