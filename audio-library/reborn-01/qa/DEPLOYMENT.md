# Reborn-01 실제 적용 확인 · 2026-10-03

사용자가 청취 승인 없이 전체 적용을 명시적으로 위임했다. 총44cue(효과39·환경5)/128WAV·19.88MiB를 실제 공유 데이터와 Godot에 연결했다. Music 원본은 읽기만 했으며 기존 BGM6곡·전투 gain0.12·전투/가격/저장 콘텐츠를 유지했다.

- 데이터 확인: source/Godot128WAV SHA-256 일치, BGM6 양쪽 해시 불변, 모든 weaponStages/enemyActions/lobbyBackgrounds 경로 존재, 오디오 외 exported 콘텐츠 불변. qa/deployed-data.json problems=[].
- Godot 가져오기:128파일 성공. 새 효과 WAV는 기본 QOA 압축 대신 PCM16 compress/mode=0을 exporter에서 유지한다. 직접청취는 하지 않았다.
- 저장차단 headless audio-only 실행:변경 main/run/attacks/enemy_brain/lobby_screen 스크립트 compile,128WAV48000Hz/16bit/단발mono·환경stereo, 매핑, 무연속변형, 보호피격감쇄예외, 일반12/총16, 공격별2hop, 전투dt예약·pause·cleanup, 단일stereoLoop 및 중지 PASS. qa/runtime-audio.json의 19개 항목 passed=true. MP3를 재생하거나 게임시뮬레이션을 돌리지 않았다.
- 초기검사에서 SceneTree 진입 스크립트의 autoload 참조/타입추론을 수정했다. 2hop 상한 검사는 Dummy 타이머의 wall-clock 간섭과 concurrency를 분리해 1→2→2 및 세 번째 재생이 없는지 독립 확인한다. 실제 기기의 연쇄음 청감 검사는 아니다.
- 음악 전환 도중 곡이 자연종료하면 fade callback이 취소되어 changing flag가 남는 race를 전용 finished handler로 수정했다. 이 race는 정적 코드 검토 근거이며 MP3 재생 검증은 하지 않았다.
- 웹:변경한13개 오디오/이벤트 파일만 타입 진단, diagnostics=[]. 기존 규칙 이벤트는 유지하며 별도 audio-only queue를 연결했다. 웹 고정 로비는 환경분류 메타가 없어 임의 환경음은 붙이지 않았고, Godot의5배경은 모두 정확히 연결했다.
- 런타임 경고:샌드박스에서 Windows 인증서 저장소 읽기·Godot 전역 editor_settings 쓰기를 못했다. 오디오 리소스/스크립트 실행은 차단되지 않았으며 해당 권한은 변경하지 않았다.
- 비교 페이지 HTTP200. 이전 WAV98개와 매핑/관련코드 원본을 rollback/files에 보존했다. 청취판은 이전/적용본 비교로 갱신했다.

미확인:직접 청감·실기기/스피커·MP3 fade 청취·전투 플레이·전체 테스트/빌드/성능. 수치와연결 PASS를 청감만족으로 보고하지 않는다. 실제 적용 기록은 deployment.json과 이 QA가 우선하며 verification.json의 live 불변은 배포 전 기록이다.
