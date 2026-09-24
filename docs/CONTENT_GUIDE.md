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

공식 수치 기준 캐릭터는 송진우입니다. 새 캐릭터는 송진우의 20개 기본 스탯을 기준으로 상대 차이를 정해 CharacterData에 반영합니다. `description`, `background`, `personality`를 입력하면 자료집에 함께 표시됩니다. 전투용 `visual.sprite`와 자료집·선택용 `portraitSprite`는 필요할 때 분리하고, 이미지 manifest·생성 출처·기본 해금·기존 저장 검증·출동 선택·전투 이동 연출·자료집·성장실 표시를 함께 확인합니다. 현재 송진우와 강태훈 모두 고유 무기 없이 공용 전투 무기를 고릅니다. 고유 무기는 필요해질 때만 선택적으로 연결합니다. 새 무기는 capability, base, maxLevel, branchAtLevel, 공통 레벨과 A/B 분기 데이터를 정의합니다. 설치물도 일반 무기이며 같은 6슬롯을 사용합니다.

산탄형 무기는 `WeaponStats.spreadAngle`을 지정하면 전체 산탄 각도 안에 투사체가 균등하게 퍼집니다. `AREA` 태그가 있으면 범위 스탯이 산탄 각도와 탄 반경에 적용됩니다. 무기 이미지는 `images.ts` 및 `InventoryArt.ts`에 등록해 상점·자료집·성장실·HUD에 연결합니다.

상점 후보는 데이터 목록에서 자동 생성됩니다. 타 캐릭터 고유 무기, 미해금, 최대 레벨, 슬롯 초과, 중복은 ShopSystem이 제외합니다. 가격을 바꾸려면 `shopConfig.ts`만 수정합니다.

## 아이템

ItemData에 이름, 설명, rarity, basePrice, statModifiers, specialEffects, maxStacks, tags, icon, unlockCondition을 지정합니다. 현재 아이템은 30개입니다. 지원하는 스탯 보정만 쓰는 아이템은 ShopSystem 변경이 필요 없습니다. 새로운 사건형 효과는 해당 사건의 전용 처리기에 effect type을 추가합니다.

자료집은 캐릭터·무기·적·아이템 원본 데이터를 직접 읽습니다. 새 맵에서 일부 콘텐츠만 보여주려면 `MapData.archiveContent`의 `weaponIds`, `enemyIds`, `itemIds`를 지정합니다. 생략한 분류는 전부 표시합니다. 자료집 하단 버튼은 맵 전환, 가운데 목록은 내부 스크롤입니다.

보급 상자는 매번 협회 코인을 지급합니다. 코인 수량은 작은 묶음일수록 높은 가중치를 가지며, 무기·캐릭터·축복 조각, 보급권, 생환석 3등급은 각각 독립된 낮은 확률로 추가 지급합니다. 생환석 확률은 하급 1.2%, 중급 0.4%, 상급 0.1%입니다. 조각이 10회 연속 나오지 않으면 마지막 상자에서 조각 하나를 보장합니다. 코인 수량별 가중치와 보너스별 확률·수량은 `src/data/metaFacilities.ts`에서 조정합니다.

생환석은 상점 상품이 아닌 영구 보유 소모품입니다. 전투 중 쓰러지면 보유한 등급 하나를 선택해 체력 30%/50%/100%로 부활하거나 종료할 수 있습니다. 오프라인 보상은 기존 협회 코인에 더해 생환석만 매우 드물게 지급하며, 30분 단위로 독립 판정하고 오래 이탈할수록 판정 확률이 소폭 증가합니다. 등급과 회복 비율은 `src/data/revivalStones.ts`에서 관리합니다.

## 적과 Stage

공식 스테이지 기준은 광화문 심도 1입니다. 새 스테이지는 balanceModifiers로 광화문 대비 HP·피해·속도·밀도·보상 차이를 명시합니다. EnemyData의 수치, 행동 ID, sprite, tags를 정의하고 기존 행동을 재사용합니다. `magicStoneDrop`은 보상량인 동시에 마력석의 1~5 시각 등급을 결정하므로 새 몬스터의 강함과 함께 조정합니다. 등급 경계와 색은 `magicStoneConfig.ts`에서 관리합니다. 완전히 새로운 움직임이나 공격만 EnemyBehaviors에 추가합니다. Wave 시간·비율·최대 수·Boss는 StageData에서 조정합니다.

## 검증

새 콘텐츠는 해금 조건, 상점 등장, 구매 직후 적용, 새 Run 초기화를 확인합니다. 저장되는 Meta ID나 형태가 바뀌면 `SAVE_SYSTEM.md`의 migration 정책을 따릅니다.
