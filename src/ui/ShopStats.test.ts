import { describe, expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { createRun } from '../state/createRun';
import { shopStatGroups, shopStats } from './ShopStats';
import { shopScreen } from './ShopScreen';

describe('Gate24 ability readout', () => {
  it('shows all four groups and derives melee, ranged, defense, recovery and structure values', () => {
    const run = createRun('awakener', 'seoul', createDefaultMeta());
    run.calculatedStats = {
      ...run.calculatedStats,
      damage: 1.2,
      meleeDamage: 1.5,
      rangedDamage: 1.25,
      armor: 100,
      hpRegeneration: 2.5,
    };
    run.structureEffects = [
      { sourceId: 'common', tag: 'STRUCTURE', type: 'maxCount', value: 1 },
      { sourceId: 'turret', tag: 'TURRET', type: 'maxCount', value: 2 },
    ];
    const groups = shopStatGroups(run);
    expect(groups.map(group => group.title)).toEqual(['공격', '무기 효과', '생존 · 이동', '회수 · 위험 · 설치물']);
    const rows = groups.flatMap(group => group.rows);
    expect(rows.find(row => row.label === '최종 근접 보정')?.value).toBe('+70%');
    expect(rows.find(row => row.label === '최종 원거리 보정')?.value).toBe('+45%');
    expect(rows.find(row => row.label === '방어력')?.value).toContain('50% 감소');
    expect(rows.find(row => row.label === '초당 회복')?.value).toBe('2.5 HP');
    expect(rows.find(row => row.label === '포탑 피해 보정')?.value).toBe('+45%');
    expect(rows.find(row => row.label === '지뢰 · 마력장')?.value).toBe('+20%');
    expect(rows.find(row => row.label === '설치물 추가 한도')?.value).toBe('공통 +1 · 포탑 +2');
  });
  it('uses the selected character and keeps sold-out weapon cards compact', () => {
    const meta = createDefaultMeta();
    const run = createRun('kangTaehoon', 'seoul', meta);
    run.shop.weaponStock.slots = [{ weaponId: null, targetLevel: 1, locked: false }];
    expect(shopStats(run)).toContain('강태훈');
    expect(shopScreen(run, meta)).toContain('구매 가능한<br>무기 없음');
  });
});
