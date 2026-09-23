import {describe,it,expect} from 'vitest';
import {Simulation} from './Simulation';
import {createDefaultMeta} from '../state/MetaState';
import {createEnemy} from '../systems/EnemyFactory';
import {items} from '../data/items';
import {enemies} from '../data/enemies';
import {weapons} from '../data/weapons';
import {SIMULATION_CONFIG} from '../data/simulationConfig';
import {CollisionSystem} from '../systems/CollisionSystem';
import type {GameEvent} from './GameEvents';
const make=()=>new Simulation('awakener','seoul',createDefaultMeta(),()=>0.4);
const drain=(sim:Simulation)=>{const a:GameEvent[]=[];sim.events.drain(e=>a.push(e));return a;};
const step=(s:Simulation)=>s.update(.02,{x:0,y:0},{width:1280,height:720});
describe('final integration',()=>{
 it('retains required content and distinct enemy silhouette metadata',()=>{
  expect(Object.values(enemies).filter(e=>!e.tags.includes('BOSS'))).toHaveLength(12);
  expect(Object.values(enemies).filter(e=>e.tags.includes('BOSS'))).toHaveLength(2);
 expect(Object.values(weapons).filter(w=>w.structure)).toHaveLength(3);
 expect(Object.values(items)).toHaveLength(30);
  expect(new Set(Object.values(enemies).map(e=>e.visual.sprite??e.visual.motif)).size).toBe(14);
  expect(Object.values(enemies).every(e=>Boolean(e.visual.sprite))).toBe(true);
  expect(Object.values(weapons).filter(w=>w.structure).every(w=>Boolean(w.structure?.sprite))).toBe(true);
  expect(weapons.guardianDaggers?.visual.sprite).toBe('guardianShuriken');
  expect(weapons.piercingShot?.visual.sprite).toBe('piercingFx');
 });
 it('opens the combined shop directly after a wave',()=>{
  const s=make();s.completeWave();expect(s.state.phase).toBe('postWave');expect(s.continuePostWave()).toBe(true);
  expect(s.state.phase).toBe('shop');expect(s.state.shop.weaponStock.slots).toHaveLength(4);expect(s.state.shop.itemStock.slots).toHaveLength(4);
 });
 it('announces successful shop operations, not rejected purchases',()=>{
  const s=make();s.debugShop();drain(s);s.state.runCurrency=0;
  expect(s.buyShopItem(0)).toBe(false);expect(drain(s)).toEqual([]);
  s.state.runCurrency=100;s.lockShopItem(0);expect(drain(s)).toContain('lock');
  const locked=s.state.shop.itemStock.slots[0]!.itemId;s.rerollShopItems();expect(drain(s)).toContain('reroll');
  expect(s.state.shop.itemStock.slots[0]!.itemId).toBe(locked);s.buyShopItem(0);expect(drain(s)).toContain('purchase');
 });
 it('developer item reset removes only item effects',()=>{
  const s=make(),before={...s.state.calculatedStats};s.debugItem('energyDrink');expect(s.state.calculatedStats.attackSpeed).toBeGreaterThan(before.attackSpeed);
  s.debugClearItems();expect(s.state.calculatedStats).toEqual(before);expect(s.state.runItems).toEqual([]);
 });
 it('rarity preview respects lock and normal purchase gating',()=>{
  const s=make();s.debugShop();s.lockShopItem(0);const locked=s.state.shop.itemStock.slots[0]!.itemId;
  s.debugRarity('LEGENDARY');expect(s.state.shop.itemStock.slots[0]!.itemId).toBe(locked);
  s.state.runCurrency=10000;expect(s.buyShopItem(1)).toBe(false);
 });
 it('signals elite and critical hits without a second critical roll',()=>{
  const s=make();drain(s);s.spawnEnemy('crawler',['GIANT']);expect(drain(s)).toContain('eliteSpawned');
  let rolls=0;const c=new CollisionSystem(s.events.emit,()=>{rolls++;return 0;});
  c.hit(s.state.enemies[0]!,5,s.state,{criticalChance:1,criticalDamage:2,lifesteal:0,healingRemaining:0});
  expect(rolls).toBe(1);expect(drain(s)).toContain('critical');
 });
 it.each([['autoTurret','turretFired'],['mineLayer','mineExploded'],['manaField','fieldActivated']] as const)('%s emits its own sound from actual combat', (id,event)=>{
  const s=make();s.state.invincible=true;s.state.ownedWeapons=[{id,level:1,cooldownRemaining:0}];step(s);
  const placed=s.state.structures[0]!;const enemy=createEnemy(999,'crawler',{x:placed.x+10,y:placed.y})!;enemy.moveSpeed=0;enemy.hp=10000;s.state.enemies.push(enemy);
  step(s);expect(drain(s)).toContain(event);
 });
 it('bounds a stress population and clears spatial references on wave exit',()=>{
  const s=make();s.state.invincible=true;for(let n=0;n<1200;n++)s.spawnEnemy('crawler');
  expect(s.state.enemies).toHaveLength(SIMULATION_CONFIG.maxDebugEnemies);for(let n=0;n<60;n++)step(s);
  s.completeWave();expect(s.state.enemies).toHaveLength(0);expect(s.state.projectiles).toHaveLength(0);
  expect(s.state.structures).toHaveLength(0);expect(s.state.hostileProjectiles).toHaveLength(0);expect(s.state.hazards).toHaveLength(0);
  s.continuePostWave();s.nextWave();step(s);expect(s.state.phase).toBe('waveActive');
 });
});
