"""Publish the focused, save-blocked captures of actual Godot screen classes."""
from pathlib import Path
import json
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
SOURCE=ROOT/'godot/exports/compact-controls-runtime-02'
RUNTIME=HERE/'runtime'
RUNTIME.mkdir(exist_ok=True)
layout=json.loads((SOURCE/'compact-controls-layout.json').read_text(encoding='utf-8'))
assert not layout['saveReads'] and not layout['saveWrites'] and not layout['simulation']
assert layout['productionClasses'] and not layout['economyCallbacks'] and not layout['audioCallbacks']
assert all(not row['fitIssues'] for row in layout['screenRecords'])
assert all(row.get('passed',True) for row in layout['checks'])
before=json.loads((ROOT/'.worktrees/compact-controls-runtime-20261005/godot/data/content.json').read_text(encoding='utf-8'))
after=json.loads((ROOT/'godot/data/content.json').read_text(encoding='utf-8'))
assert all(before[key]==after[key] for key in before if key!='images')
for path in SOURCE.iterdir():
    if path.is_file() and path.suffix in ['.png','.json']: shutil.copy2(path,RUNTIME/path.name)
shutil.copy2(ROOT/'assets/ui/image-skin/operations-light-controls-02/provenance.json',RUNTIME/'provenance.json')
shutil.copy2(ROOT/'godot/docs/UI_GUIDE.md',RUNTIME/'UI_GUIDE.md')
verification={'approval':{'date':'2026-10-05','userMessage':'구현해'},'productionConnected':True,
    'renderer':'Godot 4.7.2 Compatibility','captureCount':len(layout['screenRecords']),
    'nativeControlChecks':len(layout['checks']),'fitIssues':0,'nonImageContentUnchanged':True,
    'saveReads':False,'saveWrites':False,'simulation':False,'economyCallbacks':False,'audioCallbacks':False,
    'layoutRevision':'shop-header-02','shopHeaderPaintedSize':{'tabs':[72,30],'reroll':[120,30]},'shopHeaderTouchSizeUnchanged':True}
(RUNTIME/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
draft=HERE/'approved-drafts.html'
if not draft.exists(): shutil.copy2(HERE/'index.html',draft)

style='''*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#e7eef0;color:#243448;font-family:system-ui,"Malgun Gothic",sans-serif}main{max-width:975px;margin:auto;padding:26px 24px 56px}h1{margin:0 0 10px;font-size:26px}h2{margin:28px 0 10px;font-size:20px}p{margin:8px 0 14px;line-height:1.6;font-size:14px;color:#536b7e}nav,.links{display:flex;gap:14px;flex-wrap:wrap;margin:16px 0}a{color:#267f75}img{display:block;width:100%;height:auto;background:#d9e3e7}figure{margin:12px 0 24px}figcaption{margin:8px 0;font-size:13px;color:#536b7e}details summary{cursor:pointer;font-size:14px}details img{margin-top:12px}.status{font-size:12px;color:#267f75;letter-spacing:.08em}footer{border-top:1px solid #b4c6cf;margin-top:28px;padding-top:12px}'''
items=[
    ('title','타이틀','compact-01-title-continue.png','로고 면을 작전 정보판으로 맞추고, 이어하기·새로하기에 얇은 청록·아이보리 버튼을 연결했습니다.'),
    ('back','공통 뒤로가기','compact-03-character.png','전용 정사각형 유리 PNG와 44px 조작 영역을 사용합니다. 카드·상세 정보·배치는 유지합니다.'),
    ('shop-weapons','게이트24 · 무기','compact-05-shop-weapons.png','상단 무기·아이템·리롤의 보이는 프레임을 높이 30px로 줄여 제목 범위 안에 맞췄습니다. 터치 영역과 글자 크기는 유지합니다.'),
    ('shop-items','게이트24 · 아이템','compact-04-shop-items.png','같은 형상의 탭과 선택 색조를 사용합니다. 상품·가격·구매면·잠금 표시와 편의점 원화는 유지합니다.'),
]
extras={
    'title':[('진행 중인 게임 없음 · 시작하기','compact-02-title-start.png')],
    'back':[('844×390','compact-07-character-844x390.png')],
    'shop-items':[('구매 불가·조합 있는 하단','compact-06-shop-disabled-recipes.png'),('큰 재화·8자리 가격 · 844×390','compact-08-shop-eight-digit-price-844x390.png')],
}
parts=['<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>서울 히어로 · 얇은 프레임 실제 적용</title><style>'+style+'</style><main>',
    '<div class="status">승인 후 실제 적용 · Godot 런타임 캡처</div><h1>짧은 조작은 가볍게 · 실제 구현 결과</h1><p>승인하신 PNG 4종을 타이틀·일반 화면의 뒤로가기·게이트24에 연결했습니다. 아래는 시안이 아닌 실제 게임 화면 클래스를 저장과 전투 시뮬레이션 없이 렌더링한 결과입니다.</p>',
    '<div class="links"><a href="approved-drafts.html">승인된 시안·이전 비교</a><a href="runtime/QA.md">확인 범위</a><a href="runtime/verification.json">확인 기록</a></div>',
    '<nav>'+''.join(f'<a href="#{key}">{title}</a>' for key,title,_,_ in items)+'</nav>']
for key,title,file,description in items:
    parts.append(f'<section id="{key}"><h2>{title}</h2><p>{description}</p><figure><a href="runtime/{file}?revision=02"><img src="runtime/{file}?revision=02" alt="{title} 실제 Godot 구현" width="915" height="412"></a><figcaption>915×412 · 실제 런타임 화면</figcaption></figure>')
    for label,extra in extras.get(key,[]): parts.append(f'<details><summary>{label}</summary><a href="runtime/{extra}?revision=02"><img src="runtime/{extra}?revision=02" alt="{label}" loading="lazy"></a></details>')
    parts.append('</section>')
parts.append('<section><h2>승인된 소재 4종</h2><img src="captures/00-materials.png" alt="승인된 소재 규격판"><p>소재판은 승인한 시안 기록이며, 위 게임 화면은 실제 연결 결과입니다. 큰 정보창과 팝업·상점의 전용 진열은 유지했습니다.</p></section><footer><p>필요한 가져오기·스크립트와 변경 UI 범위의 배치를 확인했습니다. 사용자 저장·밸런스·가격·사운드는 유지했습니다. 실제 전투·터치·실기기·전체 테스트·빌드·성능 검사는 수행하지 않았습니다.</p><div class="links"><a href="runtime/UI_GUIDE.md">현재 UI 규칙</a><a href="runtime/provenance.json">PNG 출처와 승인 기록</a></div></footer></main></html>')
(HERE/'index.html').write_text(''.join(parts),encoding='utf-8')
print('Published actual runtime:',len(layout['screenRecords']),'screens;',len(layout['checks']),'checks')
