import {SpawnSystem} from '../systems/SpawnSystem';
import {maps} from '../data/maps';
import {it,expect} from 'vitest';
import {Simulation} from '../core/Simulation';
import {createDefaultMeta} from '../state/MetaState';
import {calculateStageReward} from './StageReward';
import {RunSettlement} from '../core/RunSettlement';
import {parseSave} from '../save/migrations';
import {purchaseUpgrade} from './progression';
import {curseBonuses,createEnemy} from '../systems/EnemyFactory';
import { SAVE_VERSION } from '../save/SaveData';
const make=()=>new Simulation('awakener','seoul',createDefaultMeta());
it('death pays completed waves only while the selected depth is uncleared',()=>{const sim=make();sim.state.currentWave=5;sim.state.waveElapsedTime=15;sim.endRun();expect(calculateStageReward(sim.state)).toMatchObject({completedWaves:4,failureReward:4,total:4});sim.state.characterHighestClearedDepth=1;expect(calculateStageReward(sim.state).failureReward).toBe(0);});
it('clear pays every unclaimed lower depth at a fixed rate',()=>{const clear=make();clear.state.gateDepth=20;clear.state.characterRewardedThroughDepth=4;clear.spawnBoss();clear.clearEnemies();expect(calculateStageReward(clear.state)).toMatchObject({firstClearDepths:16,firstClearReward:1600,total:1600});});
it('enemy and spawn curse caps are finite; enemy stats actually grow',()=>{expect(curseBonuses(1e9)).toMatchObject({hp:5,damage:5,speed:5,spawn:5,eliteChance:0.25});expect(curseBonuses(-10).spawn).toBe(1);const base=createEnemy(1,'crawler',{x:0,y:0})!,c=createEnemy(2,'crawler',{x:0,y:0},30)!;expect(c.maxHp).toBeGreaterThan(base.maxHp);expect(c.contactDamage).toBeGreaterThan(base.contactDamage);expect(c.moveSpeed).toBeGreaterThan(base.moveSpeed);});
it('v3 migrates balances and purchases, validates new stats and excludes run',()=>{const meta=createDefaultMeta();meta.wallet.associationCoins=321;meta.association.upgrades.power=2;const parsed=parseSave(JSON.stringify({saveVersion:3,meta,run:{runCurrency:999}}));expect(parsed.saveVersion).toBe(SAVE_VERSION);expect(parsed.meta.wallet.associationCoins).toBe(321);expect(parsed.meta.offlineReward.pendingRewards.associationCoins).toBe(0);expect(parsed.meta.association.upgrades.power).toBe(2);expect(parsed.meta.statistics.bestWave).toBe(0);expect('run' in parsed).toBe(false);});
it('new meta unlocks and Luck work and survive validation',()=>{const meta=createDefaultMeta();meta.wallet.associationCoins=1000;expect(purchaseUpgrade(meta,'fortune')).toBe(true);expect(purchaseUpgrade(meta,'circuit')).toBe(true);const saved=parseSave(JSON.stringify({saveVersion:5,meta}));expect(saved.meta.account.unlockedItemIds).toContain('bloodCircuit');const sim=new Simulation('awakener','seoul',saved.meta);expect(sim.state.calculatedStats.luck).toBe(2);expect(sim.state.ownedWeapons[0]!.id).toBe('manaBolt');expect(sim.state.runItems).toEqual([]);});
it('preview and repeated settlement never double pay',()=>{const meta=createDefaultMeta(),sim=make(),settle=new RunSettlement();sim.spawnBoss();sim.clearEnemies();settle.settle(meta,sim.state);calculateStageReward(sim.state);settle.settle(meta,sim.state);expect(meta.wallet.associationCoins).toBe(100);});

it('turret unlock gates rewards for new players',()=>{const meta=createDefaultMeta();expect(new Simulation('awakener','seoul',meta).state.availableWeaponIds).not.toContain('autoTurret');meta.wallet.associationCoins=100;expect(purchaseUpgrade(meta,'turretLicense')).toBe(true);expect(new Simulation('awakener','seoul',meta).state.availableWeaponIds).toContain('autoTurret');});

it('already unlocked content cannot charge currency again',()=>{const meta=createDefaultMeta();meta.sharedWeapons.autoTurret={unlocked:true,fragments:0,level:0};meta.wallet.associationCoins=500;expect(purchaseUpgrade(meta,'turretLicense')).toBe(false);expect(meta.wallet.associationCoins).toBe(500);});

it('Curse increases actual spawn frequency and rolls elites within the wave cap',()=>{const stage=maps.seoul!;const normal=make().state,hard=make().state;normal.enemies=[];hard.enemies=[];hard.calculatedStats.curse=100;let id=0;const a=new SpawnSystem(stage,()=>0,()=>++id),b=new SpawnSystem(stage,()=>0,()=>++id);const view={width:1280,height:720};for(let t=0;t<stage.waveDefinitions[0]!.interval*0.8;t+=0.01){a.update(normal,0.01,view);b.update(hard,0.01,view);}expect(hard.enemies.length).toBeGreaterThan(normal.enemies.length);expect(hard.enemies.some(e=>e.moveSpeed>normal.enemies[0]!.moveSpeed)).toBe(true);expect(hard.enemies.length).toBeLessThanOrEqual(stage.waveDefinitions[0]!.maxEnemies);});


