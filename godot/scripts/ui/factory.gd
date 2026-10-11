class_name HeroUI
extends RefCounted

# One vocabulary for selection, archive, growth and shop statistics.
const STAT_NAMES := {"damage":"공통 피해","attackSpeed":"공격 속도","meleeDamage":"근접 피해","rangedDamage":"원거리 피해","criticalChance":"치명타 확률","criticalDamage":"치명타 피해","range":"사거리","area":"범위","duration":"지속시간","projectileSpeed":"투사체 속도","maxHp":"최대 체력","armor":"방어력","dodge":"회피","lifesteal":"흡혈","hpRegeneration":"초당 회복","moveSpeed":"이동 속도","currencyGain":"마력석 획득","pickupRange":"획득 범위","luck":"행운","curse":"저주"}

const ICON_KEYS := ["maxHp","hpRegen","lifeSteal","damage","meleeDamage","rangedDamage","area","attackSpeed","critChance","critDamage","armor","dodge","speed","luck","duration","range","pickupRange","curse","projectileSpeed","currencyGain","back","next","settings","details","musicOn","musicOff","pause","reroll","lock","unlock","wave","depth"]
const ICON_ALIASES := {"hpRegeneration":"hpRegen","lifesteal":"lifeSteal","criticalChance":"critChance","criticalDamage":"critDamage","moveSpeed":"speed","gate":"depth","health":"maxHp","time":"duration","equipment":"settings","check":"unlock"}
static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}

# Faces have distinct roles; the Korean body face remains the number-font fallback.
static func role_font(role: String = "body") -> Font:
	return HeroImageSkin.font(role)

static func apply_font(control: Control, role: String, font_size: int = -1) -> void:
	control.add_theme_font_override("font",role_font(role))
	if font_size > 0: control.add_theme_font_size_override("font_size",font_size)
	control.set_meta("font_role",role)

static func font_role(control: Control, role: String, font_size: int = -1) -> Control:
	apply_font(control,role,font_size)
	return control

static func resolved_font_role(text: String, font_size: int, requested: String = "auto") -> String:
	if requested != "auto": return requested
	if text.strip_edges().is_valid_float(): return "number"
	return "heading" if font_size >= 17 else "body"

static func icon_texture(key: String) -> Texture2D:
	key = str(ICON_ALIASES.get(key,key))
	if _icons.has(key): return _icons[key]
	var index := ICON_KEYS.find(key)
	var source := Content.texture("urbanIconsAtlas")
	if index < 0 or source == null: return null
	var cell := source.get_size()/Vector2(8,4)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(Vector2(index%8,floori(index/8.0))*cell,cell)
	atlas.filter_clip = true
	_icons[key] = atlas
	return atlas

static func icon(parent: Node, key: String, width: float = 24, height: float = 24) -> TextureRect:
	var result := image(parent,icon_texture(key),width,height)
	result.set_meta("semantic_icon",key)
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return result

static func fixed_icon(parent: Node, key: String, rect: Rect2) -> TextureRect:
	var result := icon(parent,key,0,0)
	place(result,rect)
	return result

static func icon_button(parent: Node, key: String, rect: Rect2, action: Callable, tooltip: String, role: String = "secondary", selected: bool = false) -> Button:
	var result := arcade_button(parent,"",rect,action,role,selected)
	var art := icon(result,key,0,0)
	art.name = "SemanticIcon"
	art.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	art.offset_left = -13; art.offset_top = -13
	art.offset_right = 13; art.offset_bottom = 13
	return result

static func button_icon(button_control: Button, key: String, width: int = 20) -> Button:
	button_control.icon = icon_texture(key)
	button_control.expand_icon = true
	button_control.add_theme_constant_override("icon_max_width",width)
	button_control.add_theme_constant_override("h_separation",6)
	return button_control

static func set_icon(button_control: Button, key: String) -> void:
	var art := button_control.get_node_or_null("SemanticIcon") as TextureRect
	if art != null:
		art.texture = icon_texture(key)
		art.set_meta("semantic_icon",key)
	else: button_control.icon = icon_texture(key)

# The returned Label keeps HUD value updates independent of its icon container.
static func icon_value(parent: Node, key: String, text: String, font_size: int = 16, color: Color = Color(-1,-1,-1), icon_size: float = 24) -> Label:
	var group := row(parent)
	group.add_theme_constant_override("separation",6)
	icon(group,key,icon_size,icon_size)
	var value := label(group,text,font_size,color,"number")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return value

