class_name HeroEconomyUI
extends RefCounted

# Bright office-day-01 frame set shared with the lobby.
const _OFFICE := "res://assets/ui/office-day-01/"
const _TITLE := "#24395c"
const _MUTED := "#5a6578"
const _MINT := "#1e8276"
const _ROW_MARGINS := Vector4(20,20,20,20)
const _PRIMARY_MARGINS := Vector4(28,28,28,28)
const _SECONDARY_MARGINS := Vector4(26,26,26,26)

# The routed association keeps its existing actions inside the approved office profile.
static func association(go: Callable, act: Callable, selected: String = "vitality") -> Control:
	var root := HeroImageSkin.root()
	root.set_meta("economy_ui_preview",true)
	# Same desk as 자료집: folder of office keys on the left, a paper sheet on the right.
	HeroDesk.backdrop(root,"association")
	HeroDesk.header(root,"협회",func(): go.call("lobby"))
	HeroDesk.text(root,"협회 코인",Rect2(640,12,96,36),"control",14,HeroDesk.BODY,HORIZONTAL_ALIGNMENT_RIGHT)
	HeroDesk.chip(root,Rect2(744,10,158,40),Content.trimmed_texture("associationCoin"),HeroUI.amount(int(Profile.meta.wallet.associationCoins)),"AssociationCoins")
	var draw_kinds := {"draw:character":["character","각성자 모집","characters"],"draw:weapon":["weapon","무기 보급","weapons"],"draw:blessing":["blessing","단군의 축복 계승","blessings"]}
	if not Content.data.upgrades.has(selected) and not draw_kinds.has(selected): selected = "draw:character"
	# Left: the open folder of 협회 업무, one office key per entry.
	var folder := HeroDesk.panel(root,Rect2(10,72,322,272),"AssociationListCard") if HeroDesk.presentation else HeroDesk.folder(root,Rect2(10,52,322,356),"AssociationListCard")
	HeroDesk.text(folder,"협회 업무",Rect2(26,12,200,28) if HeroDesk.presentation else Rect2(30,10,200,28),"heading" if HeroDesk.presentation else "brand",17,HeroDesk.INK).name = "AssociationFolderTitle"
	var scroll := HeroImageSkin.scroll(root,Rect2(28,120,290,216) if HeroDesk.presentation else Rect2(28,104,290,286))
	scroll.name = "AssociationCollection"
	HeroDesk.scrollbar(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",6)
	scroll.add_child(rows)
	for draw_id in draw_kinds:
		var draw_key: String = str(draw_id)
		var spec: Array = draw_kinds[draw_key]
		var left := HeroMeta.draw_candidates(Content.data,Profile.meta,str(spec[0])).size()
		var picked: bool = draw_key == selected
		var draw_row := _desk_row(rows,picked,str(spec[1]),"남은 %d개" % left if left > 0 else "모두 해금",func(): act.call("associationSelect",draw_key))
		draw_row.name = "Association_"+str(spec[0])+"Draw"
		if picked: scroll.ensure_control_visible.call_deferred(draw_row)
	for id in Content.data.upgrades:
		var upgrade_id: String = str(id)
		var definition: Dictionary = Content.data.upgrades[upgrade_id]
		var level := int(Profile.meta.association.upgrades.get(upgrade_id,0))
		var chosen: bool = upgrade_id == selected
		var row := _desk_row(rows,chosen,str(definition.name),"해금 완료" if definition.effect.type == "unlock" and level > 0 else "콘텐츠 해금" if definition.effect.type == "unlock" else "%d회 강화" % level,func(): act.call("associationSelect",upgrade_id))
		row.name = "Association_"+upgrade_id
		if chosen: scroll.ensure_control_visible.call_deferred(row)
	if HeroDesk.presentation:
		var footer := HeroDesk.nine(root,HeroDesk.UNIFIED+"glass_row.png",Rect2(10,354,322,46),Vector4(24,24,24,24),46.0/112.0)
		footer.self_modulate.a = 0.84
		HeroDesk.text(root,"오늘도 안전한 출동을 준비해요.",Rect2(26,354,214,46),"body",12,HeroDesk.INK)
		var note := HeroDesk.postit(root,Rect2(248,342,78,60),"안전한\n출동!","mint",-1.0)
		(note.get_node("DeskNoteText") as Label).add_theme_font_size_override("font_size",11)
	if draw_kinds.has(selected):
		_draw_panel(root,act,draw_kinds[selected])
		return root
	var upgrade: Dictionary = Content.data.upgrades[selected]
	var level := int(Profile.meta.association.upgrades.get(selected,0))
	var cost := HeroMeta.association_cost(Content.data,Profile.meta,selected)
	var panel := _detail_card(root,str(upgrade.name))
	HeroDesk.text(panel,_word_wrap(str(upgrade.description),"body",14,_W-64),Rect2(0,36,_W-64,44),"body",14,_MUTED,HORIZONTAL_ALIGNMENT_LEFT,true,{"lines":2})
	if upgrade.effect.type == "stat":
		var current := HeroMeta.association_bonus(upgrade,level)
		var increase := HeroMeta.association_bonus(upgrade,level+1)-current
		var stat_name := str(HeroArchive.STATS.get(upgrade.effect.stat,upgrade.effect.stat))
		HeroDesk.text(panel,"%s · %d회 강화" % [stat_name,level],Rect2(0,84,_W,24),"control",16,_TITLE)
		var current_strip := _strip(panel,"CurrentEffect",Rect2(0,110,_W,38))
		HeroDesk.text(current_strip,"현재 효과",Rect2(18,0,170,38),"body",15,_MUTED)
		var current_value := HeroDesk.text(current_strip,_bonus(upgrade,current),Rect2(190,0,_W-210,38),"number",26,_MINT,HORIZONTAL_ALIGNMENT_RIGHT)
		current_value.name = "CurrentEffectValue"
		current_value.set_meta("association_bonus",current)
		var next_strip := _strip(panel,"NextIncrease",Rect2(0,152,_W,38))
		HeroDesk.text(next_strip,"다음 1회 증가",Rect2(18,0,170,38),"body",15,_MUTED)
		HeroDesk.text(next_strip,_bonus(upgrade,increase),Rect2(190,0,_W-210,38),"number",26,_TITLE,HORIZONTAL_ALIGNMENT_RIGHT)
		var pricing := "강화마다 비용 +%d 코인 · 반복 강화 가능" % int(upgrade.costStep)
		HeroDesk.text(panel,pricing,Rect2(0,194,_W,20),"body",13,_MUTED)
		var limit := float(upgrade.get("softCap",0.0))
		HeroDesk.text(panel,"협회 보너스는 %s에 가까워지며 증가량이 줄어듭니다." % _bonus(upgrade,limit) if limit > 0.0 else "강화 효과는 다음 출동부터 적용됩니다.",Rect2(0,214,_W,20),"body",13,_MUTED,HORIZONTAL_ALIGNMENT_LEFT,true,{"lines":1})
	else:
		var text_width := _W
		if cost >= 0:
			# Still locked: the office lock tag sits on the right of the card.
			HeroUI.fixed_art(panel,load(_OFFICE+"lock_overlay.png"),Rect2(_W-64,88,64,64)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			text_width = _W-80
		HeroDesk.text(panel,"해금 완료" if cost < 0 else "한 번 해금하면 계속 사용할 수 있습니다.",Rect2(0,90,text_width,30),"heading",18,_MINT,HORIZONTAL_ALIGNMENT_LEFT,true,{"lines":1})
		HeroDesk.text(panel,"흡혈 회로는 출동 상점에서 구매한 판에만 효과가 적용됩니다." if selected == "circuit" else "해금한 콘텐츠는 해당 화면과 출동 상점에서 사용할 수 있습니다.",Rect2(0,126,text_width,60),"body",14,_MUTED,HORIZONTAL_ALIGNMENT_LEFT,true,{"lines":3})
	var buy_caption := "해금 완료" if cost < 0 else "%s · %s 코인" % ["강화" if upgrade.effect.type == "stat" else "해금",HeroUI.amount(cost)]
	if cost < 0 and upgrade.effect.type != "stat": HeroDesk.stamp(panel,"완료",_STAMP,-0.18)
	var button := HeroDesk.key(panel,buy_caption,Rect2(0,260 if HeroDesk.presentation else 238,_W,46),func(): act.call("associationBuy",selected),"orange",18,"brand")
	button.name = "AssociationBuy"
	button.disabled = cost < 0 or int(Profile.meta.wallet.associationCoins) < cost
	return root

# 협회 코인 뽑기: one random locked character / weapon / blessing, never a duplicate.
static func _draw_panel(root: Control, act: Callable, spec: Array) -> void:
	var kind: String = spec[0]
	var cost := int(Content.data.draws.costs[kind])
	var left := HeroMeta.draw_candidates(Content.data,Profile.meta,kind)
	var panel := _detail_card(root,str(spec[1]))
	HeroDesk.text(panel,_word_wrap("협회 코인으로 아직 없는 %s 중 하나를 무작위로 해금합니다. 이미 가진 것은 나오지 않습니다." % {"character":"각성자","weapon":"무기","blessing":"축복"}[kind],"body",14,_W-64),Rect2(0,36,_W-64,44),"body",14,_MUTED,HORIZONTAL_ALIGNMENT_LEFT,true,{"lines":2})
	var total: int = Content.data[spec[2]].size()
	var owned: int = total-left.size()
	var owned_strip := _strip(panel,"OwnedCount",Rect2(0,88,_W,40))
	HeroDesk.text(owned_strip,"보유",Rect2(18,0,170,40),"body",15,_MUTED)
	HeroDesk.text(owned_strip,"%d / %d" % [owned,total],Rect2(190,0,_W-210,40),"number",26,_MINT,HORIZONTAL_ALIGNMENT_RIGHT)
	# Collection progress in the office bar frame; the fill sits inside the groove.
	_nine(panel,"bar_frame",Rect2(0,138,_W,24),Vector4(24,16,24,16),24.0/64.0)
	if total > 0 and owned > 0:
		var ratio := clampf(float(owned)/float(total),0.0,1.0)
		var fill_width := maxf(12.0,(_W-10.0)*ratio)
		_nine(panel,"bar_fill",Rect2(5,142,fill_width,16),Vector4(20,12,20,12),0.25)
	if left.is_empty(): HeroDesk.stamp(panel,"완료",_STAMP,-0.18)
	HeroDesk.text(panel,"남은 %d개" % left.size() if not left.is_empty() else "모두 해금했습니다",Rect2(0,172,_W,24),"control",16,_TITLE)
	HeroDesk.text(panel,"1회 %s 코인" % HeroUI.amount(cost),Rect2(0,196,_W,20),"body",13,_MUTED)
	var button := HeroDesk.key(panel,"모두 해금" if left.is_empty() else "뽑기 · %s 코인" % HeroUI.amount(cost),Rect2(0,260 if HeroDesk.presentation else 238,_W,46),func(): act.call("associationDraw",kind),"orange",18,"brand")
	button.name = "AssociationDraw"
	button.disabled = left.is_empty() or int(Profile.meta.wallet.associationCoins) < cost

# Blurred office photo with a light warm veil so the cream cards read clearly.
static func _office_backdrop(root: Control) -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "OfficeBackdrop"
	backdrop.texture = load(_OFFICE+"lobby_office_bg_soft.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_meta("full_bleed",true)
	root.add_child(backdrop); HeroUI.place(backdrop,Rect2(0,0,915,412))
	var veil := ColorRect.new()
	veil.name = "OfficeVeil"
	veil.color = Color(1,0.97,0.92,0.35)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_meta("full_bleed",true)
	root.add_child(veil); HeroUI.place(veil,Rect2(0,0,915,412))

# Header strip: round back button, association icon + title, coin chip on the right.
static func _office_header(root: Control, go: Callable) -> void:
	_drop_shadow(root,Rect2(16,10,883,46),5.0,0.28)
	var header := _card(root,"OperationsHeader",Rect2(12,8,891,52))
	_nine(header,"header_bar",Rect2(0,0,891,52),Vector4(24,24,24,24),52.0/128.0)
	var back := _plate_button(header,"button_round","‹",Rect2(6,4,44,44),Vector4.ZERO,44.0/160.0,func(): go.call("lobby"),24,_TITLE)
	back.name = "HeaderBack"
	back.set_meta("action_name","뒤로")
	HeroUI.fixed_art(header,load(_OFFICE+"icons/icon_association.png"),Rect2(58,8,36,36)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	HeroImageSkin.text(header,"협회",Rect2(100,4,120,44),"brand",28,_TITLE).name = "ScreenTitle"
	var chip_rect := Rect2(727,6,156,40)
	HeroImageSkin.text(header,"협회 코인",Rect2(chip_rect.position.x-96,4,88,44),"control",13,_MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	var chip := _card(header,"AssociationCoinChip",chip_rect)
	_nine(chip,"chip_currency",Rect2(Vector2.ZERO,chip_rect.size),Vector4(56,20,56,20),40.0/112.0)
	HeroUI.fixed_art(chip,Content.trimmed_texture("associationCoin"),Rect2(16,7,26,26)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var amount := HeroImageSkin.text(chip,HeroUI.amount(int(Profile.meta.wallet.associationCoins)),Rect2(48,4,94,32),"number",20,_TITLE)
	amount.name = "AssociationCoins"

# Right: the big office window card; the title sits in its cream title band.
# Right: a sheet of office paper; content keeps the old 563x334 coordinates, shifted under a
# tape strip and the sheet title.
# Content width inside the detail sheet, and where the 완료 stamp lands (top right, beside the title).
const _W := 464.0
const _STAMP := Rect2(_W-60,-14,58,58)

# Breaks only at spaces. Godot's line breaker splits Hangul between any two syllables, which
# leaves single syllables like "다" alone on the next line.
static func _word_wrap(caption: String, role: String, font_size: int, width: float) -> String:
	var face := HeroDesk.font(role)
	var lines: Array[String] = []
	var current := ""
	for word in caption.split(" ",false):
		var trial := word if current.is_empty() else current+" "+word
		if not current.is_empty() and face.get_string_size(trial,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width:
			lines.append(current)
			current = word
		else:
			current = trial
	if not current.is_empty(): lines.append(current)
	return "\n".join(lines)

static func _detail_card(root: Control, title: String) -> Control:
	var sheet := HeroDesk.panel(root,Rect2(344,72,560,272),"AssociationSheet") if HeroDesk.presentation else HeroDesk.paper(root,Rect2(344,56,560,352),"AssociationSheet")
	if not HeroDesk.presentation: HeroDesk.art(sheet,HeroDesk.ART+"tape_strip.png",Rect2(232,-10,96,28)).name = "SheetTape"
	var panel := _card(sheet,"AssociationDetail",Rect2(48,22,_W,306) if HeroDesk.presentation else Rect2(48,38,_W,286))
	HeroDesk.text(panel,title,Rect2(0,0,_W-90,34),"brand",HeroDesk.fit(title,"brand",24,_W-90),HeroDesk.INK).name = "AssociationDetailTitle"
	return panel

# Soft contact shadow under a card so it sits above the office backdrop. soft_shadow.png is a
# 64px rounded square blurred inside a 128px canvas (32 source px of falloff on every side).
static func _drop_shadow(parent: Node, rect: Rect2, depth: float, strength: float) -> NinePatchRect:
	var blur := clampf(depth*0.09,0.12,0.6)
	var patch := _nine(parent,"soft_shadow",Rect2(rect.position+Vector2(0,depth)-Vector2(32,32)*blur,rect.size+Vector2(64,64)*blur),Vector4(48,48,48,48),blur)
	patch.name = "Shadow"
	patch.self_modulate = Color(0.16,0.12,0.09,strength)
	return patch

static func _card(parent: Node, node_name: String, rect: Rect2) -> Control:
	var card := Control.new()
	card.name = node_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	HeroUI.place(card,rect)
	return card

# Inset value strip drawn with the plain list row frame.
static func _strip(parent: Node, node_name: String, rect: Rect2) -> Control:
	var strip := _card(parent,node_name,rect)
	if HeroDesk.presentation: HeroDesk.nine(strip,HeroDesk.UNIFIED+"glass_row.png",Rect2(Vector2.ZERO,rect.size),Vector4(24,24,24,24),rect.size.y/112.0)
	else: _nine(strip,"list_row_normal",Rect2(Vector2.ZERO,rect.size),_ROW_MARGINS,rect.size.y/112.0)
	return strip

# Folder entry: a cream office key (navy when chosen) with a title and a status line on its face.
static func _desk_row(parent: Node, chosen: bool, title: String, status: String, action: Callable) -> Button:
	var style: String = ("row_selected" if chosen else "row") if HeroDesk.presentation else ("navy" if chosen else "cream")
	var row := HeroDesk.key(parent,"",Rect2(0,0,276,54),action,style)
	var face: Control = row.get_node("Face")
	HeroDesk.text(face,title,Rect2(16,3,244,26),"control",HeroDesk.fit(title,"control",17,244.0),HeroDesk.ON_DARK if chosen else HeroDesk.INK).name = "RowTitle"
	HeroDesk.text(face,status,Rect2(16,26,244,20),"body",13,"#9fe3d4" if chosen else HeroDesk.BODY).name = "RowStatus"
	return row

# List entry: a plain button over list_row_normal / list_row_selected that follows the
# width the VBox gives it.
static func _list_row(parent: Node, picked: bool, action: Callable) -> Button:
	var row := HeroImageSkin.button(parent,"",Rect2(0,0,264,52),action,"plain")
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art_scale := 52.0/112.0
	var plate := _nine(row,"list_row_selected" if picked else "list_row_normal",Rect2(0,0,264,52),_ROW_MARGINS,art_scale)
	plate.name = "Plate"
	row.move_child(plate,0)
	row.resized.connect(func(): plate.size = row.size/art_scale)
	row.button_down.connect(func(): plate.modulate = Color(0.94,0.94,0.94))
	row.button_up.connect(func(): plate.modulate = Color.WHITE)
	return row

# Nine-slice frame from the office-day-01 set. Margins are authored at full texture size,
# so the patch is laid out at size/scale and drawn scaled to keep corners in proportion.
static func _nine(parent: Node, file: String, rect: Rect2, margins: Vector4, art_scale: float) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = load(_OFFICE+file+".png")
	patch.patch_margin_left = int(margins.x); patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z); patch.patch_margin_bottom = int(margins.w)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(patch)
	patch.position = rect.position
	patch.size = rect.size/art_scale
	patch.scale = Vector2(art_scale,art_scale)
	return patch

# Plain button with a nine-patch plate drawn behind its own caption; pressing swaps in the
# pressed art (3px lower) and nudges the caption down with it.
static func _plate_button(parent: Node, file: String, caption: String, rect: Rect2, margins: Vector4, art_scale: float, action: Callable, font_size: int, caption_color: String) -> Button:
	var button := HeroImageSkin.button(parent,caption,rect,action,"plain",font_size)
	var pressed_box := StyleBoxEmpty.new()
	pressed_box.content_margin_top = 6.0
	button.add_theme_stylebox_override("pressed",pressed_box)
	button.add_theme_stylebox_override("hover_pressed",pressed_box)
	var ink := Color(caption_color)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		button.add_theme_color_override(state,ink)
	button.add_theme_color_override("font_disabled_color",Color("#8a8f98"))
	var plate := _nine(button,file+"_normal",Rect2(Vector2.ZERO,rect.size),margins,art_scale)
	plate.name = "Plate"
	plate.show_behind_parent = true
	button.move_child(plate,0)
	var normal: Texture2D = plate.texture
	var pressed: Texture2D = load(_OFFICE+file+"_pressed.png")
	button.button_down.connect(func(): plate.texture = pressed)
	button.button_up.connect(func(): plate.texture = normal)
	button.mouse_entered.connect(func(): plate.modulate = Color(1.05,1.05,1.05) if not button.disabled else Color.WHITE)
	button.mouse_exited.connect(func(): plate.modulate = Color.WHITE)
	return button

static func _plate_disabled(button: Button, disabled_file: String) -> void:
	if not button.disabled: return
	var plate := button.get_node_or_null("Plate") as NinePatchRect
	if plate != null: plate.texture = load(_OFFICE+disabled_file+".png")

static func _office_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll",_bar_style(Color(0.47,0.38,0.26,0.14)))
	for state_name in ["grabber","grabber_highlight","grabber_pressed"]:
		bar.add_theme_stylebox_override(state_name,_bar_style(Color("#c9a77a")))

static func _bar_style(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(3)
	box.anti_aliasing = true
	return box

static func _bonus(upgrade: Dictionary, value: float) -> String:
	var limit := float(upgrade.get("softCap",0.0))
	return ("약 +" if limit > 0.0 and value > 0.0 and value < limit else "+")+HeroMetaScreens.association_value(upgrade,value)

static func _decimal(value: float) -> String:
	var caption := "%.2f" % value
	while caption.ends_with("0"): caption = caption.trim_suffix("0")
	return caption.trim_suffix(".")

static func resource_summary(value: Dictionary) -> String:
	var entries: Array[String] = []
	for key in HeroGuildState.RESOURCES:
		var amount := int(value.get(key,0))
		if amount <= 0: continue
		entries.append("%s %s" % [Content.data.resources[key].name,HeroUI.amount(amount)])
	return " · ".join(entries)

static func wallet(parent: Control, meta: Dictionary) -> Control:
	var panel := _modal(parent,"길드 전체 재화")
	var scroll := HeroImageSkin.scroll(panel,Rect2(22,60,711,242))
	scroll.name = "GuildWalletCollection"
	var rows := _rows(scroll)
	for key in HeroGuildState.RESOURCES:
		var definition: Dictionary = Content.data.resources[key]
		var row := _row(rows,697,70)
		HeroUI.fixed_art(row,Content.trimmed_texture(str(definition.image)),Rect2(10,15,40,40)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		HeroImageSkin.text(row,str(definition.name),Rect2(62,7,424,26),"control",16)
		HeroImageSkin.text(row,HeroUI.amount(int(meta.guild.wallet.get(key,0))),Rect2(493,7,195,26),"number",18,"accent",HORIZONTAL_ALIGNMENT_RIGHT)
		HeroImageSkin.text(row," · ".join(definition.uses),Rect2(62,36,626,28),"body",13,"muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	_close(panel)
	return panel.get_meta("overlay")

static func probabilities(parent: Control) -> Control:
	var panel := _modal(parent,"보급 확률 안내")
	HeroImageSkin.text(panel,"종류 수 먼저 추첨: 1종 75% · 2종 20% · 3종 5%",Rect2(22,53,711,24),"body",14)
	HeroImageSkin.text(panel,"종류는 중복 없이 추첨합니다. 아래 비중은 첫 종류의 확률입니다.",Rect2(22,78,711,23),"body",13,"muted")
	HeroImageSkin.text(panel,"수량 후보 확률 70% / 25% / 5% · 10상자 안에 조각 보장",Rect2(22,101,711,23),"body",13,"accent")
	HeroImageSkin.text(panel,"재화",Rect2(76,130,340,24),"control",14,"muted")
	HeroImageSkin.text(panel,"첫 선택",Rect2(430,130,100,24),"control",14,"muted",HORIZONTAL_ALIGNMENT_RIGHT)
	HeroImageSkin.text(panel,"수량 후보",Rect2(552,130,177,24),"control",14,"muted",HORIZONTAL_ALIGNMENT_RIGHT)
	var scroll := HeroImageSkin.scroll(panel,Rect2(22,160,711,142))
	scroll.name = "SupplyProbabilityCollection"
	var rows := _rows(scroll)
	for entry in Content.data.supply.entries:
		var key: String = {"associationCoin":"associationCoins","supplyTicket":"supplyTickets","characterFragment":"characterFragments","weaponFragment":"weaponFragments","blessingFragment":"blessingFragments"}.get(entry.type,str(entry.get("contentId","")))
		if entry.type == "revivalStone": key = "revivalStone"+str(entry.contentId).capitalize()
		var definition: Dictionary = Content.data.resources[key]
		var row := _row(rows,697,48)
		HeroUI.fixed_art(row,Content.trimmed_texture(str(definition.image)),Rect2(10,7,34,34)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		HeroImageSkin.text(row,str(definition.name),Rect2(54,4,336,40),"body",14)
		HeroImageSkin.text(row,_decimal(float(entry.weight))+"%",Rect2(398,4,108,40),"number",18,"accent",HORIZONTAL_ALIGNMENT_RIGHT)
		var quantities: Array[String] = []
		for amount in entry.amounts: quantities.append(str(int(amount)))
		HeroImageSkin.text(row," / ".join(quantities),Rect2(516,4,172,40),"number",18,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_close(panel)
	return panel.get_meta("overlay")

static func _modal(parent: Control, title: String) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "EconomyModal"
	overlay.color = Color(0.02,0.03,0.05,0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_to_group("input_blocker")
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.set_meta("economy_ui_preview",true)
	var panel := HeroImageSkin.material(overlay,"ops/popup",Rect2(80,20,755,372))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("overlay",overlay)
	HeroImageSkin.text(panel,title,Rect2(22,12,711,34),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	return panel

static func _close(panel: Control) -> void:
	var button := HeroImageSkin.image_button(panel,"닫기",Rect2(22,314,711,44),func(): panel.get_meta("overlay").queue_free(),"ops/secondary",16)
	button.name = "EconomyModalClose"

static func _rows(parent: Node) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",6)
	parent.add_child(rows)
	return rows

static func _row(parent: Node, width: float, height: float) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(width,height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	HeroImageSkin.put_surface(row,"ops/row")
	return row
