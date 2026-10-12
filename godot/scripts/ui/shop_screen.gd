class_name HeroShopScreen
extends RefCounted

const CORE_STATS := ["damage","attackSpeed","armor"]
# Gate24 keeps its approved convenience-store art and palette local to the shop.
const ART := "res://assets/ui/office-day-01/gate24-bright-01/"
const INK := "#24395c"
const MUTED := "#708090"
const ON_ACCENT := "#fffcf5"
const DANGER := "#d75c48"
const ORANGE := "#ff8a24"
# Item rarity and weapon level pick the shelf's accent rail.
const CARD_TIERS := {"COMMON":"common","UNCOMMON":"uncommon","RARE":"rare","EPIC":"epic","LEGENDARY":"legendary"}
const WEAPON_TIERS := ["common","common","rare","epic","legendary"]
const TIER_ACCENTS := {"common":"#00bfc5","uncommon":"#4fc95a","rare":"#4ba2db","epic":"#aa7ade","legendary":"#eab946"}
const PURCHASE_BLOCKS := {"currency":"마력석이 부족합니다.","branch":"무기 분기를 먼저 선택하세요.","weaponSlots":"무기 슬롯이 모두 찼습니다.","weaponMax":"이미 최대 레벨인 무기입니다.","itemMax":"아이템을 최대 수량까지 보유했습니다.","unavailable":"현재 진열에서 구매할 수 없습니다."}

static func build(run: HeroRun, tab: bool, set_tab: Callable, refresh: Callable, advance: Callable, pause: Callable) -> Control:
	var root := HeroImageSkin.root()
	_backdrop(root)
	HeroImageSkin.material(root,"cstore_bright/cabinet",Rect2(14,10,887,392))
	var blocked := not run.pending_branch.is_empty()
	_header(root,run,tab,set_tab,refresh,pause,blocked)
	_status_dock(root,run)
	var stock: Array = run.weapon_stock if tab else run.item_stock
	for index in range(4):
		var offer: Dictionary = stock[index] if index < stock.size() else {}
		var model := _offer_model(run,offer,tab,blocked)
		model.slot_index = index
		product(root,Rect2(205+index*171,84,162,266),model,func():
			var receipt := {"rect":Rect2(245+index*171,102,82,62),"content_id":str(offer.get("id","")),"texture":model.get("icon")}
			if HeroShop.buy(run,index,tab):
				if run.pending_branch.is_empty(): HeroUIEffects.enqueue(root,"acquire",receipt)
				else: HeroUIEffects.enqueue(root,"gloss",{"anchor":"WeaponBranchPanel"})
				refresh.call()
		,func(): _offer_popup(root,model)
		,func():
			if not run.pending_branch.is_empty() or offer.get("id","").is_empty(): return
			offer.locked = not bool(offer.get("locked",false))
			HeroUIEffects.enqueue(root,"lock" if offer.locked else "gloss",{"anchor":"ShopProduct_%d" % index})
			refresh.call()
		)
	_footer(root,run,advance,blocked,refresh)
	if blocked: _branch_popup(root,run,refresh)
	return root

