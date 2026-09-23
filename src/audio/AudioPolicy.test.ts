import { describe, expect, it } from 'vitest';
import { SoundGate, musicForScene } from './AudioPolicy';
import { Simulation } from '../core/Simulation';
import { GameEvents } from '../core/GameEvents';
import type { GameEvent } from '../core/GameEvents';
import { createDefaultMeta } from '../state/MetaState';
import { images } from '../data/images';
import { bgm, sfx } from '../data/audio';

const create = (): Simulation => new Simulation('awakener', 'seoul', createDefaultMeta(), () => 0.4);
const drain = (sim: Simulation): GameEvent[] => { const events: GameEvent[] = []; sim.events.drain(event => events.push(event)); return events; };
describe('audio and visual integration contracts', () => {
  it('registers every required image, sound and music file with a real bundled URL', () => {
    expect(Object.keys(images).length).toBeGreaterThanOrEqual(60);
    expect(Object.keys(sfx).length).toBeGreaterThanOrEqual(27);
    expect(Object.keys(bgm)).toHaveLength(3);
    for (const asset of [...Object.values(images), ...Object.values(bgm)]) expect(asset.url.length).toBeGreaterThan(10);
    for (const sound of Object.values(sfx)) {
      expect(sound.urls.length).toBeGreaterThan(0);
      for (const url of sound.urls) expect(url.length).toBeGreaterThan(10);
    }
  });
  it('chooses menu, combat and boss music without changing run state', () => {
    const sim = create();
    expect(musicForScene('lobby', null)).toBe('menu');
    expect(musicForScene('shop', sim.state)).toBe('combat');
    expect(musicForScene('waveActive', sim.state)).toBe('combat');
    sim.spawnBoss();
    expect(musicForScene('shop', sim.state)).toBe('boss');
    expect(musicForScene('paused', sim.state)).toBe('boss');
    expect(musicForScene('result', sim.state)).toBeNull();
  });
  it('throttles repeated sounds by real time and reserves voices for important cues', () => {
    const gate = new SoundGate();
    expect(gate.allow('weaponFired', 1, 0)).toBe(true);
    expect(gate.allow('weaponFired', 1.01, 0)).toBe(false);
    expect(gate.allow('weaponFired', 2, 12)).toBe(false);
    expect(gate.allow('playerHit', 2, 12)).toBe(true);
    expect(gate.allow('stageClear', 3, 16)).toBe(false);
    expect(gate.allow('weaponFired', 3, 0)).toBe(true);
  });
  it('coalesces high-speed frame events and prioritizes the terminal result', () => {
    const bus = new GameEvents(), events: GameEvent[] = [];
    for (let i = 0; i < 1000; i++) bus.emit('enemyKilled');
    bus.drain(event => events.push(event));
    expect(events).toEqual(['enemyKilled']);
    bus.emit('enemyHit'); bus.emit('stageClear');
    const ending: GameEvent[] = []; bus.drain(event => ending.push(event));
    expect(ending).toEqual(['stageClear']);
    bus.drain(() => { throw new Error('events must be consumed only once'); });
  });
  it('announces a boss once, and reports victory after actual death resolution', () => {
    const sim = create(); sim.spawnBoss(); sim.spawnBoss();
    expect(drain(sim)).toEqual(['waveStarted', 'bossSpawned']);
    sim.clearEnemies();
    expect(drain(sim)).toEqual(['stageClear']);
    expect(sim.state.phase).toBe('stageClear');
  });
  it('reports shop and game-over transitions', () => {
    const sim = create(); sim.completeWave(); sim.continuePostWave();
    expect(drain(sim)).toEqual(['waveStarted','waveCompleted']);
    sim.update(0.1, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(drain(sim)).toEqual([]);
    sim.endRun();
    expect(drain(sim)).toEqual(['gameOver']);
  });
  it('produces hit, death, drop collection and player damage events from combat', () => {
    const sim = create(); sim.state.invincible = true;
    sim.spawnEnemy('crawler');
    const enemy = sim.state.enemies[0]!; enemy.x = 100; enemy.y = 0;
    const seen = new Set<GameEvent>();
    for (let i = 0; i < 100; i++) {
      sim.update(0.05, { x: 0, y: 0 }, { width: 1280, height: 720 });
      drain(sim).forEach(event => seen.add(event));
    }
    for (const event of ['weaponFired', 'enemyHit', 'enemyKilled', 'magicStoneCollected'] as const) expect(seen.has(event)).toBe(true);
    sim.state.invincible = false; sim.spawnEnemy('crawler');
    const contact = sim.state.enemies.at(-1)!; contact.x = sim.state.player.x; contact.y = sim.state.player.y;
    sim.update(0.05, { x: 0, y: 0 }, { width: 1280, height: 720 });
    expect(drain(sim)).toContain('playerHit');
  });
});
