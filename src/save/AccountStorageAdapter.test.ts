import { afterEach, describe, expect, it, vi } from 'vitest';
import { AccountStorageAdapter, LocalStorageAdapter } from './StorageAdapter';
import { SAVE_KEY } from './SaveData';

const values = new Map<string, string>();
const storage = {
  getItem: (key: string) => values.get(key) ?? null,
  setItem: (key: string, value: string) => { values.set(key, value); },
  removeItem: (key: string) => { values.delete(key); },
};

describe('guest and account saves', () => {
  afterEach(() => { values.clear(); vi.unstubAllGlobals(); });

  it('keeps guest and different Google accounts in separate keys', () => {
    vi.stubGlobal('localStorage', storage);
    const guest = new LocalStorageAdapter();
    const alice = new AccountStorageAdapter('alice');
    const bob = new AccountStorageAdapter('bob');
    guest.setItem(SAVE_KEY, 'guest');
    alice.setItem(SAVE_KEY, 'alice');
    bob.setItem(SAVE_KEY, 'bob');
    expect(guest.getItem(SAVE_KEY)).toBe('guest');
    expect(alice.getItem(SAVE_KEY)).toBe('alice');
    expect(bob.getItem(SAVE_KEY)).toBe('bob');
    alice.removeItem(SAVE_KEY);
    expect(guest.getItem(SAVE_KEY)).toBe('guest');
    expect(bob.getItem(SAVE_KEY)).toBe('bob');
  });
});
