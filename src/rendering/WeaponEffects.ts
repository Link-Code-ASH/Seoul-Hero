import type { Graphics } from 'pixi.js';
import type { RunState } from '../state/RunState';
import { weapons } from '../data/weapons';
import { WEAPON_CONFIG } from '../data/weaponConfig';
import { weaponStats } from '../systems/CombatSystem';
import { drawAreaIndicator } from './AreaIndicator';

export function drawWeaponEffects(g: Graphics, run: RunState): void {
  for (const entity of run.structures) {
    const w = weapons[entity.weaponId]!;
    const slot = run.ownedWeapons.find(s => s.id === w.id); if (!slot) continue;
    const color=w.visual.color;
    if (!w.structure?.sprite) {
      if (w.structure?.kind === 'mine') g.poly([entity.x,entity.y-14,entity.x+18,entity.y,entity.x,entity.y+14,entity.x-18,entity.y]).fill(color);
      else if (w.structure?.kind === 'aura') { g.circle(entity.x,entity.y,18).fill(color).stroke({color:0xffffff,width:2}); g.circle(entity.x,entity.y,8).fill(0xffffff); }
      else { g.roundRect(entity.x-16,entity.y-16,32,32,5).fill(color).stroke({color:0xffffff,width:2}); g.moveTo(entity.x,entity.y).lineTo(entity.x+25,entity.y).stroke({color:0xffffff,width:6}); }
    }
  }
  for (const effect of run.effects) {
    if (effect.kind === 'warning') {
      drawAreaIndicator(g,effect.x,effect.y,effect.radius,effect.color,run.stageCombatTime);
    } else if (effect.kind === 'chain') {
      // The painted lightning sprite supplies the bolt; no duplicate zigzag overlay.
    }
  }
  for (const slot of run.ownedWeapons) {
    const weapon = weapons[slot.id]; if (!weapon || weapon.behavior !== 'orbit') continue;
    const stats = weaponStats(weapon, slot.level, run);
    for (let i = 0; i < stats.projectileCount; i++) {
      const angle = run.stageCombatTime * WEAPON_CONFIG.orbitAngularSpeed + i * Math.PI * 2 / stats.projectileCount;
      const x = run.player.x + Math.cos(angle) * stats.range, y = run.player.y + Math.sin(angle) * stats.range;
      if (!weapon.visual.sprite) g.poly([x, y - 13 * stats.areaScale, x + 5 * stats.areaScale, y, x, y + 8 * stats.areaScale, x - 5 * stats.areaScale, y]).fill(weapon.visual.color).stroke({ color: 0xffffff, width: 1 });
    }
  }
}