static func _header(root: Control, run: HeroRun, tab: bool, set_tab: Callable, refresh: Callable, pause: Callable, blocked: bool) -> void:
	HeroImageSkin.material(root,"cstore_bright/header",Rect2(24,20,867,47))
	# Separate native labels preserve the brand face while the 24 shares the orange key.
	var brand_width := HeroImageSkin.font("brand").get_string_size("게이트",HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	var number_width := HeroImageSkin.font("brand").get_string_size("24",HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	var brand_x := 42.0+(137.0-brand_width-number_width)/2.0
	HeroImageSkin.text(root,"게이트",Rect2(brand_x,26,brand_width,35),"brand",24,INK,HORIZONTAL_ALIGNMENT_CENTER).name = "ShopTitle"
	HeroImageSkin.text(root,"24",Rect2(brand_x+brand_width,26,number_width,35),"brand",24,ORANGE,HORIZONTAL_ALIGNMENT_CENTER).name = "ShopBrandNumber"
	_icon_number(root,HeroUI.icon_texture("wave"),"%02d / %02d" % [run.wave,int(run.map.totalWaves)],Vector2(236,44),18,18,INK,true)
	var money := _icon_number(root,Content.trimmed_texture("magicStone"),HeroUI.amount(floori(run.currency)),Vector2(354,44),18,20,INK)
	money.name = "ShopCurrency"
	var weapon_tab := _tab(root,"무기",Rect2(438,22,84,44),func(): set_tab.call(true),tab,blocked)
	weapon_tab.name = "ShopWeaponsTab"
	var item_tab := _tab(root,"아이템",Rect2(530,22,84,44),func(): set_tab.call(false),not tab,blocked)
	item_tab.name = "ShopItemsTab"
	var reroll_cost := HeroShop.reroll_cost(run,tab)
	var reroll := _shop_button(root,"",Rect2(644,22,140,44),func():
		var before: Array = (run.weapon_stock if tab else run.item_stock).duplicate(true)
		if HeroShop.reroll(run,tab):
			var after: Array = run.weapon_stock if tab else run.item_stock
			for index in range(mini(before.size(),after.size())):
				if not before[index].get("locked",false) and before[index] != after[index]:
					HeroUIEffects.enqueue(root,"reroll",{"anchor":"ShopProduct_%d" % index})
			refresh.call()
	,"secondary",false,Vector4(10,7,10,7))
	reroll.name = "ShopReroll"
	var reroll_icon := HeroUI.fixed_art(reroll,HeroUI.icon_texture("reroll"),Rect2(17,10,24,24))
	reroll_icon.self_modulate = Color(INK)
	_icon_number(reroll,Content.trimmed_texture("magicStone"),"무료" if run.free_rerolls_remaining > 0 else str(reroll_cost),Vector2(89,22),16,18,INK)
	var stock: Array = run.weapon_stock if tab else run.item_stock
	reroll.disabled = blocked or run.currency < reroll_cost or stock.all(func(slot): return slot.get("locked",false) or slot.get("free",false))
	var pause_button := HeroImageSkin.button(root,"",Rect2(813,22,44,44),pause,"plain")
	pause_button.name = "ShopPause"
	var pause_icon := HeroUI.fixed_art(pause_button,HeroImageSkin.source_texture("enamel/pause_icon"),Rect2(12,10,20,24))
	pause_icon.self_modulate = Color(INK)

static func _tab(parent: Control, caption: String, rect: Rect2, action: Callable, selected: bool, disabled: bool) -> Button:
	var result := _shop_button(parent,caption,rect,action,"tab",selected,Vector4(6,7,6,7))
	result.disabled = disabled
	return result

static func _backdrop(root: Control) -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "Gate24Backdrop"
	backdrop.texture = load(ART+"shop_background.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_meta("full_bleed",true)
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _shop_button(parent: Node, caption: String, rect: Rect2, action: Callable, role: String = "secondary", selected: bool = false, inset: Vector4 = Vector4.ZERO) -> Button:
	var result := HeroImageSkin.image_button(parent,caption,rect,action,"cstore_bright/"+role,16,selected,inset)
	var ink := ON_ACCENT if role == "primary" or selected else INK
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		result.add_theme_color_override(state,Color(ink))
	result.add_theme_color_override("font_disabled_color",Color(MUTED))
	# Authored selected tabs retain their geometry; held presses dim the local art.
	result.draw.connect(func():
		if result.disabled or not result.is_pressed(): return
		for surface in result.get_children(true):
			if surface is HeroImageSkin.ImageSurface: surface.self_modulate = Color(0.94,0.94,0.94)
	)
	return result

# Measure icon and number as one unit so neither alignment can pull them apart.
static func _icon_number(parent: Node, art: Texture2D, number: String, center: Vector2, font_size: int, icon_size: float, color_role: String, semantic: bool = false) -> Label:
	var number_width := ceilf(HeroImageSkin.font("number").get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+2
	var width := icon_size+6+number_width
	var left := center.x-width/2
	var icon := HeroUI.fixed_art(parent,art,Rect2(left,center.y-icon_size/2,icon_size,icon_size))
	if semantic: icon.self_modulate = Color(INK)
	return HeroImageSkin.text(parent,number,Rect2(left+icon_size+6,center.y-16,number_width,32),"number",font_size,color_role,HORIZONTAL_ALIGNMENT_CENTER)

static func _status_dock(root: Control, run: HeroRun) -> void:
	HeroImageSkin.material(root,"cstore_bright/info",Rect2(24,95,169,303))
	HeroUI.fixed_art(root,Content.actor_preview("characters",run.setup.character,run.character.portraitSprite),Rect2(64,112,90,113))
	HeroImageSkin.text(root,run.character.name,Rect2(39,225,138,29),"heading",18,INK,HORIZONTAL_ALIGNMENT_CENTER)
	var health_icon := HeroUI.fixed_icon(root,"maxHp",Rect2(39,257,18,18))
	health_icon.self_modulate = Color(INK)
	HeroImageSkin.text(root,"%d / %d" % [ceili(run.player.hp),roundi(run.stats.maxHp)],Rect2(68,253,105,23),"number",18,INK,HORIZONTAL_ALIGNMENT_RIGHT)
	for index in range(CORE_STATS.size()):
		var key: String = CORE_STATS[index]
		var y := 274+index*21
		var stat_icon := HeroUI.fixed_icon(root,key,Rect2(39,y+2,16,16))
		stat_icon.self_modulate = Color(INK)
		HeroImageSkin.text(root,HeroArchive.stat_value(key,float(run.stats[key])),Rect2(68,y,105,21),"number",18,INK,HORIZONTAL_ALIGNMENT_RIGHT)
	_shop_button(root,"전체 스탯",Rect2(37,348,145,44),func(): _stats_popup(root,run))

# The card uses authored compact copy; the popup keeps every effect and rule.
static func product(parent: Control, rect: Rect2, model: Dictionary, buy: Callable, inspect: Callable, toggle_lock: Callable) -> void:
	var bay := HeroImageSkin.material(parent,"cstore_bright/card_"+str(model.get("tier","common")),rect)
	var index := int(model.get("slot_index",0))
	bay.name = "ShopProduct_%d" % index
	bay.set_meta("ui_fx_art_rect",Rect2(40,18,82,62))
	var empty := bool(model.get("empty",false))
	var locked := bool(model.get("locked",false))
	if locked:
		for surface in bay.get_children(true):
			if surface is HeroImageSkin.ImageSurface: surface.self_modulate = Color(0.96,1.0,0.98)
	var rail := HeroImageSkin.material(bay,"cstore_bright/tier_rail",Rect2(5,3,rect.size.x-10,3))
	rail.name = "ShopTierRail"
	rail.modulate = Color(str(TIER_ACCENTS.get(str(model.get("tier","common")),TIER_ACCENTS.common)))
	var body := HeroImageSkin.button(bay,"",Rect2(8,5,rect.size.x-16,205),inspect,"plain")
	body.name = "ShopInspect_%d" % index
	body.disabled = empty
	if model.get("icon") != null:
		HeroUI.fixed_art(bay,model.icon,Rect2(40,18,82,62))
	else:
		HeroImageSkin.text(bay,"—",Rect2(40,18,82,62),"heading",30,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var name_label := _copy_area(bay,str(model.get("name","품절")),Rect2(20,82,122,50),"heading",18,MUTED if empty else INK,HORIZONTAL_ALIGNMENT_CENTER,true)
	name_label.name = "CardName"
	var summary_label := _copy_area(bay,str(model.get("summary","")),Rect2(20,137,122,36),"body",13,MUTED if empty else INK)
	summary_label.name = "CardSummary"
	var note_label := _copy_area(bay,str(model.get("note","")),Rect2(20,178,122,38),"body",13,DANGER if model.get("warning",false) else MUTED)
	note_label.name = "CardNote"
	var can_buy := bool(model.get("can_buy",false))
	var purchase := _shop_button(bay,"",Rect2(16,215,130,44),buy,"purchase",false,Vector4(10,8,10,8))
	purchase.name = "ShopPurchase_%d" % index
	purchase.disabled = not can_buy
	if not empty and model.get("free",false):
		# Elite supply: the price plate reads free instead of a stone cost.
		HeroImageSkin.text(purchase,"무료",Rect2(10,6,110,32),"control",16,INK if can_buy else MUTED,HORIZONTAL_ALIGNMENT_CENTER).name = "ShopFree"
	elif not empty:
		_icon_number(purchase,Content.trimmed_texture("magicStone"),str(int(model.price)),Vector2(65,22),16,18,INK if can_buy else MUTED)
		if not can_buy:
			for child in purchase.get_children():
				if child is TextureRect: child.self_modulate.a = 0.6
	var lock_button := _shop_button(bay,"",Rect2(114,3,44,44),toggle_lock,"lock_on" if locked else "lock",false,Vector4(6,6,6,6))
	lock_button.name = "ShopLock_%d" % index
	lock_button.disabled = not bool(model.get("can_lock",false))
	var glyph := HeroUI.fixed_icon(lock_button,"lock" if locked else "unlock",Rect2(8,8,28,28))
	glyph.name = "SemanticIcon"
	glyph.self_modulate = Color(ON_ACCENT if locked else INK)
	if lock_button.disabled: glyph.self_modulate.a = 0.35

static func _copy_area(parent: Control, copy: String, rect: Rect2, role: String, font_size: int, color_role: String, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, center: bool = false) -> Label:
	return HeroImageSkin.text(parent,copy,rect,role,font_size,color_role,align,true,{"valign":VERTICAL_ALIGNMENT_CENTER if center else VERTICAL_ALIGNMENT_TOP,"lines":2})

static func _offer_model(run: HeroRun, offer: Dictionary, weapon: bool, blocked: bool) -> Dictionary:
	var id: String = offer.get("id","")
	if id.is_empty():
		return {"empty":true,"tier":"common","name":"품절","summary":"재진열로 다시 확인","note":"","detail":"","icon":null,"price":0,"can_buy":false,"can_lock":false,"locked":false}
	var definition: Dictionary = run.data.weapons[id] if weapon else run.data.items[id]
	var full_copy := _copy(definition)
	var copy: Dictionary = definition.get("shopCardText",{"summary":full_copy.summary,"penalty":full_copy.penalty})
	var free := not weapon and bool(offer.get("free",false))
	var cost := HeroShop.price(run,offer) if weapon else HeroShop.item_price(run,offer)
	var level := int(offer.get("level",1))
	var block_reason := HeroShop.offer_block_reason(run,offer,weapon)
	var count := 0
	if weapon:
		for slot in run.owned:
			if slot.id == id: count = int(slot.level)
	else: count = int(run.items.get(id,0))
	var tier := str(WEAPON_TIERS[clampi(level,0,WEAPON_TIERS.size()-1)]) if weapon else str(CARD_TIERS.get(str(definition.get("rarity","COMMON")),"common"))
	return {"empty":false,"tier":tier,"name":definition.name,"summary":copy.summary,"note":"신규 무기" if weapon and level == 1 else "Lv.%d 강화" % level if weapon else "정예 보급품" if free and str(copy.penalty).is_empty() else copy.penalty,"warning":not weapon and not str(copy.penalty).is_empty(),"detail":definition.description,"full_effects":full_copy.summary,"full_penalty":full_copy.penalty,"icon":Content.weapon_icon(id) if weapon else Content.item_icon(id),"price":cost,"free":free,"can_buy":block_reason.is_empty(),"block_reason":block_reason,"can_lock":not blocked,"locked":bool(offer.get("locked",false)),"weapon":weapon,"count":count,"limit":definition.get("maxLevel",null) if weapon else definition.get("maxStacks",null)}

static func _copy(definition: Dictionary) -> Dictionary:
	var copy: Dictionary = definition.get("shopText",{})
	if not copy.is_empty():
		return {"summary":"\n".join(copy.get("effects",[])),"penalty":" · ".join(copy.get("penalties",[]))}
	return {"summary":str(definition.get("description","")),"penalty":""}

static func _offer_popup(root: Control, model: Dictionary) -> void:
	var details := PackedStringArray([str(model.detail)])
	if not str(model.get("full_effects",model.summary)).is_empty() and str(model.get("full_effects",model.summary)) != str(model.detail): details.append("효과\n"+str(model.get("full_effects",model.summary)))
	if not str(model.get("full_penalty","")).is_empty(): details.append("패널티\n"+str(model.full_penalty))
	details.append("가격: 무료 · 정예 보급품" if model.get("free",false) else "가격: %d 마력석" % int(model.price))
	var limit := "제한 없음" if model.get("limit") == null else str(int(model.limit))
	details.append("현재 Lv.%d / 최대 Lv.%s" % [int(model.count),limit] if model.weapon else "보유 수량: %d / %s" % [int(model.count),limit])
	if not str(model.get("block_reason","")).is_empty(): details.append("구매 불가: "+str(PURCHASE_BLOCKS.get(model.block_reason,PURCHASE_BLOCKS.unavailable)))
	if model.get("locked",false): details.append("진열 유지 중 · 잠금은 구매를 제한하지 않습니다.")
	_details_popup(root,"\n\n".join(details),str(model.name))

static func _footer(root: Control, run: HeroRun, advance: Callable, blocked: bool, refresh: Callable) -> void:
	var has_recipes: bool = not run.guild_support.unlockedRecipeIds.is_empty()
	_shop_button(root,("아이템 %d" if has_recipes else "보유 아이템 %d") % run.items.size(),Rect2(205,350,74 if has_recipes else 163,44),func():
		var lines := PackedStringArray()
		for id in run.items:
			var item: Dictionary = run.data.items[id]
			var copy := _copy(item)
			lines.append("%s ×%d\n%s%s" % [item.name,int(run.items[id]),copy.summary,"\n패널티: "+str(copy.penalty) if not str(copy.penalty).is_empty() else ""])
		_details_popup(root,"\n\n".join(lines) if not lines.is_empty() else "보유한 아이템이 없습니다.","보유 아이템 효과")
	)
	if has_recipes:
		var craft := _shop_button(root,"조합",Rect2(287,350,81,44),func(): HeroGuildScreen.crafting_dialog(root,run,refresh))
		craft.name = "ShopCrafting"
		craft.disabled = blocked
	# The transparent cabinet leaves a calm white shelf under equipped weapons.
	HeroImageSkin.material(root,"cstore_bright/secondary",Rect2(372,350,292,44)).name = "ShopEquipmentShelf"
	for index in range(6):
		var x := 376+index*46
		if index < run.owned.size():
			var slot: Dictionary = run.owned[index]
			HeroUI.fixed_art(root,Content.weapon_icon(slot.id),Rect2(x,357,30,30))
			HeroImageSkin.text(root,str(int(slot.level)),Rect2(x+30,357,14,30),"number",18,INK,HORIZONTAL_ALIGNMENT_CENTER)
		else: HeroImageSkin.text(root,"—",Rect2(x,357,44,30),"body",14,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var next := _shop_button(root,"다음 웨이브",Rect2(674,350,205,44),advance,"primary")
	next.disabled = blocked

static func _popup(root: Control, title: String, width: float = 560, height: float = 342) -> VBoxContainer:
	width = minf(width,883); height = minf(height,380)
	var overlay := ColorRect.new()
	overlay.color = Color(0.02,0.03,0.05,0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_to_group("input_blocker"); root.add_child(overlay)
	var panel := HeroImageSkin.material(overlay,"cstore_bright/popup",Rect2((915-width)/2,(412-height)/2,width,height))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := HeroUI.inset(panel,Vector2(20,12))
	box.set_meta("overlay",overlay)
	box.set_meta("fx_panel",panel)
	var heading := HeroUI.text_block(box,title,HeroUI.lines_height(box,18,2),18,Color(INK),true,{"align":HORIZONTAL_ALIGNMENT_CENTER,"valign":VERTICAL_ALIGNMENT_CENTER,"lines":2,"font_role":"heading"})
	HeroImageSkin.apply_font(heading,"heading",18)
	return box

static func _close_button(box: VBoxContainer) -> void:
	var row := HeroUI.row(box); row.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_button(row,"닫기",Rect2(0,0,120,44),func(): box.get_meta("overlay").queue_free())

static func _details_popup(root: Control, description: String, title: String) -> void:
	var box := _popup(root,title)
	var content := HeroUI.column(HeroUI.scroll(box)); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var copy := HeroUI.paragraph(content,description,14)
	HeroImageSkin.apply_font(copy,"body",14); copy.add_theme_color_override("font_color",Color(INK))
	_close_button(box)

static func _stats_popup(root: Control, run: HeroRun) -> void:
	var box := _popup(root,"전체 능력치",512,342)
	var content := HeroUI.column(HeroUI.scroll(box)); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in HeroArchive.STATS:
		var row := HeroUI.row(content)
		var icon := HeroUI.icon(row,key,24,24)
		icon.self_modulate = Color(INK)
		HeroUI.label(row,HeroArchive.STATS[key],14,Color(INK)).custom_minimum_size.x = 168
		HeroUI.spacer(row)
		var value := HeroUI.label(row,HeroArchive.stat_value(key,float(run.stats[key])),18,Color(INK),"number")
		value.custom_minimum_size.x = 120; value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_close_button(box)

static func _branch_popup(root: Control, run: HeroRun, refresh: Callable) -> void:
	var definition: Dictionary = run.data.weapons[run.pending_branch]
	var modal := _popup(root,"%s · Lv.%d 분기 선택" % [definition.name,int(definition.branchAtLevel)],780,348)
	modal.get_meta("fx_panel").name = "WeaponBranchPanel"
	var choices := HeroUI.row(modal); choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for branch in definition.branches:
		# A native texture style keeps this authored surface outside scroll clipping.
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",HeroImageSkin.style("cstore_bright/info",Vector4(20,12,20,12)))
		card.set_meta("material_key","cstore_bright/info")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		choices.add_child(card)
		var box := HeroUI.column(card)
		var name := HeroUI.text_block(box,branch.name,HeroUI.lines_height(box,18,2),18,Color(INK),true,{"align":HORIZONTAL_ALIGNMENT_CENTER,"valign":VERTICAL_ALIGNMENT_CENTER,"lines":2,"font_role":"heading"})
		HeroImageSkin.apply_font(name,"heading",18)
		var notes := HeroUI.column(HeroUI.scroll(box)); notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var description := HeroUI.paragraph(notes,branch.description,14)
		description.add_theme_color_override("font_color",Color(INK))
		_shop_button(box,"선택",Rect2(0,0,120,44),func():
			var receipt := {"rect":Rect2(376,357,260,30),"content_id":str(definition.id),"branch_id":str(branch.id)}
			if HeroShop.choose_branch(run,branch.id):
				HeroUIEffects.enqueue(root,"branch",receipt)
				refresh.call()
		,"primary")
