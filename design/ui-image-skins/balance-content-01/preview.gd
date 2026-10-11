extends Control

# Design-only memory fixtures. No game singleton, reward assignment, or save API.
const Common := preload("res://common.gd")
const SCREENS := ["01-deploy","02-deploy-locked","03-shop-weapons","04-shop-items","05-shop-detail","06-result-clear","07-result-death"]
var ui
var surface: Control
var current := "01-deploy"
var capture_mode := false
var records: Array = []
var locked_offers := [false,true,false,false]
var stock_offset := 0

func _ready() -> void:
	ui = Common.new(ProjectSettings.globalize_path("res://"))
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="): current = arg.trim_prefix("--screen=")
	if capture_mode: _capture.call_deferred()
	else: show_screen(current)

func _capture() -> void:
	var directory := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(directory)
	for id in SCREENS:
		show_screen(id)
		for frame in range(4): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(id+".png"))
		records.append(ui.report(id))
		print("BALANCE_CONTENT_DRAFT ",directory.path_join(id+".png"))
	var file := FileAccess.open(directory.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"previewOnly":true,"productionLoaded":false,"saveAdaptersLoaded":false,"simulation":false,"audioPlayback":false,"canvas":[915,412],"sourceAssets":ui.loaded_sources,"records":records},"\t"))
	get_tree().quit()

func show_screen(id: String) -> void:
	if is_instance_valid(surface):
		remove_child(surface)
		surface.queue_free()
	ui.reset()
	current = id
	surface = Control.new()
	surface.size = Vector2(915,412)
	add_child(surface)
	if id.begins_with("01") or id.begins_with("02"): _deploy(id == "02-deploy-locked")
	elif id.begins_with("03") or id.begins_with("04") or id.begins_with("05"):
		_shop(id == "04-shop-items",id == "05-shop-detail")
	else: _result(id == "07-result-death")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not capture_mode:
		match event.keycode:
			KEY_1: show_screen("01-deploy")
			KEY_2: show_screen("03-shop-weapons")
			KEY_3: show_screen("06-result-clear")
			KEY_ESCAPE: show_screen("03-shop-weapons" if current == "05-shop-detail" else "01-deploy")

func _button(caption: String, rect: Rect2, action: Callable, role := "ops/secondary", font_size := 16) -> Button:
	var result: Button = ui.button(surface,caption,rect,role,font_size)
	result.pressed.connect(action)
	return result

func _text(caption: String, rect: Rect2, role := "body", size := 14, ink := "ink", center := false, wrap := false) -> Label:
	return ui.text(surface,caption,rect,role,size,ink,HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT,wrap)

func _reward(source: String, caption: String, rect: Rect2, ink := "ink") -> void:
	ui.image(surface,source,Rect2(rect.position,Vector2(26,26)))
	_text(caption,Rect2(rect.position+Vector2(32,0),Vector2(rect.size.x-32,28)),"number",20,ink)

func _settled_reward(source: String, caption: String, quantity: int, y: int) -> void:
	ui.image(surface,source,Rect2(42,y,26,26))
	_text(caption,Rect2(80,y,130,28),"body",14)
	ui.text(surface,str(quantity),Rect2(214,y,59,28),"number",22,"reward",HORIZONTAL_ALIGNMENT_RIGHT)