class UrbanMapMotif extends Control:
	var line_color := Color(0.2,0.34,0.45,0.075)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		resized.connect(queue_redraw)
	func _draw() -> void:
		var step := 24.0
		for x in range(1,ceili(size.x/step)):
			draw_line(Vector2(x*step,0),Vector2(x*step,size.y),line_color,1)
		for y in range(1,ceili(size.y/step)):
			draw_line(Vector2(0,y*step),Vector2(size.x,y*step),line_color,1)
		var route := PackedVector2Array([Vector2(4,size.y*0.65),Vector2(size.x*0.45,size.y*0.65),Vector2(size.x*0.45,size.y*0.28),Vector2(size.x-4,size.y*0.28)])
		draw_polyline(route,line_color,3,true)
		draw_circle(route[1],3,line_color)
		draw_circle(route[2],3,line_color)

static func urban_motif(parent: Node, rect: Rect2, color: Color = Color(0.2,0.34,0.45,0.075)) -> Control:
	var result := UrbanMapMotif.new()
	result.line_color = color
	parent.add_child(result); place(result,rect)
	return result

static func amount(value: int) -> String:
	if value >= 1000000000: return "%.1fB" % (value/1000000000.0)
	if value >= 1000000: return "%.1fM" % (value/1000000.0)
	if value >= 10000: return "%.1fK" % (value/1000.0)
	return str(value)

static func palette(parent: Node = null) -> String:
	var current := parent
	while current != null:
		if current.has_meta("hero_ui_palette"): return str(current.get_meta("hero_ui_palette"))
		current = current.get_parent()
	return "light"

static func ink(parent: Node, role: String = "text") -> Color:
	if palette(parent) == "image_skin": return HeroImageSkin.color(role)
	var colors: Dictionary = Content.ui_materials.palettes[palette(parent)].colors
	return Color(str(colors.get(role,colors.text)))

static func theme(palette_id: String = "light") -> Theme:
	var result := Theme.new()
	result.default_font = role_font("body")
	result.default_font_size = 14
	var colors: Dictionary = Content.ui_materials.palettes[palette_id].colors
	for type in ["Label","Button","CheckButton"]: result.set_color("font_color",type,Color(colors.text))
	result.set_color("font_hover_color","Button",Color(colors.text))
	result.set_color("font_pressed_color","Button",Color(colors.selected))
	result.set_color("font_disabled_color","Button",Color(colors.disabled))
	result.set_color("font_color","TooltipLabel",Color(colors.text))
	result.set_stylebox("panel","TooltipPanel",material("document",8,"normal",false,palette_id))
	result.set_constant("separation","VBoxContainer",8)
	result.set_constant("separation","HBoxContainer",8)
	result.set_constant("h_separation","GridContainer",8)
	result.set_constant("v_separation","GridContainer",8)
	result.set_constant("line_spacing","Label",2)
	result.set_constant("line_spacing","Button",0)
	for state in ["normal","hover","pressed","disabled","focus"]:
		result.set_stylebox(state,"Button",material("control",-1,state,false,palette_id))
	for type in ["HSlider","VSlider"]:
		var track := material("equipment",0,"normal",false,palette_id)
		track.set_corner_radius_all(4); track.shadow_size = 0
		result.set_stylebox("slider",type,track)
		var fill := material("ceramic",0,"normal",true,palette_id)
		fill.set_corner_radius_all(4); fill.shadow_size = 0
		result.set_stylebox("grabber_area",type,fill)
		result.set_stylebox("grabber_area_highlight",type,fill)
	return result

static func material(role: String, margin: int = -1, state: String = "normal", selected: bool = false, palette_id: String = "light") -> StyleBoxFlat:
	var palette_data: Dictionary = Content.ui_materials.palettes[palette_id]
	var definition: Dictionary = palette_data.materials[role]
	var result := StyleBoxFlat.new()
	var background: Array = definition.background
	var border: Array = definition.border
	result.bg_color = Color(background[0],background[1],background[2],background[3])
	result.border_color = Color(border[0],border[1],border[2],border[3])
	if selected:
		result.bg_color = Color(palette_data.colors.selected_background)
		result.border_color = Color(palette_data.colors.accent)
	if state == "hover": result.bg_color = result.bg_color.lightened(0.08)
	elif state == "pressed": result.bg_color = result.bg_color.darkened(0.12)
	elif state == "disabled":
		result.bg_color = result.bg_color.lerp(Color(0.77,0.81,0.85),0.55)
		result.border_color = Color(palette_data.colors.disabled)
	elif state == "focus":
		result.bg_color = Color.TRANSPARENT
		result.border_color = Color(palette_data.colors.accent)
	result.set_border_width_all(2)
	result.border_width_bottom = 4 if role == "control" else 5
	result.shadow_color = Color(0.12,0.22,0.35,0.24)
	result.shadow_size = 7 if role != "control" else 4
	result.shadow_offset = Vector2(0,4 if role != "control" else 3)
	result.set_corner_radius_all(int(definition.get("radius",6)))
	result.anti_aliasing = true
	if palette_id == "arcade":
		if state == "disabled": result.bg_color = Color(0.79,0.84,0.89)
		result.set_border_width_all(1 if role == "product" else 2)
		result.border_width_bottom = 2 if role == "product" else 4
		result.shadow_size = 2 if role == "product" else 4
		result.shadow_offset = Vector2(0,2 if role == "product" else 3)
	var inset: Array = definition.padding
	for i in range(4):
		result.set_content_margin(i,inset[i] if margin < 0 else margin)
	if role in ["control","primary","secondary"]:
		# The raised face ends above its thicker lower rim. All button states
		# share this content rectangle, so pressing never shifts the caption.
		result.content_margin_top = 6
		result.content_margin_bottom = 8
	return result

