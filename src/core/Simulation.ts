import { items, type Rarity } from '../data/items';
import { addItem, applyItems } from '../systems/ItemSystem';
import { REWARD_CONFIG } from '../data/rewardConfig';
import { enterShop, buyItem, buyWeapon, rerollItems, rerollWeapons, toggleItemLock, toggleWeaponLock, chooseShopWeaponBranch, grantWeapon, itemRerollCost, weaponRerollCost, weaponPrice } from '../systems/ShopSystem';
import { characters } from '../data/characters';
import { WEAPON_CONFIG } from '../data/weaponConfig';
import { weapons } from '../data/weapons';
import type { EliteModifierId } from '../data/eliteModifiers';
import { transitionRun, isTerminal } from '../state/RunPhase';
import { ARENA_RULES, clampToArena } from '../world/Arena';
import { GAME_CONFIG } from '../data/config';
import { SIMULATION_CONFIG } from '../data/simulationConfig';
import { maps } from '../data/maps';
import type { Vec2 } from '../data/types';
import type { Projectile } from '../entities/types';
import type { MetaState } from '../state/MetaState';
import type { RunState } from '../state/RunState';
import { createRun } from '../state/createRun';
import { CombatSystem } from '../systems/CombatSystem';
import { EnemySystem } from '../systems/EnemySystem';
import { PickupSystem } from '../systems/PickupSystem';
import { SpawnSystem, type Viewport, type SpawnSnapshot } from '../systems/SpawnSystem';
import { GameEvents } from './GameEvents';
import { BalanceTelemetryCollector } from '../analytics/BalanceTelemetry';
import { declineRevival, useRevivalStone } from '../systems/RevivalSystem';
import { damagePlayer } from '../systems/PlayerDamageSystem';
import type { RevivalStoneGrade } from '../data/revivalStones';

type SavedProjectile = Omit<Projectile, 'hitIds'> & { hitIds: number[]; attackRef?: number };
export interface SimulationSnapshot {
  state: Omit<RunState, 'projectiles'> & { projectiles: SavedProjectile[] };
  sequence: number;
  spawn: SpawnSnapshot;
}

/** Pure simulation boundary: no browser, renderer, storage, or platform input dependencies. */
export class Simulation {
  readonly state: RunState;
  readonly events = new GameEvents();
  readonly telemetry: BalanceTelemetryCollector;
  private sequence = 0;
  private viewport: Viewport = { width: GAME_CONFIG.world.referenceWidth, height: GAME_CONFIG.world.referenceHeight };
  private readonly pickups: PickupSystem;
  private readonly combat: CombatSystem;
  private readonly spawn: SpawnSystem;
  private readonly enemySystem: EnemySystem;

  constructor(characterId: string, mapId: string, meta: MetaState, private readonly random: () => number = Math.random,
    setup: { gateDepth?: number; weeklyTraitId?: string; blessingId?: string; startingWeaponId?: string } = {}) {
    this.state = createRun(characterId, mapId, meta, setup.gateDepth ?? 1, setup.weeklyTraitId ?? '', setup.blessingId ?? '', setup.startingWeaponId);
    this.telemetry = new BalanceTelemetryCollector(this.state);
    const stage = maps[mapId];
    if (!stage) throw new Error('스테이지를 찾을 수 없습니다.');
    const nextId = () => ++this.sequence;
    this.pickups = new PickupSystem(nextId, this.events.emit);
    this.enemySystem = new EnemySystem(nextId, random, this.events.emit);
    this.combat = new CombatSystem(nextId, this.pickups, stage.clearReward, this.events.emit, random, (state,enemy)=>{this.telemetry.enemyKilled(enemy.definitionId);this.enemySystem.onDeath(state,enemy);}, (weaponId,damage,critical,killed)=>this.telemetry.damage(weaponId,damage,critical,killed), enemyId=>this.telemetry.playerHit(enemyId));
    this.spawn = new SpawnSystem(stage, random, nextId, this.events.emit);
    this.beginWave(1);
  }

  /** Browser-local checkpoint. Reopening a live Wave always starts paused. */
  snapshot(): SimulationSnapshot {
    const attackRefs = new Map<NonNullable<Projectile['attack']>, number>();
    return {
      state: {
        ...this.state,
        phase: this.state.phase === 'waveActive' ? 'paused' : this.state.phase,
        projectiles: this.state.projectiles.map(({ hitIds, ...projectile }) => {
          const attack = projectile.attack;
          if (attack && !attackRefs.has(attack)) attackRefs.set(attack, attackRefs.size);
          return { ...projectile, hitIds: [...hitIds], attackRef: attack ? attackRefs.get(attack) : undefined };
        }),
      },
      sequence: this.sequence,
      spawn: this.spawn.snapshot(),
    };
  }

