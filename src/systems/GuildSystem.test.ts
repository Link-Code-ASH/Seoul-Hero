import { describe, expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { getMetaModifiers } from '../meta/progression';
import { accrueOfflineRewards } from '../meta/OfflineRewardSystem';
import { openSupplyBox } from '../meta/SupplySystem';
import { parseSave } from '../save/migrations';
import { closestGuildPoint, guildFacilityCost, guildSpawn, moveInGuild, selectGuildAvatar, upgradeGuildFacility } from './GuildSystem';

describe('수탐자 길드 본부', () => {
  it('spends the shared coin wallet and stops at level three', () => {
    const meta = createDefaultMeta(); meta.wallet.associationCoins = 280;
    expect(guildFacilityCost(meta, 'training')).toBe(40);
    expect(upgradeGuildFacility(meta, 'training')).toBe(true);
    expect(guildFacilityCost(meta, 'training')).toBe(80);
    expect(upgradeGuildFacility(meta, 'training')).toBe(true);
    expect(guildFacilityCost(meta, 'training')).toBe(160);
    expect(upgradeGuildFacility(meta, 'training')).toBe(true);
    expect(meta.wallet.associationCoins).toBe(0);
    expect(upgradeGuildFacility(meta, 'training')).toBe(false);
  });

  it('only lets unlocked members control the avatar', () => {
    const meta = createDefaultMeta(); meta.characters.kangTaehoon!.unlocked = false;
    expect(selectGuildAvatar(meta, 'kangTaehoon')).toBe(false);
    meta.characters.kangTaehoon!.unlocked = true;
    expect(selectGuildAvatar(meta, 'kangTaehoon')).toBe(true);
    expect(meta.guild.avatarCharacterId).toBe('kangTaehoon');
  });

  it('moves on the room floor and locates nearby facilities', () => {
    const spawn = guildSpawn();
    expect(moveInGuild(spawn, { x: 1, y: 0 }, .1).x).toBeGreaterThan(spawn.x);
    expect(closestGuildPoint({ x: 385, y: 405 })?.id).toBe('training');
  });

  it('applies all three facility bonuses without changing gate clear rewards', () => {
    const meta = createDefaultMeta();
    meta.guild.facilityLevels = { training: 2, recovery: 2, supply: 2 };
    expect(getMetaModifiers(meta)).toContainEqual(expect.objectContaining({ id: 'guild-training', stat: 'maxHp', operation: 'multiply', value: 1.04 }));
    meta.offlineReward.lastExitAt = '2026-01-01T00:00:00.000Z';
    accrueOfflineRewards(meta, new Date('2026-01-01T00:30:00.000Z'), () => .99);
    expect(meta.offlineReward.pendingRewards.associationCoins).toBe(9);
    meta.wallet.supplyTickets = 1;
    expect(openSupplyBox(meta, 1, () => .99)?.[0]).toEqual({ type: 'associationCoins', amount: 26 });
  });

  it('migrates a v12 save and validates guild state', () => {
    const meta = createDefaultMeta(); meta.wallet.associationCoins = 72;
    const { guild: _guild, ...oldMeta } = meta;
    const save = parseSave(JSON.stringify({ saveVersion: 12, meta: oldMeta }));
    expect(save.saveVersion).toBe(13);
    expect(save.meta.wallet.associationCoins).toBe(72);
    expect(save.meta.guild).toEqual({ avatarCharacterId: 'awakener', facilityLevels: { training: 0, recovery: 0, supply: 0 } });
  });
});
