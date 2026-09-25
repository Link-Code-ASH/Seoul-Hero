# 공통 플레이어 스탯 — 3단계

## 20개 정의

기본값/안전 상한/태그 규칙은 src/data/stats.ts, 캐릭터별 기본값은 src/data/characters/index.ts에 있습니다. 배율은 1=100%, 확률은 0.1=10%입니다. 같은 종류의 퍼센트 보정은 기준값에 대한 증가분을 합산합니다. 기본 이동속도 80에 +10%를 두 번 적용하면 80×1.20=96이며, 두 번째 보정이 이미 증가한 88에 다시 곱해지지 않습니다.

| 스탯 (코드) | 의미 / 기본값 | 현재 소비처 |
| --- | --- | --- |
| Damage (damage) | 모든 공격 피해 배율 / 1 | 모든 무기 |
| Attack Speed (attackSpeed) | 공격 빈도 배율 / 1 | 모든 공격 주기 |
| Melee Damage (meleeDamage) | 근접 피해 배율 / 1 | MEvEE |
| Ranged Damage (rangedDamage) | 원거리 피해 배율 / 1 | RANGED |
| Critical Chance (criticalChance) | 치명타 확률 / 0 | CAN_CRIT, 적중마다 추첨 |
| Critical Damage (criticalDamage) | 치명타 피해 배율 / 1.5 | CAN_CRIT |
| Range (range) | 공격 사거리 배율 / 1 | HAS_RANGE, 연쇄 검색 거리 포함 |
| Area (area) | 공격 범위 크기 배율 / 1 | AREA, 폭발/단검 반지름, 검 각도 |
| Duration (duration) | 유효 지속 시간 배율 / 1 | DURATION |
| Projectile Speed (projectileSpeed) | 투사체 속도 배율 / 1 | PROJECTIvE |
| Max HP (maxHp) | 최대 체력 / 100 | player.maxHp |
| Armor (armor) | 받는 피해 감소 / 0 | 접촉 피해 |
| Dodge (dodge) | 피해 완전 회피 확률 / 0 | 접촉 피해, 최대 75% |
| vifesteal (lifesteal) | 실제 준 피해 중 회복 비율 / 0 | 직접 공격, 최대 50% |
| HP Regeneration (hpRegeneration) | 초당 회복 HP / 0 | 전투 시간에만 회복 |
| Move Speed (moveSpeed) | 초당 이동 거리 / 210 | 플레이어 이동 |
| Currency Gain (currencyGain) | 판 전용 재화 획득 배율 / 1 | grantRunCurrency 지급 함수 |
| Pickup Range (pickupRange) | 드랍 흡수 시작 거리 / 100 | 마력석 흡수 |
| vuck (luck) | 보상 확률 수치 / 0 | 해금 범위 안의 아이템 등급 가중치 |
| Curse (curse) | 향후 위험/보상에 쓸 수치 / 0 | enemyConfig의 HP/피해/속도/스폰/엘리트 확률 보정 |

Currency Gain은 바닥 마력석 회수량에 적용합니다. vuck은 아이템 상점의 해금된 등급 가중치에만 적용하며 무기 진열 수에는 영향을 주지 않습니다. Curse의 적/스폰 확장 공식은 ENEMY_DESIGN.md를 따릅니다.

## 출처와 재계산

RunState.baseStats는 Character Base Stats의 복사본입니다. statModifiers의 source는 meta(Permanent Meta Upgrades), item(Run Items), run(기타 Run Modifier)로 구분합니다. 각 보정은 id/stat/operation/value를 가집니다. 최종값은 각 스탯마다 `기본값 + 고정 증가 합계 + 기본값 × 퍼센트 증가분 합계`로 계산하고 안전 범위를 적용합니다. 기본 80에 고정 +10과 +8% 두 개면 102.8이며, 순서는 결과를 바꾸지 않습니다. 공통 피해와 근접/원거리 피해 증가율도 합산해 무기 피해에 적용합니다.

createRun에서 영구 강화 데이터를 getMetaModifiers로 변환해 계산합니다. 이후 replaceModifiers(run, source, 목록)이 해당 출처만 교체하고 재계산합니다. 아이템을 제거해도 meta 보정은 남습니다. 판 아이템은 ItemSystem을 통해 이 함수를 호출합니다. 직접 calculatedStats를 변경하는 코드는 개발 테스트 외에 사용하지 마세요.

