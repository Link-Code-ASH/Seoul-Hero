import {describe,expect,it} from 'vitest';
import {Simulation} from './Simulation';
import {RunSettlement} from './RunSettlement';
import {createDefaultMeta} from '../state/MetaState';
import {createRun} from '../state/createRun';
import {transitionRun} from '../state/RunPhase';

const make=()=>new Simulation('awakener','seoul',createDefaultMeta(),()=>0.3);

describe('Run phase and combined shop lifecycle',()=>{
 it('uses the explicit preparing, combat, post-wave and shop flow',()=>{
  const run=createRun('awakener','seoul',createDefaultMeta());expect(run.phase).toBe('preparing');
  expect(transitionRun(run,'shop')).toBe(false);expect(transitionRun(run,'waveActive')).toBe(true);expect(transitionRun(run,'postWave')).toBe(true);expect(transitionRun(run,'shop')).toBe(true);
 });
 it('stops combat time after a wave and enters one combined shop',()=>{
  const sim=make();sim.update(.1,{x:0,y:0},{width:1280,height:720});const time=sim.state.stageCombatTime;
  sim.completeWave();sim.update(.1,{x:1,y:0},{width:1280,height:720});expect(sim.state.stageCombatTime).toBe(time);
  expect(sim.continuePostWave()).toBe(true);expect(sim.state.phase).toBe('shop');expect(sim.state.shop.weaponStock.slots).toHaveLength(4);expect(sim.state.shop.itemStock.slots).toHaveLength(4);
  expect(sim.nextWave()).toBe(true);expect(sim.state.currentWave).toBe(2);
 });
 it('resets Run inventory while preserving Meta settlement',()=>{
  const meta=createDefaultMeta();meta.wallet.associationCoins=200;const sim=new Simulation('awakener','seoul',meta);sim.state.runCurrency=40;sim.state.runItems.push({id:'energyDrink',count:1});sim.endRun();
  const settlement=new RunSettlement();expect(settlement.settle(meta,sim.state)).toBe(true);expect(settlement.settle(meta,sim.state)).toBe(false);
  const next=createRun('awakener','seoul',meta);expect(next.runCurrency).toBe(0);expect(next.runItems).toEqual([]);expect(next.ownedWeapons).toHaveLength(1);
 });
});

