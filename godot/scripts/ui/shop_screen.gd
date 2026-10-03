class_name HeroShopScreen
extends RefCounted

const CORE_STATS := ["damage","attackSpeed","armor"]
const PURCHASE_BLOCKS := {"currency":"마력석이 부족합니다.","branch":"무기 분기를 먼저 선택하세요.","weaponSlots":"무기 슬롯이 모두 찼습니다.","weaponMax":"이미 최대 레벨인 무기입니다.","itemMax":"아이템을 최대 수량까지 보유했습니다.","unavailable":"현재 진열에서 구매할 수 없습니다."}

static func build(run: HeroRun, tab: bool, set_tab: Callable, refresh: Callable, advance: Callable, pause: Callable) -> Control:
	var root := HeroImageSkin.root()
	HeroUI.background(root,"premiumLobbyRain")
	HeroImageSkin.material(root,"cstore/cabinet",Rect2(14,10,887,392))
	var blocked := not run.pending_branch.is_empty()
	_header(root,run,tab,set_tab,refresh,pause,blocked)
	_status_dock(root,run)
	var stock: Array = run.weapon_stock if tab else run.item_stock
	for index in range(4):
		var offer: Dictionary = stock[index] if index < stock.size() else {}
		var model := _offer_model(run,offer,tab,blocked)
		model.slot_index = index
		product(root,Rect2(205+index*171,84,162,266),model,func():
			if HeroShop.buy(run,index,tab): refresh.call()
		,func(): _offer_popup(root,model)
		,func():
			if not run.pending_branch.is_empty() or offer.get("id","").is_empty(): return
			offer.locked = not bool(offer.get("locked",false)); refresh.call()
		)
	_footer(root,run,advance,blocked)
	if blocked: _branch_popup(root,run,refresh)
	return root