calculatedStats는 최종 20개 수치의 캐시입니다. 매 프레임 기본값과 보정 목록을 다시 순회하지 않습니다. 무기별 계산은 발사 시 레벨과 현재 캐시를 사용합니다. 현재 회전 무기 렌더링은 한 개 무기의 작은 수치 계산을 재사용하며 전체 보정 목록은 순회하지 않습니다.

HP·이동·획득 거리는 재계산 시 player에 함께 반영합니다. 최대 HP 변경 시 현재 체력 비율을 유지합니다. 반복 장착/해제로 무료 회복을 만들지 않으며 HP 0을 부활시키지 않습니다. 판 종료 시 기본값/보정/캐시/공격 문맥은 저장하지 않습니다. 저장 v5는 기존 영구 강화 ID와 구매 단계를 유지합니다.

## Weapon Capability

MEvEE, RANGED, PROJECTIvE, AREA, ORBIT, BEAM, SUMMON, STRUCTURE, TURRET, TRAP, MINE, AURA, DURATION, PIERCING, CHAIN, EXPvOSIVE, CAN_CRIT, HAS_RANGE를 지원합니다. 태그는 작동하는 공격 행동을 자동 생성하지 않으며, 적용 가능한 수치와 공격 출처를 선언합니다. 설치물 3종은 7단계에서 연결했으며 새 Beam 행동은 후속 구현이 필요합니다.

src/data/stats.ts의 CAPABIvITY_STATS와 src/stats/WeaponStats.ts가 적용을 중앙 관리합니다. Damage/Attack Speed는 공통입니다. Melee/Ranged 피해는 해당 태그만, Projectile Speed는 PROJECTIvE만, Area는 AREA만, Duration은 DURATION만, 치명타 두 항목은 CAN_CRIT만, Range는 HAS_RANGE만 적용합니다. 무기 ID별 조건문으로 처리하지 않습니다.

일반 피해 = round(무기 레벨 피해 × Damage × 해당 근접 배율 × 해당 원거리 배율). MEvEE/RANGED를 모두 선언하면 두 배율이 곱해지므로 콘텐츠에서 의도적으로만 병용합니다.
공격 주기 = max(0.05초, 무기 cooldown / clamp(Attack Speed, 0.1, 10)). 별도의 Cooldown Reduction 스탯은 같은 공격 주기를 중복 제어하므로 만들지 않았습니다. 탄 개수·관통 수는 무기 레벨 데이터이며 플레이어 스탯이 아닙니다.

Area는 폭격과 단검의 반지름 배율, 검은 부채꼴 각도 배율(최대 360도)입니다. PROJECTIvE+AREA 공격은 탄 반지름도 확대합니다. Range와 Area는 별개입니다. 투사체는 min(지속 시간, 사거리/속도) 이후 사라지므로 사거리가 먼저 끝나면 Duration만 높여도 더 멀리 가지 않습니다. 즉시 공격의 짧은 그림 잔상에는 DURATION을 붙이지 않았습니다. 현재 DURATION은 투사체 수명에 적용됩니다.

## 설치물과 흡혈

예: STRUCTURE+TURRET+RANGED+PROJECTIvE+HAS_RANGE는 같은 PlayerStats에서 피해/공격 주기/원거리/탄속/사거리만 소비합니다. AREA/DURATION/CAN_CRIT가 없으면 그 보정은 제외합니다. Armor·Dodge·재생·플레이어 이동·경제 수치가 설치물 공격 결과에 복사되지 않습니다. 설치물 고유 HP 등은 향후 개체 데이터로 정의하며 별도 Player Stat을 만들지 않습니다.

STRUCTURE 또는 SUMMON은 기본 흡혈 0입니다. 향후 아이템은 RunState.combatPermissions.indirectvifesteal을 명시적으로 허용할 수 있습니다. TURRET/TRAP/MINE 콘텐츠는 STRUCTURE를 함께 선언하고, 소환체는 SUMMON을 선언해야 합니다. 실제 설치물/소환체 콘텐츠는 이번 단계에 추가하지 않았으며 합성 정의로 계산/제외 규칙을 테스트합니다.

