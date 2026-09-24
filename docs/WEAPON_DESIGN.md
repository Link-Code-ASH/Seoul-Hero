# 무기와 통합 상점

## 고유 무기
송진우와 강태훈은 고유 무기 없이 출동 대기실에서 전투 무기 7종 중 하나를 골라 Lv.1로 시작합니다. 설치물은 시작 후보에서 제외합니다. 공용 무기 선택을 우선하며 고유 무기는 필요한 캐릭터가 생길 때만 선택적으로 연결합니다.

## 슬롯
weaponConfig.ts의 maxSlots=6을 전체 무기에 적용합니다. 송진우는 시작 무기를 포함해 6칸을 모두 사용합니다. 같은 ID는 한 슬롯만 차지합니다. 이미 보유한 무기의 보상은 강화이며, 슬롯이 차면 신규 획득은 제외하고 보유 무기 강화만 허용합니다. 각 무기의 maxLevel로 최대 레벨을 지정하며 현재 모두 10입니다.

## 상점 판매

POST_WAVE 뒤 게이트24에서 무기 4개를 판매합니다. 상품은 아직 없는 일반 무기의 신규 획득 또는 보유 무기의 바로 다음 레벨 강화입니다. 타 캐릭터 고유 무기, 미해금 무기, 최대 레벨 강화, 슬롯 초과 신규 무기, 같은 화면의 중복 무기는 제외합니다. 후보가 부족하면 빈 칸으로 둡니다. Luck은 무기 진열 수나 확률에 적용하지 않습니다.

일반 신규 36, 설치물 신규 44, Lv.2~10 강화는 각각 14/18/23/28/33/38/43/48/54 마력석입니다. 무기 리롤은 6부터 매회 6씩 증가하고 아이템 리롤과 독립적입니다. 가격과 칸 수는 `src/data/shopConfig.ts`에서 조정합니다.

## 개발과 저장
F3에서 상점 강제 진입, 무기 진열 리롤, 특정 무기 획득·강화, 고유 무기 초기화와 슬롯 확인을 사용할 수 있습니다. Run 무기와 상점 상태는 영구 저장하지 않습니다. 새로운 캐릭터도 기본적으로 공용 무기 선택을 사용합니다.

## 6단계: 공격과 분기
| 무기 | 주요 capability | 공격 | A | B |
| --- | --- | --- | --- | --- |
| 마력검 | MELEE, AREA | 가까운 적 방향 부채꼴 검격 | 각도·범위 확대, Lv.10 광역 검격 | 짧은 간격의 2연격→3연격 |
| 수호 표창 | MELEE, ORBIT, AREA | 표창 3개가 플레이어 주위를 돌며 주기적으로 타격 | 표창 수 증가, 최종 6개 | 표창 3개 유지, 크기·피해 증가 |
| 마력탄 | RANGED, PROJECTILE, PIERCING | 가까운 적을 조준해 발사 | 2→5발 난사 | 1발 유지, 4→12회 관통 |
| 마력 샷건 | RANGED, PROJECTILE, AREA | 짧은 거리에서 5발 산탄을 넓게 발사 | 확산 제압: 넓은 각도와 탄 수 증가 | 집중 산탄: 좁은 각도와 관통 강화 |
| 관통 사격 | RANGED, PROJECTILE, PIERCING | 빠른 직선 관통탄 | 관통 8→20과 탄폭 확대 | 3→5발 산개 사격 |
| 연쇄 번개 | RANGED, CHAIN | 실제 주변의 서로 다른 적에게 연결 | 5→10대상 | 2대상 집중 고피해 |
| 마력 폭격 | RANGED, AREA, EXPLOSIVE | 0.55초 예고 후 잠긴 목표 지점에 폭발 | 반경 170→250 대형 폭발 | 반경75, 3→5회 시차 폭발 |

HAS_RANGE, CAN_CRIT 등 추가 capability는 기존 스탯 규칙을 유지합니다. 위 숫자는 현재 branches.ts 기준이며 파일에서 직접 조정합니다. 설치물/새 무기 ID별 로직은 추가하지 않았습니다.

Lv.1 기본 → Lv.2~4 공통 강화 → Lv.5 A/B → Lv.6~9 분기 발전 → Lv.10 최종 형태입니다. 기존 Lv.6 데이터는 검증된 기능 변화의 입력 자료로만 남기고, `progression.ts`가 로딩 시 이를 Lv.10/분기 Lv.5 데이터로 확장합니다. 상점·전투·자료집이 받는 실제 `Weapon` 데이터의 `maxLevel`은 10, `branchAtLevel`은 5입니다. 계산 순서는 기본값 → 공통 레벨 → 선택 분기 → 플레이어 스탯이며, 분기 값은 가산이 아닌 최종 기본값 덮어쓰기입니다. 분기별 지속 값이 이후 공통 레벨 값보다 우선합니다.

Branch의 id/name/description/levels와 WeaponStats의 repeatCount/repeatInterval/explosionDelay/attackAngle/areaMultiplier/blastRadius 등이 공격 형태를 바꿉니다. 피해·쿨다운·탄 수·관통 등은 기존 필드를 재사용합니다. 새 무기는 데이터 등록과 기존 행동을 선택하면 보상 시스템 수정 없이 분기를 연결할 수 있습니다.

