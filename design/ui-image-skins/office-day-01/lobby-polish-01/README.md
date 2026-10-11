# 로비 소재 다듬기 · 2026-10-11

현재 사무실 로비의 배치·색·폰트·SD·메뉴 아이콘을 유지한 이미지 및 연출 개선이다. 사용자 승인 계획에 따라 게임에 연결했다. 현재 연결 상태는 아래 3차 피드백 설명을 우선하며, 출동 게이트는 3차에서 새 원화로 교체했다.

## 제작 PNG

| 파일 | 크기 | 표시와 용도 |
|---|---|---|
| speaker_on.png / speaker_off.png | 각 512×512 | 44px 입력 영역 안에서 32px 사각 데스크톱 우퍼. ON/OFF 동일 외형, 민트 상태등과 광택 차이 |
| menu_settings.png / menu_archive.png / menu_association.png | 각 560×152 | 252×48 메뉴판, 표시 14px 패딩 포함. 기존 보라·금색·파랑 |
| deploy_surface.png | 640×296 | 284×112 출동판, 표시 18px 패딩 포함. 남색 유리·붉은 절단면 |
| operator_surface.png | 752×196 | 360×82 민트 통신창, 표시 8px 패딩 포함 |
| deploy_corner.png | 64×64 | 32px 코너 장식. 코너별 뒤집어 표시 |
| deploy_warning_tile.png | 48×20 | 24×10 반복 경고띠 |
| deploy_streak.png | 112×16 | 56×8 이동 빛줄 |
| operator_halo.png | 256×256 | 오퍼레이터 초상 주변의 투명 민트·백색 광학 링 |
| operator_glint.png | 256×64 | 통신창을 가로지르는 곡선 광택 리본 |
| icon_deploy_gate.png | 512×512 | 72px 출동 아이콘. 각진 금속 프레임·수직 보랏빛 균열·작은 산호 포인트 |

모두 고정 크기 PNG이며 9-slice는 사용하지 않는다. 이미지에는 글자·숫자·로고를 넣지 않았고, 기존 게임 텍스트는 네이티브 Label로 유지했다. 모든 소재는 RGBA, 바깥 알파 0이다. 실제 유리 투과는 화면 흐림과 PNG 재질을 셰이더에서 합성하며, 통신창 PNG는 0.60 알파로 표시한다.

## 제작 출처

내장 imagegen 도구로 개별 원화를 생성했다. 스피커 OFF와 메뉴 색상 변형은 imagegen 편집으로 제작했다. 후처리는 생성 알파를 보존한 crop·resize 및 투명 캔버스 배치만 수행했다. 원본·정확한 프롬프트·추출 영역은 `_raw/manifest_surfaces.json`과 `_raw/manifest_speaker_decor.json`에 보존했다. 2차 광학 효과의 원본·프롬프트는 `_raw/manifest_effects_revision02.json`에 있다. `_raw/baseline/`은 수정 직전 로비 코드와 셰이더의 참고 복사본이다.

## 런타임

실행용 PNG는 `godot/assets/ui/office-day-01/lobby-polish-01/`에 있다. `HeroLobbyScreen`이 이미지를 연결하고 `lobby_plate.gdshader`의 `surface_texture`가 유리 재질을 읽는다. 화면 이동·버튼 콜백·저장 방식·음소거 범위는 기존대로다. 스피커는 `Sound.bgm_enabled()`에 따라 실제 배경음악 재생 상태를 표시한다. 로비 버튼은 배경음악·환경음을 켜고 끄며 효과음 설정은 별개다.

유리·반사의 `Plate`는 자식 클리핑 없이 화면 텍스처를 읽고, `Body`에 직접 놓인 네이티브 `WatermarkLabel`은 `lobby_plate_mask.gdshader`가 라벨 오프셋을 더한 정점 좌표로 동일한 경사 마스크를 계산해 글리프 알파에만 곱한다.

메뉴 hover는 12px·0.18초 이동 및 0.5초 광택, 눌림은 1.5px 이동이다. 제목 떨림을 제거하고 반복 Tween 충돌을 정리했다. 출동의 호흡은 2.8초 주기를 공유하며 통신 램프·음성 파형은 동적 층으로 유지한다. 숨김·앱 일시정지·포커스 상실 시 관련 움직임은 정지한다.

## 확인과 비교

### 2차 피드백 반영

