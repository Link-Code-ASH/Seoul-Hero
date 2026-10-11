"""Publish real, save-blocked Godot captures while retaining approved drafts."""
from pathlib import Path
import html, json, shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = ROOT / 'godot/exports/operations-runtime-01'
RUNTIME = HERE / 'runtime'
RUNTIME.mkdir(exist_ok=True)
shutil.copy2(ROOT / 'godot/docs/UI_GUIDE.md', RUNTIME / 'UI_GUIDE.md')
shutil.copy2(ROOT / 'assets/ui/image-skin/operations-standard-01/provenance.json', RUNTIME / 'provenance.json')
for folder in ['screens', 'guild', 'support']:
    dest = RUNTIME / folder
    dest.mkdir(exist_ok=True)
    for source in (SOURCE / folder).glob('*'):
        if source.is_file() and source.suffix in ['.png', '.json']:
            shutil.copy2(source, dest / source.name)
layout = json.loads((RUNTIME / 'screens/operations-layout.json').read_text(encoding='utf-8'))
support = json.loads((RUNTIME / 'support/capture.json').read_text(encoding='utf-8'))
assert not layout['saveWrites'] and not layout['simulation']
assert not any(row['fitIssues'] for row in layout['screenRecords'])
assert all(check.get('passed', True) for check in layout['checks'])
assert support['passed']
before = json.loads((ROOT / '.worktrees/operations-runtime-20261005/godot/data/content.json').read_text(encoding='utf-8'))
after = json.loads((ROOT / 'godot/data/content.json').read_text(encoding='utf-8'))
assert all(before[key] == after[key] for key in before if key != 'images')
verification = {'approval': {'date':'2026-10-05','userMessage':'좋아 좋아 적용해'},
    'productionConnected':True, 'renderer':'Godot 4.7.2 Compatibility',
    'screenCaptures':len(layout['screenRecords']), 'nativeTextChecks':len(layout['checks']),
    'fitIssues':0, 'supportChecks':len(support['checks']), 'supportLifecycleChecks':len(support['lifecycle']),
    'nonImageContentUnchanged':True, 'userSavesRead':False, 'saveWrites':False, 'combatSimulation':False}