## Lv.5 선택과 안전성
Lv.5 강화를 구매하면 결제 직후 SHOP 안에 pendingBranchWeaponId를 설정합니다. A/B 선택에는 추가 비용이 들지 않습니다. 분기 중 다른 구매·리롤·잠금·웨이브 이동을 막습니다. 선택한 분기는 해당 Run에서 되돌릴 수 없고 Meta 저장에는 들어가지 않습니다.

## 예약 공격과 정리
연속 검격은 시전 위치·방향을 고정한 후속 공격, 폭격은 목표 지점을 고정한 예고/지연 폭발입니다. 움직이는 적은 범위에서 벗어나 회피할 수 있습니다. 같은 시전의 모든 반복 타격은 치명타/흡혈 문맥과 회복 상한을 공유합니다. 예약 공격은 수량 상한을 갖고 Wave 정리 시 취소합니다. 브라우저 타이머가 아닌 전투 dt로만 진행해 일시정지/배속과 일치합니다. 플레이어 예고는 무기색 원, 적 예고는 붉은색입니다.

F3의 선택 무기 Lv.5 분기로 A/B UI를 열고, 보유 무기 강화로 4→5→6을 확인합니다. 모든 무기 Lv.10 A/B는 이미 정한 분기를 유지합니다. 다른 분기를 비교할 때는 먼저 시작 무기만 남기기로 개발용 초기화하세요. 일반 플레이에는 초기화/분기 변경 기능이 없습니다. HUD와 개발자 목록에 현재 Lv.와 A/B가 표시됩니다.


## 7단계: 설치물 Weapon
설치물은 무료 슬롯 없이 일반 무기 1슬롯을 사용합니다. 총 6슬롯(고유 1 + 일반 최대 5), 기존 획득/강화/해금 검사와 Lv.1~10·Lv.5 A/B 흐름을 그대로 사용합니다.

|무기|capability|적용 스탯|
|---|---|---|
|자동 포탑|STRUCTURE TURRET RANGED PROJECTILE CAN_CRIT HAS_RANGE|Damage, Attack Speed(발사), Ranged Damage, Critical Chance/Damage, Range, Projectile Speed|
|지뢰 살포기|STRUCTURE TRAP MINE AREA EXPLOSIVE|Damage, Area, Attack Speed(설치 주기)|
|마력장 발생기|STRUCTURE AURA AREA DURATION|Damage, Area, Duration, Attack Speed(피해 tick 주기)|

세 설치물에는 Move Speed, Player Armor/Dodge/HP Regen, Pickup Range를 적용하지 않습니다. 포탑/지뢰 수명에는 Duration을 적용하지 않습니다. 별도 설치물 Player Stat은 없습니다. 기본 Lifesteal은 0이며 combatPermissions.indirectLifesteal을 명시적으로 허용할 때만 기존 공격별 회복 상한을 공유합니다.

설치물은 설치한 월드 좌표에 남고 배경과 충돌하지 않습니다. 포탑은 사거리 내 가장 가까운 적에게 기존 pooled projectile을 발사합니다. 지뢰는 접촉 후 범위 폭발하며 소모됩니다. 마력장은 일정 위치에서 주기적으로 범위 피해를 줍니다. 포탑/마력장 설치 주기는 고정이며 각각 발사/tick에만 공격속도가 적용됩니다. 지뢰 설치는 공격속도와 B분기 cooldown을 사용합니다.

src/data/weapons/structures.ts에서 피해·수명·설치 주기·종류별 최대 수·분기를 관리합니다. 포탑 A는 다중탄, 지뢰/마력장 A는 영역 확대, B는 작동 주기 단축입니다. src/data/structureConfig.ts는 전체 상한 48과 배치 간격을 관리합니다. 최대 수 도달 시 추가 배치를 건너뛰며 기존 개체는 수명 후 제거됩니다.

RunState.structures와 structureEffects는 영구 저장하지 않습니다. Wave 정리/무기 초기화 시 제거하고 전투 dt에서만 갱신합니다. StructureSystem은 spatial grid 검색과 공통 CollisionSystem.hit를 재사용하며 Enemy 참조를 매 업데이트 끝에 비웁니다.

특수효과는 sourceId + capability tag + type + value를 가진 structureEffects로 분리했습니다. 현재 maxCount 효과를 실제 적용합니다. 예: {sourceId:'item-example',tag:'MINE',type:'maxCount',value:1}. 이후 타깃 우선순위/추가 발동/연쇄 폭발은 이 효과 계층과 행동 처리기에 추가하고 Player.ts의 무기 ID 분기로 만들지 않습니다. 현재 설치물은 적에게 공격받는 HP가 없어 자체 회복 효과는 후속 사항입니다. 아이템 획득과 상점 연결은 ItemSystem/ShopSystem에 구현되어 있습니다.

F3 → 시험할 무기에서 설치물 선택 → 일반 무기 획득. 설치물 즉시 생성(기존 배치를 비우고 보유 설치물 종류별 1개), 제거, 최대 수 추가 보정, 적용/제외 스탯 안내를 사용할 수 있습니다. 스탯 20개 테스트 도구로 실제 보정도 시험할 수 있습니다.

