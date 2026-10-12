import { weaponShopCardText } from '../shopCardText';
import { weaponBranches } from './branches';
import type { Weapon } from '../types';

const definitions: Record<string, Omit<Weapon, 'branches' | 'shopCardText'>> = {
  autoTurret: {
    id: "autoTurret",
    name: "자동 포탑",
    description: "고정 위치에서 자동 조준 발사",
    targeting: "nearest",
    behavior: "structure",
    capabilities: ["STRUCTURE", "TURRET", "RANGED", "PROJECTILE", "CAN_CRIT", "HAS_RANGE"],
    maxLevel: 10,
    branchAtLevel: 5,
    structure: { kind: "turret", maxCount: 2, placementInterval: 6, triggerRadius: 30, sprite: "turret" },
    base: { damage: 16, cooldown: 0.82, range: 312, duration: 12, projectileCount: 1, projectileSpeed: 600, penetration: 0, projectileRadius: 6, blastRadius: 0 },
    visual: { sprite: "turretBolt", color: 7397375, shape: "hexagon" },
    requiresUnlock: true,
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 17.6 }, { damage: 19.2 }, { damage: 20.8 }, {}, {}, {}, {}, {}, {}],
  },
  mineLayer: {
    id: "mineLayer",
    name: "마력 지뢰",
    description: "적 접촉으로 폭발하는 지뢰 설치",
    targeting: "nearest",
    behavior: "structure",
    capabilities: ["STRUCTURE", "TRAP", "MINE", "AREA", "EXPLOSIVE"],
    maxLevel: 10,
    branchAtLevel: 5,
    structure: { kind: "mine", maxCount: 6, placementInterval: 2.1, triggerRadius: 30, sprite: "mine" },
    base: { damage: 68, cooldown: 2.1, range: 1, duration: 20, projectileCount: 1, projectileSpeed: 600, penetration: 0, projectileRadius: 6, blastRadius: 110 },
    visual: { color: 16760165, shape: "diamond" },
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 74.8 }, { damage: 81.6 }, { damage: 88.4 }, {}, {}, {}, {}, {}, {}],
  },
  manaField: {
    id: "manaField",
    name: "마력장 발생기",
    description: "고정된 마력장에서 주기적으로 범위 피해",
    targeting: "nearest",
    behavior: "structure",
    capabilities: ["STRUCTURE", "AURA", "AREA", "DURATION"],
    maxLevel: 10,
    branchAtLevel: 5,
    structure: { kind: "aura", maxCount: 2, placementInterval: 6, triggerRadius: 30, sprite: "field" },
    base: { damage: 12, cooldown: 0.85, range: 1, duration: 12, projectileCount: 1, projectileSpeed: 600, penetration: 0, projectileRadius: 6, blastRadius: 130 },
    visual: { color: 12164095, shape: "hexagon" },
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 13.2 }, { damage: 14.4 }, { damage: 15.6 }, {}, {}, {}, {}, {}, {}],
  },
};

export const structureWeapons: Record<string, Weapon> = Object.fromEntries(
  Object.entries(definitions).map(([id, definition]) => [id, {
    ...definition, shopCardText: weaponShopCardText[id]!, branches: weaponBranches[id]!,
  }]),
);
