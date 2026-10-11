extends RefCounted
# Independent design-only surfaces. Reads authored content; never loads a game
# singleton, invokes commerce callbacks, changes balances, or writes a save.
static func build(ui, parent: Control, kind: String) -> void:
	if kind == "hud":
		_world(ui,parent)
		_hud(ui,parent)
	else:
		_shop(ui,parent,kind == "shop-weapons")

static func _world(ui, parent: Control) -> void:
	ui.image(parent,ui.content.maps.seoul.thumbnail,Rect2(0,0,915,412),false,true)
	var actors := [
		["crawler",Vector2(164,137)],["swarm",Vector2(261,100)],["runner",Vector2(631,152)],
		["crawler",Vector2(742,227)],["swarm",Vector2(333,315)],["crawler",Vector2(553,336)],
		["bulwark",Vector2(700,341)],["spitter",Vector2(616,280)],["crawler",Vector2(186,293)],
		["swarm",Vector2(807,119)],["runner",Vector2(297,220)],["crawler",Vector2(485,130)]
	]
	for fixture in actors:
		var enemy: Dictionary = ui.content.enemies[fixture[0]]
		var width := clampf(float(enemy.radius)*2.2*float(ui.content.enemyPresentation.get(fixture[0],{}).get("displayScale",1.0)),45.0,72.0)
		var image_id := str(enemy.visual.sprite)
		var source: Texture2D = ui.actor_texture("enemies",str(fixture[0]),image_id)
		var height := width*source.get_height()/float(source.get_width())
		var point: Vector2 = fixture[1]
		ui.image(parent,"res://assets/visuals/vfx/contact_shadow.png",Rect2(point.x-width*0.5,point.y-4,width,10)).modulate.a = 0.4
		ui.art(parent,source,Rect2(point.x-width*0.5,point.y-height,width,height))
	var character: Dictionary = ui.content.characters.awakener
	var character_height := 98.0*0.8*(915.0/1600.0)
	var character_source: Texture2D = ui.actor_texture("characters","awakener",character.portraitSprite)
	var character_width := character_height*character_source.get_width()/float(character_source.get_height())
	ui.image(parent,"res://assets/visuals/vfx/contact_shadow.png",Rect2(437,237,39,9)).modulate.a = 0.44
	ui.art(parent,character_source,Rect2(456-character_width*0.5,240-character_height,character_width,character_height))
	for point in [Vector2(317,279),Vector2(569,246),Vector2(725,282),Vector2(400,344),Vector2(125,230)]:
		ui.art(parent,ui.texture("magicStone"),Rect2(point.x,point.y,11,15))
	var projectile: TextureRect = ui.image(parent,"manaBolt",Rect2(502,210,14,29))
	projectile.pivot_offset = Vector2(7,14); projectile.rotation = -0.78
	ui.image(parent,"vfxSlashWide",Rect2(465,216,55,44)).modulate.a = 0.68
	ui.image(parent,"vfxImpact",Rect2(604,245,36,36)).modulate.a = 0.73

static func _hud(ui, parent: Control) -> void:
	ui.hud_text(parent,"84 / 100",Rect2(20,6,82,28),"number",24)
	ui.art(parent,ui.texture("magicStone"),Rect2(104,14,12,12))
	var money: Label = ui.hud_text(parent,"240",Rect2(120,8,32,24),"number",13)
	money.add_theme_constant_override("outline_size",1)
	ui.image(parent,"wallet",Rect2(157,14,12,12)).modulate = Color(0.90,0.98,1.0)
	var wallet: Label = ui.hud_text(parent,"36",Rect2(173,8,27,24),"number",13)
	wallet.add_theme_constant_override("outline_size",1)
	ui.material(parent,"enamel/hp_track",Rect2(20,37,180,10))
	ui.material(parent,"enamel/hp_fill",Rect2(22,39,176*0.84,6))
	var weapons := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard"]
	for index in range(weapons.size()):
		var x := 20+index*27
		ui.image(parent,str(ui.content.weaponArt[weapons[index]]),Rect2(x,62,25,25))
		var level: Label = ui.hud_text(parent,str(index+1),Rect2(x+12,70,13,20),"number",14,HORIZONTAL_ALIGNMENT_RIGHT)
		level.add_theme_constant_override("outline_size",1)
	ui.hud_text(parent,"웨이브 7 / 20",Rect2(365,8,185,26),"control",15,HORIZONTAL_ALIGNMENT_CENTER)
	ui.hud_text(parent,"00:28",Rect2(400,33,115,34),"number",27,HORIZONTAL_ALIGNMENT_CENTER)
	ui.material(parent,"enamel/pause_icon",Rect2(862,17,20,24))
	_hit(ui,parent,Rect2(850,7,44,44),"일시정지","unframed")

