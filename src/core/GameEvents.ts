export type GameEvent = 'weaponFired' | 'enemyHit' | 'enemyKilled'
  | 'magicStoneCollected'
  | 'purchase' | 'reroll' | 'lock' | 'weaponPurchase' | 'branchChoice' | 'critical' | 'eliteSpawned' | 'waveStarted' | 'waveCompleted' | 'slashAttack' | 'orbitAttack' | 'chainAttack' | 'bombardAttack' | 'piercingAttack' | 'turretFired' | 'minePlaced' | 'mineExploded' | 'fieldActivated'
  | 'playerHit' | 'bossSpawned' | 'stageClear' | 'gameOver';
export type GameEventSink = (event: GameEvent) => void;
export const ignoreGameEvent: GameEventSink = () => {};

/** Audio presentation payloads remain separate from rule events and saves. */
export interface GameAudioEvent {
  kind: 'weapon' | 'enemy' | 'cleanup';
  weaponId?: string;
  stage?: string;
  action?: string;
  behavior?: string;
  monsterId?: string;
  enemyId?: number;
  attackId?: string | number;
  hopIndex?: number;
  delay?: number;
}
export type GameAudioEventSink = (event: GameAudioEvent) => void;
export const ignoreGameAudioEvent: GameAudioEventSink = () => {};

/** Presentation notifications only; a fixed set of event flags bound memory even without a consumer. */
export class GameEvents {
  private readonly pending = new Set<GameEvent>();
  private readonly pendingAudio: GameAudioEvent[] = [];
  emitAudio: GameAudioEventSink = event => {
    if (event.kind === 'cleanup') this.pendingAudio.length = 0;
    if (this.pendingAudio.length < 128) this.pendingAudio.push(event);
  };
  drainAudio(consume: GameAudioEventSink): void {
    for (const event of this.pendingAudio.splice(0)) consume(event);
  }
  emit: GameEventSink = event => { this.pending.add(event); };
  drain(consume: GameEventSink): void {
    if (this.pending.has('stageClear')) consume('stageClear');
    else if (this.pending.has('gameOver')) consume('gameOver');
    else for (const event of this.pending) consume(event);
    this.pending.clear();
  }
}