  restore(snapshot: SimulationSnapshot): void {
    // Only copy fields in the current RunState schema; a newer app may have
    // added a field since this local checkpoint was written.
    const current = this.state as unknown as Record<string, unknown>;
    const saved = snapshot.state as unknown as Record<string, unknown>;
    for (const key of Object.keys(current)) if (Object.hasOwn(saved, key)) current[key] = saved[key];
    if (typeof snapshot.state.pendingBranchWeaponId === 'string')
      this.state.pendingBranchWeaponId = snapshot.state.pendingBranchWeaponId;
    const attacks = new Map<number, NonNullable<Projectile['attack']>>();
    this.state.projectiles = snapshot.state.projectiles.map(({ hitIds, attackRef, ...projectile }) => {
      const restored: Projectile = { ...projectile, hitIds: new Set(hitIds) };
      if (attackRef !== undefined && projectile.attack) {
        if (!attacks.has(attackRef)) attacks.set(attackRef, projectile.attack);
        restored.attack = attacks.get(attackRef);
      }
      return restored;
    });
    this.sequence = Math.max(snapshot.sequence,
      ...this.state.enemies.map(entity => entity.id),
      ...this.state.projectiles.map(entity => entity.id),
      ...this.state.pickups.map(entity => entity.id),
      ...this.state.structures.map(entity => entity.id));
    this.spawn.restore(snapshot.spawn);
    this.viewport = { width: GAME_CONFIG.world.referenceWidth, height: GAME_CONFIG.world.referenceHeight };
  }

  update(dt: number, direction: Vec2, viewport: Viewport): void {
    if (this.state.phase !== 'waveActive' || !Number.isFinite(dt) || dt <= 0) return;
    dt = Math.min(dt, SIMULATION_CONFIG.maxInputDelta);
    if (Number.isFinite(viewport.width) && Number.isFinite(viewport.height) && viewport.width > 0 && viewport.height > 0) {
      this.viewport.width = viewport.width;
      this.viewport.height = viewport.height;
    }
    const state = this.state;
    const stage = maps[state.mapId]!;
    if (state.currentWave !== stage.bossWave) dt = Math.min(dt, state.waveRemainingTime);
    state.curseExposure += Math.min(REWARD_CONFIG.maxCurse, Math.max(0,state.calculatedStats.curse))*dt;
    state.stageCombatTime += dt;
    state.waveElapsedTime += dt;
    state.waveRemainingTime = Math.max(0, stage.waveDefinitions[state.currentWave - 1]!.duration - state.waveElapsedTime);
    if (state.waveRemainingTime <= 0.000001 && state.currentWave !== stage.bossWave) {
      state.waveElapsedTime = stage.waveDefinitions[state.currentWave - 1]!.duration;
      state.stageCombatTime = Math.round(state.stageCombatTime * 1e6) / 1e6;
      this.completeWave(); return;
    }
    const player = state.player;
    player.hp = Math.min(player.maxHp, player.hp + state.calculatedStats.hpRegeneration * dt);
    const magnitude = Math.hypot(direction.x, direction.y);
    if (Number.isFinite(magnitude) && magnitude > 0) {
      const scale = Math.max(1, magnitude);
      player.x += direction.x / scale * player.moveSpeed * dt;
      player.y += direction.y / scale * player.moveSpeed * dt;
    }
    clampToArena(player, Math.max(player.radius, ARENA_RULES.playerEdgeInset), stage);
    player.invulnerability = Math.max(0, player.invulnerability - dt);
    this.spawn.update(state, dt, this.viewport);
    this.enemySystem.update(state, dt);
    if (state.phase !== 'waveActive') return;
    this.combat.update(state, dt);
    this.enemySystem.flush(state);
    if (state.phase !== 'waveActive') return;
    this.pickups.update(state, dt);
    this.telemetry.sample();
  }

  sweepPickupsToWallet(dt: number, target: Vec2): boolean {
    if (this.state.phase !== 'postWave' && !isTerminal(this.state.phase)) return false;
    return this.pickups.sweepToWallet(this.state, dt, target);
  }

