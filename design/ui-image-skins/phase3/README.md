# 서울 히어로 독립 UI 시안

index.html에서 게임 화면11종과 새 PNG소재8팩을 확인한다. 캡처는 captures/에 보존한다.
게임 런타임을 연결하지 않은 별도 Godot 정적 프로젝트다. 컨펌 전 게임 화면·저장·전투·구매 연결을 수정하지 않는다.

규칙·비교와 화면별 설계는 REPORT.md, 생성 출처는 PROMPTS.md/provenance.json, 확인은 QA.md.
프레임은 제작한 이미지가 기본이며 모든 요소에 프레임을 강제하지 않는다.

915×412 PNG 캡처: Godot --path design/ui-image-skins/phase3 -- --capture
필요한 가져오기: Godot --headless --path design/ui-image-skins/phase3 --editor --quit
기타 확인용: --hud-stress / --screen=14-archive-phoenix
