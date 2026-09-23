export type GameEvent = 'weaponFired' | 'enemyHit' | 'enemyKilled'
  | 'magicStoneCollected'
  | 'purchase' | 'reroll' | 'lock' | 'weaponPurchase' | 'branchChoice' | 'critical' | 'eliteSpawned' | 'waveStarted' | 'waveCompleted' | 'slashAttack' | 'orbitAttack' | 'chainAttack' | 'bombardAttack' | 'piercingAttack' | 'turretFired' | 'minePlaced' | 'mineExploded' | 'fieldActivated'
  | 'playerHit' | 'bossSpawned' | 'stageClear' | 'gameOver';
export type GameEventSink = (event: GameEvent) => void;
export const ignoreGameEvent: GameEventSink = () => {};

/** Presentation notifications only; a fixed set of event flags bound memory even without a consumer. */
export class GameEvents {
  private readonly pending = new Set<GameEvent>();
  emit: GameEventSink = event => { this.pending.add(event); };
  drain(consume: GameEventSink): void {
    if (this.pending.has('stageClear')) consume('stageClear');
    else if (this.pending.has('gameOver')) consume('gameOver');
    else for (const event of this.pending) consume(event);
    this.pending.clear();
  }
}
