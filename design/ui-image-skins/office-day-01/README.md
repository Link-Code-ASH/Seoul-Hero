# Office Day UI

내장 image_gen으로 만든 밝은 협회 사무실 메뉴용 UI 원화 25종. 원본은 `_raw/`, 실제 프롬프트와 생성 경로는 `generation.json`에 보존했다.

모든 개별 파일은 지정 크기의 8비트 채널 RGBA PNG(32비트)다. 생성 알파를 유지하며 여백을 정리하고 지정 해상도로 리샘플링했다. 외곽에 2px 투명 안전 여백을 두었다. 눌림 상태와 비활성 탭은 위쪽 시작점을 3px 낮춰 배치했다.

## 크기 및 9-slice

여백은 원본 PNG 픽셀 기준 **왼쪽 / 위 / 오른쪽 / 아래** 순서다. 표의 값은 모서리와 아래쪽 립을 보존하기 위한 권장값이다. 비대상은 전체 이미지를 비율 유지해 사용한다.

| 파일 | 크기 | 9-slice L/T/R/B (px) | 크기·RGBA·투명 가장자리 |
|---|---|---|---|
| panel_card.png | 512×384 | 28 / 28 / 28 / 28 | 통과 |
| panel_window.png | 1024×640 | 32 / 88 / 32 / 32 | 통과 |
| header_bar.png | 1024×128 | 24 / 24 / 24 / 24 | 통과 |
| button_primary_normal.png | 480×144 | 28 / 28 / 28 / 28 | 통과 |
| button_primary_pressed.png | 480×144 | 28 / 28 / 28 / 28 | 통과 |
| button_primary_disabled.png | 480×144 | 28 / 28 / 28 / 28 | 통과 |
| button_secondary_normal.png | 384×128 | 26 / 26 / 26 / 26 | 통과 |
| button_secondary_pressed.png | 384×128 | 26 / 26 / 26 / 26 | 통과 |
| button_secondary_disabled.png | 384×128 | 26 / 26 / 26 / 26 | 통과 |
| button_mint_normal.png | 384×128 | 26 / 26 / 26 / 26 | 통과 |
| button_mint_pressed.png | 384×128 | 26 / 26 / 26 / 26 | 통과 |
| button_round_normal.png | 160×160 | 비대상 | 통과 |
| button_round_pressed.png | 160×160 | 비대상 | 통과 |
| button_close.png | 128×128 | 비대상 | 통과 |
| chip_currency.png | 320×112 | 56 / 20 / 56 / 20 | 통과 |
| tab_active.png | 320×112 | 24 / 24 / 24 / 24 | 통과 |
| tab_inactive.png | 320×112 | 24 / 24 / 24 / 24 | 통과 |
| tile_facility.png | 256×288 | 비대상 | 통과 |
| badge_id_card.png | 512×288 | 비대상 | 통과 |
| list_row_normal.png | 768×112 | 20 / 20 / 20 / 20 | 통과 |
| list_row_selected.png | 768×112 | 20 / 20 / 20 / 20 | 통과 |
| bar_frame.png | 512×64 | 24 / 16 / 24 / 16 | 통과 |
| bar_fill.png | 512×64 | 20 / 12 / 20 / 12 | 통과 |
| tooltip_bubble.png | 384×192 | 28 / 24 / 28 / 40 | 통과 |
| lock_overlay.png | 256×256 | 비대상 | 통과 |

## 검사 결과

- 25/25개 파일: 요청한 해상도와 RGBA 모드 일치, alpha=0 픽셀 존재, 네 가장자리 전체 alpha=0.
- 기본/눌림/비활성 상태별 캔버스 크기 일치. 기본과 비활성 상태의 배치 사각형은 같으며 눌림 상태는 위쪽을 3px 낮췄다.
- 회색 바탕 합성 모음은 `contact_sheet.png`(1800×1500, 5열×5행). 개별 원화에는 글자·숫자·로고를 넣지 않았다. 자물쇠는 lock_overlay에만 사용했다.
- 픽셀 수, 배치 사각형, SHA-256은 `verification.json`에 기록했다.

## 사용 시 유의점

- 손으로 칠한 미세한 색 변화는 남아 있다. 가장자리와 중심에 큰 장식은 없지만 수학적으로 완전히 균일한 픽셀 띠는 아니다.
- `tooltip_bubble`은 아래 중앙 꼬리 때문에 일반 9-slice의 하단 중앙을 늘리면 꼬리 폭도 함께 늘어난다. 꼬리 비율을 유지해야 할 때는 384px 폭으로 사용하거나 꼬리를 별도로 잘라 배치한다.
- 진행 막대 채움은 프레임 안쪽 홈 크기에 맞춰 배치한다.
- 게임 코드 연결이나 빌드는 수행하지 않았다.

- lock_overlay의 베이지 표면은 재생성 후 alpha 약 190/255(약 75% 불투명)로 확인했다. 아래 이미지가 약 25% 비쳐 보인다.