(RUNTIME / 'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
old_index = HERE / 'approved-drafts.html'
if not old_index.exists(): shutil.copy2(HERE / 'index.html', old_index)
items = [
 ('01-guild','길드 본부','guild/03-management.png','고정 건물·공통 관리판·재화 묶음'),
 ('02-lobby','로비','screens/approved-lobby.png','기존 유리 도구와 출동 단말·출동 준비'),
 ('03-shop','게이트24','screens/approved-shop.png','편의점 진열 유지·같은 형상의 탭·공용 버튼'),
 ('04-character','각성자 선택','screens/04-character.png','서울 배경 유리 카드·공통 상세판'),
 ('05-archive','자료집','screens/09-archive.png','책등과 48px 여백·공용 탭'),
 ('06-hud','전투 HUD','screens/01-hud.png','기존 가벼운 배치·재화·무기 레벨'),
 ('07-map','맵 선택','screens/02-map.png','공통 헤더와 지역 정보판'),
 ('08-depth','심도 선택','screens/03-depth.png','20단계·선택·클리어·잠금'),
 ('09-weapon','시작 무기 선택','screens/05-weapon.png','7종 목록과 상세 정보'),
 ('10-blessing','단군의 축복 선택','screens/06-blessing.png','축복 없음·보유 레벨·효과'),
 ('11-formation','편성 확인','screens/07-formation.png','지역과 편성·최종 작전 투입'),
 ('12-growth','전략지원','screens/08-growth.png','같은 행의 선택 색조·성장'),
 ('13-association','협회','screens/12-association.png','공통 정보판·실제 영구 지원'),
 ('14-settings','설정','screens/10-settings.png','음량·데이터 조작 행'),
 ('15-recovery','회수','support/recovery-ready.png','지원 거점과 보상 수령'),
 ('16-supply','보급','support/supply-ready.png','기존 개봉 장면과 공통 버튼'),
 ('17-pause','일시정지','screens/11-pause.png','공통 중앙 팝업'),
 ('18-result','작전 결과','screens/13-result.png','협회 코인과 로비 복귀'),
 ('19-revival','생환석','screens/14-revival.png','보유 등급과 생환 선택'),
 ('20-branch','무기 분기','screens/17-shop-branch.png','공용 선택 팝업'),
 ('21-crafting','조합','screens/18-shop-crafting.png','길드 조합 기능 유지'),
 ('22-title','타이틀','screens/approved-title.png','승인된 로고·19px 이어하기/새로하기 유지')]
style = '''@font-face{font-family:Paperlogy;src:url('../fonts/Paperlogy-4Regular.ttf')}*{box-sizing:border-box}body{margin:0;padding:24px;background:#1b2939;color:#edf2f4;font-family:Paperlogy,system-ui,sans-serif;line-height:1.65}main{max-width:1080px;margin:auto}h1{font-size:27px;margin:0 0 8px}h2{font-size:20px;margin:0}p{color:#b9cad8}a{color:#ace0d4}nav,.links{display:flex;gap:10px;flex-wrap:wrap}nav{margin:22px 0}nav a,.links a{padding:6px 10px;border:1px solid #536b7e;border-radius:5px;text-decoration:none}section{margin-bottom:34px;scroll-margin-top:18px}img{display:block;width:100%;max-width:915px;height:auto;border-radius:5px}.heading{display:flex;align-items:center;justify-content:space-between;max-width:915px}.heading span{font-size:13px;color:#9aafc1}.stage{color:#ace0d4}.links{font-size:13px;margin-top:12px}footer{border-top:1px solid #536b7e;padding-top:20px}'''
parts = ['<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>서울 히어로 · 도시 작전풍 실제 적용</title><style>'+style+'</style></head><body><main>',
 '<div class="stage">승인 후 실제 적용 · Godot 런타임 캡처</div><h1>서울 히어로 · 도시 작전풍 UI</h1><p>승인한 PNG 소재·폰트·명칭을 게임 화면에 연결했습니다. 상점·책등·지원 거점·유리 카드·출동 단말의 고유 표현은 유지했습니다.</p><p>아래 이미지는 실제 화면 클래스를 합성 상태로 렌더링한 결과입니다. 사용자 저장 읽기·쓰기와 전투 시뮬레이션은 차단했습니다.</p>',
 '<div class="links"><a href="approved-drafts.html">승인된 이전 시안</a><a href="runtime/QA.md">확인 범위</a><a href="runtime/verification.json">검증 기록</a></div>',
 '<nav>'+''.join(f'<a href="#{key}">{title}</a>' for key,title,_,_ in items)+'</nav>']
responsive = {'04-character':'character','05-archive':'archive','06-hud':'hud','03-shop':'shop'}
extras = {'01-guild':[('직원','guild/04-staff.png'),('작업','guild/05-jobs.png')],
 '03-shop':[('무기 탭','screens/qa-shop-weapons.png'),('구매 불가','screens/qa-shop-disabled.png'),('큰 재화·8자리 가격','screens/qa-shop-eight-digit-price.png'),('전체 상세','screens/15-shop-detail.png')],
 '04-character':[('미해금 상세','screens/qa-character-locked.png')],
 '15-recovery':[('빈 보상','support/recovery-empty.png'),('수령 완료','support/recovery-claimed.png')],
 '16-supply':[('보급권 부족','support/supply-insufficient.png'),('1회 결과','support/supply-result1.png'),('10회 결과','support/supply-result10.png')]}
for key,title,file,description in items:
    parts.append(f'<section id="{key}"><div class="heading"><h2>{title}</h2><span>915×412 · 실제 구현</span></div><p>{description}</p><a href="runtime/{file}"><img src="runtime/{file}" width="915" height="412" loading="lazy" alt="{title} Godot 실제 구현"></a>')
    links = extras.get(key, []).copy()
    if key in responsive:
        links += [(size, f'screens/responsive-{responsive[key]}-{size}.png') for size in ['844x390','1830x824']]
    if links: parts.append('<div class="links">'+''.join(f'<a href="runtime/{path}">{name}</a>' for name,path in links)+'</div>')
    parts.append('</section>')
parts.append('<footer>34개 실제 화면 캡처·65종 상품 전체 문구 검사·작은 화면 및 PC 비교에서 텍스트 맞춤 진단 0건. 실제 플레이·터치·실기기·성능·전체 테스트/빌드는 수행하지 않았습니다. 가격·전투·저장·오디오 데이터는 유지했습니다.<div class="links"><a href="RULES.md">규격</a><a href="runtime/UI_GUIDE.md">UI 가이드</a><a href="assets/structures-generated.png">구조 생성 원본</a><a href="assets/controls-generated.png">조작 생성 원본</a></div></footer></main></body></html>')
(HERE / 'index.html').write_text(''.join(parts),encoding='utf-8')
print('Published real runtime gallery:', HERE / 'index.html')
