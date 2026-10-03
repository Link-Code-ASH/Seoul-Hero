# 서울 히어로 UI 비교와 독립 시안
2026-10-02 · 915×412 · 시안 전용. 런타임 연결 전 사용자 컨펌.

## 바로잡은 설계
화면의 목적과 정보 우선순위보다 승인 프레임을 반복한 것이 문제였다.
맵·심도, 각성자·무기를 합치지 않는다. 출동 축복 선택과 영구 축복 성장을 구분한다.
나사 프레임을 외곽·카드·슬롯·버튼에 반복하지 않는다. 보라 게이트 장식과 보라 설정 상태를 없앤다.
전투 HUD는 전장을 비우며, 정보가 배경 위에서 읽히게 한다. 글꼴 측정은 보조 확인이다.

## 실제 메뉴·HUD 비교의 근거
사용자가 승인한 비교 보고의 공식 공개 화면 자료를 기록한다. 이번 시안 제작에서 게임을 설치해 메뉴를 전수 조사하지 않았고, 실제 플레이·터치 확인을 추가하지 않았다. 홍보 외곽 장식과 큰 캐릭터는 HUD로 계산하지 않는다.

| 게임·공식 출처 | 메뉴에서 가져올 원칙 | HUD에서 가져올 원칙 |
|---|---|---|
| [Vampire Survivors](https://apps.apple.com/us/app/vampire-survivors/id6444525702?platform=ipad) | 지역 썸네일·설명·모드·시작의 역할 구분 | 장비 아이콘·중앙 타이머·얇은 바 |
| [Archero](https://play.google.com/store/apps/details?id=com.habby.archero&hl=en) | 능력 그림과 짧은 이름 | 작은 일시정지·재화 |
| [Survivor.io](https://play.google.com/store/apps/details?id=com.dxx.firenow&hl=en) | 이름·그림·효과·등급의 위계 | 얇은 바와 아이콘·숫자 |
| [Arknights](https://play.google.com/store/apps/details?hl=en&id=com.YoStarEN.Arknights) | 로비 기능별 크기·도시 맵 중심 | 작은 상태·배속·일시정지 |
| [Guardian Tales](https://play.google.com/store/apps/details?id=com.kakaogames.gdts) | 배경과 독립 하단 아이콘 | 모서리 정보·반투명 이동 조작 |
| [Pokémon UNITE](https://play.google.com/store/apps/details?hl=en-US&id=jp.pokemon.pokemonunite) | 작은 메뉴와 주요 전투 버튼의 강조 차이 | 중앙 시간·독립 조작 |
| [Clash Royale](https://play.google.com/store/apps/details?id=com.supercell.clashroyale&hl=en) | 실제 카드 그림·분류·선택 구분 | 필요한 위치의 시간·상태·카드 |
| [Brawl Stars](https://play.google.com/store/apps/details?hl=en&id=com.supercell.brawlstars) | 모드명·맵 미리보기 | 박스 없는 상태 글자 |
| [Dead Cells 모바일](https://play.google.com/store/apps/details?id=com.playdigious.deadcells.mobile&hl=en) | [설정의 동작명·조작 행](https://playdigious.helpshift.com/hc/en/7-dead-cells/faq/142-how-to-use-dual-binding-on-dead-cells-mobile/?p=android) | 왼쪽 위 상태·재화를 큰 공통 박스 없이 |
| [Otherworld Legends](https://play.google.com/store/apps/details?id=com.chillyroom.zhmr.gp&hl=en) | 제목 띠·슬롯·상품 받침의 형태 구분 | 작은 상태와 독립 조작 |
| [Brotato 모바일](https://apps.apple.com/us/app/brotato-premium/id1668755109?platform=ipad) | 메뉴 확인 근거 없음 | 가로 HUD의 왼쪽 위 얇은 바·재화, 중앙 웨이브 |

미니맵·수동 공격 버튼·타 게임 선택 흐름을 새 기능으로 가져오지 않는다.

## 독립 시안과 소재
| 화면 | 새 구성 |
|---|---|
| 맵 | 실제 광화문 원화 + 얇은 안내판 |
| 심도 | 1~20 번호·클리어·선택·도전·잠금·실제 배율 |
| 각성자 | 실제 SD 4종 + 낮은 발판 |
| 무기 | 시작 무기 7종 + 장비 선반·이름·역할 |
| 출동 축복 | 축복 없음·7종·해금 상태 + 청자 받침·효과 |
| 편성 확인 | 맵·심도·각성자·무기·축복·주간 규칙 |
| 영구 성장 | 조각·단계·실제 비용 + 축복 큰 원화 |
| 자료집 | 실제 수집물 진열 + 큰 원화·조용한 읽기 면 |
| 설정 | 낮은 채도의 콘솔 + 정렬된 조작 행·민트 |
| 평상시 HUD | 박스 없이 얇은 HP·재화·무기·웨이브·시간·일시정지 |
| 일시정지 | HUD와 별도 PNG 작전 알림 표면 |

새 소재는 navigation/personnel/armory/arcane/codex/console/command/controls 8팩, 각 4역할이다. SVG나 코드의 단색 박스+광택으로 소재를 대체하지 않았다. 패널·버튼의 중심은 조용하며 본문 뒤에 도시 질감을 넣지 않는다.

## 공용 글꼴
| 역할 | 실제 파일 | 사용 |
|---|---|---|
| 큰 제목 | BMJUA.ttf | 독립 화면 제목 |
| 섹션 제목 | KMU80HaeongSans.ttf | 선택 원화 이름·섹션 |
| 본문 | Paperlogy-4Regular.ttf | 효과·조건·패널티 |
| 버튼·이름 | Paperlogy-5Medium.ttf | 조작·목록 |
| 숫자·시간 | BarlowCondensed-SemiBold.ttf | HP·재화·시간·심도 |
이용 조건은 기존 ../fonts/README.md와 ../PROMPTS.md의 글꼴 기록을 따른다. 한글 대체는 Paperlogy. 본문14px, 보조13px, 조작44px 이상. 주황 버튼 안쪽 밝은 면은 남색 글자로 대비를 확보한다.

## 정적 fixture와 적용 경계
실제 콘텐츠는 지역1·각성자4·시작 무기7·축복7·아이템55종이다.
선택 시안은 심도6, 최고 해금7/클리어5, 송진우/마력탄/천부인의 맹세Lv1, 풍요의 매듭Lv2, 주간 경화된 침식을 사용한다. 이 해금·성장 상태는 잠금/선택을 비교하기 위한 시안 fixture이며 사용자 저장이 아니다. 배율은 콘텐츠의 실제 공식을 사용한다.
영구 성장은 기본 보유 조각0/미해금 풍요의 매듭0단계 fixture다. 설정은 실제 기본 음량80/50/72/78이다.
HUD는 정지한 실제 원화 조합이며 전투 시뮬레이션은 실행하지 않는다. 현재 마력석과 미회수 마력석은 별도 의미로 유지한다. 추후 연결 시 WalletIcon 목적지/실시간 Label 갱신을 보존한다.
타이틀·로비·상점의 승인된 C안 구현은 유지했다. 새 화면의 런타임·선택·구매·HUD 콜백 연결은 이번 작업에 포함하지 않는다.

## 파일
- index.html: 화면을 한 번에 하나씩 보는 갤러리
- captures/: 독립 PNG11종 + 소재보드 + 확인용2종, 글꼴 배치 JSON
- assets/: 생성 PNG 원본8팩
- materials.json: 원본 영역·9분할·표시 배율·안전 여백
- PROMPTS.md / provenance.json: 생성 프롬프트·원본 출처
- QA.md: 시안 확인과 미확인 범위

**프레임은 제작한 이미지가 기본이다.** 화면별 목적에 맞는 역할을 선택하고 프레임 없는 요소도 허용한다. 시안의 명시적 컨펌 후에만 게임 연결과 후속 소재 확장을 진행한다.
