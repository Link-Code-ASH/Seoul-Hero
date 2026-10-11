class_name HeroGuildPanelKit
extends RefCounted

# Picture-first pieces for the guild HQ side panel (tycoon look): chunky framed
# boxes, level pips, icon cost chips, portrait cards and a ring timer.
const INK := Color("#eef7fa")
const MUTED := Color("#8fb3c4")
const MINT := Color("#3dd6b5")
const MINT_DARK := Color("#0b5a49")
const GOLD := Color("#e8b75a")
const CORAL := Color("#ef7a6d")
const NAVY := Color("#071019")
const FILL := Color("#0f2130")
const EDGE := Color("#23415a")

static func flat(fill: Color, border: Color, radius: int = 10, width: int = 2, drop: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if drop > 0:
		style.shadow_color = NAVY
		style.shadow_size = 0
		style.shadow_offset = Vector2(0,drop)
		style.expand_margin_bottom = 0
	return style

static func frame(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	var style := flat(Color("#11243a"),Color("#2b5066"),16,3)
	style.shadow_color = NAVY; style.shadow_size = 2; style.shadow_offset = Vector2(0,5)
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel); HeroUI.place(panel,rect)
	return panel

static func label(parent: Node, caption: String, size: int = 14, color: Color = INK, role: String = "heading") -> Label:
	var result := Label.new()
	HeroImageSkin.apply_font(result,role,size)
	result.add_theme_color_override("font_color",color)
	result.add_theme_color_override("font_outline_color",NAVY)
	result.add_theme_constant_override("outline_size",3 if size >= 18 else 0)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.text = caption
	parent.add_child(result)
	return result

static func placed_label(parent: Control, caption: String, rect: Rect2, size: int = 14, color: Color = INK, role: String = "heading", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := label(parent,caption,size,color,role)
	result.horizontal_alignment = align
	result.clip_text = true
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	HeroUI.place(result,rect)
	return result

# Room art cropped to its floor and walls for a framed thumbnail.
static func thumbnail(parent: Control, texture: Texture2D, rect: Rect2, badge: String = "") -> Control:
	var holder := Panel.new()
	holder.add_theme_stylebox_override("panel",flat(Color("#0a1620"),Color("#3a6a84"),12,2))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	parent.add_child(holder); HeroUI.place(holder,rect)
	if texture != null:
		var crop := AtlasTexture.new()
		crop.atlas = texture
		crop.region = Rect2(40,40,432,370) if texture.get_width() >= 512 else Rect2(Vector2.ZERO,texture.get_size())
		var art := TextureRect.new()
		art.texture = crop
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(art); HeroUI.place(art,Rect2(Vector2(3,3),rect.size-Vector2(6,6)))
	if not badge.is_empty():
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel",_padded(flat(GOLD,NAVY,9,2),7,0))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(tag)
		label(tag,badge,13,Color("#3a2604"))
		tag.position = rect.position+Vector2(-5,rect.size.y-16)
	return holder

static func _padded(style: StyleBoxFlat, x: int, y: int) -> StyleBoxFlat:
	style.content_margin_left = x; style.content_margin_right = x
	style.content_margin_top = y; style.content_margin_bottom = y
	return style

class Pips extends Control:
	var level := 0
	var maximum := 10
	func _draw() -> void:
		var gap := 3.0
		var width := (size.x-gap*(maximum-1))/maxf(1.0,float(maximum))
		for index in maximum:
			var cell := Rect2(index*(width+gap),0,width,size.y)
			if index < level:
				draw_rect(cell.grow(1.5),Color(0.24,0.84,0.71,0.25))
				draw_rect(cell,Color("#3dd6b5"))
			else:
				draw_rect(cell,Color("#1e3344"))
				if index == level: draw_rect(cell,Color("#3dd6b5"),false,1.5)

static func pips(parent: Control, rect: Rect2, level: int, maximum: int) -> Control:
	var bar := Pips.new()
	bar.level = level; bar.maximum = maxi(1,maximum)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar); HeroUI.place(bar,rect)
	return bar

static func _button_styles(button: Button, kind: String, radius: int = 12) -> void:
	var looks := {
		"primary":[Color("#33cdab"),Color("#9af5e0"),MINT_DARK,Color("#04261e")],
		"secondary":[Color("#264257"),Color("#5f8aa6"),Color("#0b1a26"),INK],
		"tab":[Color("#122434"),Color("#24425a"),NAVY,Color("#9db8c6")],
		"off":[Color("#22313d"),Color("#3b5263"),Color("#0b141b"),Color("#9fb1bc")],
	}
	var look: Array = looks.get(kind,looks.secondary)
	var normal := flat(look[0],look[1],radius,2)
	normal.shadow_color = look[2]; normal.shadow_size = 1; normal.shadow_offset = Vector2(0,3)
	var hover := normal.duplicate() as StyleBoxFlat; hover.bg_color = (look[0] as Color).lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat; pressed.shadow_offset = Vector2(0,1); pressed.bg_color = (look[0] as Color).darkened(0.08)
	var disabled := flat(looks.off[0],looks.off[1],radius,2)
	for state in ["normal","focus"]: button.add_theme_stylebox_override(state,normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("disabled",disabled)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(state,look[3])
	button.add_theme_color_override("font_disabled_color",looks.off[3])

static func button(parent: Node, caption: String, action: Callable, kind: String = "primary", size: int = 17, minimum: Vector2 = Vector2(0,40)) -> Button:
	var result := Button.new()
	result.text = caption
	result.custom_minimum_size = minimum
	result.focus_mode = Control.FOCUS_NONE
	HeroImageSkin.apply_font(result,"heading",size)
	_button_styles(result,kind)
	if action.is_valid(): result.pressed.connect(action)
	parent.add_child(result)
	return result

# A button with a small second line (cost, time or the reason it is blocked).
static func action_button(parent: Node, caption: String, note: String, action: Callable, enabled: bool, kind: String = "primary", minimum: Vector2 = Vector2(0,44), icon: Texture2D = null) -> Button:
	var result := button(parent,"",action,kind,17,minimum)
	result.disabled = not enabled
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(row); row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint: Color = Color("#04261e") if enabled and kind == "primary" else INK if enabled else Color("#9fb1bc")
	if icon != null: icon_rect(row,icon,22)
	var main := label(row,caption,17,tint)
	result.set_meta("caption_label",main)
	if not note.is_empty():
		var tag := PanelContainer.new()
		var tag_fill := Color(0,0,0,0.16) if enabled else Color(CORAL,0.16)
		tag.add_theme_stylebox_override("panel",_padded(flat(tag_fill,Color(0,0,0,0),8,0),7,1))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		var note_label := label(tag,note,12,tint if enabled else Color("#ffb1a7"),"body")
		note_label.clip_text = true
		note_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var note_width := HeroImageSkin.font("body").get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+2.0
		note_label.custom_minimum_size.x = minf(note_width,190.0)
	return result

static func icon_rect(parent: Node, texture: Texture2D, side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side,side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

# Room art crop for use inside containers.
static func room_icon(parent: Node, texture: Texture2D, side: Vector2) -> TextureRect:
	var crop: Texture2D = texture
	if texture != null and texture.get_width() >= 512:
		var atlas := AtlasTexture.new(); atlas.atlas = texture; atlas.region = Rect2(40,40,432,370); crop = atlas
	var art := icon_rect(parent,crop,side.x)
	art.custom_minimum_size = side
	return art

static func tab(parent: Control, caption: String, rect: Rect2, selected: bool, action: Callable, dot: bool = false) -> Button:
	var result := button(parent,caption,action,"primary" if selected else "tab",15,rect.size)
	HeroUI.place(result,rect)
	if dot:
		var marker := Panel.new()
		marker.add_theme_stylebox_override("panel",flat(CORAL,NAVY,5,1))
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.add_child(marker); HeroUI.place(marker,Rect2(rect.size.x-16,6,10,10))
	return result

static func card_panel(parent: Node, highlight: Color = EDGE, fill: Color = FILL, radius: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_padded(flat(fill,highlight,radius,2),6,4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

# What a room does, one short tile per effect phrase.
static func tiles(parent: Node, phrases: Array, badge_index: int = -1, badge: String = "") -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = mini(3,maxi(1,phrases.size()))
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for index in phrases.size():
		var tile := card_panel(grid)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(0,40)
		var caption := label(tile,str(phrases[index]),12,Color("#d8eaf2"),"body")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.max_lines_visible = 2
		caption.custom_minimum_size.x = 80
		if index == badge_index and not badge.is_empty():
			tile.add_theme_stylebox_override("panel",_padded(flat(FILL,GOLD,10,2),6,4))
	return grid

static func chip(parent: Node, texture: Texture2D, amount: String, lacking: bool) -> PanelContainer:
	var panel := card_panel(parent,Color("#8a3b34") if lacking else Color("#1f3a50"),Color("#2a1414") if lacking else Color("#0a1823"),9)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(20,20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var number := label(row,amount,15,Color("#ffb1a7") if lacking else INK,"number")
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel

# Cost as icon chips; wallet decides which chips turn red.
static func cost_chips(parent: Node, cost: Dictionary, guild_wallet: Dictionary, wallet: Dictionary = {}) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for key in ["associationCoins"]+HeroGuildState.RESOURCES:
		var need := int(cost.get(key,0))
		if need <= 0: continue
		var have := int(wallet.get(key,0)) if key == "associationCoins" else int(guild_wallet.get(key,0))
		var definition: Dictionary = Content.data.resources[key]
		chip(grid,Content.trimmed_texture(definition.image),HeroUI.amount(need),have < need)
	return grid

# Reward cards (type/contentId/amount) as plain icon chips.
static func reward_chips(parent: Node, cards: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for card in cards:
		var display := HeroMetaScreens.reward_display(card)
		chip(grid,display.texture,HeroUI.amount(int(card.amount)),false)
	return grid

static func caption_row(parent: Node, left: String, right: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var start := label(row,left,13,MUTED)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not right.is_empty(): label(row,right,13,MUTED)
	return row

# Portrait card: picture, name, role and level stars. Gold edge marks a specialist.
static func portrait_card(parent: Node, texture: Texture2D, name: String, role: String, stars: int, max_stars: int, specialist: bool, selected: bool, action: Callable, note: String = "") -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(94,128)
	card.focus_mode = Control.FOCUS_NONE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edge := MINT if selected else GOLD if specialist else EDGE
	var style := flat(FILL,edge,11,3 if selected else 2)
	for state in ["normal","hover","pressed","focus","disabled"]: card.add_theme_stylebox_override(state,style)
	if action.is_valid(): card.pressed.connect(action)
	parent.add_child(card)
	var stage := Panel.new()
	var back := flat(Color("#1d4258"),Color(0,0,0,0),9,0)
	back.corner_radius_bottom_left = 0; back.corner_radius_bottom_right = 0
	stage.add_theme_stylebox_override("panel",back)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	card.add_child(stage)
	stage.set_anchors_preset(Control.PRESET_TOP_WIDE); stage.offset_left = 3; stage.offset_right = -3; stage.offset_top = 3; stage.offset_bottom = 67
	if texture != null:
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(art)
		# Head and shoulders: the sprite is taller than the stage, centred and hung from its top.
		# All four offsets are set; a preset alone keeps the zero width the node had before layout.
		var tall := 108.0
		var wide := tall*texture.get_width()/maxf(1.0,float(texture.get_height()))
		art.anchor_left = 0.5; art.anchor_right = 0.5; art.anchor_top = 0.0; art.anchor_bottom = 0.0
		art.offset_left = -wide*0.5; art.offset_right = wide*0.5; art.offset_top = 3; art.offset_bottom = 3+tall
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.set_anchors_preset(Control.PRESET_FULL_RECT); column.offset_top = 68; column.offset_left = 2; column.offset_right = -2; column.offset_bottom = -2
	for line in [[name,13,INK,"heading"],[role,10,MUTED,"body"],["★".repeat(stars)+"☆".repeat(maxi(0,max_stars-stars)),11,GOLD,"body"]]:
		var text := label(column,str(line[0]),int(line[1]),line[2],str(line[3]))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not note.is_empty():
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel",_padded(flat(Color(NAVY,0.85),Color(0,0,0,0),6,0),4,0))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tag); tag.position = Vector2(5,5)
		label(tag,note,10,MINT,"body")
	return card

static func add_card(parent: Node, caption: String, action: Callable, enabled: bool = true) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(94,128)
	card.focus_mode = Control.FOCUS_NONE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.disabled = not enabled
	var style := flat(Color("#0b1822"),Color("#3a6a84"),11,2)
	for state in ["normal","hover","pressed","focus","disabled"]: card.add_theme_stylebox_override(state,style)
	card.text = "＋\n"+caption
	HeroImageSkin.apply_font(card,"heading",14)
	for state in ["font_color","font_hover_color","font_pressed_color"]: card.add_theme_color_override(state,Color("#7fb0c6"))
	card.add_theme_color_override("font_disabled_color",Color("#4b6474"))
	if action.is_valid(): card.pressed.connect(action)
	parent.add_child(card)
	return card

class Ring extends Control:
	var progress := 0.0
	var art: Texture2D
	func _draw() -> void:
		var center := size*0.5
		var radius := minf(size.x,size.y)*0.5
		draw_circle(center,radius,Color("#071019"))
		draw_arc(center,radius-6,0,TAU,64,Color("#1a2c3a"),9,true)
		if progress > 0.0: draw_arc(center,radius-6,-PI*0.5,-PI*0.5+TAU*clampf(progress,0.0,1.0),64,Color("#3dd6b5"),9,true)
		draw_circle(center,radius-11,Color("#0e1c29"))
		if art != null:
			var inner := (radius-13)*2.0
			var dims := art.get_size()
			var fit := inner/maxf(dims.x,dims.y)*1.15
			draw_texture_rect(art,Rect2(center-dims*fit*0.5,dims*fit),false)

static func ring(parent: Node, size: float, progress: float, art: Texture2D) -> Control:
	var result := Ring.new()
	result.progress = progress; result.art = art
	result.custom_minimum_size = Vector2(size,size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result
