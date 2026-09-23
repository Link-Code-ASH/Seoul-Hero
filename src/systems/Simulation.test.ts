import {describe,expect,it} from 'vitest';
import {Simulation} from '../core/Simulation';
import {createDefaultMeta} from '../state/MetaState';
import {GAME_CONFIG} from '../data/config';
import {weapons} from '../data/weapons';
import {calculateDamage,weaponStats} from './CombatSystem';

const viewport={width:1280,height:720};
const make=()=>new Simulation('awakener','seoul',createDefaultMeta(),()=>0.4);

describe('simulation boundary',()=>{
 it('normalizes diagonal movement and freezes while paused',()=>{const sim=make();sim.state.invincible=true;for(let i=0;i<10;i++)sim.update(.1,{x:1,y:1},viewport);expect(Math.hypot(sim.state.player.x,sim.state.player.y)).toBeCloseTo(210);const before=sim.state.stageCombatTime;sim.pause();sim.update(1,{x:1,y:0},viewport);expect(sim.state.stageCombatTime).toBe(before);sim.resume();sim.update(.1,{x:0,y:0},viewport);expect(sim.state.stageCombatTime).toBeGreaterThan(before);});
 it('bounds invalid and background-tab deltas',()=>{const sim=make();sim.update(NaN,{x:0,y:0},viewport);sim.update(-1,{x:0,y:0},viewport);expect(sim.state.stageCombatTime).toBe(0);sim.update(10000,{x:1,y:0},viewport);expect(sim.state.stageCombatTime).toBeLessThanOrEqual(GAME_CONFIG.time.maxFrameDelta);});
 it('enters the shop without experience or a reward phase',()=>{const sim=make();sim.completeWave();expect(sim.state.phase).toBe('postWave');expect(sim.continuePostWave()).toBe(true);expect(sim.state.phase).toBe('shop');expect(sim.state).not.toHaveProperty('experience');expect(sim.state).not.toHaveProperty('pendingWeaponChoices');});
 it('keeps boss combat active until the boss dies',()=>{const sim=make();sim.state.invincible=true;sim.goToWave(20);sim.setTime(900);expect(sim.state.phase).toBe('waveActive');sim.completeWave();expect(sim.state.phase).toBe('waveActive');sim.clearEnemies();expect(sim.state.phase).toBe('stageClear');});
 it('calculates damage and cumulative weapon levels without mutating data',()=>{const sim=make(),definition=weapons.manaBolt!;const original=structuredClone(definition);sim.state.calculatedStats.damage=1.2;expect(calculateDamage(22,1.2)).toBe(26);const base=weaponStats(definition,1,sim.state),stats=weaponStats(definition,4,sim.state);expect(stats.damage).toBeGreaterThan(base.damage);expect(definition).toEqual(original);});
});