static func _shop(ui, parent: Control, weapons: bool) -> void:
	ui.image(parent,"premiumLobbyRain",Rect2(0,0,915,412),false,true)
	ui.material(parent,"cstore/cabinet",Rect2(14,10,887,392))
	_shop_header(ui,parent,weapons)
	_status(ui,parent)
	var ids := ["manaSword","chainLightning","manaShotgun","manaBolt"] if weapons else ["phoenixMatch","vaultLedger","revengeFuse","ankleGuard"]
	for index in range(4):
		var id: String = ids[index]
		var definition: Dictionary = ui.content.weapons[id] if weapons else ui.content.items[id]
		var copy: Dictionary = definition.get("shopCardText",{"summary":definition.description,"penalty":""})
		var level := 2 if weapons and index in [0,3] else 3 if weapons and index == 1 else 1
		var price := int(ui.content.shop.weaponPrices.upgrade[str(level)]) if weapons and level > 1 else int(ui.content.shop.weaponPrices.newWeapon) if weapons else int(definition.basePrice)
		# Explicit number-width stress fixture only, never a live content price.
		if weapons and index == 3: price = 12345678
		var model := {"name":definition.name,"summary":copy.summary,"note":"Lv.%d 강화" % level if weapons and level > 1 else "신규 무기" if weapons else copy.penalty,"warning":not weapons and not str(copy.penalty).is_empty(),"price":price,"locked":index == 1,"can_buy":price <= 60,"icon":ui.content.weaponArt[id] if weapons else definition.icon,"description":definition.description,"fullEffects":definition.get("shopText",{}),"stressPrice":weapons and index == 3}
		_product(ui,parent,Rect2(205+index*171,84,162,266),model,index)
	_footer(ui,parent)

