import { describe, expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { purchaseUpgrade } from '../meta/progression';
import { BACKUP_KEY, RECOVERY_KEY, SAVE_KEY, SAVE_VERSION } from './SaveData';
import { SaveManager } from './SaveManager';
import type { StorageAdapter } from './StorageAdapter';
import { FutureSaveVersionError, parseSave } from './migrations';

class MemoryStorage implements StorageAdapter {
  values = new Map<string, string>();
  failReads = false;
  failWrites = false;
  getItem(key: string): string | null {
    if (this.failReads) throw new Error('SecurityError');
    return this.values.get(key) ?? null;
  }
  setItem(key: string, value: string): void {
    if (this.failWrites) throw new Error('QuotaExceededError');
    this.values.set(key, value);
  }
  removeItem(key: string): void { this.values.delete(key); }
}

describe('자동 저장과 백업', () => {
  it('처음 실행하면 기본 저장을 만들고 새 인스턴스에서도 구매·재화·설정을 유지한다', () => {
    const storage = new MemoryStorage();
    const saves = new SaveManager(storage);
    const meta = saves.load();
    expect(JSON.parse(storage.getItem(SAVE_KEY)!).saveVersion).toBe(SAVE_VERSION);
    meta.wallet.associationCoins = 200;
    purchaseUpgrade(meta, 'reroll');
    meta.settings.highResolution = false;
    meta.settings.musicVolume = 0.25;
    expect(saves.save(meta)).toBe(true);
    expect(new SaveManager(storage).load()).toEqual(meta);
    expect(JSON.parse(saves.export(meta)).meta).toEqual(meta);
  });

  it('손상된 주 저장은 이전 정상 사본으로 복구하고 손상 원본을 따로 보관한다', () => {
    const storage = new MemoryStorage();
    const saves = new SaveManager(storage);
    const meta = saves.load();
    meta.wallet.associationCoins = 99;
    saves.save(meta);
    meta.wallet.associationCoins = 125;
    saves.save(meta);
    storage.setItem(SAVE_KEY, '{broken');
    const recovered = new SaveManager(storage);
    expect(recovered.load().wallet.associationCoins).toBe(99);
    expect(recovered.status).toContain('복구');
    expect(storage.getItem(RECOVERY_KEY)).toBe('{broken');
    expect(recovered.save(recovered.load())).toBe(true);
    expect(parseSave(storage.getItem(SAVE_KEY)!).meta.wallet.associationCoins).toBe(99);
  });

  it('저장과 사본이 모두 손상되어도 기본 상태로 실행한다', () => {
    const storage = new MemoryStorage();
    storage.setItem(SAVE_KEY, 'null');
    storage.setItem(BACKUP_KEY, '[]');
    const saves = new SaveManager(storage);
    expect(saves.load()).toEqual(createDefaultMeta());
    expect(saves.status).toContain('복구에 실패');
  });

  it('용량 부족으로 저장에 실패하면 이전 저장을 유지하고 실패를 알린다', () => {
    const storage = new MemoryStorage();
    const saves = new SaveManager(storage);
    const meta = saves.load();
    const before = storage.getItem(SAVE_KEY);
    storage.failWrites = true;
    meta.wallet.associationCoins = 20;
    expect(saves.save(meta)).toBe(false);
    expect(storage.getItem(SAVE_KEY)).toBe(before);
    expect(saves.status).toContain('저장하지 못');
  });

  it('브라우저 저장 접근이 차단되어도 플레이 가능한 기본 상태를 반환한다', () => {
    const storage = new MemoryStorage();
    storage.failReads = true;
    const saves = new SaveManager(storage);
    expect(saves.load()).toEqual(createDefaultMeta());
    expect(saves.status).toContain('메모리');
    expect(saves.export(createDefaultMeta())).toContain('saveVersion');
  });

  it('미래 버전 원본은 자동 저장이나 가져오기로 덮어쓰지 않으며 명시적 초기화로만 교체한다', () => {
    const storage = new MemoryStorage();
    const future = JSON.stringify({ saveVersion: 999, meta: { unknown: true } });
    storage.setItem(SAVE_KEY, future);
    const saves = new SaveManager(storage);
    const meta = saves.load();
    expect(saves.save(meta)).toBe(false);
    expect(() => saves.import(saves.export(meta))).toThrow('새로운 버전');
    expect(storage.getItem(SAVE_KEY)).toBe(future);
    expect(saves.reset()).toEqual(createDefaultMeta());
    expect(JSON.parse(storage.getItem(SAVE_KEY)!).saveVersion).toBe(SAVE_VERSION);
  });

  it('불러오기 없이 저장하더라도 미래 버전 보호를 우회하지 않는다', () => {
    const storage = new MemoryStorage();
    storage.setItem(SAVE_KEY, JSON.stringify({ saveVersion: SAVE_VERSION + 1 }));
    expect(new SaveManager(storage).save(createDefaultMeta())).toBe(false);
  });

  it('유효한 JSON 가져오기는 저장 후 적용하고 잘못된 파일은 기존 진행을 보존한다', () => {
    const storage = new MemoryStorage();
    const saves = new SaveManager(storage);
    saves.load();
    const imported = createDefaultMeta();
    imported.wallet.associationCoins = 321;
    expect(saves.import(saves.export(imported))).toEqual(imported);
    const before = storage.getItem(SAVE_KEY);
    expect(() => saves.import('{bad')).toThrow();
    expect(() => saves.import(JSON.stringify({ saveVersion: 42 }))).toThrow(FutureSaveVersionError);
    expect(storage.getItem(SAVE_KEY)).toBe(before);
    storage.failWrites = true;
    expect(() => saves.import(saves.export(createDefaultMeta()))).toThrow('저장하지 못');
  });

  it('다른 창의 최신 저장과 사본을 보존하고 새로 불러온 뒤에만 저장을 재개한다', () => {
    const storage = new MemoryStorage();
    const first = new SaveManager(storage);
    const second = new SaveManager(storage);
    const firstMeta = first.load();
    const staleMeta = second.load();
    firstMeta.wallet.associationCoins = 250;
    expect(first.save(firstMeta)).toBe(true);
    const latestPrimary = storage.getItem(SAVE_KEY);
    const latestBackup = storage.getItem(BACKUP_KEY);
    staleMeta.wallet.associationCoins = 20;
    expect(second.save(staleMeta)).toBe(false);
    expect(second.status).toContain('다른 창');
    expect(second.status).toContain('JSON');
    expect(second.status).toContain('새로고침');
    expect(() => second.import(second.export(staleMeta))).toThrow('다른 창');
    expect(second.save(staleMeta)).toBe(false);
    expect(storage.getItem(SAVE_KEY)).toBe(latestPrimary);
    expect(storage.getItem(BACKUP_KEY)).toBe(latestBackup);
    const refreshed = second.load();
    expect(refreshed.wallet.associationCoins).toBe(250);
    refreshed.wallet.associationCoins += 10;
    expect(second.save(refreshed)).toBe(true);
    expect(parseSave(storage.getItem(SAVE_KEY)!).meta.wallet.associationCoins).toBe(260);
    expect(first.save(firstMeta)).toBe(false);
  });

  it('다른 창과 충돌한 뒤에도 명시적인 초기화는 새 저장을 만들 수 있다', () => {
    const storage = new MemoryStorage();
    const first = new SaveManager(storage);
    const second = new SaveManager(storage);
    const firstMeta = first.load();
    const secondMeta = second.load();
    firstMeta.wallet.associationCoins = 500;
    first.save(firstMeta);
    expect(second.save(secondMeta)).toBe(false);
    const resetMeta = second.reset();
    expect(resetMeta).toEqual(createDefaultMeta());
    expect(second.status).toContain('초기화했습니다');
    expect(parseSave(storage.getItem(SAVE_KEY)!).meta).toEqual(resetMeta);
    resetMeta.wallet.associationCoins = 30;
    expect(second.save(resetMeta)).toBe(true);
    expect(first.save(firstMeta)).toBe(false);
  });

  it('다른 창이 저장을 지운 경우에도 오래된 자동 저장으로 되살리지 않는다', () => {
    const storage = new MemoryStorage();
    const saves = new SaveManager(storage);
    const meta = saves.load();
    storage.removeItem(SAVE_KEY);
    expect(saves.save(meta)).toBe(false);
    expect(storage.getItem(SAVE_KEY)).toBeNull();
  });
});

describe('버전 이관과 검증', () => {
  it('레거시 마력석은 제거하고 강화와 설정은 유지한다', () => {
    const save = parseSave(JSON.stringify({
      saveVersion: 0, savedAt: '2026-01-01T00:00:00.000Z',
      meta: { coins: 123, upgrades: { vitality: 2 }, settings: { masterVolume: 0.2 } },
    }));
    expect(save.saveVersion).toBe(SAVE_VERSION);
    expect(save.meta.wallet.associationCoins).toBe(0);
    expect(save.meta.association.upgrades.vitality).toBe(2);
    expect(save.meta.settings.masterVolume).toBe(0.2);
    expect(save.meta.characters.awakener?.unlocked).toBe(true);
  });

  it('이관된 상태를 저장할 때 읽어 둔 레거시 원문을 충돌로 오인하지 않는다', () => {
    const storage = new MemoryStorage();
    const legacy = JSON.stringify({ saveVersion: 0, meta: { coins: 123 } });
    storage.setItem(SAVE_KEY, legacy);
    const saves = new SaveManager(storage);
    const meta = saves.load();
    expect(meta.wallet.associationCoins).toBe(0);
    expect(saves.save(meta)).toBe(true);
    expect(JSON.parse(storage.getItem(SAVE_KEY)!).saveVersion).toBe(SAVE_VERSION);
    expect(storage.getItem(BACKUP_KEY)).toBe(legacy);
  });

  it('깨진 수치·타입은 제한하고 알려지지 않은 안전한 콘텐츠 ID는 보존한다', () => {
    const save = parseSave(JSON.stringify({
      saveVersion: 1, meta: {
        currency: -100, upgrades: { vitality: 900, futureHeroPower: 3, reroll: 1 },
        unlockedCharacters: ['newHero', 'newHero', 5, '__proto__'],
        stats: { runs: 2.9, clears: 500, totalKills: 'oops', bestTime: 1.5 },
        settings: { masterVolume: 500, soundVolume: -2, musicVolume: 'no', developerMode: 'true' },
      },
    }));
    expect(save.meta.wallet.associationCoins).toBe(0);
    expect(save.meta.association.upgrades).toEqual({ vitality: 5, futureHeroPower: 3, reroll: 1 });
    expect(save.meta.characters.awakener?.unlocked).toBe(true);
    expect(save.meta.account.unlockedFeatureIds).toContain('reroll');
    expect(save.meta.statistics).toEqual({ bestWave: 0, runs: 2, clears: 2, kills: 0, bestTime: 1.5, byCharacter: {}, byMap: {} });
    expect(save.meta.settings).toMatchObject({ masterVolume: 1, soundVolume: 0, musicVolume: 0.5, developerMode: false });
  });

  it('객체 프로토타입에 영향을 주는 JSON 키를 진행 데이터에 복사하지 않는다', () => {
    const save = parseSave('{"saveVersion":1,"meta":{"upgrades":{"__proto__":4,"constructor":2,"prototype":3,"power":1}}}');
    expect(Object.keys(save.meta.association.upgrades)).toEqual(['power']);
    expect(Object.getPrototypeOf(save.meta.association.upgrades)).toBe(Object.prototype);
  });

  it('누락된 버전과 구조는 오류로 판단한다', () => {
    for (const value of [{ meta: {} }, { saveVersion: -1, meta: {} }, { saveVersion: 1, meta: [] }, { saveVersion: 1.5 }]) {
      expect(() => parseSave(JSON.stringify(value))).toThrow();
    }
  });
});

