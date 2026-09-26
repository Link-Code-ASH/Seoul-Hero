import { describe, expect, it } from 'vitest';
import { characters } from '../data/characters';
import { enemies } from '../data/enemies';
import { items } from '../data/items';
import { weapons } from '../data/weapons';
import { archiveScreen, firstArchiveId, type ArchiveCategory } from './ArchiveScreen';

const screen = (category: ArchiveCategory, selectedId = firstArchiveId(category)) => archiveScreen({ category, selectedId, mapId: 'seoul' });

describe('ArchiveScreen', () => {
  it('shows all content in one scrollable list, including every store item', () => {
    for (const [category, records] of [
      ['characters', characters], ['weapons', weapons], ['enemies', enemies], ['items', items],
    ] as const) {
      const html = screen(category);
      for (const record of Object.values(records)) expect(html).toContain(record.name);
      expect(html).toContain('archive-entry-grid');
      expect(html).not.toContain('archive-pager');
    }
  });

  it('groups store items by rarity and shows price and actual modifiers', () => {
    const html = screen('items', Object.keys(items)[0]);
    for (const rarity of ['COMMON', 'UNCOMMON', 'RARE', 'LEGENDARY']) expect(html).toContain(rarity);
    expect(html).toContain('기본 가격');
    expect(html).toContain('능력치 변화');
  });

  it('reserves the bottom controls for map switching and lists only names under icons', () => {
    const html = screen('enemies');
    expect(html).toContain('archive-map-switcher');
    expect(html).toContain('광화문');
    expect(html).not.toContain('<small>추적형</small>');
  });

  it('shows complete weapon growth and branch information', () => {
    const html = screen('weapons', 'manaSword');
    expect(html).toContain('Lv.10');
    expect(html).toContain('광역 검격');
    expect(html).toContain('연속 검격');
    expect(html).toContain('90°');
    expect(html).toContain('weapon_mana_sword_casual_01');
  });

  it('shows monster behavior and boss patterns', () => {
    const html = screen('enemies', 'gatekeeper');
    expect(html).toContain('BOSS ENTITY');
    expect(html).toContain('광역 공격');
    expect(html).toContain('소환');
  });

  it('returns to the lobby with the shared lobby control', () => {
    const html = screen('characters');
    expect(html).toContain('data-action="lobby"');
    expect(html).not.toContain('data-action="menu"');
  });
});
