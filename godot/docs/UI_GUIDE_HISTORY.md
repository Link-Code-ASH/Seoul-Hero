# Godot 이미지 UI 소재와 시안 규칙

915×412를 우선 기준으로 한다. 모든 새 UI는 `design/ui-image-skins`에 게임과 분리한 시안으로 제시하고, 사용자가 승인한 다음 런타임에 연결한다. 시안 작업만으로 게임 화면·규칙·저장·밸런스·오디오를 변경하지 않는다.

## 이미지 소재

- 프레임·버튼·기본 표면은 제작한 래스터 PNG를 기본 미술 소재로 사용한다. 고정 크기 소재는 원래 비율로, 크기가 달라지는 소재는 검토한 9분할로 표시한다. 모서리·테두리·중앙 영역과 내용 안전 여백을 함께 기록한다.
- `StyleBoxFlat`·SVG·코드로 그린 프레임과 광택을 새 UI의 기본 경로로 사용하지 않는다. 승인된 PNG를 `TextureRect`/`StyleBoxTexture`로 조합하고 기존 행·열·스크롤 컨테이너가 배치를 소유하게 한다.
- 단색 패널을 이미지 소재 위에 덧대지 않는다. 넓은 여백에는 얕은 재질·작은 삽화를 활용하되 본문·효과·가격 뒤에는 복잡한 장식을 놓지 않는다. 선택·잠금·비활성·위험 상태는 읽을 수 있는 이미지 상태와 텍스트로 구분한다.
- 기존 소재 역할은 glass(로비·HUD·팝업), equipment(무기·상품), document(자료집·협회), ceramic(축복·선택), reward(보상), control(버튼)이다. `HeroUI.panel`의 역할과 각 화면의 배치 책임을 유지한다. 기존 `data/visuals/ui_materials.json`의 텍스처·9분할·안전 여백 기록을 승인된 소재에 맞춰 확장한다.
- 새 PNG의 원본·프롬프트·출처는 시안 폴더에 보존한다. 기존 `assets/ui/urban/source`와 이전 원화 출처를 삭제하지 않는다.

## 텍스트와 아이콘

- 기능 텍스트는 HTML/Godot의 네이티브 텍스트로 렌더링한다. 상품명·효과·패널티·가격·상태를 소재 이미지에 구워 넣지 않는다. 제목·버튼·배지는 중앙, 본문은 좌측 상단, 숫자는 우측 정렬한다.
- 실제 파일이 다른 폰트를 역할별로 선택한다. Paperlogy는 본문/버튼, Haeong Sans는 메뉴/시설 제목, Sungkok Serif는 기록/협회 제목, SF Ssaraknun·BMJUA는 보상 강조, Barlow Condensed는 숫자/계기에 사용할 수 있다. 합성 굵기나 이름만 다른 동일 폰트로 다양성을 대신하지 않는다. 시안의 각 화면에서 제목·본문·숫자 위계를 유지한다.
- 시안용 제공 TTF와 출처·라이선스 기록은 `design/ui-image-skins/fonts/README.md`에 있다. 폰트 엔진의 실제 높이·fallback·행간으로 줄 공간을 계산하며 본문14px·보조13px·조작 영역44px 이상을 유지한다. 중요한 글자를 숨기거나 줄여서 박스에 맞추지 않는다.
- 아이콘은 정보·기능·조작의 의미가 있는 곳에 사용한다. 텍스트를 대신하는 아이콘에는 설명과 상태 구분을 제공하며, 모호한 조건·횟수·패널티는 글자를 유지한다. 메인 타이틀은 로고·부제·핵심 일러스트로 구성하고 기능 아이콘을 장식처럼 채우지 않는다.
- 기본·선택·누름·비활성 상태에서 버튼의 크기와 내용 위치를 유지한다. 팝업의 제목/하단 버튼을 먼저 확보하고 긴 목록·설명만 내부 스크롤한다.

## 승인과 연결

먼저 실제 PNG 소재와 제공 폰트를 조합한 시안을 제시한다. 사용자 피드백과 승인을 반영한 다음 이미지 manifest·소재 데이터·화면 연결을 함께 갱신한다. 기존 `arcade`/`light` 역할과 구매·잠금·리롤·HUD 갱신은 이 연결 단계까지 유지한다. 필요한 가져오기/스크립트 오류와 요청된 시안만 확인하며 전체 테스트·빌드·수동 플레이 QA를 기본 절차로 추가하지 않는다.

## 선택한 시안 방향

2026-10-02 사용자 피드백: B안의 폰트·디자인과 A안의 나사형 PNG 프레임을 조합한다. BMJUA·해옹산스·Paperlogy·Barlow의 역할과 크림·남색·보라 강조를 사용하며, 프레임 형태는 나사·볼트가 있는 A안 소재를 유지한다. 로비 시설 5개는 공통 받침 프레임에 묶지 않고 각각 독립적으로 둔다. 각 시설의 구분은 테두리 없는 옅은 글래스모피즘·간격으로 표현한다. 수정 시안은 design/ui-image-skins의 c-title/c-lobby/c-shop이다. 사용자가 이 조합을 컨펌했으며 타이틀·로비·상점에 적용한다. 다른 화면은 같은 조합의 시안을 먼저 제시한다.

