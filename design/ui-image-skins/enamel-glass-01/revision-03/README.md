# 에나멜·유리 UI 독립 시안 · 3차 수정

상태: **approvalPending — 사용자 승인 대기**

915×412 독립 Godot 디자인 프로젝트입니다. 동결 콘텐츠·기존 원화와 제작 PNG로 UI의 표면·배치·글꼴을 비교합니다. 생산 UI·프로필/저장 어댑터·오디오·전투 시뮬레이션은 로드하지 않습니다. UI 런타임 연결은 승인 후 진행합니다. 이번 3차 수정은 게임 소스를 변경하지 않습니다. 앞선 2차에서 반영한 공용 마력석 원화와 기존 런타임 갤러리·전투·가격·저장 규칙은 유지합니다.

## 화면과 비교

| 캡처 | 화면 |
|---|---|
| 01-hud.png | 전투 HUD |
| 02-character.png | 각성자 선택 |
| 03-weapon.png | 시작 무기 선택 |
| 04-blessing.png | 단군의 축복 선택 |
| 05-archive.png | 자료집 |
| 06-lobby.png | 로비 |
| 07-shop-weapons.png | 게이트24 · 무기 |
| 08-shop-items.png | 게이트24 · 아이템 |

[3차 시안 갤러리](http://127.0.0.1:8764/enamel-glass-01/index.html) · [이전 2차 시안](revision-02/index.html) · [1차 시안](revision-01/index.html) · [현재 런타임 화면](http://127.0.0.1:8764/runtime-feedback/index.html)

## 폰트와 소재

- BMJUA: 큰 브랜드 제목.
- KMU80 해옹산스: 화면 제목·주요 메뉴·로비 시설 이름.
- Paperlogy: 본문·기능 문구. 기본 14px, 짧은 상품 설명 13px.
- Barlow Condensed: 재화·가격·시간·수치.
- 프레임·표면·버튼은 제작 PNG/9분할을 사용하며 글자는 실제 폰트로 렌더링합니다.
- 신규 소재: assets/cstore-surfaces-02.png, assets/cstore-controls-02.png, assets/spy-02.png. 1536×1024 시트 원본을 보존합니다. 9분할 테두리는 asset_scale 4로 표시하며, 중앙 면과 전체 상품 크롭의 배율은 표시 영역에 따라 달라집니다. 영역과 9분할은 materials.json, 출처·프롬프트는 provenance.json과 PROMPTS.md에 기록합니다.
- 로비 배경 premiumLobbyRain과 하단 독립 시설 5개는 유지합니다. 왼쪽 상단은 기존 glass/tools 정보판·흰색 글자와 약한 그림자를 유지합니다. 재화 숫자는 Barlow 21px 실제 폭으로 아이콘과 6px 간격을 유지합니다. 오른쪽은 Rect(714,17,182,48)의 공용 유리 면 안에 제작한 책·정교한 톱니·음악 일러스트만 표시합니다. 각 원화는 실제 알파 경계의 종횡비를 유지해 36×36 범위 안에 맞추고, 조작 영역은 44×44이며, 텍스트·툴팁·개별 프레임은 없습니다.
- 이번 구매면은 assets/purchase-navy-03.png의 1536×1024 원본에서 1464×300 영역을 사용합니다. cstore/purchase_navy와 purchase_disabled_navy는 같은 원본·9분할을 공유하고 표시 밀도는 8이며, 기존 9분할 소재의 4밀도는 유지합니다.
- 이번 로비 메뉴 신규 원화는 assets/lobby-icons-03.png의 1536×1024 투명 시트입니다. 각 그림의 실제 알파 경계를 materials.json에 기록하고 원화 비율을 유지합니다. 프롬프트·출처는 PROMPTS.md와 provenance.json에 보존합니다.
- 일러스트 역할은 lobby_icons/codex, lobby_icons/settings, lobby_icons/music_on과 동일 형태의 lobby_icons/music_off입니다. 음악 ON이 동결 시안 기본 상태이며, 실제 음향 상태 연결은 승인 후 진행합니다.
- 출동 단말은 190×175의 spy/terminal, 출동 버튼은 240×56의 spy/deploy PNG입니다. 네이티브 흰색 해옹산스 20px을 사용합니다.

## 스캔광 미리보기

로비 갤러리는 pulse를 제외한 captures/06-lobby-base.png 위에 assets/lobby-scan-overlay.png를 배치합니다. 위치와 크기는 게임 기준 Rect(695,145,190,175)에 고정하고, 원화 색 그대로 CSS opacity만 0.25↔0.60의 2초 주기로 반복합니다. 빛의 형태·프레임을 CSS로 생성하지 않습니다. 움직임 줄이기 설정에서는 opacity 0.25로 고정합니다.

Godot 시안의 미캡처 호출에는 같은 밝기 변화 Tween 의도를 기록합니다. 공식 PNG 캡처 06-lobby.png는 시작 위상 0.25로 고정하며, 이 웹 표현은 실제 게임 애니메이션 연결 결과가 아닙니다.

## 확인과 적용 경계

시안 8개·네이티브 문구 218개, 배치 진단 0건입니다. 조작 영역 66개는 모두 44px 이상이며, 아이템 55종·무기 10종의 상품 문구 195개도 배치 진단 0건입니다. 상점 무기 한 칸의 12,345,678(12345678) 가격은 큰 수치 배치 확인용이며 실제 가격을 변경하지 않습니다.

자세한 확인 범위는 [QA.md](QA.md), 원본 진단은 [captures/font-fit.json](captures/font-fit.json)을 확인하세요. 원본 게임 UI 수정·런타임 연결·실제 게임 캡처는 승인 후의 후속 단계입니다.
