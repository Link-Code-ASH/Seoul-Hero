class_name HeroImageSkin
extends RefCounted

# Approved image art owns the surfaces. Native Controls still own input/text.
# The old light/arcade theme stays active on screens awaiting a design review.
static var _fonts: Dictionary = {}

class ImageSurface extends NinePatchRect:
	var source_factor := 4.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		var owner_control := get_parent() as Control
		if owner_control != null:
			owner_control.resized.connect(_fit)
			_fit()
	func _fit() -> void:
		position = Vector2.ZERO
		size = (get_parent() as Control).size * source_factor
		scale = Vector2.ONE / source_factor

static func _data() -> Dictionary:
	return Content.ui_materials.image_skin

static func color(role: String = "ink") -> Color:
	var aliases := {"text":"ink","selected":"accent","disabled":"muted","scene_muted":"muted"}
	var key: String = aliases.get(role,role)
	var extra := {"rule":"#b4c6cf","danger":"#b64e49","coral":"#b64e49","reward":"#9a7128","navy":"#243448","white":"#f5f8fa"}
	return Color(role) if role.begins_with("#") else Color(str(extra.get(key,_data().colors.get(key,_data().colors.ink))))

static func font(role: String = "body") -> Font:
	if role in ["logo","brand","display"]: role = "brand"
	if role == "numbers": role = "number"
	if _fonts.has(role): return _fonts[role]
	var paths := {"brand":"BMJUA.ttf","heading":"KMU80HaeongSans.ttf","body":"Paperlogy-4Regular.ttf","control":"Paperlogy-5Medium.ttf","number":"BarlowCondensed-SemiBold.ttf"}
	var face := FontVariation.new()
	face.base_font = load("res://assets/ui/fonts/"+str(paths.get(role,paths.body)))
	if role != "body": face.fallbacks = [font("body")]
	_fonts[role] = face
	return face

static func apply_font(control: Control, role: String = "body", font_size: int = 14) -> void:
	control.add_theme_font_override("font",font(role))
	control.add_theme_font_size_override("font_size",font_size)
	control.set_meta("font_role",role)