static func _header(root: Control, run: HeroRun, tab: bool, set_tab: Callable, refresh: Callable, pause: Callable, blocked: bool) -> void:
	HeroImageSkin.material(root,"cstore/header",Rect2(24,20,867,47))
	HeroImageSkin.text(root,"게이트24",Rect2(42,31,137,35),"heading",22,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_icon_number(root,HeroUI.icon_texture("wave"),"%02d / %02d" % [run.wave,int(run.map.totalWaves)],Vector2(236,49),18,18,"ink")
	var money := _icon_number(root,Content.trimmed_texture("magicStone"),HeroUI.amount(floori(run.currency)),Vector2(354,49),20,20,"ink")
	money.name = "ShopCurrency"
	var weapon_tab := _tab(root,"무기",Rect2(438,27,84,44),func(): set_tab.call(true),tab,blocked)
	weapon_tab.name = "ShopWeaponsTab"
	var item_tab := _tab(root,"아이템",Rect2(530,27,84,44),func(): set_tab.call(false),not tab,blocked)
	item_tab.name = "ShopItemsTab"
	var reroll_cost := HeroShop.reroll_cost(run,tab)
	var reroll := HeroImageSkin.button(root,"",Rect2(644,27,140,44),func():
		if HeroShop.reroll(run,tab): refresh.call()
	,"plain")
	reroll.name = "ShopReroll"
	var reroll_face := HeroImageSkin.material(reroll,"cstore/reroll",Rect2(4,6,133,32))
	HeroUI.fixed_art(reroll,HeroImageSkin.source_texture("enamel/reroll_icon"),Rect2(13,12,20,20))
	_icon_number(reroll,Content.trimmed_texture("magicStone"),str(reroll_cost),Vector2(89,22),16,18,"ink")
	var stock: Array = run.weapon_stock if tab else run.item_stock
	reroll.disabled = blocked or run.currency < reroll_cost or stock.all(func(slot): return slot.get("locked",false))
	if reroll.disabled: reroll_face.modulate = Color(0.82,0.86,0.89,0.8)
	var pause_button := HeroImageSkin.button(root,"",Rect2(813,27,44,44),pause,"plain")
	pause_button.name = "ShopPause"
	HeroUI.fixed_art(pause_button,HeroImageSkin.source_texture("enamel/pause_icon"),Rect2(12,10,20,24))

static func _tab(parent: Control, caption: String, rect: Rect2, action: Callable, selected: bool, disabled: bool) -> Button:
	var result := HeroImageSkin.button(parent,"",rect,action,"plain",14)
	result.disabled = disabled
	var face := HeroImageSkin.material(result,"cstore/tab",Rect2(0,5,rect.size.x,34))
	face.modulate = Color(0.80,1.0,0.91) if selected else Color.WHITE
	if disabled: face.modulate.a = 0.6
	HeroImageSkin.text(result,caption,Rect2(8,5,rect.size.x-16,34),"control",14,"muted" if disabled else "accent" if selected else "ink",HORIZONTAL_ALIGNMENT_CENTER)
	return result

# Measure icon and number as one unit so neither alignment can pull them apart.
static func _icon_number(parent: Node, art: Texture2D, number: String, center: Vector2, font_size: int, icon_size: float, color_role: String) -> Label:
	var number_width := ceilf(HeroImageSkin.font("number").get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+2
	var width := icon_size+6+number_width
	var left := center.x-width/2
	HeroUI.fixed_art(parent,art,Rect2(left,center.y-icon_size/2,icon_size,icon_size))
	return HeroImageSkin.text(parent,number,Rect2(left+icon_size+6,center.y-16,number_width,32),"number",font_size,color_role,HORIZONTAL_ALIGNMENT_CENTER)

static func _status_dock(root: Control, run: HeroRun) -> void:
	HeroImageSkin.material(root,"cstore/info",Rect2(24,95,169,303))
	HeroUI.fixed_art(root,Content.actor_preview("characters",run.setup.character,run.character.portraitSprite),Rect2(64,112,90,113))
	HeroImageSkin.text(root,run.character.name,Rect2(39,225,138,29),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	HeroUI.fixed_icon(root,"maxHp",Rect2(39,257,18,18))
	HeroImageSkin.text(root,"%d / %d" % [ceili(run.player.hp),roundi(run.stats.maxHp)],Rect2(68,253,105,23),"number",17,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	for index in range(CORE_STATS.size()):
		var key: String = CORE_STATS[index]
		var y := 274+index*21
		HeroUI.fixed_icon(root,key,Rect2(39,y+2,16,16))
		HeroImageSkin.text(root,HeroArchive.stat_value(key,float(run.stats[key])),Rect2(68,y,105,21),"number",16,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	HeroImageSkin.image_button(root,"전체 스탯",Rect2(37,348,145,44),func(): _stats_popup(root,run),"cstore/secondary",14)

# The card uses authored compact copy; the popup keeps every effect and rule.
static func product(parent: Control, rect: Rect2, model: Dictionary, buy: Callable, inspect: Callable, toggle_lock: Callable) -> void:
	var bay := HeroImageSkin.material(parent,"cstore/card",rect)
	var index := int(model.get("slot_index",0))
	bay.name = "ShopProduct_%d" % index
	var empty := bool(model.get("empty",false))
	var locked := bool(model.get("locked",false))
	if locked:
		for surface in bay.get_children(true):
			if surface is HeroImageSkin.ImageSurface: surface.self_modulate = Color(0.80,1.0,0.91)
	var body := HeroImageSkin.button(bay,"",Rect2(8,5,rect.size.x-16,205),inspect,"plain")
	body.name = "ShopInspect_%d" % index
	body.disabled = empty
	if model.get("icon") != null:
		HeroUI.fixed_art(bay,model.icon,Rect2(40,18,82,62))
	else:
		HeroImageSkin.text(bay,"—",Rect2(40,18,82,62),"heading",30,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	var name_label := _copy_area(bay,str(model.get("name","품절")),Rect2(20,87,122,42),"heading",15,"muted" if empty else "ink",HORIZONTAL_ALIGNMENT_CENTER,true)
	name_label.name = "CardName"
	var summary_label := _copy_area(bay,str(model.get("summary","")),Rect2(20,132,122,36),"body",13,"muted" if empty else "ink")
	summary_label.name = "CardSummary"
	var note_label := _copy_area(bay,str(model.get("note","")),Rect2(20,173,122,36),"body",13,"danger" if model.get("warning",false) else "muted")
	note_label.name = "CardNote"
	var can_buy := bool(model.get("can_buy",false))
	var purchase := HeroImageSkin.button(bay,"",Rect2(16,215,130,44),buy,"plain")
	purchase.name = "ShopPurchase_%d" % index
	purchase.disabled = not can_buy
	HeroImageSkin.material(purchase,"cstore/purchase_yellow" if can_buy else "cstore/purchase_disabled_yellow",Rect2(10,8,110,28))
	if not empty:
		_icon_number(purchase,Content.trimmed_texture("magicStone"),str(int(model.price)),Vector2(65,22),16,18,"ink")
		if not can_buy:
			for child in purchase.get_children():
				if child is TextureRect: child.self_modulate.a = 0.6
	var lock_button := HeroImageSkin.button(bay,"",Rect2(114,3,44,44),toggle_lock,"plain")
	lock_button.name = "ShopLock_%d" % index
	lock_button.disabled = not bool(model.get("can_lock",false))
	var glyph := HeroUI.fixed_icon(lock_button,"lock" if locked else "unlock",Rect2(8,8,28,28))
	glyph.name = "SemanticIcon"
	if lock_button.disabled: glyph.self_modulate.a = 0.35

static func _copy_area(parent: Control, copy: String, rect: Rect2, role: String, font_size: int, color_role: String, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, center: bool = false) -> Label:
	return HeroImageSkin.text(parent,copy,rect,role,font_size,color_role,align,true,{"valign":VERTICAL_ALIGNMENT_CENTER if center else VERTICAL_ALIGNMENT_TOP,"lines":2})

static func _offer_model(run: HeroRun, offer: Dictionary, weapon: bool, blocked: bool) -> Dictionary:
	var id: String = offer.get("id","")
	if id.is_empty():
		return {"empty":true,"name":"품절","summary":"재진열로 다시 확인","note":"","detail":"","icon":null,"price":0,"can_buy":false,"can_lock":false,"locked":false}
	var definition: Dictionary = run.data.weapons[id] if weapon else run.data.items[id]
	var full_copy := _copy(definition)
	var copy: Dictionary = definition.get("shopCardText",{"summary":full_copy.summary,"penalty":full_copy.penalty})
	var cost := HeroShop.price(run,offer) if weapon else int(definition.basePrice)
	var level := int(offer.get("level",1))
	var block_reason := HeroShop.offer_block_reason(run,offer,weapon)
	var count := 0
	if weapon:
		for slot in run.owned:
			if slot.id == id: count = int(slot.level)
	else: count = int(run.items.get(id,0))
	return {"empty":false,"name":definition.name,"summary":copy.summary,"note":"신규 무기" if weapon and level == 1 else "Lv.%d 강화" % level if weapon else copy.penalty,"warning":not weapon and not str(copy.penalty).is_empty(),"detail":definition.description,"full_effects":full_copy.summary,"full_penalty":full_copy.penalty,"icon":Content.weapon_icon(id) if weapon else Content.item_icon(id),"price":cost,"can_buy":block_reason.is_empty(),"block_reason":block_reason,"can_lock":not blocked,"locked":bool(offer.get("locked",false)),"weapon":weapon,"count":count,"limit":definition.get("maxLevel",null) if weapon else definition.get("maxStacks",null)}

static func _copy(definition: Dictionary) -> Dictionary:
	var copy: Dictionary = definition.get("shopText",{})
	if not copy.is_empty():
		return {"summary":"\n".join(copy.get("effects",[])),"penalty":" · ".join(copy.get("penalties",[]))}
	return {"summary":str(definition.get("description","")),"penalty":""}

static func _offer_popup(root: Control, model: Dictionary) -> void:
	var details := PackedStringArray([str(model.detail)])
	if not str(model.get("full_effects",model.summary)).is_empty() and str(model.get("full_effects",model.summary)) != str(model.detail): details.append("효과\n"+str(model.get("full_effects",model.summary)))
	if not str(model.get("full_penalty","")).is_empty(): details.append("패널티\n"+str(model.full_penalty))
	details.append("가격: %d 마력석" % int(model.price))
	var limit := "제한 없음" if model.get("limit") == null else str(int(model.limit))
	details.append("현재 Lv.%d / 최대 Lv.%s" % [int(model.count),limit] if model.weapon else "보유 수량: %d / %s" % [int(model.count),limit])
	if not str(model.get("block_reason","")).is_empty(): details.append("구매 불가: "+str(PURCHASE_BLOCKS.get(model.block_reason,PURCHASE_BLOCKS.unavailable)))
	if model.get("locked",false): details.append("진열 유지 중 · 잠금은 구매를 제한하지 않습니다.")
	_details_popup(root,"\n\n".join(details),str(model.name))

static func _footer(root: Control, run: HeroRun, advance: Callable, blocked: bool) -> void:
	HeroImageSkin.image_button(root,"보유 아이템 %d" % run.items.size(),Rect2(205,350,163,44),func():
		var lines := PackedStringArray()
		for id in run.items:
			var item: Dictionary = run.data.items[id]
			var copy := _copy(item)
			lines.append("%s ×%d\n%s%s" % [item.name,int(run.items[id]),copy.summary,"\n패널티: "+str(copy.penalty) if not str(copy.penalty).is_empty() else ""])
		_details_popup(root,"\n\n".join(lines) if not lines.is_empty() else "보유한 아이템이 없습니다.","보유 아이템 효과")
	,"cstore/secondary",14)
	for index in range(6):
		var x := 376+index*46
		if index < run.owned.size():
			var slot: Dictionary = run.owned[index]
			HeroUI.fixed_art(root,Content.weapon_icon(slot.id),Rect2(x,357,30,30))
			HeroImageSkin.text(root,str(int(slot.level)),Rect2(x+30,357,14,30),"number",15,"ink",HORIZONTAL_ALIGNMENT_CENTER)
		else: HeroImageSkin.text(root,"—",Rect2(x,357,44,30),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	var next := HeroImageSkin.image_button(root,"다음 웨이브",Rect2(674,350,205,44),advance,"cstore/next",18)
	next.disabled = blocked
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		next.add_theme_color_override(state,HeroImageSkin.color("scene"))
	next.add_theme_color_override("font_disabled_color",HeroImageSkin.color("scene").darkened(0.25))

static func _popup(root: Control, title: String, width: float = 560, height: float = 342) -> VBoxContainer:
	width = minf(width,883); height = minf(height,380)
	var overlay := ColorRect.new()
	overlay.color = Color(0.02,0.03,0.05,0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_to_group("input_blocker"); root.add_child(overlay)
	var panel := HeroImageSkin.frame(overlay,"popup",Rect2((915-width)/2,(412-height)/2,width,height))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := HeroUI.inset(panel,Vector2(20,16))
	box.set_meta("overlay",overlay)
	var heading := HeroUI.text_block(box,title,HeroUI.lines_height(box,21,2),21,HeroImageSkin.color("ink"),true,{"align":HORIZONTAL_ALIGNMENT_CENTER,"valign":VERTICAL_ALIGNMENT_CENTER,"lines":2,"font_role":"heading"})
	HeroImageSkin.apply_font(heading,"heading",21)
	return box

static func _close_button(box: VBoxContainer) -> void:
	var row := HeroUI.row(box); row.alignment = BoxContainer.ALIGNMENT_CENTER
	HeroImageSkin.button(row,"닫기",Rect2(0,0,120,44),func(): box.get_meta("overlay").queue_free(),"secondary",14)

static func _details_popup(root: Control, description: String, title: String) -> void:
	var box := _popup(root,title)
	var content := HeroUI.column(HeroUI.scroll(box)); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var copy := HeroUI.paragraph(content,description,14)
	HeroImageSkin.apply_font(copy,"body",14); copy.add_theme_color_override("font_color",HeroImageSkin.color("ink"))
	_close_button(box)

static func _stats_popup(root: Control, run: HeroRun) -> void:
	var box := _popup(root,"전체 능력치",512,342)
	var content := HeroUI.column(HeroUI.scroll(box)); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in HeroArchive.STATS:
		var row := HeroUI.row(content)
		HeroUI.icon(row,key,24,24)
		HeroUI.label(row,HeroArchive.STATS[key],14,HeroImageSkin.color("ink")).custom_minimum_size.x = 168
		HeroUI.spacer(row)
		var value := HeroUI.label(row,HeroArchive.stat_value(key,float(run.stats[key])),16,HeroImageSkin.color("ink"),"number")
		value.custom_minimum_size.x = 120; value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_close_button(box)

static func _branch_popup(root: Control, run: HeroRun, refresh: Callable) -> void:
	var definition: Dictionary = run.data.weapons[run.pending_branch]
	var modal := _popup(root,"%s · Lv.%d 분기 선택" % [definition.name,int(definition.branchAtLevel)],780,348)
	var choices := HeroUI.row(modal); choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for branch in definition.branches:
		var card := HeroImageSkin.panel(choices,"card",12)
		var box := HeroUI.column(card)
		var name := HeroUI.text_block(box,branch.name,HeroUI.lines_height(box,18,2),18,HeroImageSkin.color("ink"),true,{"align":HORIZONTAL_ALIGNMENT_CENTER,"valign":VERTICAL_ALIGNMENT_CENTER,"lines":2,"font_role":"heading"})
		HeroImageSkin.apply_font(name,"heading",18)
		var notes := HeroUI.column(HeroUI.scroll(box)); notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var description := HeroUI.paragraph(notes,branch.description,14)
		description.add_theme_color_override("font_color",HeroImageSkin.color("ink"))
		HeroImageSkin.button(box,"선택",Rect2(0,0,120,44),func():
			if HeroShop.choose_branch(run,branch.id): refresh.call()
		,"primary",14)