static func arcade_sheet(parent: Node, role: String, rect: Rect2, selected: bool = false) -> Panel:
	var result := Panel.new()
	result.add_theme_stylebox_override("panel",material(role,0,"normal",selected,"arcade"))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result); place(result,rect)
	# Product wells stay clean; only the cabinet and controls carry gloss.
	if role != "product": finish(result)
	return result

static func arcade_button(parent: Node, text: String, rect: Rect2, action: Callable, role: String = "secondary", selected: bool = false) -> Button:
	var result := button(parent,text,action,rect.size.x)
	result.custom_minimum_size = Vector2(rect.size.x,maxf(44,rect.size.y))
	for state in ["normal","hover","pressed","disabled","focus"]:
		result.add_theme_stylebox_override(state,material(role,8,state,selected,"arcade"))
	var color := ink(parent,"scene") if role in ["primary","dock","status"] else ink(parent,"selected" if selected else "text")
	for state in ["font_color","font_hover_color","font_pressed_color"]: result.add_theme_color_override(state,color)
	result.add_theme_color_override("font_disabled_color",ink(parent,"muted"))
	apply_font(result,"control")
	place(result,rect)
	finish(result)
	return result

static func root(palette_id: String = "light") -> Control:
	if palette_id in ["light","image_skin"]: return HeroImageSkin.root()
	var control := HeroMobileScreen.new()
	control.set_meta("hero_ui_palette",palette_id)
	control.theme = theme(palette_id)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

static func layout(root_control: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	return box

static func inset(parent: Control, padding: Vector2 = Vector2(16,12)) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,roundi(padding.x))
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,roundi(padding.y))
	parent.add_child(margin)
	var box := column(margin)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

static func background(parent: Control, id: String, tint: Color = Color.WHITE) -> TextureRect:
	var image := TextureRect.new()
	image.texture = Content.texture(id)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.modulate = tint
	image.set_meta("full_bleed",true)
	parent.add_child(image)
	parent.move_child(image,0)
	return image

static func panel(parent: Node, id: String) -> PanelContainer:
	var result := PanelContainer.new()
	result.clip_contents = true
	if palette(parent) == "image_skin":
		# PanelContainer owns its child layout: use a native texture style so an
		# internal NinePatch cannot be laid out as another content child.
		result.add_theme_stylebox_override("panel",HeroImageSkin.style("ops/info",Vector4(20,12,20,12)))
		result.set_meta("material_key","ops/info")
	else:
		result.add_theme_stylebox_override("panel",material(id,-1,"normal",false,palette(parent)))
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	if palette(parent) != "image_skin": finish(result)
	return result

# Native enamel surfaces keep artwork and text independent of frame graphics.
static func finish(control: Control) -> void:
	if palette(control) == "image_skin": return
	if control.has_meta("material_finish"): return
	var layer := HeroSurfaceFinish.new()
	layer.palette_id = palette(control)
	control.add_child(layer)
	control.move_child(layer,0)
	control.set_meta("material_finish",true)

static func place(control: Control, rect: Rect2) -> Control:
	control.position = rect.position
	control.size = rect.size
	return control

static func sheet(parent: Node, frame: String, rect: Rect2, selected: bool = false) -> Panel:
	if palette(parent) == "image_skin":
		var panel_control := HeroImageSkin.material(parent,"ops/info",rect)
		if selected: panel_control.modulate = Color(0.8,1,0.91)
		return panel_control
	var result := Panel.new()
	result.add_theme_stylebox_override("panel",material(frame,0,"normal",selected,palette(parent)))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	place(result,rect)
	finish(result)
	return result

