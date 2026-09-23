import { describe, expect, it } from 'vitest';
import { characters } from '../data/characters';
import { enemies } from '../data/enemies';
import { weapons } from '../data/weapons';
import { archivePageSize, archiveScreen, firstArchiveId } from './ArchiveScreen';

describe('ArchiveScreen', () => {
  it('lists every character, weapon and enemy directly from content data', () => {
    const categories = [
      ['characters', characters],
      ['weapons', weapons],
      ['enemies', enemies],
    ] as const;
    for (const [category, records] of categories) {
      const pageSize=archivePageSize();
      const pages=Math.max(1,Math.ceil(Object.keys(records).length/pageSize));
      const html=Array.from({length:pages},(_,page)=>archiveScreen({category,selectedId:Object.keys(records)[page*pageSize]??firstArchiveId(category),page})).join('');
      for(const record of Object.values(records))expect(html).toContain(record.name);
    }
  });

  it('fills the visible archive grid before starting a new page', () => {
    expect(archivePageSize(1920,1080)).toBe(8);
    expect(archivePageSize(1920,1270)).toBe(12);
    expect(archivePageSize(700,900)).toBe(6);
  });

  it('shows complete weapon growth and branch information', () => {
    const html = archiveScreen({ category: 'weapons', selectedId: 'manaSword' });
    expect(html).toContain('Lv.10');
    expect(html).toContain('광역 검격');
    expect(html).toContain('연속 검격');
    expect(html).toContain('90°');
    expect(html).toContain('weapon_mana_sword_01');
  });

  it('shows monster behavior and boss patterns', () => {
    const html = archiveScreen({ category: 'enemies', selectedId: 'gatekeeper' });
    expect(html).toContain('BOSS ENTITY');
    expect(html).toContain('광역 공격');
    expect(html).toContain('소환');
  });

  it('returns to the lobby with the shared lobby control', () => {
    const html = archiveScreen({ category: 'characters', selectedId: firstArchiveId('characters') });
    expect(html).toContain('data-action="lobby"');
    expect(html).not.toContain('data-action="menu"');
  });
});
