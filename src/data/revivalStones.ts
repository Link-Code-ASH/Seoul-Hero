export const REVIVAL_STONES = {
  low: { name: '조제 생환석', grade: '하급', healthFraction: 0.3, image: 'revivalStoneLow' },
  mid: { name: '정제 생환석', grade: '중급', healthFraction: 0.5, image: 'revivalStoneMid' },
  high: { name: '순정 생환석', grade: '상급', healthFraction: 1, image: 'revivalStoneHigh' },
} as const;

export type RevivalStoneGrade = keyof typeof REVIVAL_STONES;
export const REVIVAL_STONE_GRADES = Object.keys(REVIVAL_STONES) as RevivalStoneGrade[];
export const REVIVAL_CONFIG = { invulnerabilitySeconds: 2.5 } as const;

export const REVIVAL_STONE_LORE = '고순도 마력석을 정제해 제작한 각성자 전용 마도구. 마력핵이 소멸하기 직전 저장된 마력을 방출해 생명 활동을 강제로 재개한다. 사용 후 결정체는 완전히 파괴된다.';
