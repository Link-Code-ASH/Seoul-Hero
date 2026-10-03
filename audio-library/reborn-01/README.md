# 서울 히어로 사운드 재탄생 01

**전체 채택 승인으로 실제 적용. 효과음 39종·환경음 5종, 총 128개 WAV를 사용한다.**

BGM6곡과 전투 gain0.12는 유지한다. 원본·이전 소리·편집 기록은 보존하며 청취판의 이전/적용본 비교는 계속 사용할 수 있다.

짧고 탄력 있는 타격, 산뜻한 마력, 명확한 보상으로 경쾌한 SD 액션을 만든다. 원본은 `C:\Users\geniu\Music`의 Sonniss GDC 2026 번들 5개이며 읽기만 한다. 기존 450편집본과 BGM6곡은 유지한다.

## 청취

`http://127.0.0.1:4175/reborn-01/`에서 이전 소리·적용본·사용한 원본 구간을 비교한다. `../index.html`은 이전 450개 라이브러리다. 페이지는 자동 재생하지 않으며 음량 50%에서 시작한다.

- **개별 비교:** 현재 첫 변형과 새 첫 변형을 전체 구간 RMS로 맞춘다. 이는 지각 음량이 완전히 같다는 뜻은 아니다. 다른 새 변형과 원본 구간은 별도로 들을 수 있다.
- **장면 믹스:** BGM과 예정 gain·동시 재생 정책을 포함한 오프라인 편집 장면이다. 실제 게임 녹음이 아니다. 현재/새 양쪽이 피크 제한을 넘으면 같은 안전 배율을 적용하고 기록한다.
- **원본 검토:** 346개 전체의 길이·채널·파형 동작 구간·무음·피크·조용한 구간 RMS·사용 후보/보류/제외 사유를 제공한다. 긴 파일은 여러 구간으로 분할하고, 원본 미리듣기는 일부 구간이다.
- **의견:** 소리별 유지/수정/교체 의견과 메모를 청취판 전용 브라우저 키에 저장한다. JSON으로 내보낼 수 있으며 게임 저장은 읽거나 쓰지 않는다.

직접 청각 평가 도구가 없어 **청감 평가는 미실시**다. 신호 분석·편집·출력 확인과 실제 청감 평가를 구분한다. 사용자는 별도 청취 승인 없이 전체 적용을 명시적으로 맡겼다. 음색·반복 피로·기기 출력은 직접 청취 검증으로 보고하지 않는다.

## 재현

프로젝트 루트에서 실행한다. `--preview-only`는 필수이며 배포 옵션은 제공하지 않는다.

```powershell
python -m pip install -r audio-library/reborn-01/requirements.txt --target audio-library/reborn-01/.tools
python scripts/audio-library/reborn_build.py inventory --preview-only --source "C:\Users\geniu\Music"
python scripts/audio-library/reborn_decode_bgm.py
python scripts/audio-library/reborn_build.py build --preview-only --source "C:\Users\geniu\Music"
python scripts/audio-library/reborn_build.py verify --preview-only
python -m http.server 4175 --bind 127.0.0.1 --directory audio-library
```

`inventory`는 기존 캐시를 복사하지 않고 원본 346개 전체를 디코딩·분석·해시 확인한다. `build`는 분석 후 크기·수정시각이 바뀐 원본을 거부하고, `reborn_recipes.py`의 명시한 구간만 사용한다. 사용 구간을 피치만 바꿔 변형 수를 채우지 않는다.

MP3 디코더 설치 파일의 샌드박스 읽기가 제한되면, 허용된 프로세스에서 `reborn_decode_bgm.py`로 BGM6곡의 첫20초를 캐시할 수 있다. 이 명령은 권한을 바꾸거나 기존 음악을 편집하지 않는다. 캐시는 `decoded-bgm/`에만 만들고 게임에 포함하지 않는다. 믹스 정책만 바꿀 때는 `reborn_build.py mixes --preview-only`로 동일 원본의 재편집을 생략한다.

## 기록과 책임

- `inventory.json`: 전수 파형 분석, 원본 SHA-256, 활동 구간·검토 상태·사유·청취 대기.
- `manifest.json`: 31기존+8신규cue, 5환경 루프, 128편집본, 원본 구간·레이어·선택 EQ·페이드·음량·출력 해시와 향후 연결표.
- `source-previews/`: 사용 구간과 원본 검토용 발췌. 48kHz 변환·안전 음량·끝단 페이드 외의 EQ·레이어 없음.
- `comparisons/`: 음량 맞춤 개별 비교. `mixes/`: BGM 포함 장면과 실제 예정 gain 정책 기록.
- `provenance/`: 번들별 라이선스·Readme 사본과 해시. 외부 생성 모델에 원본을 제공하지 않는다.
- `verification.json`: 포맷·무음·피크·끝단·루프 접점·중복·참조·현재 게임 파일 불변 확인. 청감 통과를 의미하지 않는다.
- `scripts/audio-library/reborn_recipes.py`: 원본 90개를 사용한 명시적 편집 레시피. cue마다 처리와 선정 이유가 다르다.
- `scripts/audio-library/reborn_build.py`: 전수 분석·편집·원본 발췌·음량 비교·출력 검사.
- `scripts/audio-library/reborn_mix.py`: 기존 Godot 정책과 예정 정책을 각각 재현하는 오프라인 믹서.

적용 정책은 총16voice·일반12voice, 중요한 피격/위험/결과 보호, 동일 변형 연속 방지, 번개 후속 공격당2회, 로비 환경 루프1개다. 음악 전환0.35초·일시정지25%·화면 숨김 정지·결과 BGM 정지를 포함한다. BGM 원본과 전투 gain0.12는 유지한다. 실제 `Sound.cue(id, context = {})`와 별도 audio-only 이벤트를 연결하며 저장 설정은 추가하지 않는다.

## 실제 적용과 복구

미리듣기 제작은 위 --preview-only 명령을 그대로 사용한다. 실제 배포는 별도 스크립트이며 기존 편집본을 덮어쓰지 않는다.

```powershell
python scripts/audio-library/reborn_deploy.py --deploy
node scripts/export-godot-content.mjs
python scripts/audio-library/reborn_deploy.py --verify
```

- `deployment.json`: 실제 적용 목록과 source/Godot 파일 hash, BGM hash, 사용자 승인과 확인 상태.
- `qa/deployed-data.json`, `qa/runtime-audio.json`: 적용 데이터와 저장 차단 오디오 실행 확인.
- `rollback/files/`: 수정 전 공용 매핑·오디오 어댑터·관련 이벤트 연결·Godot 콘텐츠 사본, 이전 WAV. `rollback/audio-files.json`은 이전 파일 hash다.

복구할 때는 필요한 오디오 관련 파일을 rollback/files의 같은 상대 경로에서 복사하고 exporter로 Godot 데이터를 다시 내보낸다. 전체 content.json은 당시 스냅샷이므로 다른 콘텐츠 작업 이후에는 과거 전체 데이터를 일괄 복사하지 않는다. 기존 sourced WAV는 현재 assets에도 유지해 비교 링크가 끊어지지 않는다.

`verification.json`의 live_files_unchanged는 **적용 전 미리듣기 제작 시점의 기록**이다. 적용 이후는 reborn_deploy.py --verify와 deployment/qa 기록이 우선한다. preview verify의 기준 게임 해시를 적용 후의 검증으로 사용하지 않는다.