  pause(): void { if (this.state.phase === 'waveActive') transitionRun(this.state, 'paused'); }
  resume(): void { if (this.state.phase === 'paused') transitionRun(this.state, 'waveActive'); }
  revive(meta: MetaState, grade: RevivalStoneGrade): boolean { return useRevivalStone(this.state, meta, grade); }
  declineRevival(): boolean { const declined = declineRevival(this.state); if (declined) this.events.emit('gameOver'); return declined; }
  debugDown(): void { if (this.state.phase === 'waveActive') { this.state.player.hp = 1; this.state.player.invulnerability = 0; this.state.invincible = false; damagePlayer(this.state, 1_000_000, () => 0.99, this.events.emit); } }
  endRun(): void { if (this.active()) { transitionRun(this.state, 'gameOver'); this.events.emit('gameOver'); } }

  chooseBranch(id: string): boolean {
    if (!chooseShopWeaponBranch(this.state, id)) return false;
    this.events.emit('branchChoice'); return true;
  }
  debugWeapon(id: string, upgrade: boolean): boolean {
    return this.active()&&grantWeapon(this.state,id,upgrade);
  }
  debugBranch(id: string): void {
    if (!this.active() || this.state.pendingBranchWeaponId) return;
    if (!this.state.ownedWeapons.some(w => w.id === id)) this.debugWeapon(id, false);
    const slot = this.state.ownedWeapons.find(w => w.id === id);
    if (!slot || slot.branchId) return;
    slot.level = weapons[id]!.branchAtLevel - 1;
    this.debugWeapon(id, true);
  }
  debugMaxWeapons(branchId: 'A' | 'B'): void {
    if (!this.active() || this.state.pendingBranchWeaponId) return;
    const signature = characters[this.state.characterId]!.signatureWeaponId;
    const ids = [signature ?? this.state.startingWeaponId, ...this.state.availableWeaponIds.filter(id => id !== (signature ?? this.state.startingWeaponId) && !weapons[id]?.signatureOwnerId)].slice(0, WEAPON_CONFIG.maxSlots);
    this.state.ownedWeapons = ids.map(id => ({ id, level: weapons[id]!.maxLevel, cooldownRemaining: 0, branchId: this.state.ownedWeapons.find(w => w.id === id)?.branchId ?? branchId }));
  }
  debugStructures(clear = false): void {
    this.state.structures.length = 0;
    if (!clear) for (const slot of this.state.ownedWeapons) { const w=weapons[slot.id]!; this.combat.structures.place(this.state,w); }
  }
  debugShop(): boolean {
    if (!this.active() || this.state.pendingBranchWeaponId) return false;
    if (this.state.phase === 'paused') this.resume();
    if (this.state.phase === 'waveActive') this.completeWave();
    if (this.state.phase === 'postWave') this.continuePostWave();
    return this.state.phase === 'shop';
  }
  debugItem(id: string): boolean { return this.active() && addItem(this.state,id); }
  debugClearItems(): void { if(this.active()){this.state.runItems=[];applyItems(this.state);} }
  debugRarity(rarity: Rarity): void {
    if(this.state.phase!=='shop') return;
    const pool=Object.values(items).filter(i=>i.rarity===rarity);
    for(const [index,slot] of this.state.shop.itemStock.slots.entries()) if(!slot.locked)slot.itemId=pool[index%pool.length]?.id??null;
  }
  resetWeapons(): void {
    this.state.structures.length = 0;
    if (!this.active()) return;
    this.state.ownedWeapons = [{ id: this.state.startingWeaponId, level: 1, cooldownRemaining: 0 }];
    this.state.pendingBranchWeaponId = undefined;
  }
  heal(): void { if (this.active()) this.state.player.hp = this.state.player.maxHp; }

  clearEnemies(): void {
    if (!this.active()) return;
    for (const enemy of this.state.enemies) enemy.hp = 0;
    this.combat.resolveDeaths(this.state);
    this.enemySystem.flush(this.state);
  }

  spawnEnemy(id: string, modifiers: readonly EliteModifierId[] = []): void { if (this.state.phase === 'waveActive') this.spawn.spawn(this.state, id, this.viewport, false, 1, 1, modifiers); }
  spawnBoss(): void { this.goToWave(maps[this.state.mapId]!.bossWave); }