func _deploy(later_page: bool) -> void:
	ui.image(surface,str(ui.content.maps.seoul.thumbnail),Rect2(0,0,915,412),false,true)
	var wash: ColorRect = ui.wash(surface,Color(0.90,0.94,0.96,0.90))
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.header(surface,"출동 준비")
	_text("밸런스·콘텐츠 시안",Rect2(671,24,205,28),"body",13,"scene",true)
	ui.material(surface,"ops/info",Rect2(20,78,486,246))
	ui.material(surface,"ops/info",Rect2(518,78,377,246))
	_text("광화문 광장",Rect2(36,88,215,30),"heading",18)
	_text("심도 21~40" if later_page else "심도 1~20",Rect2(272,88,144,30),"control",16,"muted",true)
	_button("‹" if later_page else "›",Rect2(439,84,48,44),func(): show_screen("01-deploy" if later_page else "02-deploy-locked"),"compact/secondary",24)
	for index in range(20):
		var depth := index+21 if later_page else index+1
		var selected := depth == 3
		var locked := depth > 3
		var x := 31+(index%10)*46
		var y := 136+floori(index/10.0)*68
		var role := "ops/tab_selected" if selected else "ops/disabled" if locked else "ops/tab"
		var hit: Button = ui.button(surface,"",Rect2(x,y,44,60),role,16)
		hit.disabled = locked
		_text(str(depth),Rect2(x+4,y+2,36,29),"number",23,"muted" if locked else "accent" if selected else "ink",true)
		if locked: ui.icon(surface,"lock",Rect2(x+15,y+37,14,14))
		else: _text("선택" if selected else "완료",Rect2(x+1,y+33,42,21),"body",12,"accent" if selected else "muted",true)
	_text("이전 완료 기록은 유지됩니다." if later_page else "처음 완료한 심도는 보급권을 지급합니다.",Rect2(36,281,454,26),"body",13,"muted")
	if later_page:
		_text("심도 20 완료 후 21 해금",Rect2(536,90,340,30),"heading",18,"muted",true)
		ui.art(surface,ui.actor_texture("enemies","riftQueen","riftQueenSD"),Rect2(819,126,50,50)).modulate = Color(0.82,0.86,0.88)
		_text("다음 전술 변화 (기획 후보)",Rect2(536,130,270,30),"control",16,"accent")
		_text("25 · 방호군집 / 방패·치유 편성",Rect2(541,179,330,27),"control",15)
		_text("30 · 여왕파동 / 소환·탄막·광역",Rect2(541,219,330,27),"control",15)
		_text("40 · 심층지휘 / 보스순서·정예예고",Rect2(541,259,330,27),"control",15)
		_text("현재 게임에 없는 후속 콘텐츠 예시",Rect2(541,292,330,24),"body",13,"muted")
	else:
		_text("심도 3 · 이번 작전",Rect2(536,88,340,30),"heading",18)
		ui.image(surface,str(ui.content.maps.seoul.thumbnail),Rect2(536,124,116,76),false,true)
		ui.art(surface,ui.actor_texture("enemies","runner","runnerSD"),Rect2(672,125,65,56))
		ui.art(surface,ui.actor_texture("enemies","spitter","spitterSD"),Rect2(771,123,61,59))
		_text("돌진 · 원거리 대응",Rect2(654,177,225,25),"body",13,"danger",true)
		_text("최초 완료",Rect2(538,211,94,27),"body",14,"muted")
		_reward("associationCoin","120",Rect2(644,211,102,28),"reward")
		_reward("supplyTicket","1",Rect2(777,211,79,28),"reward")
		_text("다음 콘텐츠 변화",Rect2(538,254,330,25),"body",13,"muted")
		_text("심도 10 · 그림자 잠복자 등장",Rect2(538,283,338,25),"control",15)
	ui.material(surface,"ops/row",Rect2(20,334,636,62))
	ui.image(surface,str(ui.content.weaponArt.manaBolt),Rect2(34,344,43,41))
	_text("주력 성장 목표 (기획 후보)",Rect2(88,337,312,25),"control",15,"accent")
	_text("첫 완료: 마력탄 조각 12개 · 성장에는 50코인",Rect2(88,364,549,25),"body",13,"muted")
	_button("해금 조건 확인" if later_page else "각성자 선택",Rect2(670,346,225,44),func(): show_screen("01-deploy" if later_page else "03-shop-weapons"),"ops/secondary" if later_page else "ops/primary")

