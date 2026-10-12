import type { WeaponBranch } from '../types';

// Each row is a direct Lv.5–10 patch. There is no hidden level expansion or final damage cut.
export const weaponBranches: Record<string, WeaponBranch[]> = {
  manaSword: [
    { id: 'A', name: '광역 검격', description: '90°의 넓은 검격. 사거리와 위력이 성장합니다.', levels: [
      { attackAngle: 1.570796327, damage: 60.06, range: 180 }, // Lv.5
      { cooldown: 0.952, damage: 66.848, range: 189 }, // Lv.6
      { cooldown: 0.904, damage: 73.636, range: 198 }, // Lv.7
      { cooldown: 0.856, damage: 80.424, range: 207 }, // Lv.8
      { cooldown: 0.808, damage: 87.212, range: 216 }, // Lv.9
      { cooldown: 0.76, damage: 94, range: 225 }, // Lv.10
    ] },
    { id: 'B', name: '연속 검격', description: '60° 범위를 빠르게 연속으로 베어냅니다.', levels: [
      { attackAngle: 1.047197551, damage: 34, range: 135, repeatCount: 2, repeatInterval: 0.14 }, // Lv.5
      { cooldown: 0.928, damage: 36.8 }, // Lv.6
      { cooldown: 0.856, damage: 39.6 }, // Lv.7
      { cooldown: 0.784, damage: 42.4 }, // Lv.8
      { cooldown: 0.712, damage: 45.2 }, // Lv.9
      { cooldown: 0.64, damage: 48 }, // Lv.10
    ] },
  ],
  guardianDaggers: [
    { id: 'A', name: '표창 군무', description: '회전 표창 증가. 최종 6개.', levels: [
      { damage: 24, projectileCount: 5 }, // Lv.5
      { cooldown: 0.34, damage: 25.2 }, // Lv.6
      { cooldown: 0.33, damage: 26.4 }, // Lv.7
      { cooldown: 0.32, damage: 27.6, projectileCount: 6 }, // Lv.8
      { cooldown: 0.31, damage: 28.8 }, // Lv.9
      { cooldown: 0.3, damage: 30 }, // Lv.10
    ] },
    { id: 'B', name: '중량 표창', description: '표창 3개를 유지하고 크기·피해 확대.', levels: [
      { areaMultiplier: 1.45, damage: 36 }, // Lv.5
      { areaMultiplier: 1.54, cooldown: 0.344, damage: 40.4 }, // Lv.6
      { areaMultiplier: 1.63, cooldown: 0.338, damage: 44.8 }, // Lv.7
      { areaMultiplier: 1.72, cooldown: 0.332, damage: 49.2 }, // Lv.8
      { areaMultiplier: 1.81, cooldown: 0.326, damage: 53.6 }, // Lv.9
      { areaMultiplier: 1.9, cooldown: 0.32, damage: 58 }, // Lv.10
    ] },
  ],
  piercingShot: [
    { id: 'A', name: '관통 포격', description: '한 발의 폭과 관통 수 증가.', levels: [
      { damage: 45, penetration: 6, projectileRadius: 9 }, // Lv.5
      { cooldown: 1.044, damage: 51.6, penetration: 7, projectileRadius: 10.4 }, // Lv.6
      { cooldown: 0.988, damage: 58.2, penetration: 8, projectileRadius: 11.8 }, // Lv.7
      { cooldown: 0.932, damage: 64.8, penetration: 10, projectileRadius: 13.2 }, // Lv.8
      { cooldown: 0.876, damage: 71.4, penetration: 11, projectileRadius: 14.6 }, // Lv.9
      { cooldown: 0.82, damage: 78, penetration: 12, projectileRadius: 16 }, // Lv.10
    ] },
    { id: 'B', name: '산개 사격', description: '관통은 3회, 여러 방향으로 동시 발사.', levels: [
      { damage: 34, projectileCount: 2 }, // Lv.5
      { cooldown: 1.048, damage: 37.2 }, // Lv.6
      { cooldown: 0.996, damage: 40.4 }, // Lv.7
      { cooldown: 0.944, damage: 43.6, projectileCount: 3 }, // Lv.8
      { cooldown: 0.892, damage: 46.8 }, // Lv.9
      { cooldown: 0.84, damage: 50 }, // Lv.10
    ] },
  ],
  chainLightning: [
    { id: 'A', name: '연쇄 폭풍', description: '많은 적을 연결. 최종 7개 대상.', levels: [
      { damage: 31, projectileCount: 5 }, // Lv.5
      { cooldown: 1.33, damage: 33.2 }, // Lv.6
      { cooldown: 1.26, damage: 35.4, projectileCount: 6 }, // Lv.7
      { cooldown: 1.19, damage: 37.6 }, // Lv.8
      { cooldown: 1.12, damage: 39.8, projectileCount: 7 }, // Lv.9
      { cooldown: 1.05, damage: 42 }, // Lv.10
    ] },
    { id: 'B', name: '집중 뇌격', description: '대상을 2개로 제한하고 강한 타격.', levels: [
      { damage: 58, projectileCount: 2 }, // Lv.5
      { cooldown: 1.312, damage: 68 }, // Lv.6
      { cooldown: 1.224, damage: 78 }, // Lv.7
      { cooldown: 1.136, damage: 88 }, // Lv.8
      { cooldown: 1.048, damage: 98 }, // Lv.9
      { cooldown: 0.96, damage: 108 }, // Lv.10
    ] },
  ],
  manaBombard: [
    { id: 'A', name: '대형 폭발', description: '예고 후 넓은 한 번의 폭발.', levels: [
      { blastRadius: 155, cooldown: 2, damage: 82, repeatCount: 1 }, // Lv.5
      { blastRadius: 167, cooldown: 1.92, damage: 92 }, // Lv.6
      { blastRadius: 179, cooldown: 1.84, damage: 102 }, // Lv.7
      { blastRadius: 191, cooldown: 1.76, damage: 112 }, // Lv.8
      { blastRadius: 203, cooldown: 1.68, damage: 122 }, // Lv.9
      { blastRadius: 215, cooldown: 1.6, damage: 132 }, // Lv.10
    ] },
    { id: 'B', name: '연속 폭격', description: '작은 폭발을 같은 목표 지점에 연속 투하.', levels: [
      { blastRadius: 78, cooldown: 2, damage: 40.413043478, repeatCount: 2, repeatInterval: 0.2 }, // Lv.5
      { cooldown: 1.924, damage: 42.330434783 }, // Lv.6
      { cooldown: 1.848, damage: 44.247826087 }, // Lv.7
      { cooldown: 1.772, damage: 46.165217391, repeatCount: 3 }, // Lv.8
      { cooldown: 1.696, damage: 48.082608696 }, // Lv.9
      { cooldown: 1.62, damage: 50 }, // Lv.10
    ] },
  ],
  manaBolt: [
    { id: 'A', name: '다중 마력 난사', description: '넓게 퍼지는 여러 마력탄. 최종 3발.', levels: [
      { damage: 32, projectileCount: 2, projectileSpeed: 620 }, // Lv.5
      { cooldown: 0.632, damage: 33.6 }, // Lv.6
      { cooldown: 0.614, damage: 35.2 }, // Lv.7
      { cooldown: 0.596, damage: 36.8, projectileCount: 3 }, // Lv.8
      { cooldown: 0.578, damage: 38.4 }, // Lv.9
      { cooldown: 0.56, damage: 40 }, // Lv.10
    ] },
    { id: 'B', name: '초관통 마력탄', description: '한 발로 긴 적 대열을 관통. 최종 8회 관통.', levels: [
      { damage: 42, penetration: 3, projectileSpeed: 620 }, // Lv.5
      { cooldown: 0.636, damage: 48, penetration: 4, projectileRadius: 6.6, projectileSpeed: 640 }, // Lv.6
      { cooldown: 0.622, damage: 54, penetration: 5, projectileRadius: 7.2, projectileSpeed: 660 }, // Lv.7
      { cooldown: 0.608, damage: 60, penetration: 6, projectileRadius: 7.8, projectileSpeed: 680 }, // Lv.8
      { cooldown: 0.594, damage: 66, penetration: 7, projectileRadius: 8.4, projectileSpeed: 700 }, // Lv.9
      { cooldown: 0.58, damage: 72, penetration: 8, projectileRadius: 9, projectileSpeed: 720 }, // Lv.10
    ] },
  ],
  manaShotgun: [
    { id: 'A', name: '확산 제압', description: '더 넓은 부채꼴에 많은 산탄을 퍼뜨려 다수의 적을 제압한다.', levels: [
      { cooldown: 1.43, damage: 10.711380952, projectileCount: 7, projectileSpeed: 680, range: 220, spreadAngle: 0.98 }, // Lv.5
      { cooldown: 1.384, damage: 10.969104762, range: 222, spreadAngle: 1 }, // Lv.6
      { cooldown: 1.338, damage: 11.226828571, projectileCount: 8, range: 224, spreadAngle: 1.02 }, // Lv.7
      { cooldown: 1.292, damage: 11.484552381, range: 226, spreadAngle: 1.04 }, // Lv.8
      { cooldown: 1.246, damage: 11.74227619, projectileCount: 9, range: 228, spreadAngle: 1.06 }, // Lv.9
      { cooldown: 1.2, damage: 12, range: 230, spreadAngle: 1.08 }, // Lv.10
    ] },
    { id: 'B', name: '집중 산탄', description: '좁은 각도의 강한 산탄이 적을 뚫고 뒤의 적에게도 닿는다.', levels: [
      { cooldown: 1.43, damage: 15, penetration: 1, projectileSpeed: 680, range: 220, spreadAngle: 0.32 }, // Lv.5
      { cooldown: 1.392, damage: 16, range: 222, spreadAngle: 0.308 }, // Lv.6
      { cooldown: 1.354, damage: 17, range: 224, spreadAngle: 0.296 }, // Lv.7
      { cooldown: 1.316, damage: 18, penetration: 2, range: 226, spreadAngle: 0.284 }, // Lv.8
      { cooldown: 1.278, damage: 19, range: 228, spreadAngle: 0.272 }, // Lv.9
      { cooldown: 1.24, damage: 20, range: 230, spreadAngle: 0.26 }, // Lv.10
    ] },
  ],
  autoTurret: [
    { id: 'A', name: '다중 발사', description: '동시 발사 탄 수 증가', levels: [
      { damage: 18.88, projectileCount: 2 }, // Lv.5
      { damage: 20.384 }, // Lv.6
      { damage: 21.888 }, // Lv.7
      { damage: 23.392 }, // Lv.8
      { damage: 24.896 }, // Lv.9
      { damage: 26.4 }, // Lv.10
    ] },
    { id: 'B', name: '고속 작동', description: '공격 또는 지뢰 설치 주기 단축', levels: [
      { cooldown: 0.6396, damage: 18.88 }, // Lv.5
      { cooldown: 0.61008, damage: 20.384 }, // Lv.6
      { cooldown: 0.58056, damage: 21.888 }, // Lv.7
      { cooldown: 0.55104, damage: 23.392 }, // Lv.8
      { cooldown: 0.52152, damage: 24.896 }, // Lv.9
      { cooldown: 0.492, damage: 26.4 }, // Lv.10
    ] },
  ],
  mineLayer: [
    { id: 'A', name: '광역 강화', description: '피해 영역 확대', levels: [
      { blastRadius: 137.5, damage: 97.24 }, // Lv.5
      { blastRadius: 143, damage: 100.232 }, // Lv.6
      { blastRadius: 148.5, damage: 103.224 }, // Lv.7
      { blastRadius: 154, damage: 106.216 }, // Lv.8
      { blastRadius: 159.5, damage: 109.208 }, // Lv.9
      { blastRadius: 165, damage: 112.2 }, // Lv.10
    ] },
    { id: 'B', name: '고속 작동', description: '공격 또는 지뢰 설치 주기 단축', levels: [
      { cooldown: 1.638, damage: 80.24 }, // Lv.5
      { cooldown: 1.5624, damage: 86.632 }, // Lv.6
      { cooldown: 1.4868, damage: 93.024 }, // Lv.7
      { cooldown: 1.4112, damage: 99.416 }, // Lv.8
      { cooldown: 1.3356, damage: 105.808 }, // Lv.9
      { cooldown: 1.26, damage: 112.2 }, // Lv.10
    ] },
  ],
  manaField: [
    { id: 'A', name: '광역 강화', description: '피해 영역 확대', levels: [
      { blastRadius: 162.5, damage: 17.16 }, // Lv.5
      { blastRadius: 169, damage: 17.688 }, // Lv.6
      { blastRadius: 175.5, damage: 18.216 }, // Lv.7
      { blastRadius: 182, damage: 18.744 }, // Lv.8
      { blastRadius: 188.5, damage: 19.272 }, // Lv.9
      { blastRadius: 195, damage: 19.8 }, // Lv.10
    ] },
    { id: 'B', name: '고속 작동', description: '공격 또는 지뢰 설치 주기 단축', levels: [
      { cooldown: 0.663, damage: 14.16 }, // Lv.5
      { cooldown: 0.6324, damage: 15.288 }, // Lv.6
      { cooldown: 0.6018, damage: 16.416 }, // Lv.7
      { cooldown: 0.5712, damage: 17.544 }, // Lv.8
      { cooldown: 0.5406, damage: 18.672 }, // Lv.9
      { cooldown: 0.51, damage: 19.8 }, // Lv.10
    ] },
  ],
};
