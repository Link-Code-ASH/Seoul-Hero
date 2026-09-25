import { STAT_RULES } from '../data/stats';
import { characters } from '../data/characters';
import type { RunState } from '../state/RunState';

type Tone = '' | ' boosted' | ' reduced';
interface StatRow { label: string; value: string; tone: Tone; hint?: string }
interface StatGroup { title: string; rows: StatRow[] }

const number = (value: number, digits = 1): string => Number.isInteger(value)
  ? String(value)
  : value.toFixed(digits).replace(/0+$/, '').replace(/\.$/, '');
const percent = (value: number): string => `${value >= 0 ? '+' : ''}${number(value * 100)}%`;
const chance = (value: number): string => `${number(value * 100)}%`;
const multiplierTone = (value: number): Tone => value > 1 ? ' boosted' : value < 1 ? ' reduced' : '';
const valueTone = (value: number, base: number): Tone => value > base ? ' boosted' : value < base ? ' reduced' : '';

export function shopStatGroups(run: RunState): StatGroup[] {
  const stats = run.calculatedStats;
  const base = run.baseStats;
  const melee = Math.max(0, stats.damage + stats.meleeDamage - 1);
  const ranged = Math.max(0, stats.damage + stats.rangedDamage - 1);
  const armorReduction = stats.armor / (STAT_RULES.armorScale + Math.max(0, stats.armor));
  const commonStructureLimit = run.structureEffects.filter(effect => effect.tag === 'STRUCTURE')
    .reduce((total, effect) => total + effect.value, 0);
  const turretLimit = run.structureEffects.filter(effect => effect.tag === 'TURRET')
    .reduce((total, effect) => total + effect.value, 0);
  const mineLimit = run.structureEffects.filter(effect => effect.tag === 'MINE')
    .reduce((total, effect) => total + effect.value, 0);
  const limitParts = [
    commonStructureLimit ? `공통 +${number(commonStructureLimit)}` : '',
    turretLimit ? `포탑 +${number(turretLimit)}` : '',
    mineLimit ? `지뢰 +${number(mineLimit)}` : '',
  ].filter(Boolean);

  return [
    { title: '공격', rows: [
      { label: '공통 피해', value: percent(stats.damage - 1), tone: multiplierTone(stats.damage), hint: '모든 공격' },
      { label: '최종 근접 보정', value: percent(melee - 1), tone: multiplierTone(melee), hint: '공통 + 근접' },
      { label: '최종 원거리 보정', value: percent(ranged - 1), tone: multiplierTone(ranged), hint: '공통 + 원거리' },
      { label: '공격 속도', value: percent(stats.attackSpeed - 1), tone: multiplierTone(stats.attackSpeed) },
      { label: '치명타 확률', value: chance(stats.criticalChance), tone: valueTone(stats.criticalChance, base.criticalChance) },
      { label: '치명타 피해', value: chance(stats.criticalDamage), tone: valueTone(stats.criticalDamage, base.criticalDamage) },
    ] },
    { title: '무기 효과', rows: [
      { label: '사거리', value: percent(stats.range - 1), tone: multiplierTone(stats.range) },
      { label: '범위', value: percent(stats.area - 1), tone: multiplierTone(stats.area) },
      { label: '지속시간', value: percent(stats.duration - 1), tone: multiplierTone(stats.duration) },
      { label: '투사체 속도', value: percent(stats.projectileSpeed - 1), tone: multiplierTone(stats.projectileSpeed) },
    ] },
    { title: '생존 · 이동', rows: [
      { label: '체력', value: `${number(run.player.hp)} / ${number(stats.maxHp)}`, tone: valueTone(stats.maxHp, base.maxHp) },
      { label: '방어력', value: `${number(stats.armor)} · ${chance(armorReduction)} 감소`, tone: valueTone(stats.armor, base.armor) },
      { label: '회피', value: chance(stats.dodge), tone: valueTone(stats.dodge, base.dodge) },
      { label: '흡혈', value: chance(stats.lifesteal), tone: valueTone(stats.lifesteal, base.lifesteal) },
      { label: '초당 회복', value: `${number(stats.hpRegeneration, 2)} HP`, tone: valueTone(stats.hpRegeneration, base.hpRegeneration) },
      { label: '이동 속도', value: number(stats.moveSpeed), tone: valueTone(stats.moveSpeed, base.moveSpeed) },
    ] },
    { title: '회수 · 위험 · 설치물', rows: [
      { label: '마력석 획득', value: percent(stats.currencyGain - 1), tone: multiplierTone(stats.currencyGain) },
      { label: '획득 범위', value: number(stats.pickupRange), tone: valueTone(stats.pickupRange, base.pickupRange) },
      { label: '행운', value: number(stats.luck), tone: valueTone(stats.luck, base.luck) },
      { label: '저주', value: number(stats.curse), tone: valueTone(stats.curse, base.curse) },
      { label: '포탑 피해 보정', value: percent(ranged - 1), tone: multiplierTone(ranged), hint: '공통 + 원거리' },
      { label: '지뢰 · 마력장', value: percent(stats.damage - 1), tone: multiplierTone(stats.damage), hint: '공통 피해' },
      { label: '설치물 추가 한도', value: limitParts.join(' · ') || '+0', tone: limitParts.length ? ' boosted' : '' },
    ] },
  ];
}

export function shopStats(run: RunState): string {
  const groups = shopStatGroups(run).map(group => `<section class="shop-stat-group"><h3>${group.title}</h3>${group.rows.map(row =>
    `<div class="shop-stat${row.tone}"><span>${row.label}${row.hint ? `<small>${row.hint}</small>` : ''}</span><b>${row.value}</b></div>`
  ).join('')}</section>`).join('');
  return `<aside class="shop-stats"><header><small>CURRENT LOADOUT</small><strong>${characters[run.characterId]?.name ?? '각성자'}</strong><span>구매 즉시 반영</span></header><div class="shop-stat-list">${groups}</div></aside>`;
}
