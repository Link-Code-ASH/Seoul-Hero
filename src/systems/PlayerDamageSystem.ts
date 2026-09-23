import type { RunState } from '../state/RunState';
import { armorDamage, dodges } from '../stats/Damage';
import { GAME_CONFIG } from '../data/config';
import { transitionRun } from '../state/RunPhase';
import { ignoreGameEvent, type GameEventSink } from '../core/GameEvents';
export function damagePlayer(state: RunState, damage: number, random: () => number = Math.random, emit: GameEventSink = ignoreGameEvent): boolean {
  const player = state.player;
  if (state.phase !== 'waveActive' || player.hp <= 0 || state.invincible || player.invulnerability > 0) return false;
  player.invulnerability = GAME_CONFIG.combat.invulnerabilitySeconds;
  if (dodges(state.calculatedStats.dodge, random)) return false;
  player.hp = Math.max(0, player.hp - armorDamage(damage, state.calculatedStats.armor));
  emit('playerHit');
  if (player.hp === 0) { transitionRun(state, 'gameOver'); emit('gameOver'); }
  return true;
}
