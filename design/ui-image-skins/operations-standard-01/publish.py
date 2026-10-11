"""Publish approved-for-review artifacts, without connecting game UI."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
before=json.loads((ROOT/'.worktrees/operations-standard-01/runtime-before.json').read_text(encoding='utf-8'))
changed=[path for path,expected in before.items() if not (ROOT/path).is_file() or hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=expected]
if changed: raise RuntimeError('Unexpected runtime changes: '+str(changed))
layout=json.loads((HERE/'captures/layout.json').read_text(encoding='utf-8'))
if layout['fitIssues'] or layout['productionLoaded'] or not layout['approvalPending']: raise RuntimeError('Preview verification failed')
roles={
    'header':['guild','growth','association','settings','gate','archive','offline','supply'],
    'info':['guild','growth','association','settings','gate'],
    'row':['growth','guild'], 'popup':['all'], 'primary':['all'],
    'secondary':['all'], 'tab':['all'], 'tab_selected':['all'], 'disabled':['all'], 'icon':['all'],
}
materials=json.loads((HERE/'materials.json').read_text(encoding='utf-8'))
provenance=json.loads((HERE/'provenance.json').read_text(encoding='utf-8'))
for name,screens in roles.items():
    materials['packs']['ops']['roles'][name]['allowed_screens']=screens
    provenance['roles'][name]['allowed_screens']=screens
materials['specialized_usage']={'cstore':['shop'],'codex/panel':['archive'],'support/panel':['offline','supply'],'spy/deploy':['lobby'],'cards/normal':['gate','archive']}
for file,data in [('materials.json',materials),('provenance.json',provenance)]: (HERE/file).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
screens=[
 ('00-materials','소재 규격판','헤더·정보판·목록·팝업·버튼·탭·상태와 글꼴 역할'),
 ('01-guild','길드 본부','도시 작전풍 공통 헤더와 정보판 · 동일한 형상의 선택 탭'),
 ('02-lobby','로비','기존 장면과 전용 도구·시설을 유지 · 준비 진입은 출동 준비'),
 ('03-shop','게이트24','편의점 진열은 상점 전용 · 버튼과 탭은 공통 역할'),
 ('04-character','각성자 선택','서울 배경·유리 카드 유지 · 공통 상세 정보판'),
 ('05-archive','자료집','유리 썸네일과 책등 프레임 유지 · 책등 쪽 48px 여백'),
 ('06-hud','전투 HUD','큰 공용 박스 없이 기존 위치 유지 · 체력·재화·무기 레벨'),
]
navigation=''.join(f'<a href="#{id}">{title}</a>' for id,title,_ in screens)
sections=[]
for id,title,description in screens:
    sizes=''
    if id not in ['00-materials','02-lobby']:
        sizes=f'<div class="sizes"><a href="captures/{id}-844x390.png">844×390</a><a href="captures/{id}-1830x824.png">1830×824</a></div>'
    sections.append(f'<section id="{id}"><div class="section-title"><h2>{title}</h2><span>915×412</span></div><p>{description}</p><a href="captures/{id}.png"><img src="captures/{id}.png" width="915" height="412" alt="{title} 독립 UI 시안"></a>{sizes}</section>')
html='''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>서울 히어로 · 도시 작전풍 UI 규격</title><style>
@font-face{font-family:Paperlogy;src:url('../fonts/Paperlogy-4Regular.ttf')}*{box-sizing:border-box}body{margin:0;padding:24px;background:#1b2939;color:#EDF2F4;font-family:Paperlogy,system-ui,sans-serif;line-height:1.65}main{max-width:1080px;margin:auto}h1{font-size:27px;margin:0 0 8px}h2{font-size:20px;margin:0}p{color:#b9cad8;margin:8px 0 14px}.stage{color:#ace0d4;font-size:14px;margin-bottom:12px}nav,.links,.sizes{display:flex;gap:10px;flex-wrap:wrap}nav{margin:22px 0 28px}a{color:#a5ddd2}nav a,.sizes a{padding:8px 12px;border:1px solid #536B7E;border-radius:5px;text-decoration:none}section{margin-bottom:32px;scroll-margin-top:18px}.section-title{display:flex;justify-content:space-between;align-items:center;max-width:915px}.section-title span{font-size:13px;color:#9aafc1}img{display:block;width:100%;max-width:915px;height:auto;border-radius:5px}.sizes{margin-top:10px;font-size:13px}footer{font-size:14px;color:#b9cad8;border-top:1px solid #536B7E;padding-top:18px}.links{margin-top:14px}
</style></head><body><main><div class="stage">독립 시안 · 외관 승인 대기</div><h1>서울 히어로 · 도시 작전풍 UI 규격</h1><p>남색 구조와 밝은 내용 면. 같은 기능에는 같은 소재·폰트·상태를 사용하고, 상점·책·유리 카드의 개성은 유지합니다.</p><p>규격판 1장과 대표 화면 6장입니다. 게임 연결은 이 외관을 확인한 다음 진행합니다. 기능 텍스트는 실제 Godot 글꼴로 렌더링했습니다.</p><nav>'''+navigation+'''</nav>'''+''.join(sections)+'''<footer>독립 Godot Compatibility 프로젝트 · 게임/저장/전투/오디오 모듈 미사용 · 915×412와 작은 화면·PC 비교에서 글자 배치 진단 0건. 새 PNG는 생성 원본과 9분할 확장 마스터를 분리해 보존했습니다.<div class="links"><a href="RULES.md">용도·위치·명칭 규칙</a><a href="QA.md">확인 범위</a><a href="provenance.json">PNG 출처·안전 영역</a><a href="prompts.json">생성 프롬프트</a><a href="assets/structures-generated.png">구조 생성 원본</a><a href="assets/controls-generated.png">조작 생성 원본</a><a href="IMPLEMENTATION_AFTER_APPROVAL.md">승인 후 적용 범위</a></div></footer></main></body></html>'''
(HERE/'index.html').write_text(html,encoding='utf-8')
captures={file.name:list(Image.open(file).size) for file in sorted((HERE/'captures').glob('*.png'))}
verification={'previewOnly':True,'approvalPending':True,'productionConnected':False,'runtimeFilesCompared':len(before),'runtimeChangedFiles':changed,'saveAdaptersLoaded':False,'simulation':False,'captures':captures,'fitIssues':layout['fitIssues'],'sizes':[[915,412],[844,390],[1830,824]],'newMaterials':'2 built-in image_gen sprite sheets, native crop and 4x raster 9-slice masters','sourceDetail':'Generated image dimensions1254x1254/1448x1086; 4x master expansion does not invent higher-resolution native detail.','notVerified':['runtime callbacks','economic operations','actual gameplay','touch','device performance','full tests/build']}
(HERE/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(HERE/'QA.md').write_text('''# 도시 작전풍 UI 시안 확인 · 2026-10-05

## 수행 범위

- 소재판 1장과 길드·로비·게이트24·각성자·자료집·HUD 6장을 독립 Godot 4.7.2 Compatibility로 렌더링했다. 게임 autoload, Profile, 사운드, 전투 시뮬레이션, 구매/지급 콜백을 불러오지 않았다.
- 915×412 기준 7장, 844×390과1830×824의 대표5장씩 총17PNG를 만들었다. 실제 폰트 줄 높이·글자폭·정렬·44px 입력영역 진단에서 fitIssues0이다. 기준6화면과 규격판을 직접 이미지로 확인했고, 작은/PC 이미지에서도 여백과 가독성을 비교했다.
- 같은 선택카드의 서울 배경/원본영역을 유지하고 투명 유리·색조·선택테두리만 추가한다. 탭 선택은 같은 PNG 파일/원본 영역을 사용한다. 정보판20px, 책등48px, 상품 설명20px 안전여백을 확인했다. 짧은 상품 설명13px/가격16px, HUD재화13px/레벨14px 예외를 유지했다.
- 현재 콘텐츠의 상품 설명과 이미지, SD원화, 시설 원화를 읽었다. 길드재화·시설레벨·상점진열·HUD수치는 화면별 고정 예시다. 실제 경제/지원보너스/성장 결과를 실행하거나 새 보상 효과를 만들지 않았다.
- 게임 scripts/data/shaders/scenes 및공용src/data 182파일을 작업전SHA256과비교해 변경0을 확인했다. 현행UI가이드와 독립시안/PNG파일만 작성했다. 기존가이드는 UI_GUIDE_HISTORY.md에 원문을 보존했다.

## PNG와 오류

새 원화는 built-in image_gen 구조1254×1254/조작1448×1086 두 시트다. 생성원본·잘라낸native PNG·최소4배 작업마스터를 분리하고 프롬프트·참조·해시·9분할·안전영역을 보존했다. 4배마스터는 생성된 모서리/테두리를 유지해 중앙면을 래스터9분할 확장한 작업본이며 모델이4K세부를 새로 생성했다는 뜻은 아니다. 새 UI의 프레임/광택을 SVG·StyleBoxFlat·코드도형으로 대체하지 않았다.

필수 가져오기·스크립트 렌더링 오류는 없었다. 환경 인증서·시안프로젝트 user로그/셰이더캐시·편집기설정 쓰기권한 메시지는 있었다. 사용자 저장 접근 코드는 이 프로젝트에 없다.

## 미확인과 승인 경계

이번 산출물은 외관 시안이다. 실제 게임의 입력/콜백/생산/지급/출동/상태갱신/터치/실기기/성능/전체테스트·빌드는 확인하지 않았다. 준비진입은 출동준비, 최종출동은 작전투입 등의 규칙은 승인후 운영화면에 연결한다. 새PNG외관 승인 전에는 HeroImageSkin·운영소재manifest·전체 화면을 교체하지 않는다.
''',encoding='utf-8')
print(json.dumps({'screens':len(screens),'captures':len(captures),'fitIssues':layout['fitIssues'],'runtimeChangedFiles':len(changed),'approvalPending':True},ensure_ascii=False))
