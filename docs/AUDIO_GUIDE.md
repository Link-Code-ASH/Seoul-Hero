# 오디오 가이드

## 현재 적용 · reborn-02 · 2026-10-11

사용자가 제공한 `C:/Users/geniu/Music`의 Sonniss GDC2026 원본 5개 묶음을 직접 편집했다. 346개 원본 중 67개 재료로 고정 WAV 117개를 제작했다. 단발 111개는 48kHz/16bit 모노, 환경음 6개는 같은 포맷의 16초 스테레오 루프다. 피크는 −4dBFS 이하이며 원본 구간·SHA-256·EQ·레이어·페이드·라이선스를 보존한다. 이전 가공 WAV를 제작 재료로 사용하지 않는다.

같은 사건에는 같은 음원·pitch 1·고정 gain·중앙 방향을 사용한다. 런타임 무작위 변형, 직전 변형 회피, 음높이/음량 변동, 혼잡에 따른 개별 음량 감소는 없다. 치명타는 기본 적중과 같은 소리이며 기존 시각 효과로 구분한다. 실제 혼합 출력에는 다른 소리·사용자 설정·기존 Master 보호 처리가 적용된다.

## 배정과 연결

- `src/data/audioIdentity.ts`가 몬스터 47종의 재질, 무기 10종, 아이템 55종을 명시적으로 연결한다. 새 콘텐츠를 추가할 때 이 연결표도 갱신한다. 랜덤·해시·파일명 추측으로 배정하지 않는다.
- 무기 9종 × soft/metal/stone/crystal/energy/paper 6재질의 적중 54개를 사용한다. 무기 시작음·낮은 몸통·대상 재질·짧은 잔향은 제작 시 한 WAV로 합성한다. 마력장은 기존 활성음만 사용하고 지속 피해음은 추가하지 않는다.
- 처치는 대상 재질, 드롭은 마력석/협회 코인/생환석 low·mid·high, 아이템 획득은 콘텐츠 ID로 배정한다. 같은 소재인 아이템은 음색을 공유할 수 있다.
- `Sound.cue(id, context = {})`와 `run.audio_event`를 유지한다. 표시용 payload의 `weaponId`, `monsterId`, `stage`, `pickupType`, `grade`, `itemId`로 찾으며 저장/체크포인트에는 넣지 않는다. 전투의 기존 게임 이벤트도 유지하되 main의 연결에서 중복 소리만 생략한다.
- 출처가 없는 기존 호출은 고정 기본음으로 처리한다. `critical` 호환 ID는 `enemyHit`와 동일하다. 레벨·분기·치명타·개체·위치·시간·재생 순서는 음원 선택에 관여하지 않는다.

총 16voice, 일반음 최대 12voice와 중요음 우선순위, cue별 간격·동시 수를 유지한다. 혼잡할 때는 사건 전체를 생략하며 레이어를 일부만 재생하거나 다른 음원으로 대체하지 않는다. 연쇄 공격 후속음은 공격당 최대 2회, 전투 dt로 예약하고 일시정지 때 정지·웨이브 정리 때 취소한다. 앱 포커스 상실 때 음성과 예약을 폐기하고 음악/환경음만 기존 방식으로 복귀한다.

최신 로비는 실제 낮 사무실 배경에 맞는 `officeDay` 고정 환경음을 사용한다. 한 번에 루프 하나를 낮게 재생하고 음악 볼륨·음소거를 따르며 로비 밖에서는 끈다. 기존 날씨 환경음은 별도 고정 프로필로 보존한다. 발소리·상시 이동음·지속 울음·대사를 추가하지 않는다.

BGM MP3 6곡과 음악 선택·전환은 그대로다. 메뉴 gain 0.65·길드 0.48·전투 0.12, 0.35초 전환·일시정지 25%와 사용자 음량/음소거/저장 형식을 유지한다.

## 제작·배포·복구

- [reborn-02 기록](../audio-library/reborn-02/README.md): 원본 구간·레이어·라이선스·신호 결과·비교판.
- `scripts/audio-library/reborn02_recipes.py` / `reborn02_build.py`: 원본으로 마스터를 재생성한다. Music 원본과 실행용 에셋에는 쓰지 않는다.
- `reborn02_deploy.py`: 기존 연결·음원·콘텐츠를 먼저 보존하고 승인한 117개 마스터를 `assets/audio/sfx/reborn-02`로 복사한다. `src/data/sourcedAudio.ts`는 manifest에서 생성한다.
- `src/data/audio.ts`: 채택한 revision의 음원만 읽고 고정 연결표를 합친다. `scripts/export-godot-content.mjs --audio-only`는 기존 Godot 콘텐츠의 오디오 부분만 갱신하며 BGM 변경을 차단한다. Godot WAV는 손실 압축 없는 PCM으로 가져온다.
- 기존 `reborn-01` 에셋·제작 기록과 `audio-library/reborn-02/rollback/files`를 보존한다. 사용자 저장은 복구/배포에 포함하지 않는다. 이전 제작 규칙은 [reborn-01 가이드](history/AUDIO_GUIDE_REBORN_01.md)에 있다.

```powershell
python scripts/audio-library/reborn02_build.py build --source C:/Users/geniu/Music
python scripts/audio-library/reborn02_deploy.py --deploy
node scripts/export-godot-content.mjs --audio-only
python scripts/audio-library/reborn02_deploy.py --verify
python scripts/audio-library/reborn02_preview.py
```

## 확인과 청취

`qa/audio-signal.json`은 PCM 포맷·피크·루프·해시, `qa/deployed-data.json`은 source/Godot 복사·전체 연결·BGM6·원본·그 밖의 콘텐츠 불변을 확인한다. Godot의 `tools/audio_identity_check.gd`는 `--ui-preview --audio-identity-check`를 함께 요구한다. 이 경로의 Profile은 사용자 파일을 읽거나 쓰지 않고 합성 메모리 상태만 사용한다.

진단은 Dummy 출력으로 반복·치명타 동등성·획득/구매 이벤트·중복 차단·음성 제한·연쇄·일시정지·이탈·포커스·음소거를 확인한다. 전체 테스트·전투 플레이 QA·실기기 청음은 하지 않는다. 파형과 Dummy 재생 확인을 직접 청취로 간주하지 않는다.

[전후 청취판](../audio-library/reborn-02/index.html)의 6초 비교 7개는 동일한 입력을 편집한 오프라인 예시이며 실제 게임 녹음이 아니다. 비교만 전체 구간 RMS를 맞춘다. 실제 적용 음원/gain과 BGM은 변경하지 않으며, 체감 음량이 같다는 뜻은 아니다. 재생성 가능한 청취 WAV·마스터 미리보기·복구 파일은 커밋하지 않고 실행용 WAV와 재현 기록은 보존한다.