static func surface(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var result := image(parent,texture,0,0)
	result.stretch_mode = TextureRect.STRETCH_SCALE
	place(result,rect)
	return result

static func fixed_art(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var result := image(parent,texture,0,0)
	place(result,rect)
	return result

static func lines_height(_parent: Node, font_size: int, lines: int, spacing: int = 2, role: String = "auto") -> float:
	var requested := "heading" if role == "auto" and font_size >= 17 else "body" if role == "auto" else role
	var font := role_font(requested)
	var line_height := maxf(font.get_height(font_size),role_font("body").get_height(font_size))
	return ceilf(line_height*maxi(1,lines)+spacing*maxi(0,lines-1))

static func fixed_text(parent: Node, text: String, rect: Rect2, font_size: int = 14, color: Color = Color(-1,-1,-1), wrap: bool = false, options: Dictionary = {}) -> Label:
	# The viewport is a containment guard, not a way to shorten required copy.
	# Explicit line budgets are reserved by the owning panel; preview diagnostics
	# report any text that still exceeds them instead of treating clipping as fit.
	var viewport := Control.new()
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(viewport); place(viewport,rect)
	var result := label(viewport,text,font_size,ink(parent) if color.r < 0 else color,str(options.get("font_role","auto")))
	result.horizontal_alignment = int(options.get("align",HORIZONTAL_ALIGNMENT_LEFT))
	result.vertical_alignment = int(options.get("valign",VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER))
	var overflow: String = options.get("overflow","wrap" if wrap else "none")
	result.clip_text = overflow == "ellipsis"
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if overflow == "ellipsis" else TextServer.OVERRUN_NO_TRIMMING
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if overflow == "wrap" or wrap else TextServer.AUTOWRAP_OFF
	result.max_lines_visible = int(options.get("lines",-1))
	result.set_meta("text_layout",options.duplicate())
	result.set_meta("text_frame",rect)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

static func text_block(parent: Node, text: String, height: float, font_size: int = 14, color: Color = Color(-1,-1,-1), wrap: bool = true, options: Dictionary = {}) -> Label:
	var result := fixed_text(parent,text,Rect2(0,0,0,height),font_size,color,wrap,options)
	var viewport := result.get_parent() as Control
	viewport.custom_minimum_size.y = height
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return result

static func text_area(parent: Node, text: String, rect: Rect2, font_size: int = 14, color: Color = Color(-1,-1,-1)) -> Label:
	var viewport := scroll(parent)
	place(viewport,rect)
	viewport.size_flags_vertical = Control.SIZE_FILL
	viewport.size_flags_horizontal = Control.SIZE_FILL
	var content := column(viewport)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var result := paragraph(content,text,font_size)
	if color.r >= 0: result.add_theme_color_override("font_color",color)
	return result

static func flat_button(parent: Node, text: String, rect: Rect2, action: Callable, selected: bool = false) -> Button:
	var result := button(parent,text,action,rect.size.x)
	if text.is_empty():
		for state in ["normal","hover","pressed","disabled","focus"]: result.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		result.add_theme_color_override("font_color",Color(0.72,0.96,0.94) if selected else Color(0.73,0.81,0.86))
		result.add_theme_color_override("font_hover_color",Color(0.9,1,1))
	else:
		set_selected(result,selected)
	place(result,rect)
	return result

static func framed_button(parent: Node, text: String, rect: Rect2, action: Callable, selected: bool = false) -> Button:
	if palette(parent) == "image_skin": return HeroImageSkin.image_button(parent,text,rect,action,"ops/secondary",16,selected)
	var result := button(parent,text,action,rect.size.x)
	for state in ["normal","hover","pressed","disabled"]:
		result.add_theme_stylebox_override(state,material("control",-1,state,selected,palette(parent)))
	result.add_theme_color_override("font_color",ink(parent,"selected" if selected else "text"))
	place(result,rect)
	return result

static func label(parent: Node, text: String, size: int = 14, color: Color = Color(-1,-1,-1), role: String = "auto") -> Label:
	var result := Label.new()
	result.text = text
	result.clip_text = false
	result.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size",size)
	apply_font(result,resolved_font_role(text,size,role),size)
	result.add_theme_color_override("font_color",ink(parent) if color.r < 0 else color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	if parent is HBoxContainer:
		result.custom_minimum_size.x = minf(180.0,result.get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
	return result

static func paragraph(parent: Node, text: String, size: int = 14) -> Label:
	var result := label(parent,text,size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return result

static func ui_reaction(target: Control) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree(): return
	var effects = target.get_tree().get_first_node_in_group("ui_effects")
	if effects != null: effects.show_effect("click",{"control":target})

static func button(parent: Node, text: String, action: Callable, width: float = 90.0, selected: bool = false) -> Button:
	if palette(parent) == "image_skin":
		return HeroImageSkin.image_button(parent,text,Rect2(0,0,width,44),action,"ops/icon" if text.is_empty() else "ops/secondary",16,selected)
	var result := Button.new()
	result.text = text
	result.clip_text = true
	result.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_font(result,"control")
	result.custom_minimum_size = Vector2(width,44)
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.add_to_group("input_blocker")
	result.pressed.connect(func(): ui_reaction(result); Sound.prime(); Sound.cue("buttonClick"); action.call())
	parent.add_child(result)
	if not text.is_empty(): finish(result)
	if text in ["이전","뒤로"]: button_icon(result,"back",18)
	if selected: set_selected(result,true)
	return result

static func set_selected(control: Button, selected: bool) -> void:
	if palette(control) == "image_skin":
		control.set_meta("selected_state",selected)
		control.add_theme_color_override("font_color",HeroImageSkin.color("accent" if selected else "ink"))
		control.queue_redraw()
		return
	for state in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state,material("control",-1,state,selected,palette(control)))
	control.add_theme_color_override("font_color",ink(control,"selected" if selected else "text"))
	control.add_theme_color_override("font_hover_color",ink(control,"selected" if selected else "text"))

static func danger(control: Button) -> Button:
	if palette(control) == "image_skin":
		control.set_meta("danger_action",true)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			control.add_theme_color_override(state,HeroImageSkin.color("danger"))
		control.queue_redraw()
		return control
	for state in ["normal","hover","pressed","disabled"]:
		var style := material("control",-1,state,false,palette(control))
		if state != "disabled":
			style.bg_color = Color(1,0.89,0.89).darkened(0.05 if state == "pressed" else 0.0)
			style.border_color = ink(control,"danger")
		control.add_theme_stylebox_override(state,style)
	control.add_theme_color_override("font_color",ink(control,"danger"))
	control.add_theme_color_override("font_hover_color",ink(control,"danger"))
	return control

static func image(parent: Node, texture: Texture2D, width: float, height: float) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(width,height)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func row(parent: Node) -> HBoxContainer:
	var result := HBoxContainer.new(); parent.add_child(result); return result

static func column(parent: Node) -> VBoxContainer:
	var result := VBoxContainer.new(); parent.add_child(result); return result

static func spacer(parent: Node) -> Control:
	var result := Control.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func header(parent: Node, title: String, back: Callable, coins: bool = true) -> HBoxContainer:
	var result := row(parent)
	var previous := button(result,"이전",back,80)
	previous.icon = icon_texture("back"); previous.expand_icon = true; previous.add_theme_constant_override("icon_max_width",18)
	var heading := paragraph(result,title,20)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color",ink(parent,"scene"))
	if coins:
		image(result,Content.trimmed_texture("associationCoin"),24,24)
		var value := label(result,amount(int(Profile.meta.wallet.associationCoins)),16,ink(parent,"scene_reward"),"number")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return result

static func scroll(parent: Node) -> ScrollContainer:
	var result := ScrollContainer.new()
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Text ends before the scrollbar, including right-aligned numeric columns.
	result.add_theme_constant_override("scrollbar_h_separation",10)
	result.add_to_group("input_blocker")
	parent.add_child(result)
	var bar := result.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	if palette(parent) == "image_skin":
		bar.add_theme_stylebox_override("scroll",HeroImageSkin.style("sliders/scroll_track"))
		for state in ["grabber","grabber_highlight","grabber_pressed"]:
			bar.add_theme_stylebox_override(state,HeroImageSkin.style("sliders/scroll_thumb"))
		return result
	for state in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var style := material("glass" if state == "scroll" else "control",0,"normal",false,palette(parent))
		style.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(state,style)
	return result

static func choice(parent: Node, text: String, texture: Texture2D, selected: bool, action: Callable, frame: String = "equipment", height: float = 96.0) -> Button:
	if palette(parent) == "image_skin": return HeroImageSkin.card(parent,text,texture,Vector2(126,height),selected,false,action)
	var result := button(parent,"",action,126)
	result.custom_minimum_size.y = height
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal","hover","pressed","disabled"]:
		result.add_theme_stylebox_override(state,material(frame,8,state,selected,palette(parent)))
	finish(result)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,8)
	result.add_child(margin)
	var box := column(margin)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_height := lines_height(parent,14,2)
	if texture:
		var art := image(box,texture,60,maxf(24,height - 32 - name_height))
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var name_label := label(box,text,14,ink(parent,"selected" if selected else "text"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.y = name_height
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result
