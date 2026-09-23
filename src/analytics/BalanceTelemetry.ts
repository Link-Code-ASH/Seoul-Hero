import { BALANCE_CONFIG } from '../data/balanceConfig';
import type { RunState } from '../state/RunState';

export interface WaveBalanceSummary {
  wave: number; seconds: number; kills: number; damageTaken: number; magicStone: number; peakEnemies: number;
}
export interface WeaponBalanceSummary { id: string; level: number; branchId?: 'A'|'B'; damage: number; hits: number; criticals: number; kills: number }
export interface PurchaseBalanceSummary { wave: number; kind: 'weapon'|'item'; id: string; price: number; targetLevel?: number }
export interface BalanceRunSummary {
  id: string; recordedAt: string; balanceVersion: string; characterId: string; startingWeaponId: string; gateDepth: number;
  weeklyTraitId: string; blessingId: string; outcome: 'stageClear'|'gameOver'; reachedWave: number; completedWaves: number;
  combatSeconds: number; kills: number; damageTaken: number; magicStoneEarned: number; magicStoneSpent: number;
  walletRecovered: number; walletRemaining: number; deathCause: string;
  weapons: WeaponBalanceSummary[]; items: {id:string;count:number}[]; purchases: PurchaseBalanceSummary[];
  itemRerolls: number; weaponRerolls: number; waves: WaveBalanceSummary[]; averageFps: number; lowFps: number;
  enemyKills: Record<string,number>;
}

export class BalanceTelemetryCollector {
  private readonly startedAt = new Date().toISOString();
  private readonly weapon = new Map<string,{damage:number;hits:number;criticals:number;kills:number}>();
  private readonly enemyKills: Record<string,number> = {};
  private readonly waves = new Map<number,WaveBalanceSummary>();
  private readonly purchases: PurchaseBalanceSummary[] = [];
  private lastHp: number;
  private lastCollected: number;
  private spent = 0;
  private walletRecovered = 0;
  private lastWalletBonus: number;
  private itemRerolls = 0;
  private weaponRerolls = 0;
  private fpsTotal = 0;
  private fpsSamples = 0;
  private lowFps = Number.POSITIVE_INFINITY;
  private lastDamageSource = 'unknown';
  constructor(private readonly run: RunState) {
    this.lastHp = run.player.hp;
    this.lastCollected = run.collectedMagicStone;
    this.lastWalletBonus = run.walletBonusRemaining;
    this.ensureWave();
  }
  sample(fps?: number): void {
    const wave = this.ensureWave();
    wave.seconds = this.run.waveElapsedTime;
    wave.kills = this.run.kills - this.run.waveStartKills;
    wave.peakEnemies = Math.max(wave.peakEnemies, this.run.enemies.length);
    if (this.run.player.hp < this.lastHp) wave.damageTaken += this.lastHp - this.run.player.hp;
    this.lastHp = this.run.player.hp;
    const collected = Math.max(0, this.run.collectedMagicStone - this.lastCollected);
    if (collected > 0) wave.magicStone += collected;
    this.lastCollected = this.run.collectedMagicStone;
    if(this.run.walletBonusRemaining<this.lastWalletBonus)this.walletRecovered+=this.lastWalletBonus-this.run.walletBonusRemaining;
    this.lastWalletBonus=this.run.walletBonusRemaining;
    if (fps !== undefined && Number.isFinite(fps) && fps > 0) {
      this.fpsTotal += fps; this.fpsSamples++; this.lowFps = Math.min(this.lowFps, fps);
    }
  }
  damage(weaponId: string | undefined, amount: number, critical: boolean, killed = false): void {
    if (!weaponId || amount <= 0) return;
    const entry = this.weapon.get(weaponId) ?? {damage:0,hits:0,criticals:0,kills:0};
    entry.damage += amount; entry.hits++; if (critical) entry.criticals++; if(killed)entry.kills++;
    this.weapon.set(weaponId,entry);
  }
  enemyKilled(id: string): void { this.enemyKills[id] = (this.enemyKills[id] ?? 0) + 1; }
  playerHit(sourceId:string):void{this.lastDamageSource=sourceId;}
  syncWallet():void{this.lastWalletBonus=this.run.walletBonusRemaining;}
  purchase(kind: 'weapon'|'item', id: string, price: number, targetLevel?: number): void {
    this.spent += price; this.purchases.push({wave:this.run.currentWave,kind,id,price,targetLevel});
  }
  reroll(kind:'weapon'|'item',price:number):void { this.spent += price; if(kind==='weapon')this.weaponRerolls++;else this.itemRerolls++; }
  completeWave():void { this.sample(); }
  finish(): BalanceRunSummary {
    this.sample();
    return {
      id:`${Date.now()}-${Math.random().toString(36).slice(2,8)}`,recordedAt:this.startedAt,balanceVersion:BALANCE_CONFIG.version,
      characterId:this.run.characterId,startingWeaponId:this.run.startingWeaponId,gateDepth:this.run.gateDepth,
      weeklyTraitId:this.run.weeklyTraitId,blessingId:this.run.blessingId,outcome:this.run.phase==='stageClear'?'stageClear':'gameOver',
      reachedWave:this.run.currentWave,completedWaves:this.run.phase==='stageClear'?this.run.totalWaves:Math.max(0,this.run.currentWave-1),
      combatSeconds:this.run.stageCombatTime,kills:this.run.kills,
      damageTaken:[...this.waves.values()].reduce((sum,w)=>sum+w.damageTaken,0),magicStoneEarned:this.run.collectedMagicStone,
      magicStoneSpent:this.spent,walletRecovered:this.walletRecovered,walletRemaining:this.run.walletBonusRemaining+this.run.walletStoredThisRun,
      deathCause:this.run.phase==='gameOver'?this.lastDamageSource:'none',
      weapons:this.run.ownedWeapons.map(slot=>({id:slot.id,level:slot.level,branchId:slot.branchId,...(this.weapon.get(slot.id)??{damage:0,hits:0,criticals:0,kills:0})})),
      items:this.run.runItems.map(item=>({...item})),purchases:[...this.purchases],itemRerolls:this.itemRerolls,weaponRerolls:this.weaponRerolls,
      waves:[...this.waves.values()].sort((a,b)=>a.wave-b.wave),averageFps:this.fpsSamples?this.fpsTotal/this.fpsSamples:0,
      lowFps:Number.isFinite(this.lowFps)?this.lowFps:0,enemyKills:{...this.enemyKills},
    };
  }
  private ensureWave():WaveBalanceSummary {
    let value=this.waves.get(this.run.currentWave);
    if(!value){value={wave:this.run.currentWave,seconds:0,kills:0,damageTaken:0,magicStone:0,peakEnemies:0};this.waves.set(this.run.currentWave,value);}
    return value;
  }
}

const STORAGE_KEY='project-seoul-gate.balance-runs.v1';
export class BalanceTelemetryStore {
  load():BalanceRunSummary[]{try{const value=JSON.parse(localStorage.getItem(STORAGE_KEY)??'[]');return Array.isArray(value)?value:[];}catch{return [];}}
  append(summary:BalanceRunSummary):void{try{const runs=[...this.load(),summary].slice(-BALANCE_CONFIG.telemetryRuns);localStorage.setItem(STORAGE_KEY,JSON.stringify(runs));}catch{/* 분석 기록 실패는 게임 진행을 막지 않는다. */}}
  clear():void{localStorage.removeItem(STORAGE_KEY);}
  exportJson():string{return JSON.stringify({format:'project-seoul-gate-balance',version:1,runs:this.load()},null,2);}
}