## 승인한 PNG 스킨의 구현

`HeroImageSkin`은 승인된 PNG 9분할 표면·버튼 상태·글꼴·로비 유리 효과와 카드·스크롤·슬라이더 표시를 소유한다. `data/visuals/ui_materials.json`의 `image_skin`에 원본 영역·분할·여백·4배 소스 배율을 보존하고, 실제 버튼과 텍스트는 네이티브 Control에 남긴다. `assets/ui/image-skin/provenance.json`과 원본 시안 프롬프트를 함께 유지한다. 내부 NinePatchRect를 뒤에 그려 컨테이너 크기와 네이티브 글자 위치를 바꾸지 않는다. Godot의 [CanvasItem 표시 순서](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-show-behind-parent)를 사용한다.

2026-10-03 phase3 시안과 피드백을 승인받아 출동 6단계·성장·자료집·설정·전투 HUD·일시정지에 실제 연결했다. 승인된 타이틀·로비·상점은 기존 호출과 소재를 유지한다. 구매·잠금·리롤·분기·저장·전투 규칙을 스킨 데이터에 넣지 않는다.

## 선택 목록과 실제 화면 검토

- 각성자·시작 무기·출동 축복은 공용 4열 PNG 카드 목록과 오른쪽 내부 스크롤 상세판을 사용한다. 쟁반·발판·반원 받침은 렌더링하지 않는다. 미해금 카드도 상세를 볼 수 있으며 실제 선택 변경은 기존 해금 조건을 따른다.
- `main.gd`의 `gate_ui.inspected`·`gate_ui.scroll`은 화면 검토 상태다. 출동 `draft`, `HeroRun.setup`, 체크포인트·영구 저장에 넣지 않는다. 성장·자료집 목록의 위치도 UI 상태에만 보관한다.
- `HeroImageSkin.DragScroll`은 8px 세로 드래그 이후 카드의 클릭을 취소하고 터치·마우스 드래그와 네이티브 휠을 처리한다. 다시 생성된 목록은 UI 상태에서 스크롤 위치를 복원한다.
- `content_rect`와 `safe_padding`은 소재 안쪽의 텍스트 기준을 제공한다. 제목/버튼은 중앙, 본문은 좌측 상단, 숫자는 우측 정렬한다. 자료집 책 프레임은 왼쪽 48px·오른쪽 24px 여백을 확보한다.
- PNG 소재·프롬프트·출처는 `assets/ui/image-skin/runtime/provenance.json`, 분할·내용 여백·논리 크기는 `data/visuals/ui_materials.json`에 있다. B 글꼴은 BMJUA 큰 제목·해옹산스 섹션·Paperlogy 본문/버튼·Barlow Condensed 숫자를 사용한다.
- 실제 화면 캡처는 `tools/image_skin_capture.tscn -- --ui-preview --output=res://exports/ui-feedback-runtime`로 만든다. 운영 화면 클래스와 데이터·실제 UI 콜백을 사용하되 저장 쓰기와 전투 시뮬레이션을 차단한다. 확인 갤러리는 `design/ui-image-skins/runtime-feedback/index.html`이다.

## 2026-10-03 선택 상태·선명도·밀도 보정

- 선택 카드는 항상 `cards/normal`의 같은 원본 영역과 배치를 유지한다. 공용 상태 셰이더가 색/채도를 조절하고 `accents/selection` 투명 테두리만 덧씌운다. 별도 배경 셀로 선택 상태를 교체하지 않는다. 상점 탭도 `stable_button`으로 같은 나사 프레임 원본을 유지한다.
- `texture(key, raster_density=1)`와 `style(key, inset=ZERO, raster_density=1)`은 배율별 캐시를 사용한다. HP·음량 Range만 밀도4 PNG와 내부 크기4배/표시¼배율을 사용한다. 스타일 내부 여백·텍스처 분할도 같은 배율로 처리하고 실제 44px 입력 영역을 유지한다.
- 전용 PNG는 `assets/ui/image-skin/runtime/bars_02.png`·`accents_02.png`이며 원본 프롬프트/출처와 안전영역은 같은 폴더 provenance 및 Godot 소재 데이터에 있다. 기존 소재와 이전 원본은 보존한다.
- 상품 카드의 이름15px·설명/메모13px·가격16px은 사용자가 선택한 예외다. 본문은 핵심 요약이며 두 줄을 넘지 않는 `shopCardText {summary, penalty}`를 사용한다. 카드 안에는 스크롤을 만들지 않고 기존 전체 설명/조건/패널티/한도는 터치 상세에서 유지한다. 현재 아이템55종·무기10종 모두 표시 문구를 갖는다.
- 구매면은 마력석+정확 가격, 잠금은 상품 우상단과 테두리 강조, 일시정지·리롤은 프레임 없는 PNG 아이콘이다. 잠금은 진열 유지이며 구매와 구분한다.
- Godot 마우스 툴팁은 사용하지 않는다. 터치 상세와 화면의 잠금 사유를 정보 경로로 유지한다.

