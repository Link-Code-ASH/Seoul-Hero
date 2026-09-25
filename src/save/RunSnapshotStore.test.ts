import { describe, expect, it } from 'vitest';
import { Simulation } from '../core/Simulation';
import { createDefaultMeta } from '../state/MetaState';
import { RunSnapshotStore } from './RunSnapshotStore';

function memoryStorage(): Pick<Storage, 'getItem' | 'setItem' | 'removeItem'> {
  const data = new Map<string, string>();
  return {
    getItem: key => data.get(key) ?? null,
    setItem: (key, value) => { data.set(key, value); },
    removeItem: key => { data.delete(key); },
  };
}

describe('device-local Run checkpoint', () => {
  it('restores the active Wave paused with currency, HP, branch choice and projectile hit history', () => {
    const meta = createDefaultMeta(), store = new RunSnapshotStore(memoryStorage());
    const original = new Simulation('awakener', 'seoul', meta);
    original.state.player.hp = 37;
    original.state.waveElapsedTime = 12;
    original.state.runCurrency = 54;
    original.state.pendingBranchWeaponId = 'manaBolt';
    const attack = { criticalChance: 0.1, criticalDamage: 2, lifesteal: 0.2, healingRemaining: 5 };
    original.state.projectiles.push({ id: 91, x: 4, y: 8, vx: 10, vy: 0, radius: 3,
      damage: 11, remaining: 0.5, penetration: 1, hitIds: new Set([17]), attack,
      visual: { color: 0xffffff, shape: 'circle' } });
    original.state.projectiles.push({ id: 92, x: 5, y: 8, vx: 10, vy: 0, radius: 3,
      damage: 11, remaining: 0.5, penetration: 1, hitIds: new Set(), attack,
      visual: { color: 0xffffff, shape: 'circle' } });
    expect(store.save('guest', original.snapshot())).toBe(true);
    expect(store.load('another-account')).toBeNull();
    const checkpoint = store.load('guest')!;
    const restored = new Simulation('awakener', 'seoul', meta);
    restored.restore(checkpoint);
    expect(restored.state.phase).toBe('paused');
    expect(restored.state.player.hp).toBe(37);
    expect(restored.state.waveElapsedTime).toBe(12);
    expect(restored.state.runCurrency).toBe(54);
    expect(restored.state.pendingBranchWeaponId).toBe('manaBolt');
    expect(restored.state.projectiles[0]?.hitIds.has(17)).toBe(true);
    expect(restored.state.projectiles[0]?.attack).toBe(restored.state.projectiles[1]?.attack);
    store.clear('guest');
    expect(store.load('guest')).toBeNull();
  });
});