- 메뉴판 가장자리에 생성된 중성 흰색 림만 셰이더에서 배경으로 섞어 제거하고, 보라·금색·파랑 절단면과 유리 재질은 유지했다. PNG 원본은 보존했다.
- 한글 제목을 영문 태그와 같은 색으로 통일했다: 설정/SETTINGS `#6a3fd0`, 자료집/ARCHIVE `#a86a00`, 협회/ASSOCIATION `#1f5fc8`.
- 스피커는 실제 `Sound.bgm_enabled()` 상태가 ON일 때만 가볍게 진동하고 바깥으로 음파를 보낸다. OFF 전환 시 이미지와 움직임을 0.15초 동안 부드럽게 정지한다.
- 오퍼레이터에 제작한 광학 링과 이동 광택을 더하고, 초상 호흡·송신 램프의 확산 파동을 적용했다. 메뉴는 이동 광택·레일 패킷·아이콘 부유로 작동감을 강화했다. 숨김·포커스 상실 시 정지는 유지한다.
- 신규 효과 2개는 크기·RGBA·알파 0·런타임 복사 일치를 확인했다. 링 중앙 픽셀의 알파는 0이며 중앙 64×64의 알파는 0~1이다. 생성 원본의 극미세 알파를 보존해 초상을 가리지 않는다. 글자·로고·가짜 체크무늬가 없음을 육안 확인했다. 수치는 `_raw/validation_effects_revision02.json`에 있다.

기존 소재판 `contact_sheet.png`와 1차 캡처 `runtime/`는 보존했다. `contact_sheet_revision02.png`에는 기존 10개와 신규 효과 2개를 모았고, 2차 실제 화면 비교·움직임은 `runtime-revision-02/`에 별도로 기록한다.

### 3차 피드백 반영

- 스피커 그림을 왼쪽으로 4px 옮기고 44×44 입력 영역은 유지했다. 좌우 진동을 기존 7Hz·0.65px에서 0.75Hz·0.12px로, 배율 변화는 0.4%로 줄였다. 짙은 남색 음파 2개가 약 2.86초 주기로 반지름 21px부터 퍼져 몸체와 간격을 둔다. 실제 BGM 상태와 0.15초 ON/OFF 전환은 유지한다.
- 메뉴와 출동판은 공통 경사 비율 `32/112`를 사용한다. 메뉴 PNG 내부 유리를 UV 재투영해 이 경사에 채우고, 중성 흰색 림은 주변의 칠한 유리 재질로 치환한다. 메뉴 재질 합성 밀도는 기본 0.92다. 원본 PNG와 네이티브 글리프 알파 마스크는 유지한다.
- 메뉴·게이트 아이콘의 대기 중 위치·크기 움직임을 제거하고, 한서아 초상의 위치·배율도 고정했다. 통신창의 광학 링·이동 광택·송신 파동·파형과 메뉴 유리·레일의 빛 연출은 유지했다.
- 새 출동 게이트는 내장 imagegen으로 제작한 각진 남색 금속 프레임과 수직 보랏빛 균열이다. 화살표·금색 기둥·글자·로고 없이 72px 남색 배경에서 형태를 확인했다. 크기 512×512·RGBA·알파 0~255·런타임 복사 SHA 일치를 확인했으며, 원본과 전체 프롬프트는 [_raw/revision03/manifest_deploy_gate.json](_raw/revision03/manifest_deploy_gate.json)에 있다. 기존 `office-day-01/icons/icon_deploy_gate.png`는 보존했다.

`contact_sheet_revision03.png`는 신규 게이트를 포함한 13개 소재판이다. 1·2차 소재판과 `runtime/`, `runtime-revision-02/`는 보존하고, 3차 화면 비교와 움직임은 `runtime-revision-03/`에 별도로 기록한다.

`contact_sheet.png`는 제작 소재판이다. `_raw/validation_assets.json`에는 10개 PNG의 크기·RGBA·알파 0·런타임 복사 일치 결과를 기록했다. 글자·로고·체크무늬 없음과 작은 우퍼 형태는 육안으로 확인했다.

수정 전·후 실제 Godot 화면을 동일한 915×412, 동일 대사·SD 배치로 촬영했다. `runtime/before_after.png`, `runtime/details.png`, `runtime/motion_preview.gif`와 개별 상태 캡처를 함께 제공한다. 움직임 GIF는 실제 뷰포트 90프레임을 6초로 구성했다. 캡처 중 사용자 프로필 읽기·쓰기는 비활성화하며 ON/OFF 표시 고정은 미리보기 모드에서만 허용한다. 상세 확인 범위와 도구 사용법은 `runtime/README.md`와 `runtime/capture_report.json`에 기록했다. 전체 테스트·전투 플레이·실제 모바일 조작 및 청음은 수행하지 않았다.
