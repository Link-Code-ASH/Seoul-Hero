import { describe, expect, it } from 'vitest';
import { Simulation } from '../core/Simulation';
import { createDefaultMeta } from '../state/MetaState';
import { damagePlayer } from './PlayerDamageSystem';
import { declineRevival, hasRevivalStone, useRevivalStone } from './RevivalSystem';
import { revivalScreen } from '../ui/RevivalScreen';
import { shopScreen } from '../ui/ShopScreen';

describe('persistent revival stones', () => {
  it.each([['low',.3],['mid',.5],['high',1]] as const)('revives with %s at the defined health fraction', (grade,fraction) => {
    const meta=createDefaultMeta();meta.wallet.revivalStones[grade]=1;
    const run=new Simulation('awakener','seoul',meta).state;
    const remaining=run.waveRemainingTime;
    run.player.hp=1;run.player.invulnerability=0;
    expect(damagePlayer(run,999,()=>.99)).toBe(true);
    expect(run.phase).toBe('revivalChoice');
    expect(useRevivalStone(run,meta,grade)).toBe(true);
    expect(run.phase).toBe('waveActive');
    expect(run.player.hp).toBe(Math.ceil(run.player.maxHp*fraction));
    expect(run.player.invulnerability).toBeGreaterThan(0);
    expect(run.waveRemainingTime).toBe(remaining);
    expect(meta.wallet.revivalStones[grade]).toBe(0);
    expect(useRevivalStone(run,meta,grade)).toBe(false);
  });
  it('rejects unavailable stones and only ends the run when revival is declined',()=>{
    const meta=createDefaultMeta(),run=new Simulation('awakener','seoul',meta).state;
    run.player.hp=1;run.player.invulnerability=0;
    damagePlayer(run,999,()=>.99);
    expect(hasRevivalStone(meta)).toBe(false);
    expect(useRevivalStone(run,meta,'high')).toBe(false);
    expect(run.phase).toBe('revivalChoice');
    expect(declineRevival(run)).toBe(true);
    expect(run.phase).toBe('gameOver');
  });
  it('shows persistent counts in the shop and available recovery in the downed screen',()=>{
    const meta=createDefaultMeta();meta.wallet.revivalStones.mid=2;
    const simulation=new Simulation('awakener','seoul',meta);simulation.completeWave();simulation.continuePostWave();
    expect(shopScreen(simulation.state,meta)).toContain('정제 생환석 2개');
    expect(revivalScreen(meta)).toContain('체력 50%');
    expect(revivalScreen(meta)).toContain('보유 2');
  });
});