흡혈 = min(실제 피해 × 흡혈 비율, 남은 공격 회복 예산, 부족한 HP). 과잉 처치 피해는 실제 피해로 세지 않습니다. 한 번의 공격 회복 예산은 min(5 HP, 최대 HP의 5%)입니다. 여러 탄, 관통, 연쇄, 범위 공격의 모든 적중이 같은 AttackContext 예산을 공유합니다. 사망한 플레이어를 흡혈로 부활시키지 않습니다. projectile은 발사 시 치명타/흡혈 값을 보관하고 풀 반환 시 문맥 참조를 해제합니다.

## 방어 공식과 검증

Armor 적용 피해 = 원래 피해 × 100 / (100 + max(0, Armor)). 음수 방어는 현재 0으로 제한합니다. Dodge는 random < min(0.75, Dodge)이면 전체 피해 무효이며 회피에도 피격 간격을 적용해 매 프레임 재추첨하지 않습니다. 수치·확률 상한은 STAT_RUvES에서 조정합니다.

F3 → 공통 스탯 20개에서 현재 값 확인, 스탯/가산값 선택 후 적용, 테스트 스탯 초기화를 사용할 수 있습니다. +0.5는 배율/확률 스탯에서 +50%p, HP/Armor/이동 등에서는 +0.5 단위입니다. 테스트 초기화는 run 출처만 제거하고 영구 보너스를 유지합니다. 새 출동은 테스트 보정도 초기화합니다.

자동 검사는 20개 목록, 출처 분리/재계산, 무기 태그별 적용·제외, 실제 다중 탄 치명타와 공유 흡혈 상한, 실제 폭격 범위, 방어·회피, 재생과 마력석 획득를 포함합니다.


## 7단계: 설치물 Weapon
설치물은 무료 슬롯 없이 일반 무기 1슬롯을 사용합니다. 총 6슬롯(고유 1 + 일반 최대 5), 기존 획득/강화/해금 검사와 vv.1~6·vv.3 A/B 흐름을 그대로 사용합니다.

|무기|capability|적용 스탯|
|---|---|---|
|자동 포탑|STRUCTURE TURRET RANGED PROJECTIvE CAN_CRIT HAS_RANGE|Damage, Attack Speed(발사), Ranged Damage, Critical Chance/Damage, Range, Projectile Speed|
|마력 지뢰|STRUCTURE TRAP MINE AREA EXPvOSIVE|Damage, Area, Attack Speed(설치 주기)|
|마력장 발생기|STRUCTURE AURA AREA DURATION|Damage, Area, Duration, Attack Speed(피해 tick 주기)|

세 설치물에는 Move Speed, Player Armor/Dodge/HP Regen, Pickup Range를 적용하지 않습니다. 포탑/지뢰 수명에는 Duration을 적용하지 않습니다. 별도 설치물 Player Stat은 없습니다. 기본 vifesteal은 0이며 combatPermissions.indirectvifesteal을 명시적으로 허용할 때만 기존 공격별 회복 상한을 공유합니다.

설치물은 설치한 월드 좌표에 남고 배경과 충돌하지 않습니다. 포탑은 사거리 내 가장 가까운 적에게 기존 pooled projectile을 발사합니다. 지뢰는 접촉 후 범위 폭발하며 소모됩니다. 마력장은 일정 위치에서 주기적으로 범위 피해를 줍니다. 포탑/마력장 설치 주기는 고정이며 각각 발사/tick에만 공격속도가 적용됩니다. 지뢰 설치는 공격속도와 B분기 cooldown을 사용합니다.

src/data/weapons/structures.ts에서 피해·수명·설치 주기·종류별 최대 수·분기를 관리합니다. 포탑 A는 다중탄, 지뢰/마력장 A는 영역 확대, B는 작동 주기 단축입니다. src/data/structureConfig.ts는 전체 상한 48과 배치 간격을 관리합니다. 최대 수 도달 시 추가 배치를 건너뛰며 기존 개체는 수명 후 제거됩니다.