## 2026-10-03 에나멜·유리 피드백의 실제 연결

최신 피드백을 포함한 실제 적용을 사용자가 명시적으로 승인했다. enamel/glass/cstore/spy/lobby_icons 소재를 운영 화면에 연결했다. 원본과 built-in imagegen 프롬프트는 assets/ui/image-skin/enamel-glass/provenance.json 및 design/ui-image-skins/enamel-glass-01/에 있다. 공용 역할은 image_id로 다른 승인된 PNG 시트를 참조할 수 있다. 기능/저장 규칙은 여전히 화면/상태 계층에 남는다.

- 선택·자료집 카드는 같은 서울 배경 위에 투명 유리/약한 그림자 PNG를 조합한다. 원화색과 배경 좌표는 바꾸지 않는다. 선택 상세는 원화+핵심 정보를 상단에 고정하고 설명/스탯만 아래 스크롤한다.
- HUD는 체력 표기 옆에 재화13px/아이콘12px을 한 행으로 묶고 HP 바의 가로 범위x20~200 안에 둔다.180×10 HP 바는y37, 무기6개/흰14px레벨은 아래x20~182/원화y62에 둔다. 네이티브 ProgressBar와 WalletIcon 비행 목적지를 유지한다.
- 로비는 양쪽 유리 영역, 차분한 뉴모피즘 PNG 도구3개, 큰 작전 단말/스캔광/남색 투입 버튼을 쓴다. 제목BMJUA·메뉴해옹산스·본문Paperlogy·숫자Barlow를 실제로 구분한다.
- 상점은 편의점 냉장 진열대 PNG와 상단 흰 내용면을 쓴다. 나사 없는 탭/리롤, 연한 노란110×28 구매면과44px입력, 민트 잠금 상태를 분리한다. 가격/짧은 문구/전체 터치 상세와 구매·잠금·독립 리롤은 기존 데이터를 사용한다.
- PNG 상태에는 명시적 disabled_role을 지원하며 선택 상태도 같은 원본 기하를 유지한다. 래스터 고밀도 스타일 캐시는 배율과 소재 역할로 구분한다.

실제 적용 캡처: tools/image_skin_capture.tscn -- --ui-preview --output=res://exports/ui-enamel-runtime04. 갤러리: design/ui-image-skins/enamel-glass-01/index.html. 이전 독립 시안은 revision-03/에 보존했다. 확인 범위는 같은 폴더 QA.md에 기록했다.

## 2026-10-05 회수·보급 승인 연결

`seoul-support-01` Revision 02의 접지감 보정을 승인받아 회수·보급을 각각 `HeroRecoveryScreen`·`HeroSupplyScreen`으로 연결했다. `HeroSupportScreen`은 PNG 표면/폰트/안전 여백, `HeroSupportPresentation`은 원화·드론/착지/분리 뚜껑 연출을 소유한다. 보상은 코어의 기존 행동에서 한 번 지급·저장하고 실제 반환값만 화면에 전달한다. 표시 완료·결과 확인·화면 닫기에서 지급하지 않는다. 숨김/앱 중단에 시간 정지, 이탈에 취소하며 공용 UI VFX 상한을 재사용한다.

PNG 8종·프롬프트·원본 해시는 `assets/ui/image-skin/seoul-support`, 소재 여백은 `image_skin.support/panel`에 있다. 배경 원본 약2배/합성4배의 구분을 유지한다. 로비 배경/시설 아이콘·확률·비용·저장 형식은 유지했다. 읽기 전용 운영 클래스 캡처는 `tools/support_runtime_capture.tscn -- --ui-preview`, 실제 지급/추첨을 실행하지 않는 고정 콜백임을 갤러리에 명시한다.

## 2026-10-05 고정 관리 패널 길드

사용자가 guild-offices-01 수정 시안을 승인했다. 길드는 왼쪽547px 건물과 오른쪽330px 관리 공간을 항상 확보하며 하단 버튼을 제거한다. 선택 전 오른쪽은 빈 배경이고, 시설 선택 후 관리·직원·작업 탭과 내용 내부 스크롤을 사용한다. 패널 개폐로 건물 배율이나 스크롤을 바꾸지 않는다. 기존 승인 방/SD PNG와 cstore 패널/버튼을 재사용한다. 실제 연결과 v3 저장 경계는 GUILD_OFFICES.md, 저장 없는 캡처와 확인 범위는 design/ui-image-skins/guild-offices-01/QA.md에 기록한다.
