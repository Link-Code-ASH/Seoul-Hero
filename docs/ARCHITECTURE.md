# 구조와 책임

## 실행과 상태

AppController는 HTML UI·입력·렌더링·오디오·저장을 연결합니다. Simulation은 순수 게임 규칙을 실행하고 GameLoop는 제한된 delta와 배속을 적용합니다.

RunPhase는 `preparing → waveActive → postWave → shop → waveActive` 전환표를 사용합니다. 치명상 시 `waveActive → revivalChoice → waveActive/gameOver`로 이동하며 생환석을 소비할 때만 부활합니다. paused는 전투 일시정지, stageClear/gameOver는 결과 상태입니다. Lv.5 무기 구매로 `pendingBranchWeaponId`가 생기면 분기를 고르기 전 다른 구매·리롤·다음 Wave 이동을 막습니다.

RunState에는 Wave/시간/HP/무기/아이템/계산 스탯/한 판용 마력석/복구 지갑/통합 상점과 출동 시 고정된 맵·심도·주간 규칙·축복만 둡니다. 저장 v12의 MetaState는 계정 해금, 게이트 진행, 캐릭터, 공용 무기, 축복, 생환석 보유 수량, 협회, 주간 상태, 보급, 오프라인 보상, 통계, 설정을 책임별 하위 상태로 보존합니다.

전투 밖에서는 `lobby`가 시작 화면입니다. `GateEntryDraft`는 저장하지 않는 임시 선택이며 `map → depth → character → weapon → blessing → confirm` 여섯 화면을 거쳐 중앙 검증을 통과해야 Simulation을 만듭니다. 맵 정의는 `data/maps`, 계정 공용 심도는 MetaState의 `gateProgression`에 있어 서로 독립적입니다.

## 모듈

- `data`: 콘텐츠와 밸런스
- `systems`: 전투, 스폰, 무기, 아이템, 통합 상점, 설치물
- `state`: Run/Meta와 phase, 공통 스탯
- `world`/`rendering`: 유한 아레나, 카메라, Pixi WebGL
- `input`: 키보드·터치를 공통 이동 방향으로 변환
- `save`/`meta`: 검증·이관·백업, 영구 성장과 종료 정산
- `ui`/`dev`: HTML 화면과 개발 도구

로비와 게이트 흐름은 `LobbyScreen`, `GateFlowScreen`, 진행 골격은 `MetaScreens`에 나뉩니다. 새 맵은 MapData 등록만으로 게이트 목록에 나타나며, 캐릭터·무기·축복은 각 콘텐츠 데이터와 Meta 기본 진행 레코드를 통해 화면과 저장 검증에 연결됩니다.

`data/gateProgression.ts`는 심도 배율과 10심도 콘텐츠 변화를, `data/weeklyGate.ts`는 패널티와 고정 베네핏을 묶은 주간 규칙 및 조각형 축복을 소유합니다. `WeeklyGateSystem`은 KST 주차 계산·비복원 추첨·주간 베네핏과 보유 축복의 스탯 변환을 담당합니다. `StageReward`와 `RunSettlement`은 캐릭터별 미수령 심도 보상과 계정 공용 해금을 한 번만 정산합니다.

## 상점 데이터 흐름

`ShopSystem`은 `RunState.shop.weaponStock`과 `itemStock`을 독립적으로 채우고 리롤·잠금·구매를 검증합니다. 무기 구매는 기존 무기 레벨·분기 적용 로직을 재사용하고 아이템 구매는 ItemSystem을 통해 스탯을 즉시 재계산합니다. 상품 상태는 영구 저장하지 않습니다.

공간 검색으로 전투 충돌 대상을 제한하고 투사체·Pickup을 재사용합니다. Wave 종료 시 적·투사체·설치물·예약 공격·공간 검색 참조를 정리하며, 남은 마력석은 다음 Wave 복구 지갑으로 이동합니다.


## UI 스타일과 모바일 검증

스타일 진입점은 `src/styles/main.css` 하나이며 화면/재질/타이포그래피 뒤에 `mobile-viewport.css`를 적용합니다. 공통 재질은 :where 기본값으로 두어 selected/active 상태를 덮지 않게 합니다. 915×412 가로 화면을 기준으로 루트는 고정하고 목록만 내부 스크롤합니다. 상점의 전투 시작 버튼은 상품 스크롤 바깥에 둡니다. 정리 범위와 실제 확인 근거는 [STRUCTURE_AUDIT.md](./STRUCTURE_AUDIT.md)를 참고합니다.