func _shop(items: bool, detail: bool) -> void:
	ui.image(surface,"premiumLobbyRain",Rect2(0,0,915,412),false,true)
	ui.material(surface,"cstore/cabinet",Rect2(14,10,887,392))
	ui.material(surface,"cstore/header",Rect2(24,20,867,47))
	_text("게이트24",Rect2(40,29,130,35),"brand",24,"ink",true)
	ui.icon(surface,"wave",Rect2(193,39,20,20))
	_text("04 / 20",Rect2(219,30,82,35),"number",20)
	_reward("magicStone","72",Rect2(319,34,91,30))
	_button("무기",Rect2(438,27,84,44),func(): show_screen("03-shop-weapons"),"compact/tab" if items else "compact/tab_selected")
	_button("아이템",Rect2(530,27,84,44),func(): show_screen("04-shop-items"),"compact/tab_selected" if items else "compact/tab")
	var reroll: Button = _button("",Rect2(644,27,140,44),func():
		stock_offset = (stock_offset+1)%4
		show_screen("04-shop-items" if items else "03-shop-weapons")
	,"compact/secondary")
	ui.material(surface,"enamel/reroll_icon",Rect2(661,39,18,20))
	_reward("magicStone","5" if items else "6",Rect2(706,34,67,30))
	_button("Ⅱ",Rect2(813,27,44,44),func(): show_screen("01-deploy"),"compact/secondary",18)
	ui.material(surface,"cstore/info",Rect2(24,84,169,310))
	ui.art(surface,ui.actor_texture("characters","awakener","songJinwooSD"),Rect2(82,101,46,70))
	_text("송진우",Rect2(39,178,139,27),"heading",18,"ink",true)
	_text("보유 빌드 역할",Rect2(40,215,140,25),"body",13,"muted",true)
	_text("대열 관통",Rect2(40,242,140,26),"heading",17,"accent",true)
	_text("단일 대응 보완 권장",Rect2(38,271,143,28),"body",13,"ink",true)
	ui.image(surface,str(ui.content.weaponArt.manaBolt),Rect2(64,314,27,28))
	ui.image(surface,str(ui.content.weaponArt.manaSword),Rect2(123,314,27,28))
	_text("다음: 마탄 사수 등장",Rect2(215,79,380,26),"control",15,"danger")
	_text("상점 정보 배치 시안",Rect2(666,79,220,26),"body",13,"muted",true)
	var ids := ["openingTicket","kineticSpool","duelCompass","bandage"] if items else ["manaBolt","manaSword","chainLightning","manaShotgun"]
	for index in range(4):
		var id: String = ids[(index+stock_offset)%4] if not locked_offers[index] else ids[index]
		_product(id,index,items)
	_button("전체 스탯",Rect2(36,349,145,44),func(): show_screen("05-shop-detail"),"compact/secondary")
	_text("송진우 · 주간·길드·축복 추가 보정 없음",Rect2(219,355,430,31),"body",13,"muted")
	_button("다음 웨이브",Rect2(703,348,178,44),func(): show_screen("06-result-clear"),"compact/primary")
	if detail: _detail()

