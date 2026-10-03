# 서울 히어로 · Godot판

Godot **4.7.2 Standard / GDScript / 2D Compatibility** 프로젝트입니다. 기존 웹게임은 상위 폴더에 그대로 있고, Godot판은 여기에서 독립 실행합니다.

## 실행

1. Godot 프로젝트 관리자에서 이 폴더의 `project.godot`을 가져옵니다.
2. 프로젝트를 열고 **F6이 아닌 F5**로 게임을 실행합니다.
3. `시작하기/이어하기 → 작전 투입 → 맵 → 심도 → 각성자 → 무기 → 축복 → 편성 확인`으로 전투에 들어갑니다. 축복이 없을 때도 독립 선택 화면에서 ‘축복 없음’을 선택합니다.

키보드 **WASD / 방향키**, 화면 어디에서나 시작하는 터치 조이스틱, PC 마우스 드래그를 지원합니다. **Escape**는 이전 화면 또는 일시정지, 길드에서 **E**는 가까운 시설 조작입니다. 상점에서도 오른쪽 `Ⅱ`를 눌러 출동을 종료할 수 있습니다.

편집기 없이 실행하려면 `tools/play.cmd`를 더블클릭합니다. 수정 후에는 실행 중인 게임을 닫고 다시 실행해야 최신 코드가 표시됩니다. 브라우저의 5174 주소는 웹 원본이며 Godot 변경을 표시하지 않습니다.

송진우 빈손 SD와 주변 공격 효과 샘플은 **설정 → SD 캐릭터 샘플** 또는 `tools/play.ps1 -Screen sd-sample`로 확인합니다. 본체 PNG 한 장·손발 공용 최소 모션·투사체/VFX의 확장 규칙은 [SD_PIPELINE.md](docs/SD_PIPELINE.md)에 있습니다. 플레이어 4종과 길드 한서아가 동일한 공용 SD 모션을 사용합니다.

## 현재 화면과 확인 도구

- 승인된 PNG 프레임·유리 카드·실제 폰트로 타이틀·로비·출동 선택·성장·자료집·상점·설정·팝업을 구성합니다. 선택 목록은 4열 내부 스크롤과 오른쪽 상세판을 사용하며, 새로운 UI는 시안 승인 후 적용합니다.
- 전투 HUD는 작은 체력바·재화·무기 아이콘/레벨·중앙 웨이브와 시간을 사용합니다. 무기 본체를 캐릭터 주변에 띄우지 않으며 공격 투사체/VFX만 표시합니다.
- 광화문은 직각 도로와 동상이 포함된 단일 원화입니다. 고정 카메라로 화면을 채우고 모든 지형을 통과할 수 있습니다. 별도 동상·차량·바닥 타일 표시 경로는 없습니다.
- UI 기준은 915×412이며 PC에서도 같은 배치를 비례 확대합니다. 저장 없이 화면을 캡처하려면 `tools/ui_preview.tscn`, `tools/image_skin_capture.tscn`, 전투 표현만 확인하려면 `tools/combat_feedback_capture.tscn`을 `-- --ui-preview`로 실행합니다. 실제 플레이 QA를 대신하지 않습니다.
- 현재 확인 갤러리 원본은 상위 `design/ui-image-skins/runtime-feedback`, `enamel-glass-01`, `combat-feedback`입니다. 구형 시안과 승인 기록은 유지합니다. 소재 규칙은 [UI_GUIDE.md](docs/UI_GUIDE.md), 전투 표현은 [COMBAT_ART.md](docs/COMBAT_ART.md)를 참고하세요.

`tools/open.ps1`로 편집기를 열 수 있습니다. 실행 파일을 옮겼다면 `-EnginePath`로 지정합니다. 개발 화면 바로 열기: 엔진 실행 인수 뒤에 `-- --open=guild`처럼 붙입니다. `lobby / gate / combat / growth / association / offline / supply / settings / archive / guild / graphics / sd-sample`를 지원합니다.

## 데이터와 파일

| 경로 | 책임 |
|---|---|
| `project.godot`, `scenes/main.tscn` | 엔진·915×412 기준 화면·실행 씬 |
| `scripts/core` | 실행 연결, 고정 간격 시뮬레이션, 콘텐츠 읽기 |
| `scripts/state` | 한 판의 상태 |
| `scripts/systems` | 스탯, 공격, 적 행동, 상점, 메타 규칙 |
| `scripts/input` | 키보드·터치·마우스 이동 |
| `scripts/presentation` | 2D 전투, 길드, 오디오 버스 |
| `scripts/ui` | Godot Control 화면과 공통 이미지 소재 |
| `scripts/save` | 새 로컬 저장·백업·진행 중 출동 복원 |
| `data/content.json` | 기존 TS 데이터에서 추출한 콘텐츠·밸런스 |
| `data/import-provenance.json` | 가져온 이미지·음원 목록과 원본 해시 |
| `assets` | 실제 사용 이미지·음원·폰트 사본 |

