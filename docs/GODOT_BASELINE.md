# Godot 로컬 기준 · 2026-10-03

현재 실행 대상은 `godot/project.godot`이다. 루트 `AGENTS.md`는 공통 원칙·공용 데이터·보존 웹판의 적용 범위를 구분하며, Godot 세부 규칙은 `godot/AGENTS.md`와 `godot/README.md`를 따른다. 설치된 실행 파일의 `--version` 결과는 `4.7.2.stable.official.ed1daf0bf`다.

## 포함 범위

- Godot 프로젝트·씬·GDScript·셰이더·콘텐츠/비주얼 JSON·사용 에셋·도구·문서. `.uid`와 원본 옆 `.import`는 안정된 리소스 식별자와 가져오기 설정이므로 포함한다.
- 공용 `src/data`와 exporter가 사용하는 상태/저장 정의·import 의존성, `scripts/export-godot-content.mjs`, `design/ui-premium-v5/weapon-notes.ts`, npm 패키지/lock 설정.
- 현재 메인 작업 폴더의 웹 소스와 에셋 변경도 함께 보존한다. 최신 공용 이미지/오디오/아이템 정의가 참조하는 어댑터와 표시 경로를 옛 코드와 섞지 않는다.
- 사용 원화·음원·폰트·생성 프롬프트·라이선스·승인 시안/확인 갤러리, 퇴역 원본과 `archive`의 이동/해시 기록. VFX 재생성 도구가 사용하는 보관 원본도 포함한다.

`.gitattributes`는 에셋·미술 자료·archive에서 Git의 자동 줄바꿈 변환을 끈다. JSON·SVG·출처 문서·보관 `.import`도 원본 바이트로 복원되어 가져오기/이동 기록의 SHA-256이 Windows 새 체크아웃에서 유지된다. 일반 실행 코드와 저장소 문서는 기존 Git 텍스트 정책을 따른다.

## 제외 범위

모든 `.godot/`, `node_modules/`, `dist/`, npm/Python 캐시, 로그, `test-results/`, `godot/exports/` 출력, 로컬 오디오 `.tools/`·`decoded-bgm/`, 자격 증명과 `.env`는 버전 관리하지 않는다. `godot/exports/.gdignore`는 출력 폴더를 Godot 리소스 가져오기에서 제외하므로 포함한다.

`audio-library/reborn-01`의 `source-previews/`·`comparisons/`·`mixes/`·`sounds/`·`rollback/files/`는 재생성 산출물/중복 사본으로 제외한다. 실제 게임 WAV는 `assets/audio/sfx/reborn-01`과 Godot 사본에 포함하며, 레시피·분석/배포/출처/라이선스 기록은 보존한다. 새 체크아웃에서 청취판의 WAV 링크를 사용하려면 해당 README의 명령과 외부 원본 음원이 필요하다.

파일은 디스크에서 삭제하지 않는다. 기존 워크트리 네 개는 기존 HEAD와 편집 내용을 유지한다. 새 확인용 워크트리는 루트의 무시된 `.worktrees/godot-baseline`에 `codex/godot-baseline` 브랜치로 만든다. 푸시·배포는 수행하지 않는다.

## 재생성·확인

새 워크트리에서도 `godot/project.godot`을 직접 가져올 수 있다. 콘텐츠를 바꿀 때는 루트에서 lock 파일에 맞게 npm 의존성을 설치하고 `node scripts/export-godot-content.mjs`를 실행한다. 현재 exporter 결과는 캐릭터 4·무기 10·몬스터 19·아이템 55, 가져온 파일 348, 누락 이미지 0이다.

이 기준 작업은 커밋할 파일의 경로·크기·민감 정보·리소스 참조와 새 워크트리의 가져오기/저장 쓰기 차단 시작만 확인한다. 전체 테스트·웹 빌드·수동 전투·Android 실기기·청음 검증은 수행하지 않는다. 최종 확인 결과는 `docs/FINAL_QA.md`의 로컬 기준 기록을 참고한다.