func _product(id: String, index: int, items: bool) -> void:
	var x := 205+index*171
	var card: NinePatchRect = ui.material(surface,"cstore/card",Rect2(x,112,162,226))
	if locked_offers[index]: card.modulate = Color(0.90,1.0,0.96)
	var definition: Dictionary = ui.content.items[id] if items else ui.content.weapons[id]
	var texture: Texture2D = ui.item_texture(id) if items else ui.texture(str(ui.content.weaponArt[id]))
	ui.art(surface,texture,Rect2(x+46,126,69,53))
	_text(str(definition.name),Rect2(x+12,185,138,29),"heading",17,"ink",true)
	var note := "조건형·첫 적중" if id == "openingTicket" else "기동·공격 속도" if id == "kineticSpool" else "근거리·위험 감수" if id == "duelCompass" else "초당 체력 회복" if items else "단일·대열 관통" if id == "manaBolt" else "근접·넓은 베기" if id == "manaSword" else "밀집·연쇄 대응" if id == "chainLightning" else "근거리·산탄 제압"
	_text(note,Rect2(x+14,216,134,25),"body",13,"muted",true)
	var level := "Lv.3 → Lv.4" if id == "manaBolt" else "Lv.1 → Lv.2" if id == "manaSword" else "신규 무기"
	var effect := "+65% 첫 적중" if id == "openingTicket" else "+22% 이동 중" if id == "kineticSpool" else "+35% 거리 110 이내" if id == "duelCompass" else "+0.12 초당 회복" if items else "피해 25 → 28" if id == "manaBolt" else "피해 37 → 43" if id == "manaSword" else "연쇄 대상 3명" if id == "chainLightning" else "산탄 5발"
	if items:
		_text(effect,Rect2(x+10,242,142,24),"body",13,"accent",true)
		var penalty := "치명 확률 -2%" if id == "openingTicket" else "방어력 -3" if id == "kineticSpool" else "사거리 -12%" if id == "duelCompass" else ""
		if not penalty.is_empty(): _text(penalty,Rect2(x+10,267,142,24),"body",13,"danger",true)
	else:
		_text(level,Rect2(x+14,245,134,22),"body",13,"accent",true)
		_text(effect,Rect2(x+10,269,142,25),"body",13,"ink",true)
	var price := int(definition.basePrice) if items else 29 if id == "manaBolt" else 18 if id == "manaSword" else 36
	ui.button(surface,"",Rect2(x+12,293,93,44),"compact/primary",16).pressed.connect(func(): show_screen("05-shop-detail"))
	_reward("magicStone",str(price),Rect2(x+32,300,66,29))
	var lock: Button = ui.button(surface,"",Rect2(x+110,293,44,44),"compact/secondary",16)
	lock.pressed.connect(func():
		locked_offers[index] = not locked_offers[index]
		show_screen("04-shop-items" if items else "03-shop-weapons")
	)
	ui.icon(surface,"lock" if locked_offers[index] else "unlock",Rect2(x+122,305,20,20))

func _detail() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.06,0.10,0.16,0.60)
	shade.size = Vector2(915,412)
	surface.add_child(shade)
	ui.material(surface,"ops/popup",Rect2(193,26,530,362))
	ui.image(surface,str(ui.content.weaponArt.manaBolt),Rect2(219,43,53,47))
	_text("마력탄 · Lv.3 → Lv.4",Rect2(284,48,409,32),"heading",20)
	ui.material(surface,"ops/row",Rect2(218,97,479,44))
	_text("타격 피해",Rect2(232,105,163,28),"control",16)
	_text("25 → 28",Rect2(465,105,215,28),"number",22,"accent",true)
	_text("현재 강화: 관통 0회 유지",Rect2(220,149,471,27),"body",14)
	_text("다음 Lv.5 · 분기 선택 미리보기",Rect2(220,180,471,27),"control",16,"accent")
	ui.material(surface,"ops/row",Rect2(218,214,234,77))
	ui.material(surface,"ops/row",Rect2(465,214,234,77))
	_text("다중 마력 난사",Rect2(230,220,209,27),"heading",16)
	_text("넓게 2발\n관통 없음",Rect2(230,250,209,36),"body",13,"muted",false,true)
	_text("초관통 마력탄",Rect2(478,220,209,27),"heading",16)
	_text("대열 3회 관통\n한 발",Rect2(478,250,209,36),"body",13,"muted",false,true)
	_text("송진우 · 주간·길드·축복 보정 없음",Rect2(220,293,473,26),"body",13,"muted",true)
	_button("29 마력석 · 구매",Rect2(218,324,282,44),func(): show_screen("03-shop-weapons"),"ops/primary")
	_button("닫기",Rect2(512,324,187,44),func(): show_screen("03-shop-weapons"),"ops/secondary")