  /** Developer seek changes only this wave's timer, not earned combat time. */
  setTime(seconds: number): void {
    if (this.state.phase !== 'waveActive' || !Number.isFinite(seconds)) return;
    const wave = maps[this.state.mapId]!.waveDefinitions[this.state.currentWave - 1]!;
    this.state.waveElapsedTime = Math.max(0, Math.min(SIMULATION_CONFIG.maxDeveloperTime, seconds));
    this.state.waveRemainingTime = Math.max(0, wave.duration - this.state.waveElapsedTime);
    if (this.state.waveRemainingTime === 0) this.completeWave();
  }
  completeWave(): void {
    if (this.state.phase !== 'waveActive' || this.state.currentWave === maps[this.state.mapId]!.bossWave) return;
    this.telemetry.completeWave();
    this.cleanupCombat();
    this.state.waveRemainingTime = 0;
    transitionRun(this.state, 'postWave'); this.events.emit('waveCompleted');
  }
  buyShopItem(index:number):boolean{const id=this.state.shop.itemStock.slots[index]?.itemId??'',price=items[id]?.basePrice??0;const ok=buyItem(this.state,index);if(ok){this.telemetry.purchase('item',id,price);this.events.emit('purchase');}return ok;}
  buyShopWeapon(index:number):boolean{const slot=this.state.shop.weaponStock.slots[index],offer=slot?.weaponId?{weaponId:slot.weaponId,targetLevel:slot.targetLevel}:undefined,price=offer?weaponPrice(offer):0;const ok=buyWeapon(this.state,index);if(ok&&offer){this.telemetry.purchase('weapon',offer.weaponId,price,offer.targetLevel);this.events.emit('weaponPurchase');}return ok;}
  rerollShopItems():boolean{const price=itemRerollCost(this.state),ok=rerollItems(this.state,this.random);if(ok){this.telemetry.reroll('item',price);this.events.emit('reroll');}return ok;}
  rerollShopWeapons():boolean{const price=weaponRerollCost(this.state),ok=rerollWeapons(this.state,this.random);if(ok){this.telemetry.reroll('weapon',price);this.events.emit('reroll');}return ok;}
  lockShopItem(index:number):boolean{const ok=toggleItemLock(this.state,index);if(ok)this.events.emit('lock');return ok;}
  lockShopWeapon(index:number):boolean{const ok=toggleWeaponLock(this.state,index);if(ok)this.events.emit('lock');return ok;}
  nextWave(): boolean {
    if (this.state.phase !== 'shop') return false;
    return this.goToWave(this.state.currentWave + 1);
  }
  goToWave(number: number): boolean {
    if (this.state.pendingBranchWeaponId || !this.active() || !Number.isInteger(number) || number < 1 || number > this.state.totalWaves) return false;
    if (this.state.phase !== 'preparing' && !transitionRun(this.state, 'preparing')) return false;
    this.beginWave(number); return true;
  }
  private cleanupCombat(): void {
    this.combat.clearWave(this.state);
    this.enemySystem.clear(this.state);
    this.spawn.reset();
  }
  private beginWave(number: number): void {
    const state = this.state, stage = maps[state.mapId]!;
    const wave = stage.waveDefinitions[number - 1];
    if (!wave || wave.waveNumber !== number) throw new Error('웨이브 정의를 확인하세요.');
    this.cleanupCombat();
    // Missed stones from the previous Wave stay unavailable in its Shop.
    // They become the one-for-one pickup bonus only when the next Wave begins.
    if (number > 1 && state.walletStoredThisRun > 0) {
      state.walletBonusRemaining += state.walletStoredThisRun;
      state.walletStoredThisRun = 0;
    }
    this.telemetry.syncWallet();
    state.currentWave = number; state.waveId = wave.id;
    state.waveElapsedTime = 0; state.waveRemainingTime = wave.duration;
    state.waveStartKills = state.kills; state.bossSpawned = false;
    state.player.hp = state.player.maxHp;
    this.combat.structures.relocateForWave(state);
    transitionRun(state, 'waveActive'); this.events.emit('waveStarted');
    for (const slot of state.ownedWeapons) slot.cooldownRemaining = 0;
    clampToArena(state.player, Math.max(state.player.radius, ARENA_RULES.playerEdgeInset), stage);
    if (number === stage.bossWave) this.spawn.boss(state, this.viewport);
  }

  private active(): boolean { return !isTerminal(this.state.phase); }

  continuePostWave(): boolean {
    if (this.state.phase !== 'postWave') return false;
    if (this.state.pickups.length > 0) this.pickups.storeRemainingInWallet(this.state);
    if(!transitionRun(this.state,'shop'))return false;enterShop(this.state,this.random);return true;
  }
}

