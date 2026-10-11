# 공용 운영 UI 독립 시안

길드·로비·게이트24·각성자 선택·자료집·HUD 여섯 대표 화면과 공용 소재판의 외관은 2026-10-05 **“좋아 좋아 적용해”**로 승인됐다. 공용 PNG를 Godot 운영 화면에 연결했으며 [현재 갤러리](index.html)는 실제 런타임 캡처를 보여준다. [승인된 시안](approved-drafts.html)과 기존 `captures`는 보존했다.

가로 915×412를 기준으로 `ops/header`, `ops/info`, `ops/row`, `ops/popup`, `ops/primary`, `ops/secondary`, `ops/tab`, `ops/icon`을 비교한다. 기존 선택 카드·자료집 책등·편의점·회수/보급 장면과 로비 작전 단말 원화는 유지한다. 준비 진입은 `출동 준비`, 최종 행동은 `작전 투입`으로 표시한다.

실제 생성 원본은 구조 1254×1254, 조작 1448×1086 PNG이며 `assets`에 보존한다. 표시용 `*-4x.png`는 생성된 모서리·테두리를 유지해 래스터 9분할로 확장한 마스터다. 생성 원본·추출 원본·표시용 마스터를 구분하며 모델이 4K 원화를 생성한 결과로 표시하지 않는다. 역할별 크기와 준비 기록은 [RULES.md](RULES.md)·[provenance.json](provenance.json)에 있다.

현재 `captures`에는 규격판 1장과 대표 화면 6장, 길드·게이트24·각성자 선택·자료집·HUD의 작은 화면 844×390 및 PC 1830×824 각 5장을 포함한 PNG 17장이 있다. 시안 전용 [layout.json](captures/layout.json)의 Godot 라벨 맞춤 진단은 `fitIssues: 0`이며 `previewOnly: true`, `productionLoaded: false`다. 이는 독립 시안의 표시 확인이고 실제 플레이·터치·실기기·청음 QA는 수행하지 않았다.

- [RULES.md](RULES.md): 공용 역할·색·배치·폰트·상태·전용 소재 범위.
- [IMPLEMENTATION_AFTER_APPROVAL.md](IMPLEMENTATION_AFTER_APPROVAL.md): 사용자 승인 후 런타임 연결 순서와 확인 범위.
- [UI_GUIDE.md](../../../godot/docs/UI_GUIDE.md): 현행 Godot UI 규칙.
- [UI_GUIDE_HISTORY.md](../../../godot/docs/UI_GUIDE_HISTORY.md): 이전 시안·승인·실제 연결 기록의 원문.

독립 시안 프로젝트는 그대로 보존한다. 현재 실제 연결과 확인 범위는 [runtime/QA.md](runtime/QA.md), 공용 API와 소재 사용 규칙은 Godot UI 가이드를 따른다. `connect_assets.py`는 승인 원본과 manifest를 연결하고, `publish_runtime.py`는 읽기 전용 Godot 캡처를 게시한다. 원본 생성 시트·native 추출·4배 마스터는 `assets/ui/image-skin/operations-standard-01`에도 출처와 함께 보존한다.