func _result(dead: bool) -> void:
	ui.image(surface,str(ui.content.maps.seoul.thumbnail),Rect2(0,0,915,412),false,true)
	ui.wash(surface,Color(0.90,0.94,0.96,0.93))
	ui.header(surface,"작전 종료" if dead else "작전 완료")
	_text("광화문 · 심도 3 · 완료 10 / 20" if dead else "광화문 · 심도 3 · 최초 완료",Rect2(413,25,460,29),"control",15,"scene",true)
	ui.material(surface,"ops/info",Rect2(20,78,278,244))
	ui.material(surface,"ops/info",Rect2(311,78,285,244))
	ui.material(surface,"ops/info",Rect2(609,78,286,244))
	_text("정산 보상",Rect2(38,90,244,30),"heading",18,"ink",true)
	_settled_reward("associationCoin","협회 코인",3 if dead else 120,135)
	if not dead: _settled_reward("supplyTicket","보급권",1,173)
	_settled_reward("guildMaterials","마력자재",5 if dead else 10,179 if dead else 211)
	_settled_reward("guildSpeedupTicket","가속권",2 if dead else 4,223 if dead else 249)
	_text("완료 웨이브만 계산합니다." if dead else "최초 완료 보상 · 중복 지급 없음",Rect2(39,280,244,28),"body",13,"muted",true,true)
	_text("누적 피해 비중 (예시)",Rect2(328,90,250,30),"heading",18,"ink",true)
	var contribution := [["manaBolt","대열 관통","62%"],["manaSword","근접 방어","24%"],["chainLightning","밀집 제거","14%"]]
	for index in range(3):
		var row: Array = contribution[index]
		var y := 135+index*51
		ui.image(surface,str(ui.content.weaponArt[row[0]]),Rect2(331,y,34,34))
		_text(str(ui.content.weapons[row[0]].name),Rect2(375,y-2,121,25),"control",15)
		_text(str(row[1]),Rect2(375,y+23,142,22),"body",13,"muted")
		_text(str(row[2]),Rect2(512,y+4,64,29),"number",22,"accent",true)
	_text("실제 플레이 기록이 아닙니다.",Rect2(330,290,247,26),"body",13,"muted",true)
	_text("성장 목표 (기획 후보)",Rect2(623,90,259,30),"heading",18,"accent",true)
	if dead:
		_text("심도 3 최초 완료",Rect2(631,137,245,28),"control",16)
		_text("선택 축복 조각 18개",Rect2(631,173,245,27),"control",15,"reward")
		_text("최고 기록: 10 / 20 웨이브",Rect2(631,212,245,27),"body",14)
		_text("미수령 · 새 출동에서 완료하면 지급",Rect2(631,251,245,28),"body",13,"muted",false,true)
	else:
		ui.image(surface,"blessingWhiteTigerEye",Rect2(631,136,36,39))
		_text("백호의 눈 조각 18개",Rect2(677,139,200,29),"control",15,"reward")
		_text("기획 보상 · 정산 보상과 별도",Rect2(631,184,245,26),"body",13,"muted")
		_text("첫 성장: 조각 18개 + 50코인",Rect2(631,221,245,27),"body",14)
		_text("부족 재료: 없음",Rect2(631,263,245,28),"control",15,"accent")
	_button("편성 변경" if dead else "다음 심도",Rect2(20,347,210,44),func(): show_screen("01-deploy"),"ops/primary")
	_button("성장 확인",Rect2(243,347,210,44),func(): show_screen("01-deploy"),"ops/secondary")
	_button("길드 생산",Rect2(466,347,210,44),func(): show_screen("02-deploy-locked"),"ops/secondary")
	_button("다시 도전" if dead else "로비",Rect2(689,347,206,44),func(): show_screen("01-deploy"),"ops/secondary")