static func _empty(inset: Vector4 = Vector4.ZERO) -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	for side in range(4): style.set_content_margin(side,inset[side])
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = font("body")
	result.default_font_size = 14
	for type in ["Label","Button","CheckButton"]:
		result.set_color("font_color",type,color("ink"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		result.set_stylebox(state,"Button",_empty(Vector4(12,4,12,4)))
	result.set_constant("line_spacing","Label",2)
	result.set_constant("separation","VBoxContainer",8)
	result.set_constant("separation","HBoxContainer",8)
	return result

static func root() -> Control:
	var result := HeroMobileScreen.new()
	result.set_meta("hero_ui_palette","image_skin")
	result.set_meta("approved_image_skin",true)
	result.theme = theme()
	return result

static func _surface(parent: Control, pack_name: String, role: String) -> ImageSurface:
	var pack: Dictionary = _data()[pack_name]
	var entry: Dictionary = pack.roles[role]
	var bounds: Array = entry.rect
	var slices: Array = entry.slice
	var surface := ImageSurface.new()
	surface.name = "AuthoredImageSurface"
	surface.texture = Content.texture(str(entry.get("image_id",pack.image_id)))
	surface.region_rect = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	if int(entry.get("rotation",0)) != 0:
		surface.texture = source_texture(pack_name+"/"+role)
		surface.region_rect = Rect2(Vector2.ZERO,surface.texture.get_size())
	if entry.has("saturation") or entry.has("tint"):
		var tint: Array = entry.get("tint",[1.0,1.0,1.0,1.0])
		surface.material = _state_material(float(entry.get("saturation",1.0)),Color(tint[0],tint[1],tint[2],tint[3]))
	surface.patch_margin_left = int(slices[0]); surface.patch_margin_top = int(slices[1])
	surface.patch_margin_right = int(slices[2]); surface.patch_margin_bottom = int(slices[3])
	surface.source_factor = float(entry.get("asset_scale",pack.get("asset_scale",4)))
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if entry.has("opacity"): surface.modulate.a = float(entry.opacity)
	# Internal decoration does not participate in Container content sizing.
	parent.add_child(surface,false,Node.INTERNAL_MODE_BACK)
	return surface

static func frame(parent: Node, role: String, rect: Rect2) -> Panel:
	var result := Panel.new()
	result.add_theme_stylebox_override("panel",_empty())
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	HeroUI.place(result,rect)
	_surface(result,"panels",role)
	return result

static func panel(parent: Node, role: String = "popup", margin: int = 12) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel",_empty(Vector4(margin,margin,margin,margin)))
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	_surface(result,"panels",role)
	return result

static func _button_surface(button_control: Button, surface: ImageSurface, role: String, selected: bool) -> void:
	var effective := "disabled" if button_control.disabled else "selected" if selected else role
	var pack: Dictionary = _data().buttons
	var entry: Dictionary = pack.roles[effective]
	var bounds: Array = entry.rect
	var region := Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	if surface.region_rect != region: surface.region_rect = region
	var brightness := 0.93 if button_control.is_pressed() else 1.05 if button_control.is_hovered() or button_control.has_focus() else 1.0
	surface.self_modulate = Color(brightness,brightness,brightness)

static func button(parent: Node, caption: String, rect: Rect2, action: Callable, role: String = "secondary", font_size: int = 16, selected: bool = false) -> Button:
	var result := Button.new()
	result.text = caption
	result.clip_text = true
	result.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.custom_minimum_size = Vector2(rect.size.x,maxf(44,rect.size.y))
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.add_to_group("input_blocker")
	apply_font(result,"control",font_size)
	for state in ["normal","hover","pressed","disabled","focus"]:
		result.add_theme_stylebox_override(state,_empty(Vector4(12,4,12,4) if role != "plain" else Vector4.ZERO))
	var caption_color := color("scene") if role == "primary" else color("ink")
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		result.add_theme_color_override(state,caption_color)
	result.add_theme_color_override("font_disabled_color",color("muted"))
	parent.add_child(result)
	HeroUI.place(result,rect)
	if role != "plain":
		var surface := _surface(result,"buttons","selected" if selected else role)
		result.draw.connect(func(): _button_surface(result,surface,role,selected))
	if action.is_valid(): result.pressed.connect(func():
		Sound.prime()
		Sound.cue("buttonClick")
		action.call()
	)
	result.set_meta("image_button_role",role)
	return result

static func text(parent: Node, caption: String, rect: Rect2, role: String = "body", font_size: int = 14, color_role: String = "ink", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false, options: Dictionary = {}) -> Label:
	var result := Label.new()
	apply_font(result,role,font_size)
	result.add_theme_color_override("font_color",color(color_role))
	result.add_theme_constant_override("line_spacing",2)
	result.horizontal_alignment = align
	result.vertical_alignment = int(options.get("valign",VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER))
	result.max_lines_visible = int(options.get("lines",-1))
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	result.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.set_meta("text_frame",rect)
	parent.add_child(result)
	HeroUI.place(result,rect)
	result.text = caption
	return result

static func glass(parent: Node, rect: Rect2) -> Control:
	var result := Control.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	HeroUI.place(result,rect)
	var surface := _surface(result,"glass","guild")
	var frosting := ShaderMaterial.new()
	frosting.shader = preload("res://shaders/ui_glass.gdshader")
	frosting.set_shader_parameter("surface_opacity",float(_data().glass.opacity))
	surface.material = frosting
	return result

# Role-specific authored materials for the approved runtime screens.
static var _role_textures: Dictionary = {}
static var _source_textures: Dictionary = {}

static func _definition(key: String) -> Dictionary:
	return _data()[key.get_slice("/",0)].roles[key.get_slice("/",1)]

static func material(parent: Node, key: String, rect: Rect2) -> Panel:
	var result := Panel.new()
	result.add_theme_stylebox_override("panel",_empty())
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.set_meta("material_key",key)
	parent.add_child(result)
	HeroUI.place(result,rect)
	_surface(result,key.get_slice("/",0),key.get_slice("/",1))
	return result

static func put_surface(parent: Control, key: String) -> ImageSurface:
	parent.set_meta("material_key",key)
	return _surface(parent,key.get_slice("/",0),key.get_slice("/",1))

static func content_rect(parent: Control, key: String = "") -> Rect2:
	if key.is_empty(): key = str(parent.get_meta("material_key",""))
	var padding: Array = _definition(key).get("safe_padding",[16,12,16,12]) if not key.is_empty() else [16,12,16,12]
	return Rect2(float(padding[0]),float(padding[1]),maxf(0,parent.size.x-float(padding[0])-float(padding[2])),maxf(0,parent.size.y-float(padding[1])-float(padding[3])))

static func source_texture(key: String) -> Texture2D:
	if _source_textures.has(key): return _source_textures[key]
	var pack: Dictionary = _data()[key.get_slice("/",0)]
	var entry := _definition(key)
	var bounds: Array = entry.rect
	var bitmap := Content.texture(str(entry.get("image_id",pack.image_id))).get_image().get_region(Rect2i(int(bounds[0]),int(bounds[1]),int(bounds[2]),int(bounds[3])))
	if int(entry.get("rotation",0)) == 90: bitmap.rotate_90(CLOCKWISE)
	var result := ImageTexture.create_from_image(bitmap)
	_source_textures[key] = result
	return result

static func texture(key: String, raster_density: int = 1) -> Texture2D:
	var density := maxi(1,raster_density)
	var cache_key := key+"@"+str(density)
	if _role_textures.has(cache_key): return _role_textures[cache_key]
	var entry := _definition(key)
	var pack: Dictionary = _data()[key.get_slice("/",0)]
	var bitmap := source_texture(key).get_image()
	var factor := float(entry.get("asset_scale",pack.get("asset_scale",4)))
	var logical: Array = entry.get("logical_size",[maxi(1,roundi(bitmap.get_width()/factor)),maxi(1,roundi(bitmap.get_height()/factor))])
	bitmap.resize(int(logical[0])*density,int(logical[1])*density,Image.INTERPOLATE_LANCZOS)
	var result := ImageTexture.create_from_image(bitmap)
	_role_textures[cache_key] = result
	return result

static func style(key: String, inset: Vector4 = Vector4.ZERO, raster_density: int = 1) -> StyleBoxTexture:
	var entry := _definition(key)
	var pack: Dictionary = _data()[key.get_slice("/",0)]
	var factor := float(entry.get("asset_scale",pack.get("asset_scale",4)))
	var slices: Array = entry.get("slice",[0,0,0,0])
	var density := maxi(1,raster_density)
	var result := StyleBoxTexture.new()
	result.texture = texture(key,density)
	for side in range(4):
		result.set_texture_margin(side,float(slices[side])*density/factor)
		result.set_content_margin(side,inset[side]*density)
	return result

static func _state_material(saturation: float, tint: Color) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/ui_surface_state.gdshader")
	result.set_shader_parameter("saturation",saturation)
	result.set_shader_parameter("tint",tint)
	return result

static func stable_button(parent: Node, caption: String, rect: Rect2, action: Callable, base_role: String = "tab", font_size: int = 15, selected: bool = false) -> Button:
	var result := button(parent,caption,rect,action,"plain",font_size)
	var surface := _surface(result,"buttons",base_role)
	surface.material = _state_material(1.0,Color(0.82,1.0,0.94) if selected else Color.WHITE)
	result.set_meta("stable_frame",base_role)
	result.draw.connect(func():
		var material := surface.material as ShaderMaterial
		material.set_shader_parameter("saturation",0.0 if result.disabled else 1.0)
		surface.self_modulate = Color(0.95,0.95,0.95) if result.is_pressed() else Color.WHITE
	)
	return result

static func _image_button_state(control: Button, surface: ImageSurface, base_role: String, selected: bool) -> void:
	var pack_name := base_role.get_slice("/",0)
	var base_name := base_role.get_slice("/",1)
	var pack: Dictionary = _data()[pack_name]
	var roles: Dictionary = pack.roles
	var base: Dictionary = roles[base_name]
	var name := str(base.get("disabled_role","disabled")) if control.disabled else "selected" if selected else base_name
	var entry: Dictionary = roles.get(name,base)
	var bounds: Array = entry.rect
	surface.texture = Content.texture(str(entry.get("image_id",pack.image_id)))
	surface.region_rect = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	var slices: Array = entry.get("slice",[0,0,0,0])
	surface.patch_margin_left = int(slices[0]); surface.patch_margin_top = int(slices[1])
	surface.patch_margin_right = int(slices[2]); surface.patch_margin_bottom = int(slices[3])
	var tint: Array = entry.get("tint",[0.82,1.0,0.94,1.0] if selected and not roles.has("selected") else [1.0,1.0,1.0,1.0])
	surface.material = _state_material(float(entry.get("saturation",0.0 if control.disabled else 1.0)),Color(tint[0],tint[1],tint[2],tint[3]))
	surface.self_modulate = Color(0.94,0.94,0.94) if control.is_pressed() else Color(1.03,1.03,1.03) if control.is_hovered() else Color.WHITE

static func image_button(parent: Node, caption: String, rect: Rect2, action: Callable, role: String = "controls/secondary", font_size: int = 16, selected: bool = false) -> Button:
	var result := Button.new()
	result.text = caption; result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	result.alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.custom_minimum_size = Vector2(rect.size.x,maxf(44,rect.size.y))
	result.add_to_group("input_blocker")
	apply_font(result,"control",font_size)
	var padding: Array = [0,0,0,0] if role == "plain" else _definition(role).get("safe_padding",[16,4,16,8])
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		result.add_theme_stylebox_override(state_name,_empty(Vector4(padding[0],padding[1],padding[2],padding[3])))
	for text_state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		result.add_theme_color_override(text_state,color("ink"))
	result.add_theme_color_override("font_disabled_color",color("muted"))
	parent.add_child(result); HeroUI.place(result,rect)
	if role != "plain":
		var selected_role := role.get_slice("/",0)+"/selected"
		var surface := put_surface(result,selected_role if selected and _data()[role.get_slice("/",0)].roles.has("selected") else role)
		result.draw.connect(func(): _image_button_state(result,surface,role,selected))
	if action.is_valid(): result.pressed.connect(func():
		var ancestor: Node = result.get_parent()
		while ancestor != null:
			if ancestor is DragScroll and ancestor.suppress_click: return
			ancestor = ancestor.get_parent()
		Sound.prime(); Sound.cue("buttonClick"); action.call()
	)
	return result

class DragScroll extends ScrollContainer:
	var state: Dictionary = {}
	var state_key := ""
	var suppress_click := false
	var _pointer := -999
	var _start_y := 0.0
	var _start_scroll := 0.0
	var _dragged := false
	func _ready() -> void:
		set_process_input(true)
		get_v_scroll_bar().value_changed.connect(func(value):
			if not state_key.is_empty(): state[state_key] = int(value)
		)
		_restore.call_deferred()
	func _restore() -> void:
		if not state_key.is_empty(): scroll_vertical = int(state.get(state_key,0))
	func _local(point: Vector2) -> Vector2:
		return get_global_transform_with_canvas().affine_inverse() * point
	func _begin(point: Vector2, pointer: int) -> void:
		var local := _local(point)
		if not Rect2(Vector2.ZERO,size).has_point(local): return
		_pointer = pointer; _start_y = local.y; _start_scroll = scroll_vertical
		_dragged = false; suppress_click = false
	func _move(point: Vector2) -> void:
		var delta := _local(point).y-_start_y
		if absf(delta) >= 8: _dragged = true; suppress_click = true
		if _dragged:
			scroll_vertical = roundi(_start_scroll-delta)
			get_viewport().set_input_as_handled()
	func _finish() -> void:
		_pointer = -999
		_clear_drag.call_deferred()
	func _clear_drag() -> void:
		suppress_click = false; _dragged = false
	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree(): return
		if event is InputEventScreenTouch:
			if event.pressed and _pointer == -999: _begin(event.position,event.index)
			elif not event.pressed and _pointer == event.index: _finish()
		elif event is InputEventScreenDrag and _pointer == event.index:
			_move(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _pointer == -999: _begin(event.position,-1)
			elif not event.pressed and _pointer == -1: _finish()
		elif event is InputEventMouseMotion and _pointer == -1:
			_move(event.position)

static func scroll(parent: Node, rect: Rect2, state: Dictionary = {}, key: String = "") -> ScrollContainer:
	var result := DragScroll.new()
	result.state = state; result.state_key = key
	result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("scrollbar_h_separation",8)
	result.add_to_group("input_blocker")
	parent.add_child(result); HeroUI.place(result,rect)
	var bar := result.get_v_scroll_bar()
	bar.custom_minimum_size.x = 6
	bar.add_theme_stylebox_override("scroll",style("sliders/scroll_track"))
	for state_name in ["grabber","grabber_highlight","grabber_pressed"]:
		bar.add_theme_stylebox_override(state_name,style("sliders/scroll_thumb"))
	return result

static func card(parent: Node, caption: String, art: Texture2D, minimum_size: Vector2, selected: bool, locked: bool, action: Callable) -> Button:
	var result := Button.new()
	result.custom_minimum_size = minimum_size
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_to_group("input_blocker")
	for state_name in ["normal","hover","pressed","disabled","focus"]: result.add_theme_stylebox_override(state_name,_empty())
	parent.add_child(result)
	var background := put_surface(result,"cards/normal")
	background.set_meta("fixed_card_background",true)
	background.material = _state_material(0.25 if locked else 1.0,Color(0.90,1.0,0.96) if selected else Color(0.82,0.85,0.89) if locked else Color.WHITE)
	put_surface(result,"glass/cell")
	result.clip_contents = true
	if selected:
		var outline := put_surface(result,"accents/selection")
		outline.name = "CardSelectionOutline"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side_name in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side_name,6)
	result.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)
	if art != null:
		var media := Control.new()
		media.custom_minimum_size.y = 24 if caption.is_empty() else 56
		media.size_flags_horizontal = Control.SIZE_EXPAND_FILL; media.size_flags_vertical = Control.SIZE_EXPAND_FILL
		media.mouse_filter = Control.MOUSE_FILTER_IGNORE; media.clip_contents = true
		body.add_child(media)
		var shadow := TextureRect.new()
		shadow.texture = source_texture("glass/shadow"); shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_SCALE; shadow.modulate.a = 0.4
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE; shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		media.add_child(shadow)
		media.resized.connect(func():
			shadow.position = Vector2(media.size.x*0.24,maxf(0,media.size.y-10))
			shadow.size = Vector2(media.size.x*0.52,14)
		)
		var image := TextureRect.new()
		image.texture = art; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE; image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if locked: image.modulate.a = 0.66
		media.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not caption.is_empty():
		var label := Label.new()
		label.text = caption; apply_font(label,"control",14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		label.custom_minimum_size.y = 36; label.add_theme_constant_override("line_spacing",2)
		label.add_theme_color_override("font_color",color("accent" if selected else "muted" if locked else "ink"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(label)
	if action.is_valid(): result.pressed.connect(func():
		var ancestor: Node = result.get_parent()
		while ancestor != null:
			if ancestor is DragScroll and ancestor.suppress_click: return
			ancestor = ancestor.get_parent()
		Sound.prime(); Sound.cue("buttonClick"); action.call()
	)
	return result