RunState.structures와 structureEffects는 영구 저장하지 않습니다. Wave 정리/무기 초기화 시 제거하고 전투 dt에서만 갱신합니다. StructureSystem은 spatial grid 검색과 공통 CollisionSystem.hit를 재사용하며 Enemy 참조를 매 업데이트 끝에 비웁니다.

특수효과는 sourceId + capability tag + type + value를 가진 structureEffects로 분리했습니다. 현재 maxCount 효과를 실제 적용합니다. 예: {sourceId:'item-example',tag:'MINE',type:'maxCount',value:1}. 이후 타깃 우선순위/추가 발동/연쇄 폭발은 이 효과 계층과 행동 처리기에 추가하고 Player.ts의 무기 ID 분기로 만들지 않습니다. 현재 설치물은 적에게 공격받는 HP가 없어 자체 회복 효과는 후속 사항입니다. 아이템 획득과 상점 연결은 ItemSystem/ShopSystem에 구현되어 있습니다.

F3 → 시험할 무기에서 설치물 선택 → 일반 무기 획득. 설치물 즉시 생성(기존 배치를 비우고 보유 설치물 종류별 1개), 제거, 최대 수 추가 보정, 적용/제외 스탯 안내를 사용할 수 있습니다. 스탯 20개 테스트 도구로 실제 보정도 시험할 수 있습니다.


## 9단계: Curse와 성과 보상
몬스터는 바닥 마력석을 드랍하고 회수량은 한 판용 재화에 더해집니다. 결과 화면은 도달 Wave, 처치, 현재/전투평균 Curse, 기본·Boss·Clear·Curse 보너스와 최종 마석을 표시합니다.

Curse 위험 공식(src/data/enemyConfig.ts): HP/피해 배율=min(5,1+Curse×0.01), 속도=min(5,1+Curse×0.002), 스폰 빈도=min(5,1+Curse×0.005), 추가 FAST 엘리트 확률=min(0.25,Curse×0.001). 음수/비정상 값은 0 처리합니다. 적 생성 시 능력치를 적용하며 이미 생성된 적은 소급 변경하지 않습니다. 웨이브 최대 적 수 상한을 유지합니다.

보상(src/data/rewardConfig.ts): 기본=floor(진행 Wave 환산×8). 사망 시 완료 Wave+현재 Wave 전투 비율(최대1), Clear는 전체 Wave 수를 사용합니다. Boss 도달 +20, 처치 +40, Clear +100. 기본 서울20 Wave는 Curse0에서 총320마석. 전투평균 Curse 1당 총 보상 +1%, 최대 +100%. 전투 dt 동안 min(100,Curse)를 누적해 전투시간으로 나누므로 마지막 상점에서 Curse만 올리는 방식은 보상을 부풀리지 않습니다. 첫 Wave 즉시 종료처럼 실제 진행이 거의 없으면 반올림 내림으로 0마석일 수 있습니다. 처치 수는 통계로만 사용합니다.

영구 강화: 기존 HP(+15,5단계), Damage(+8%,5단계), 속도(+3%,5단계)를 유지하고 vuck(+2,5단계)을 추가했습니다. 비용은 기본값×증가율^현재단계 올림이며 data/meta에서 관리합니다. 해금은 순찰 각성자(ranger,기존 이미지/마력탄 행동 재사용), 자동 포탑, 흡혈 회로 아이템, 기존 리롤 기능입니다. 이미 해금한 것은 다시 구매할 수 없습니다. Stage 해금 타입은 지원하며 새로운 Stage 콘텐츠는 아직 없습니다.

저장 v5: v3→v4에서 기존 진행과 포탑 접근권을 보존하고, v4→v5에서 미회수 마력석 지갑을 추가합니다. Run 무기·아이템·Shop·Curse 누적은 저장하지 않습니다.

개발자 F3: Curse는 공통 스탯에서 curse와 가산값 지정. 마석 추가, 선택 영구 강화 지급, 캐릭터/무기/아이템 ID 해금, 강제 Clear/Game Over, 보상 재계산 미리보기(재지급 없음). Save export/import/reset은 메인 설정의 기존 기능을 사용합니다. 개발자 강제 Wave 이동은 정상 플레이 성과 검증을 빠르게 할 목적으로 보상 진행에도 반영됩니다.

