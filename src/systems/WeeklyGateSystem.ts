import { dangunBlessings, weeklyGateRules, type StatEffect } from '../data/weeklyGate';
import type { MetaState } from '../state/MetaState';
import type { StatModifier } from '../stats/PlayerStats';

const HOUR = 3_600_000;
const DAY = 24 * HOUR;

/** Sunday 05:00 KST. The shifted UTC date makes the boundary deterministic on every device. */
export function koreanWeekKey(now = new Date()): string {
  const shifted = new Date(now.getTime() + 4 * HOUR);
  const sunday = new Date(shifted.getTime() - shifted.getUTCDay() * DAY);
  return sunday.toISOString().slice(0, 10);
}

function draw<T>(pool: readonly T[], count: number, random: () => number): T[] {
  const remaining = [...pool], result: T[] = [];
  while (remaining.length && result.length < count) result.push(remaining.splice(Math.floor(random() * remaining.length), 1)[0]!);
  return result;
}

/** Returns true when a new weekly roll was stored. */
export function ensureWeeklyGate(meta: MetaState, now = new Date(), random: () => number = Math.random): boolean {
  const key = koreanWeekKey(now);
  const current = meta.weeklyGate;
  const ruleIds = Object.keys(weeklyGateRules);
  const valid = current.weekKey === key && Object.hasOwn(weeklyGateRules, current.ruleId);
  if (valid) return false;
  let remaining = current.remainingRuleIds.filter(id => Object.hasOwn(weeklyGateRules, id));
  if (!remaining.length) remaining = [...ruleIds];
  const ruleId = draw(remaining, 1, random)[0] ?? ruleIds[0]!;
  remaining = remaining.filter(id => id !== ruleId);
  meta.weeklyGate = { weekKey: key, ruleId, remainingRuleIds: remaining };
  return true;
}

function scaledModifiers(effects: readonly StatEffect[], level: number, prefix: string): StatModifier[] {
  return effects.map((modifier,index)=>({...modifier,
    value:modifier.operation==='multiply'?1+(modifier.value-1)*level:modifier.value*level,
    id:`${prefix}-${index}`,source:'blessing' as const,
  }));
}

export function weeklyBenefitModifiers(ruleId: string): StatModifier[] {
  const rule=weeklyGateRules[ruleId];
  return rule?scaledModifiers(rule.benefit,1,`weekly-${ruleId}`):[];
}

export function blessingModifiers(id: string, level = 1): StatModifier[] {
  const blessing = dangunBlessings[id];
  return blessing&&level>0?scaledModifiers(blessing.modifiers,Math.min(5,level),`blessing-${id}`):[];
}
