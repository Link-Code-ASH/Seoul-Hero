# 콘텐츠 추가 안내

콘텐츠와 밸런스는 `src/data`에서 먼저 정의합니다. 새 ID를 위해 Simulation이나 Shop UI에 조건문을 추가하지 않습니다. 새로운 행동 방식이 필요할 때만 해당 시스템의 행동 처리기를 확장합니다.

## 주요 위치

- 캐릭터: `src/data/characters`
- 무기·레벨·분기: `src/data/weapons`
- 적·엘리트·Boss: `src/data/enemies`, `enemyConfig.ts`, `eliteModifiers.ts`
- 맵과 Wave: `src/data/maps`
- 아이템: `src/data/items`
- 상점 가격·칸·리롤: `src/data/shopConfig.ts`
- 영구 강화와 해금: `src/data/meta`
- 이미지·소리 연결: `src/data/images.ts`, `src/data/audio.ts`

## 캐릭터와 무기

공식 기준 캐릭터는 송진우입니다. 새 캐릭터는 송진우의 20개 기본 스탯을 기준으로 상대 차이를 정해 CharacterData에 반영합니다. 고유 무기를 쓸 경우 signatureWeaponId와 signatureOwnerId를 양쪽에 연결합니다. 새 무기는 capability, base, maxLevel, branchAtLevel, 공통 레벨과 A/B 분기 데이터를 정의합니다. 설치물도 일반 무기이며 같은 6슬롯을 사용합니다.

상점 후보는 데이터 목록에서 자동 생성됩니다. 타 캐릭터 고유 무기, 미해금, 최대 레벨, 슬롯 초과, 중복은 ShopSystem이 제외합니다. 가격을 바꾸려면 `shopConfig.ts`만 수정합니다.

## 아이템

ItemData에 이름, 설명, rarity, basePrice, statModifiers, specialEffects, maxStacks, tags, icon, unlockCondition을 지정합니다. 현재 아이템은 30개입니다. 지원하는 스탯 보정만 쓰는 아이템은 ShopSystem 변경이 필요 없습니다. 새로운 사건형 효과는 해당 사건의 전용 처리기에 effect type을 추가합니다.

## 적과 Stage

공식 스테이지 기준은 광화문 심도 1입니다. 새 스테이지는 balanceModifiers로 광화문 대비 HP·피해·속도·밀도·보상 차이를 명시합니다. EnemyData의 수치, 행동 ID, sprite, tags를 정의하고 기존 행동을 재사용합니다. `magicStoneDrop`은 보상량인 동시에 마력석의 1~5 시각 등급을 결정하므로 새 몬스터의 강함과 함께 조정합니다. 등급 경계와 색은 `magicStoneConfig.ts`에서 관리합니다. 완전히 새로운 움직임이나 공격만 EnemyBehaviors에 추가합니다. Wave 시간·비율·최대 수·Boss는 StageData에서 조정합니다.

## 검증

새 콘텐츠는 해금 조건, 상점 등장, 구매 직후 적용, 새 Run 초기화를 확인합니다. 저장되는 Meta ID나 형태가 바뀌면 `SAVE_SYSTEM.md`의 migration 정책을 따릅니다.
