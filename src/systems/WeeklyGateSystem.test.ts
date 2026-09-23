import { describe,expect,it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { blessingModifiers,ensureWeeklyGate,weeklyBenefitModifiers } from './WeeklyGateSystem';

describe('weekly gate rules and owned blessings',()=>{
  it('stores one weekly rule without weekly blessing candidates',()=>{
    const meta=createDefaultMeta();
    expect(ensureWeeklyGate(meta,new Date('2026-09-20T00:00:00Z'),()=>0)).toBe(true);
    expect(meta.weeklyGate.ruleId).toBeTruthy();
    expect(meta.weeklyGate).not.toHaveProperty('blessingCandidateIds');
    expect(weeklyBenefitModifiers(meta.weeklyGate.ruleId).length).toBeGreaterThan(0);
  });
  it('scales owned blessing effects by progression level',()=>{
    const damage=blessingModifiers('cheonbuOath',3).find(value=>value.stat==='damage');
    expect(damage?.value).toBeCloseTo(1.12);
  });
});