static func _shop_header(ui, parent: Control, weapons: bool) -> void:
	ui.material(parent,"cstore/header",Rect2(24,20,867,47))
	ui.text(parent,"게이트24",Rect2(42,31,137,35),"brand",24,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_icon_number(ui,parent,_icon_source(ui,"wave"),"12 / 20",Vector2(236,49),18,18)
	_icon_number(ui,parent,ui.texture("magicStone"),"60",Vector2(354,49),18,20)
	_tab(ui,parent,"무기",Rect2(438,27,84,44),weapons)
	_tab(ui,parent,"아이템",Rect2(530,27,84,44),not weapons)
	ui.material(parent,"ops/secondary",Rect2(644,27,140,44))
	ui.material(parent,"enamel/reroll_icon",Rect2(657,39,20,20))
	_icon_number(ui,parent,ui.texture("magicStone"),str(int(ui.content.shop.weaponRerollBase if weapons else ui.content.shop.itemRerollBase)),Vector2(733,49),16,18)
	_hit(ui,parent,Rect2(644,27,140,44),"재진열","ops/secondary")
	ui.material(parent,"enamel/pause_icon",Rect2(825,37,20,24))
	_hit(ui,parent,Rect2(813,27,44,44),"일시정지","unframed")

static func _icon_source(ui, key: String) -> Texture2D:
	var index: int = ui.ICON_KEYS.find(key)
	var atlas := AtlasTexture.new()
	atlas.atlas = ui.texture("urbanIconsAtlas",false)
	var cell := atlas.atlas.get_size()/Vector2(8,4)
	atlas.region = Rect2(Vector2(index%8,floori(index/8.0))*cell,cell)
	atlas.filter_clip = true
	return atlas

static func _icon_number(ui, parent: Control, source: Texture2D, number: String, center: Vector2, font_size: int, icon_size: float) -> void:
	var number_width: float = ceilf(ui.font("number").get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+2
	var width := icon_size+6+number_width
	var left := center.x-width/2
	ui.art(parent,source,Rect2(left,center.y-icon_size/2,icon_size,icon_size))
	ui.text(parent,number,Rect2(left+icon_size+6,center.y-16,number_width,32),"number",font_size,"ink",HORIZONTAL_ALIGNMENT_CENTER)

static func _tab(ui, parent: Control, caption: String, rect: Rect2, selected: bool) -> void:
	var role := "ops/tab_selected" if selected else "ops/tab"
	ui.material(parent,role,rect)
	ui.text(parent,caption,Rect2(rect.position+Vector2(8,5),Vector2(rect.size.x-16,34)),"control",16,"accent" if selected else "ink",HORIZONTAL_ALIGNMENT_CENTER)
	_hit(ui,parent,rect,caption,role)

static func _status(ui, parent: Control) -> void:
	ui.material(parent,"cstore/info",Rect2(24,95,169,303))
	var character: Dictionary = ui.content.characters.awakener
	ui.art(parent,ui.actor_texture("characters","awakener",character.portraitSprite),Rect2(64,112,90,113))
	ui.text(parent,character.name,Rect2(39,225,138,29),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.icon(parent,"maxHp",Rect2(39,257,18,18))
	ui.text(parent,"84 / 100",Rect2(68,253,105,23),"number",18,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	var values := [["damage","100%"],["attackSpeed","100%"],["armor","0"]]
	for index in range(values.size()):
		var y := 274+index*21
		ui.icon(parent,values[index][0],Rect2(39,y+2,16,16))
		ui.text(parent,values[index][1],Rect2(68,y,105,21),"number",18,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	ui.button(parent,"전체 스탯",Rect2(37,348,145,44),"ops/secondary",16)

static func _product(ui, parent: Control, rect: Rect2, model: Dictionary, index: int) -> void:
	var glass: NinePatchRect = ui.material(parent,"cstore/card",rect)
	if model.locked: glass.modulate = Color(0.80,1.0,0.91)
	var card := Control.new()
	card.position = rect.position; card.size = rect.size
	card.set_meta("description",model.description)
	card.set_meta("fullEffects",model.fullEffects)
	card.set_meta("stressPrice",model.stressPrice)
	parent.add_child(card)
	ui.art(card,model.icon,Rect2(40,18,82,62))
	ui.text(card,str(model.name),Rect2(20,82,122,50),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER,true).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.text(card,str(model.summary),Rect2(20,137,122,36),"body",13,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.text(card,str(model.note),Rect2(20,178,122,38),"body",13,"danger" if model.warning else "muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.material(card,"cstore/purchase_yellow" if model.can_buy else "cstore/purchase_disabled_yellow",Rect2(26,223,110,28))
	_icon_number(ui,card,ui.texture("magicStone"),str(int(model.price)),Vector2(81,237),16,18)
	_hit(ui,card,Rect2(16,215,130,44),"가격 %d" % int(model.price),"cstore/purchase_yellow")
	ui.icon(card,"lock" if model.locked else "unlock",Rect2(122,11,28,28))
	_hit(ui,card,Rect2(114,3,44,44),"잠금 %d" % index,"unframed")
	_hit(ui,card,Rect2(8,48,146,162),"전체 상세 %d" % index,"unframed")

static func _footer(ui, parent: Control) -> void:
	ui.button(parent,"보유 아이템 1",Rect2(205,350,163,44),"ops/secondary",16)
	var weapons := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard"]
	for index in range(weapons.size()):
		var x := 376+index*46
		ui.image(parent,str(ui.content.weaponArt[weapons[index]]),Rect2(x,357,30,30))
		ui.text(parent,str(index+1),Rect2(x+30,357,14,30),"number",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.button(parent,"다음 웨이브",Rect2(674,350,205,44),"ops/primary",16)

static func _hit(ui, parent: Control, rect: Rect2, caption: String, role: String) -> void:
	var hit := Button.new()
	hit.position = rect.position; hit.size = rect.size
	for state in ["normal","hover","pressed","focus","disabled"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(hit)
	ui.controls.append({"caption":caption,"role":role,"rect":[hit.global_position.x,hit.global_position.y,rect.size.x,rect.size.y],"minimum44":rect.size.x >= 44 and rect.size.y >= 44,"staticPreview":true})
