extends RefCounted
# Preview only. Deliberately does not load Profile, run simulation or save adapters.
# Fixture: Seoul/depth 6/Song/Mana Bolt/Cheonbu Oath; highest unlocked 7,
# Song cleared through 5; all four characters and seven starter weapons unlocked;
# Cheonbu Oath Lv.1 and Harvest Knot Lv.2 unlocked, remaining blessings locked.
const WEAPONS := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard","manaShotgun"]
const BLESSINGS := ["","cheonbuOath","unyieldingJangseung","samjogoWing","whiteTigerEye","goblinForge","harvestKnot","reverseScale"]
const FIXTURE := {"map":"seoul","depth":6,"character":"awakener","weapon":"manaBolt","blessing":"cheonbuOath","weekly":"hardened","highestUnlockedDepth":7,"highestClearedDepth":5}

static func build(ui, parent: Control, screen: String) -> void:
	match screen:
		"map": _map(ui,parent)
		"depth": _depth(ui,parent)
		"character": _character(ui,parent)
		"weapon": _weapon(ui,parent)
		"blessing": _blessing(ui,parent)
		"formation": _formation(ui,parent)

static func _map(ui, p: Control) -> void:
	var map: Dictionary = ui.content.maps.seoul
	ui.header(p,"작전 구역 선택","서울에서 진행할 작전 구역을 고르세요.","01 / 06")
	ui.material(p,"navigation/panel",Rect2(56,96,537,239))
	ui.image(p,map.thumbnail,Rect2(67,107,515,217),false,true)
	ui.material(p,"navigation/selection",Rect2(58,318,533,5))
	ui.text(p,"광화문 광장",Rect2(626,100,260,41),"brand",29)
	ui.text(p,"%d 웨이브 · 마지막 보스 전투" % int(map.totalWaves),Rect2(626,149,260,28),"control",15,"accent")
	ui.text(p,map.description,Rect2(626,191,258,60),"body",15,"muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.text(p,"직선 도로와 광장 사이에서\n침식체를 버티는 서울 작전",Rect2(626,254,260,57),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	_footer(ui,p,"현재 구역 1개 · 광화문 광장","심도 선택")

static func _depth(ui, p: Control) -> void:
	ui.header(p,"웨이브 심도 선택","높은 심도일수록 침식체가 강해집니다.","02 / 06")
	ui.material(p,"navigation/panel",Rect2(30,94,854,107))
	ui.material(p,"navigation/panel",Rect2(30,206,854,107))
	for index in range(20):
		var n := index+1
		var locked := n > int(FIXTURE.highestUnlockedDepth)
		var cleared := n <= int(FIXTURE.highestClearedDepth)
		var selected := n == int(FIXTURE.depth)
		var x := 38.0+float(index%10)*84.0
		var y := 98.0+floorf(index/10.0)*112.0
		if selected: ui.material(p,"navigation/selection",Rect2(x+8,y+87,60,5))
		ui.text(p,"%02d" % n,Rect2(x+4,y+7,68,49),"number",36,"muted" if locked else "accent" if selected else "ink",HORIZONTAL_ALIGNMENT_CENTER)
		ui.text(p,"선택" if selected else "잠금" if locked else "클리어" if cleared else "도전",Rect2(x+2,y+58,72,25),"control",13,"muted" if locked else "accent" if selected else "reward" if cleared else "ink",HORIZONTAL_ALIGNMENT_CENTER)
	var d := _difficulty(ui.content,6)
	ui.text(p,"심도 06",Rect2(38,327,116,35),"brand",24)
	ui.text(p,"적 체력 ×%.2f   피해 ×%.3f   생성 ×%.2f" % [d.hp,d.damage,d.spawn],Rect2(168,324,490,29),"body",14)
	ui.text(p,"이번 주  경화된 침식 · 모든 피해 +12%",Rect2(168,353,490,27),"body",13,"muted")
	ui.button(p,"각성자 선택",Rect2(729,351,156,45),"controls/primary",16)

static func _character(ui, p: Control) -> void:
	ui.header(p,"각성자 선택","함께 서울의 게이트로 들어갈 각성자를 고르세요.","03 / 06")
	var ids: Array = ui.content.characters.keys()
	var colors := [Color("598b9b"),Color("6e7c83"),Color("b88549"),Color("769ca2")]
	for i in range(ids.size()):
		var c: Dictionary = ui.content.characters[ids[i]]
		var x := 34.0+float(i)*220.0
		ui.material(p,"personnel/plinth",Rect2(x+19,214,164,35))
		ui.image(p,c.portraitSprite,Rect2(x+36,82,130,156),true)
		var strip = ui.material(p,"personnel/selection",Rect2(x+29,263,145,5))
		if strip != null: strip.modulate = colors[i]
		ui.text(p,c.name,Rect2(x+7,271,187,31),"brand",23,"ink",HORIZONTAL_ALIGNMENT_CENTER)
		ui.text(p,c.trait.name,Rect2(x+7,304,187,28),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
		if c.id == "awakener":
			ui.material(p,"personnel/selection",Rect2(x+20,231,163,10))
			ui.text(p,"선택",Rect2(x+69,244,62,24),"control",13,"accent",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(p,"송진우  ·  "+ui.content.characters.awakener.trait.description,Rect2(40,354,605,29),"control",15)
	ui.button(p,"시작 무기 선택",Rect2(711,350,174,46),"controls/primary",16)

static func _weapon(ui, p: Control) -> void:
	ui.header(p,"시작 무기 선택","선택한 무기 1종으로 시작합니다. 전투 보유 한도는 6종입니다.","04 / 06")
	ui.material(p,"armory/tray",Rect2(31,92,562,122))
	ui.material(p,"armory/tray",Rect2(31,224,562,122))
	for i in range(WEAPONS.size()):
		var id: String = WEAPONS[i]
		var w: Dictionary = ui.content.weapons[id]
		var x := 37.0+float(i%4)*140.0
		var y := 78.0+floorf(i/4.0)*135.0
		ui.image(p,ui.content.weaponArt[id],Rect2(x+24,y+16,86,78),true)
		var caption = ui.text(p,w.name,Rect2(x+1,y+98,132,26),"control",14,"#a7ebda" if id == "manaBolt" else "white",HORIZONTAL_ALIGNMENT_CENTER)
		caption.add_theme_color_override("font_outline_color",Color("#1b2d42"))
		caption.add_theme_constant_override("outline_size",2)
		if id == "manaBolt": ui.material(p,"armory/selection",Rect2(x+4,y+120,125,5))
	ui.text(p,"마력탄",Rect2(638,95,241,38),"brand",28)
	ui.text(p,"원거리 · 투사체",Rect2(638,135,240,28),"control",15,"accent")
	ui.image(p,ui.content.weaponArt.manaBolt,Rect2(702,157,112,110),true)
	ui.text(p,ui.content.weapons.manaBolt.description,Rect2(637,279,242,61),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	_footer(ui,p,"7종 중 선택 · 마력탄","단군의 축복")

static func _blessing(ui, p: Control) -> void:
	ui.header(p,"단군의 축복 선택","이번 작전에 적용할 축복을 하나 고르세요.","05 / 06")
	for i in range(BLESSINGS.size()):
		var id: String = BLESSINGS[i]
		var x := 32.0+float(i%4)*145.0
		var y := 94.0+floorf(i/4.0)*146.0
		var unlocked := id in ["","cheonbuOath","harvestKnot"]
		var selected := id == "cheonbuOath"
		ui.material(p,"arcane/plinth",Rect2(x+9,y+52,121,31))
		if id.is_empty():
			ui.text(p,"축복 없음",Rect2(x+4,y+24,129,35),"heading",17,"muted",HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var b: Dictionary = ui.content.blessings[id]
			var art = ui.image(p,b.image,Rect2(x+31,y-3,78,74),true)
			if art != null and not unlocked: art.modulate = Color(0.84,0.87,0.88,0.53)
			ui.text(p,b.name,Rect2(x+3,y+80,135,24),"control",14,"ink" if unlocked else "muted",HORIZONTAL_ALIGNMENT_CENTER,true)
			ui.text(p,"선택 · Lv.1" if selected else "Lv.2" if id == "harvestKnot" else "미해금",Rect2(x+11,y+103,115,21),"body",13,"accent" if selected else "muted",HORIZONTAL_ALIGNMENT_CENTER)
		if selected: ui.material(p,"arcane/selection",Rect2(x+14,y+74,111,5))
	ui.material(p,"arcane/panel",Rect2(625,85,260,254))
	ui.text(p,"천부인의 맹세",Rect2(645,102,220,37),"heading",21,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.image(p,ui.content.blessings.cheonbuOath.image,Rect2(706,143,96,89),true)
	ui.text(p,"모든 피해 +4%",Rect2(646,240,216,28),"control",16,"accent",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(p,str(ui.content.blessings.cheonbuOath.description).replace("마력이 ","마력이\n"),Rect2(646,276,216,49),"body",14,"muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.button(p,"편성 확인",Rect2(726,351,160,45),"controls/primary",16)

static func _formation(ui, p: Control) -> void:
	ui.header(p,"작전 편성 확인","선택한 구역과 편성을 확인하고 출동하세요.","06 / 06")
	var map: Dictionary = ui.content.maps.seoul
	ui.material(p,"navigation/panel",Rect2(32,137,449,177))
	ui.image(p,map.thumbnail,Rect2(43,148,427,155),false,true)
	ui.text(p,map.name+"  ·  심도 06",Rect2(35,99,438,31),"brand",24)
	ui.text(p,"20 웨이브 · 마지막 보스 전투",Rect2(42,318,439,28),"body",14,"muted")
	ui.material(p,"personnel/plinth",Rect2(526,210,124,28))
	ui.image(p,ui.content.characters.awakener.portraitSprite,Rect2(537,92,103,132),true)
	ui.text(p,"송진우",Rect2(520,243,135,33),"brand",22,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(p,"모든 무기 피해 +5%",Rect2(510,279,164,29),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	ui.material(p,"armory/tray",Rect2(704,155,166,86))
	ui.image(p,ui.content.weaponArt.manaBolt,Rect2(742,109,85,108),true)
	ui.text(p,"마력탄",Rect2(708,248,158,30),"brand",22,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(p,"원거리 · 투사체",Rect2(704,282,166,28),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	ui.image(p,ui.content.blessings.cheonbuOath.image,Rect2(524,315,46,47),true)
	ui.text(p,"천부인의 맹세  Lv.1",Rect2(581,313,277,26),"control",15)
	ui.text(p,"모든 피해 +4%",Rect2(581,340,220,25),"body",14,"accent")
	ui.text(p,"경화된 침식  ·  적 체력 +20% / 모든 피해 +12%",Rect2(39,359,661,26),"body",13,"muted")
	ui.button(p,"작전 투입",Rect2(724,359,162,45),"controls/primary",17)

static func _footer(ui, p: Control, caption: String, next_caption: String) -> void:
	ui.text(p,caption,Rect2(38,355,650,34),"control",14)
	ui.button(p,next_caption,Rect2(726,351,160,45),"controls/primary",16)

static func _difficulty(data: Dictionary, depth: int) -> Dictionary:
	# Same pure calculation as HeroStats.difficulty; no production module is loaded.
	var c: Dictionary = data.gate
	var offset := maxi(0,depth-1)
	var result := {"hp":1.0+offset*c.hpPerDepth,"damage":1.0+offset*c.damagePerDepth,"spawn":1.0+offset*c.spawnPerDepth}
	for milestone in data.milestones:
		if int(milestone.depth) <= depth: result.spawn *= milestone.get("spawnMultiplier",1.0)
	result.spawn = minf(c.spawnMultiplierCap,result.spawn)
	var balance: Dictionary = data.maps.seoul.balanceModifiers
	for pair in [["hp","enemyHp"],["damage","enemyDamage"],["spawn","spawnDensity"]]: result[pair[0]] *= balance.get(pair[1],1.0)
	var penalty: Dictionary = data.weeklyRules.hardened.penalty
	for pair in [["hp","enemyHp"],["damage","enemyDamage"],["spawn","spawn"]]: result[pair[0]] *= penalty.get(pair[1],1.0)
	return result
