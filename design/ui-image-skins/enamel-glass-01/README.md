# 서울 히어로 실제 UI 적용 결과

2026-10-03 최신 피드백까지 실제 Godot에 연결했다. index.html은 runtime-captures/의 운영 화면 캡처를 보여준다. 승인 전 시안은 revision-01/·revision-02/·revision-03/에 보존한다.

## 소재와 폰트

- 이미지 프레임/유리/반사/그림자: 제작한 PNG와 검토한9분할. 원본과 프롬프트는 assets/, PROMPTS.md, provenance.json. 이번 뉴모피즘 아이콘과 노란 구매면은 built-in imagegen 편집으로 제작했고 표시 크기의4배 이상 원본을 보존했다.
- BMJUA: 큰 제목/로비 브랜드. 해옹산스: 메뉴/섹션. Paperlogy: 본문/버튼. Barlow Condensed: 숫자/시간. 실제 TTF와 이용 조건은 ../fonts/README.md.
- 마력석은 공용 pickup_magic_stone_02 원화를 재사용한다. 프레임 상태는 서울 배경/나사 위치를 바꾸지 않는다.

## 실제 소스

- godot/scripts/ui/image_skin.gd: PNG 표면/버튼/유리 카드/고밀도 스타일.
- combat_ui.gd·lobby_screen.gd·shop_screen.gd·gate_screen.gd·meta_screens.gd: 운영 화면 배치와 기존 콜백.
- godot/data/visuals/ui_materials.json: 원본 영역/9분할/내용 안전 여백/배율. src/data/images.ts와 콘텐츠 exporter로 Godot 이미지 manifest를 연결했다.
- godot/tools/image_skin_capture.tscn -- --ui-preview --output=res://exports/ui-enamel-runtime04: 저장 쓰기·전투 진행 없이 실제 화면 클래스를 캡처한다.

최신 확인 범위는 QA.md, 연결 내역은 IMPLEMENTATION_AFTER_APPROVAL.md에 있다.
