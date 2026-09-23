import {describe,expect,it} from 'vitest';
import {createDefaultMeta} from '../state/MetaState';
import {createRun} from '../state/createRun';
import {gateDifficulty} from '../data/gateProgression';
import {BalanceTelemetryCollector} from './BalanceTelemetry';

describe('starting weapon and low-cost balance telemetry',()=>{
  it('starts Song Jinwoo with the selected combat weapon and no forced signature',()=>{
    const run=createRun('awakener','seoul',createDefaultMeta(),1,'','','manaSword');
    expect(run.startingWeaponId).toBe('manaSword');
    expect(run.ownedWeapons).toEqual([{id:'manaSword',level:1,cooldownRemaining:0}]);
  });
  it('rejects a structure as a starting weapon',()=>{
    const meta=createDefaultMeta();meta.sharedWeapons.autoTurret={unlocked:true,fragments:0,level:0};
    expect(()=>createRun('awakener','seoul',meta,1,'','','autoTurret')).toThrow('시작 무기');
  });
  it('uses the comfortable linear gate curve at depth 1, 10 and 20',()=>{
    expect(gateDifficulty(1)).toMatchObject({hp:1,damage:1,speed:1,spawn:1,eliteChance:0});
    expect(gateDifficulty(10).hp).toBeCloseTo(1.54);expect(gateDifficulty(10).damage).toBeCloseTo(1.315);
    expect(gateDifficulty(20).hp).toBeCloseTo(2.14);expect(gateDifficulty(20).speed).toBeCloseTo(1.019);
  });
  it('summarizes damage without storing individual hit events',()=>{
    const run=createRun('awakener','seoul',createDefaultMeta(),1,'','','manaBolt');
    const telemetry=new BalanceTelemetryCollector(run);telemetry.damage('manaBolt',12,false);telemetry.damage('manaBolt',20,true);
    run.kills=2;run.stageCombatTime=4;run.phase='gameOver';
    expect(telemetry.finish().weapons[0]).toMatchObject({id:'manaBolt',damage:32,hits:2,criticals:1,kills:0});
  });
});
