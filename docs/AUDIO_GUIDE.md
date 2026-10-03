# 오디오 가이드

## 현재 적용 · reborn-01 · 2026-10-03

사용자의 전체 채택 승인에 따라 효과음 39종과 로비 환경음 5종, 총 128개 WAV를 실제 게임에 연결한다. 짧고 탄력 있는 타격, 산뜻한 마력, 명확한 보상을 기준으로 원본마다 구간·EQ·레이어·페이드를 다르게 편집했다. Sonniss 원본 346개 전수 신호 분석에서 사용 재료 90개를 선택했으며, Music 원본과 기존 450개 편집본은 변경하지 않았다.

BGM MP3 6곡은 그대로 사용한다. 메뉴 gain 0.65·길드 0.48·전투 **0.12**를 유지한다. 사용자 볼륨·음소거와 저장 형식은 바꾸지 않는다. 직접 청취는 수행하지 않았으며 파일 분석과 연결 확인을 청감 평가로 간주하지 않는다.

## 파일과 책임

- `assets/audio/sfx/reborn-01/`: 채택된 128개 WAV와 전체 구간·레이어·출처 기록. 단발은 48kHz/16bit 모노, 환경은 스테레오 루프이며 피크는 -4dBFS 이하.
- `src/data/sourcedAudio.ts`: manifest에서 생성한 경로·gain·재생 간격·동시 수·우선순위·보호 여부·루프·정책·행동 연결표.
- `src/data/audio.ts`: URL과 BGM 목록을 연결한다. 현재 revision만 glob에 포함하므로 이전 소리·원본·비교 믹스를 게임 번들에 넣지 않는다.
- `scripts/export-godot-content.mjs`: 같은 데이터를 `godot/data/content.json`의 sfx/audioConfig/audioConnections와 Godot assets에 내보낸다.
- `godot/scripts/presentation/sound.gd`, `src/audio/AudioManager.ts`: 출력 어댑터. 순수 게임 시스템은 오디오 API를 호출하지 않는다.
- [reborn-01 기록](../audio-library/reborn-01/README.md): 원본 346개 목록·사용 구간·SHA-256·편집 설정·라이선스·비교판·복구본.

## 이벤트와 믹스

기존 게임 이벤트 ID는 유지한다. 별도 표시용 사운드 이벤트가 무기 ID·공격 단계·행동·공격 ID를 전달하고, 공용 audioConnections에서 소리를 찾는다. 이 payload는 전투/영구 저장에 넣지 않는다.

산탄은 마력탄과 별도 발사음, 폭격은 발사와 착탄으로 분리한다. 검기는 스윙, 표창은 접점, 번개는 최초 방전과 공격당 최대 2회의 후속 연결음을 사용한다. 마력장은 설치/활성 순간만 강조한다. 적 발사·돌진 예고·지원/소환·자폭 예고·보스 주요 공격만 추가하고 이동음·상시 울음·대사는 넣지 않는다.

총 16voice, 일반음 최대 12voice다. 같은 변형을 연속 재생하지 않으며 각 cue의 간격과 동시 수를 적용한다. 피격·위험 경고·결과음은 혼잡 감쇄에서 보호한다. 예약된 후속음은 전투 dt로 진행하고 일시정지 때 정지하며 웨이브 정리 때 취소한다.

로비는 이미 선택된 배경의 rain/wind/gate/winter/roof 분류에 따라 환경 루프 하나를 낮게 재생한다. 음악 볼륨·음소거를 따르고 전투에서는 끈다. 음악 전환은 0.35초 페이드, 일시정지는 기존 음악의 25%, 앱 숨김은 재생 정지, 결과는 BGM 정지와 결과음 우선이다. 브라우저는 첫 입력으로 재생을 허용받으며 기존 볼륨 설정을 유지한다.

## 재현과 확인

`reborn_build.py`는 계속 미리듣기 전용이다. 실제 적용은 별도 명령으로 명시한다.

```powershell
python scripts/audio-library/reborn_deploy.py --deploy
node scripts/export-godot-content.mjs
python scripts/audio-library/reborn_deploy.py --verify
```

배포 명령은 검증된 128개 해시·포맷을 확인하고 old 매핑과 WAV를 먼저 보존한다. `qa/deployed-data.json`은 source/Godot WAV 해시·BGM6 불변·연결 누락·전투/가격/저장 콘텐츠 불변을 확인한다. Godot 가져오기·실행 차단 오류와 오디오 연결만 확인하며 전체 테스트·빌드·성능 검사·실기기·플레이·청감 QA는 기본 절차에 추가하지 않는다.

청취판: [이전/적용본 비교](http://127.0.0.1:4175/reborn-01/). 비교 믹스는 오프라인 편집이며 실제 게임 녹음이 아니다. 이전 게임 파일은 `audio-library/reborn-01/rollback/files/`에 보존한다. 과거 제작 방식은 [이전 가이드](history/AUDIO_GUIDE_BEFORE_REBORN_01.md)를 참고한다.