현재 콘텐츠는 플레이어 4종, 길드 SD NPC 1종, 무기·설치물 10종, 다리 없는 몬스터 19종, 아이템 55종과 광화문 20웨이브입니다. 웨이브 지갑, 무기 분기·성장, 독립 진열·리롤·잠금, 설치물, 생환석, 심도·주간 규칙, 조각형 축복과 메타 시설을 연결했습니다.

무기별 피해·적중·처치, 웨이브별 피해·처치·회수량·최대 적 수, 구매·리롤·지갑·FPS 요약을 메모리에서 합산합니다. 런 종료 시 한 번만 별도 `analytics.json`에 기록하고 최근 50판만 유지합니다. 프레임별 공격 기록을 파일에 남기지 않습니다. 설정의 저장 폴더에서 JSON을 꺼낼 수 있습니다.

현재 이관 단계에서는 상위 웹게임의 `src/data`가 밸런스 원본입니다. 변경 후 저장소 최상위에서 다음 명령을 실행하면 Godot 데이터와 사용 에셋이 갱신됩니다.

```powershell
node scripts/export-godot-content.mjs
```

원본 생성·라이선스 기록은 상위 `assets`와 문서에 보존하며, `.godot` 캐시는 버전 관리하지 않습니다. 퇴역 원화·관절 리그의 원본과 이동 목록은 상위 `archive`로 분리했습니다. 콘텐츠 exporter는 현행 Godot에 필요한 사본만 연결합니다. 파일 소유권과 정리 내역은 [CLEANUP.md](../docs/CLEANUP.md)를 봅니다.

`tools/prepare_vfx_assets.py`는 보존된 VFX 원본에서 공용 효과 PNG만 추출하며 캐릭터·몬스터 프로필이나 맵 원화를 변경하지 않습니다.

## 저장과 배포 경계

- 웹 LocalStorage와 별개로 **새 게임**을 시작합니다. Windows 저장 위치는 `%APPDATA%/SeoulHeroGodot/`입니다.
- `profile.json`은 영구 상태, `run.json`은 진행 중 출동입니다. 5초 간격과 일시정지/앱 중단 시 체크포인트를 기록하고, 재시작 시 `이어하기`에서 일시정지 상태로 복원합니다.
- 전투 체크포인트 v2는 아이템의 발동 카운터·생존 효과 소모 상태를 포함합니다. v1을 순차 이관하며 잘못된 데이터는 복원을 중단하고, 더 새로운 체크포인트는 자동으로 덮어쓰지 않습니다. 영구 프로필 형식은 그대로입니다.
- 형식 `formatVersion: 1`을 사용합니다. 기존 웹 v13 콘텐츠 구조를 재사용하되 웹 저장 이관은 수행하지 않습니다. 미래 저장 버전을 자동 덮어쓰지 않으며, 이전 저장·백업·내보내기 파일을 보존합니다.
- 배경음악 ON/OFF는 BGM 버스만 제어합니다. 효과음은 Combat/UI 버스와 재생 간격·동시 수 제한을 사용합니다. 로비·길드·전투 음악은 한 플레이어에서 전환합니다.
- **Google 로그인/Supabase 계정 연동, Android APK/AAB 빌드·실기기 검증은 아직 이관하지 않았습니다.** 기존 웹 서비스는 변경하지 않습니다. APK에는 Godot export template, Android SDK/JDK와 서명이 추가로 필요합니다.
- 기존 개발자 도구 전체와 웹 UI의 세부 전환 연출은 동일 기능까지 이식하지 않았습니다. 오프라인 시간 조작·보급권 지급과 화면 바로 열기는 제공하며, 로컬 코어 게임과 시설을 먼저 이전했습니다.

타이틀·로비·출동·시설·자료집·HUD·상점·팝업을 Godot OpenGL로 915×412에서 렌더링하여 이미지 잘림과 프레임·텍스트 배치를 확인했습니다. 읽기 전용 `tools/ui_preview.tscn`을 `-- --ui-preview`로 실행하면 저장을 변경하지 않고 `exports/ui-preview`에 화면 이미지를 만듭니다. 음량·터치 플레이·Android 실기기·장시간 플레이·전체 회귀는 확인하지 않았습니다.
