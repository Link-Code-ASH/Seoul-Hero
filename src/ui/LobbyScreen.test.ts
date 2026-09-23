import { describe, expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { lobbyScreen } from './LobbyScreen';

describe('LobbyScreen', () => {
  it('shows the five lobby destinations and keeps blessings in the gate flow', () => {
    const html = lobbyScreen(createDefaultMeta());
    for (const action of ['gateMap','growth','association','offline','supply']) {
      expect(html).toContain(`data-action="${action}"`);
    }
    expect(html).toContain('data-action="archive"');
    expect(html).toContain('data-action="settings"');
    expect(html).not.toContain('metaBlessings');
    expect(html).not.toContain('단군의 축복');
  });

  it('uses raster lobby art instead of glyph icons', () => {
    const html = lobbyScreen(createDefaultMeta());
    expect(html).toContain('lobby_gate_terminal_01');
    expect(html).toContain('lobby_future_strategy_01');
    expect(html).toContain('lobby_recovery_unit_01');
    expect(html).toContain('lobby_supply_vault_02');
    expect(html).not.toContain('<i>⌁</i>');
  });
});
