"""Refresh contact silhouettes after replacing character, monster, or facility art."""
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'player': 'combat-chibi/song.png',
    'kangTaehoonTruck': 'combat-chibi/kang.png',
    'brute': 'combat-chibi/brute.png',
    'hound': 'combat-chibi/hound.png',
    'bulwark': 'combat-chibi/bulwark.png',
    'spitter': 'combat-chibi/spitter.png',
    'spitterFire': 'combat-chibi/spitter-fire.png',
    'swarm': 'combat-chibi/swarm.png',
    'charger': 'combat-chibi/charger.png',
    'chargerBrace': 'combat-chibi/charger-brace.png',
    'bomber': 'combat-chibi/bomber.png',
    'splitter': 'combat-chibi/splitter.png',
    'splitterAir': 'combat-chibi/splitter-air.png',
    'mender': 'combat-chibi/mender.png',
    'summoner': 'combat-chibi/summoner.png',
    'sentinel': 'combat-chibi/sentinel.png',
    'lurker': 'combat-chibi/lurker.png',
    'boss': 'combat-chibi/boss.png',
    'bossAttack': 'combat-chibi/boss-attack.png',
    'riftQueen': 'combat-chibi/riftQueen.png',
    'riftQueenCast': 'combat-chibi/riftQueen-cast.png',
    'guildTraining': 'guild/training_station_casual_02.png',
    'guildRecovery': 'guild/recovery_station_casual_02.png',
    'guildSupply': 'guild/supply_station_casual_02.png',
    'guildRoster': 'guild/roster_kiosk_casual_02.png',
    'guildGate': 'guild/gate_terminal_casual_02.png',
    'lobbyGate': 'ui/lobby/lobby_gate_terminal_01.png',
    'turret': 'ui/weapons/weapon_auto_turret_omni_02.png',
    'mine': 'ui/weapons/weapon_mine_layer_casual_01.png',
    'field': 'ui/weapons/weapon_mana_field_casual_01.png',
}

lines = [
    "import type { ImageId } from '../data/images';",
    '',
    '/** Normalized bottom alpha contour of each rendered object; generated from its PNG master. */',
    'export const shadowFootprints: Partial<Record<ImageId, readonly (readonly [number, number])[]>> = {',
]
for key, relative in SOURCES.items():
    alpha = np.asarray(Image.open(ROOT / 'assets' / relative).convert('RGBA'))[:, :, 3]
    height, width = alpha.shape
    ys, xs = np.where(alpha > 160)
    min_x, max_x = int(xs.min()), int(xs.max())
    points = []
    for x in np.linspace(min_x, max_x, 17).astype(int):
        visible = np.where(alpha[:, x] > 160)[0]
        if len(visible) and visible[-1] >= height * .62:
            points.append((round(x / width, 3), round(int(visible[-1]) / height, 3)))
    if len(points) < 2:
        raise ValueError(f'Not enough contact points for {key}')
    lines.append(f"  {key}: [{', '.join(f'[{x}, {y}]' for x, y in points)}],")
lines.append('};')
lines.append('')
(ROOT / 'src/rendering/ShadowFootprints.ts').write_text('\n'.join(lines), encoding='utf-8')
