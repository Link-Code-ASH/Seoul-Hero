# reborn-02 · 고정된 사운드 정체성과 짧은 깊이

사용자가 제공한 `C:/Users/geniu/Music`의 Sonniss GDC2026 묶음 5개 폴더를 직접 읽어 제작했다. 전체 346개 원본 중 67개 재료를 명시한 구간으로 편집했다. 이전 가공 WAV를 제작 입력으로 사용하지 않는다. 원본 SHA-256을 재확인했으며 원본과 BGM은 수정하지 않았다.

## 결과와 재현

- 단일 고정 WAV 117개: 단발 111개, 16초 스테레오 환경 루프 6개.
- 무기 9종 × 재질 6종 = 적중 54개. 마력장은 지속 피해음을 추가하지 않는다.
- 단발은 48kHz/16bit 모노이며 중앙 출력. 제작 시 무기 접점·낮은 몸통·대상 재질·짧은 잔향을 한 WAV로 합성했다.
- 모든 cue는 단일 음원, runtime pitch 1, volumeVariation 0. `critical`과 `enemyHit`는 WAV 바이트와 gain이 같다.
- `inventory.json`은 원본 경로·해시·라이선스, `manifest.json`은 구간·EQ·고정 속도·레이어 gain/delay·페이드·정규화 기록을 보존한다. `provenance/`는 제공 묶음의 라이선스 사본이다.
- 빌드: `python scripts/audio-library/reborn02_build.py build --source C:/Users/geniu/Music`
- 신호 확인: `python scripts/audio-library/reborn02_build.py verify`
- 빌더는 이 폴더에만 쓴다. 실제 적용은 공용 데이터와 exporter를 통해 별도 수행한다. `reborn-01`은 보존한다.

## 확인 결과

`qa/audio-signal.json`: 파일 전체의 크기·48kHz·16bit·채널 수·해시·피크 −4dBFS 이하·루프 16초·치명타 바이트 동일을 확인했다. 직접 청취와 실제 모바일/전투 플레이 QA는 수행하지 않았다. 청취 비교는 오프라인 편집 자료이며 실제 게임 녹음으로 표시하지 않는다.

## 새로운 소리 배정

적중은 `hit_<weaponId>_<material>`, 처치는 `death_<material>`. 재질은 soft/metal/stone/crystal/energy/paper이다. 드롭은 마력석·협회 코인·생환석 low/mid/high를 고정 배정한다. 아이템은 consumable/cloth/optic/paper/metal/arcane/circuitry의 소재·용도 음색을 콘텐츠 ID에 명시적으로 연결한다. 서로 같은 소재인 콘텐츠가 소리를 공유할 수 있으며 무작위 선택은 하지 않는다. 최신 사무실에는 `officeDay` 고정 실내·먼 도시 루프를 사용한다.

## 실제 적용과 전후 청취

2026-10-11 Godot에 적용했다. 실행용 소재는 `assets/audio/sfx/reborn-02/`와 `godot/assets/audio/sfx/reborn-02/`, 명시적 연결표는 `src/data/audioIdentity.ts`에 있다. 기존 연결과 128개 WAV는 `rollback/files/`에 보존하며 이전 실행용 `reborn-01`도 남긴다.

```powershell
python scripts/audio-library/reborn02_deploy.py --deploy
node scripts/export-godot-content.mjs --audio-only
python scripts/audio-library/reborn02_deploy.py --verify
python scripts/audio-library/reborn02_preview.py
```

`--audio-only`는 현재 콘텐츠의 오디오 부분만 갱신한다. BGM 6곡과 음악 설정, 전투·가격·저장·미술 데이터는 변경하지 않는다. `qa/deployed-data.json`의 누락/해시/연결/원본/BGM/PCM 확인은 `problems: []`이다.

`qa/runtime-audio.json`의 Godot Dummy 출력 진단은 전체 통과했다. 합성 프로필에서 일반/치명타 10회 교차 반복, 드롭 5종과 아이템 55종의 각 10회 반복, 실제 전투·획득·구매 이벤트와 중복 차단, 16/12voice 제한, 연쇄 2회, 일시정지·예약 취소, 환경음·음소거·포커스를 확인했다. 진단에는 `--ui-preview --audio-identity-check`를 함께 사용하며 사용자 저장을 읽거나 쓰지 않는다.

타격의 선행 여백을 정리했다. 54개 적중의 1% 에너지 시작은 최대 18.4ms, 95% 에너지 도달은 최대 294ms였다. 이 값은 파형 지표이며 청감 평가를 대신하지 않는다.

[전후 청취 페이지](index.html)에 6초 비교 7개와 전체 적용 음원을 모았다. 비교는 같은 사건을 편집한 오프라인 자료이며 게임 녹음이 아니다. 비교에만 전체 구간 RMS를 맞추고 실제 적용 gain은 보존한다. 체감 음량이 같다는 뜻은 아니다. 로컬 페이지: `http://127.0.0.1:4176/audio-library/reborn-02/`.

재생성 가능한 마스터 미리보기·비교 WAV·복구 사본은 Git에서 제외한다. 실행용 음원·편집 레시피·manifest·라이선스·확인 기록은 유지한다. 직접 청취, 실기기 재생과 전투 플레이 QA는 수행하지 않았다.
