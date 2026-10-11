class_name HeroDesk
extends RefCounted

# Approved office glass profiles for 설정, 자료집, 협회 and 출동 준비.
# PNGs own surfaces; native Controls own input, text and scrolling.

const OFFICE := "res://assets/ui/office-day-01/"
const ART := "res://assets/ui/office-day-01/archive/"
const INK := "#24395c" # headings
const BODY := "#4a5568" # body copy
const ACCENT := "#1e8276" # values, selected states
const MUTED := "#8a8f98" # locked, disabled
const REWARD := "#b9771e" # cleared, rewards
const DANGER := "#c2483d"
const ON_DARK := "#fffcf5" # text on navy / orange keys

# The approved profiles are live; read-only baseline captures can opt into the legacy desk.
static var presentation: bool = true
static var _presentation_fonts: Dictionary = {}
static var _presentation_textures: Dictionary = {}
const UNIFIED := "res://assets/ui/office-day-01/menu-unified-01/"
const PROFILES := {
	"settings": {"accent":"#7347d7","tag":"SETTINGS"},
	"archive": {"accent":"#aa741a","tag":"ARCHIVE"},
	"association": {"accent":"#347bce","tag":"ASSOCIATION"},
	"gate": {"accent":"#c64f5f","tag":"DEPLOYMENT"},
}

static func profile(parent: Node) -> String:
	var cursor: Node = parent
	while cursor != null:
		if cursor.has_meta("office_profile"): return str(cursor.get_meta("office_profile"))
		cursor = cursor.get_parent()
	return "settings"

static func accent(parent: Node) -> String:
	return str(PROFILES.get(profile(parent),PROFILES.settings).accent)

static func font(role: String = "body") -> Font:
	if not presentation: return HeroImageSkin.font(role)
	if _presentation_fonts.has(role): return _presentation_fonts[role]
	var files := {"brand":"Paperlogy-8ExtraBold.ttf","heading":"Paperlogy-6SemiBold.ttf","control":"Paperlogy-6SemiBold.ttf","body":"Paperlogy-4Regular.ttf","number":"BarlowCondensed-Bold.ttf","tag":"BarlowCondensed-Bold.ttf"}
	var face := FontVariation.new()
	face.base_font = load("res://assets/ui/fonts/"+str(files.get(role,files.body)))
	if role == "tag": face.spacing_glyph = 1
	if role != "body": face.fallbacks = [font("body")]
	_presentation_fonts[role] = face
	return face

static func _presentation_texture(file: String) -> Texture2D:
	if _presentation_textures.has(file): return _presentation_textures[file]
	var texture := load(UNIFIED+file) as Texture2D
	if texture == null: return null
	_presentation_textures[file] = texture
	return texture

# Key art: source height, bottom lip (px of source), nine-slice margin.
const KEYS := {
	"cream": {"file":"button_secondary","height":128.0,"lip":16.0,"margin":26.0,"ink":INK},
	"navy": {"file":"button_deploy_navy","height":144.0,"lip":18.0,"margin":40.0,"ink":ON_DARK},
	"orange": {"file":"button_primary","height":144.0,"lip":18.0,"margin":40.0,"ink":ON_DARK},
	"mint": {"file":"button_mint","height":128.0,"lip":16.0,"margin":26.0,"ink":INK},
}

static func backdrop(root: Control, screen_profile: String = "") -> TextureRect:
	var desk := TextureRect.new()
	desk.name = "DeskBackdrop"
	if presentation:
		var selected: String = screen_profile if PROFILES.has(screen_profile) else "settings"
		root.set_meta("office_profile",selected)
		root.set_meta("office_accent",str(PROFILES[selected].accent))
		root.set_meta("office_presentation",true)
		desk.texture = _presentation_texture("bg_"+selected+".png")
	else:
		desk.texture = load(ART+"desk_background.png")
	desk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	desk.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.set_meta("full_bleed",true)
	root.add_child(desk); HeroUI.place(desk,Rect2(0,0,915,412))
	return desk

# Top-left: navy back key with a painted chevron, then the screen title in navy ink.
# `tag` (e.g. "02 / 06") sits on a strip of tape at the top right.
static func header(root: Control, title: String, back: Callable, back_caption: String = "로비", tag: String = "") -> Button:
	if presentation: return _presentation_header(root,title,back,back_caption,tag)
	var previous := key(root,back_caption,Rect2(12,8,96,40),back,"navy",17,"brand",Vector2(34,0))
	previous.name = "HeaderBack"
	previous.set_meta("action_name",back_caption)
	var chevron := art(previous.get_node("Face"),OFFICE+"glass/glass_chevron_double.png",Rect2(14,9,22,17))
	chevron.flip_h = true
	chevron.name = "BackChevron"
	text(root,title,Rect2(118,6,300,44),"brand",fit(title,"brand",28,300.0),INK).name = "ScreenTitle"
	if not tag.is_empty():
		var holder := Control.new()
		holder.name = "HeaderTag"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(holder); HeroUI.place(holder,Rect2(800,12,100,30))
		holder.pivot_offset = Vector2(50,15)
		holder.rotation = deg_to_rad(2.0)
		art(holder,ART+"tape_strip.png",Rect2(0,0,100,30))
		text(holder,tag,Rect2(0,1,100,26),"number",15,INK,HORIZONTAL_ALIGNMENT_CENTER).name = "HeaderTagText"
	return previous

# Soft contact shadow under a desk piece: a blurred warm-brown patch `depth` px lower than the
# piece. soft_shadow.png is a 64px rounded square blurred inside a 128px canvas, so the patch
# extends 32 source px past the piece on every side.
static func shadow(parent: Node, rect: Rect2, depth: float = 5.0, strength: float = 0.34) -> NinePatchRect:
	var blur := clampf(depth*0.09,0.12,0.6)
	var patch := nine(parent,OFFICE+"soft_shadow.png",Rect2(rect.position+Vector2(0,depth)-Vector2(32,32)*blur,rect.size+Vector2(64,64)*blur),Vector4(48,48,48,48),blur)
	patch.name = "Shadow"
	patch.self_modulate = Color(0.24,0.13,0.05,strength)
	return patch

# 9-slice margins stay in source pixels; the node is scaled down as one piece.
static func nine(parent: Node, path: String, rect: Rect2, margins: Vector4, art_scale: float) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = _presentation_texture(path.trim_prefix(UNIFIED)) if presentation and path.begins_with(UNIFIED) else load(path)
	patch.patch_margin_left = int(margins.x); patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z); patch.patch_margin_bottom = int(margins.w)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(patch)
	patch.position = rect.position
	patch.size = rect.size/art_scale
	patch.scale = Vector2(art_scale,art_scale)
	return patch

static func art(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var result := HeroUI.fixed_art(parent,load(path),rect)
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return result

static func text(parent: Node, caption: String, rect: Rect2, role: String = "body", font_size: int = 14, color: String = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false, options: Dictionary = {}) -> Label:
	var result := HeroImageSkin.text(parent,caption,rect,role,font_size,color,align,wrap,options)
	if presentation:
		result.add_theme_font_override("font",font(role))
	return result

# Largest size (down to `smallest`) at which a single line fits `width`.
static func fit(caption: String, role: String, largest: int, width: float, smallest: int = 9) -> int:
	var face := font(role)
	var result := largest
	while result > smallest and face.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,result).x > width: result -= 1
	return result

# The glass profile owns only presentation; paper/folder below remain physical office props.
static func panel(parent: Node, rect: Rect2, node_name: String = "OfficePanel") -> Control:
	if not presentation: return paper(parent,rect,node_name)
	var holder := Control.new()
	holder.name = node_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	var surface := _presentation_surface(holder,"glass_panel.png",Rect2(Vector2.ZERO,rect.size),"panel")
	surface.name = "PanelArt"
	surface.self_modulate.a = 0.94
	return holder

static func _presentation_surface(parent: Node, file: String, rect: Rect2, kind: String = "panel") -> NinePatchRect:
	var source_height: float = 160.0 if kind == "button" else 128.0 if kind == "header" else 112.0
	var art_scale: float = rect.size.y/source_height if kind in ["button","row","header"] else 0.5
	var margins := Vector4(32,32,32,32)
	if kind == "row": margins = Vector4(24,24,24,24)
	elif kind == "button": margins = Vector4(72,20,72,20)
	elif kind == "header": margins = Vector4(80,20,80,20)
	return nine(parent,UNIFIED+file,rect,margins,art_scale)

static func _presentation_header(root: Control, title: String, back: Callable, back_caption: String, tag: String) -> Button:
	var surface := _presentation_surface(root,"glass_button.png",Rect2(12,8,891,48),"button")
	surface.name = "OfficeHeaderArt"
	surface.self_modulate.a = 0.94
	var previous := key(root,back_caption,Rect2(20,10,96,44),back,"navy",16,"control",Vector2(24,0))
	previous.name = "HeaderBack"
	previous.set_meta("action_name",back_caption)
	var chevron := art(previous.get_node("Face"),OFFICE+"glass/glass_chevron_double.png",Rect2(14,15,18,14))
	chevron.flip_h = true
	chevron.name = "BackChevron"
	text(root,title,Rect2(136,10,332,44),"brand",fit(title,"brand",26,332.0),accent(root)).name = "ScreenTitle"
	text(root,str(PROFILES.get(profile(root),PROFILES.settings).tag),Rect2(478,17,152,27),"tag",14,accent(root),HORIZONTAL_ALIGNMENT_RIGHT).name = "ScreenSubtitle"
	if not tag.is_empty(): text(root,tag,Rect2(798,14,90,32),"number",18,INK,HORIZONTAL_ALIGNMENT_RIGHT).name = "HeaderTagText"
	return previous

static func _presentation_key(parent: Node, caption: String, rect: Rect2, action: Callable, style: String, font_size: int, role: String, caption_offset: Vector2) -> Button:
	var button := HeroImageSkin.button(parent,caption,rect,action,"plain",font_size)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_hover_pressed_color"]:
		button.add_theme_color_override(state,Color(0,0,0,0))
	var is_row: bool = style in ["row","row_selected"]
	var is_dark: bool = style in ["navy","orange","row_selected"]
	var file: String = "glass_row.png" if is_row else "glass_button_navy.png" if is_dark else "glass_button.png"
	var plate := _presentation_surface(button,file,Rect2(Vector2.ZERO,rect.size),"row" if is_row else "button")
	plate.name = "Plate"
	plate.show_behind_parent = true
	var tint := Color.WHITE
	if is_dark and is_row: tint = Color("#223a58")
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face); HeroUI.place(face,Rect2(Vector2.ZERO,rect.size))
	var glint := TextureRect.new()
	glint.name = "OfficeKeyGlint"
	glint.texture = load(OFFICE+"lobby-polish-01/operator_glint.png")
	glint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glint.stretch_mode = TextureRect.STRETCH_SCALE
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glint.self_modulate.a = 0.10
	face.add_child(glint); HeroUI.place(glint,Rect2(-rect.size.y*2.4,0,rect.size.y*2.4,rect.size.y))
	var glint_mask := ShaderMaterial.new()
	glint_mask.shader = load("res://shaders/lobby_plate_mask.gdshader")
	glint_mask.set_shader_parameter("rect_size",rect.size)
	glint_mask.set_shader_parameter("pad",5.0 if is_row else 3.0)
	glint_mask.set_shader_parameter("slant",0.0 if is_row else maxf(0.0,rect.size.y-6.0)*(32.0/112.0))
	glint_mask.set_shader_parameter("label_offset",glint.position)
	glint.material = glint_mask
	glint.hide()
	if not caption.is_empty():
		var text_width: float = rect.size.x-caption_offset.x-20.0
		var label := text(face,caption,Rect2(caption_offset+Vector2(10,0),Vector2(text_width,rect.size.y)),role,fit(caption,role,font_size,text_width),ON_DARK if is_dark else INK,HORIZONTAL_ALIGNMENT_CENTER)
		label.name = "Caption"
	button.resized.connect(func():
		plate.size = button.size/plate.scale
		face.size = button.size
		glint.size.y = button.size.y
		glint_mask.set_shader_parameter("rect_size",button.size)
		var label: Label = key_label(button)
		if label != null: label.size.x = maxf(0.0,button.size.x-caption_offset.x-20.0)
	)
	var motion := OfficeKeyMotion.new()
	motion.name = "OfficeKeyMotion"
	motion.button = button; motion.plate = plate; motion.face = face; motion.base = tint; motion.glint = glint
	button.add_child(motion)
	button.set_meta("office_key_style",style)
	return button

class OfficeKeyMotion extends Node:
	var button: Button
	var plate: NinePatchRect
	var face: Control
	var glint: TextureRect
	var base := Color.WHITE
	var clock := 0.0
	var _hover: Tween
	var _press: Tween
	var _sweep: Tween
	var _focused := true
	var _disabled := false
	var _capture_hover := -1

	func _ready() -> void:
		plate.self_modulate = base
		button.mouse_entered.connect(_hover_changed)
		button.mouse_exited.connect(_hover_changed)
		button.focus_entered.connect(_hover_changed)
		button.focus_exited.connect(_hover_changed)
		button.button_down.connect(func(): _pressed(true))
		button.button_up.connect(func(): _pressed(false))
		button.visibility_changed.connect(func(): if not button.is_visible_in_tree(): _reset())
		button.draw.connect(_state)
		_state()

	func _hover_changed() -> void:
		if (not _focused and _capture_hover < 0) or button.disabled: return
		if _hover != null and _hover.is_valid(): _hover.kill()
		var highlight: bool = _capture_hover == 1 if _capture_hover >= 0 else button.is_hovered() or button.has_focus()
		var target: Color = base*1.055 if highlight else base
		target.a = 1.0
		_hover = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_parallel(true)
		_hover.tween_property(plate,"self_modulate",target,0.18)
		_hover.tween_property(face,"self_modulate",Color(1.025,1.025,1.025) if highlight else Color.WHITE,0.18)
		if highlight: _start_sweep()
		else: _stop_sweep()

	func set_hover_for_capture(enabled: bool) -> void:
		if not OS.get_cmdline_user_args().has("--ui-preview"): return
		_capture_hover = 1 if enabled else 0
		_hover_changed()

	func _pressed(active: bool) -> void:
		if not _focused or button.disabled: return
		if _press != null and _press.is_valid(): _press.kill()
		_press = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_parallel(true)
		_press.tween_property(face,"position:y",1.5 if active else 0.0,0.08)
		_press.tween_property(plate,"position:y",1.5 if active else 0.0,0.08)
		if active: _start_sweep()

	func _start_sweep() -> void:
		_stop_sweep()
		glint.show()
		_sweep = create_tween()
		_sweep.tween_method(_move_glint,-glint.size.x,button.size.x+glint.size.x,0.5)
		_sweep.tween_callback(func(): glint.hide())

	func _move_glint(x: float) -> void:
		glint.position.x = x
		(glint.material as ShaderMaterial).set_shader_parameter("label_offset",glint.position)

	func _stop_sweep() -> void:
		if _sweep != null and _sweep.is_valid(): _sweep.kill()
		if is_instance_valid(glint): glint.hide()

	func _state() -> void:
		if _disabled == button.disabled: return
		_disabled = button.disabled
		_reset()

	func _reset() -> void:
		if _hover != null and _hover.is_valid(): _hover.kill()
		if _press != null and _press.is_valid(): _press.kill()
		_stop_sweep()
		plate.self_modulate = base
		plate.self_modulate.a = 0.48 if button.disabled else 1.0
		face.self_modulate = Color.WHITE
		face.modulate.a = 0.56 if button.disabled else 1.0
		face.position.y = 0.0; plate.position.y = 0.0

	func advance_for_capture(delta: float) -> void:
		clock += delta

	func _notification(what: int) -> void:
		if not is_instance_valid(button): return
		if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
			_focused = false; _reset()
		elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN,NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
			_focused = true; _reset()

	func _exit_tree() -> void:
		if _hover != null and _hover.is_valid(): _hover.kill()
		if _press != null and _press.is_valid(): _press.kill()
		if _sweep != null and _sweep.is_valid(): _sweep.kill()

# A sheet of plain office paper with a shadow. Returns a Control laid over the paper for content.
static func paper(parent: Node, rect: Rect2, node_name: String = "DeskPaper") -> Control:
	shadow(parent,rect.grow(-4),7.0,0.36)
	var holder := Control.new()
	holder.name = node_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	nine(holder,OFFICE+"paper_plain.png",Rect2(Vector2.ZERO,rect.size),Vector4(48,48,48,48),0.5).name = "PaperArt"
	return holder

# Open manila folder (tab at the top left). Content starts ~50px below the top.
static func folder(parent: Node, rect: Rect2, node_name: String = "DeskFolder") -> Control:
	shadow(parent,Rect2(rect.position+Vector2(8,24),rect.size-Vector2(16,28)),7.0,0.38)
	var holder := Control.new()
	holder.name = node_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	nine(holder,ART+"folder_open.png",Rect2(Vector2.ZERO,rect.size),Vector4(40,145,40,35),0.5).name = "FolderArt"
	return holder

# A chunky office key. The art has a thick bottom lip, so the caption is a Label centred on the
# key face above the lip (the Button's own text would centre on the 44px touch box and sink
# below the plate). Pressing swaps in the pressed art and lowers the face with it. Children
# that should sink with the key go into the "Face" node.
static func key(parent: Node, caption: String, rect: Rect2, action: Callable, style: String = "cream", font_size: int = 14, role: String = "control", caption_offset: Vector2 = Vector2.ZERO) -> Button:
	if presentation: return _presentation_key(parent,caption,rect,action,style,font_size,role,caption_offset)
	var spec: Dictionary = KEYS.get(style,KEYS.cream)
	var result := HeroImageSkin.button(parent,caption,rect,action,"plain",font_size)
	result.custom_minimum_size = Vector2(rect.size.x,maxf(rect.size.y,result.custom_minimum_size.y))
	result.autowrap_mode = TextServer.AUTOWRAP_OFF
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_hover_pressed_color"]:
		result.add_theme_color_override(state,Color(0,0,0,0))
	var lip := float(spec.lip)/float(spec.height)
	var plate_height := rect.size.y
	var key_shadow := shadow(result,Rect2(2,3,rect.size.x-4,plate_height-4),3.0,0.32)
	key_shadow.show_behind_parent = true
	var margin := float(spec.margin)
	var plate := nine(result,OFFICE+str(spec.file)+"_normal.png",Rect2(0,0,rect.size.x,plate_height),Vector4(margin,margin,margin,margin),plate_height/float(spec.height))
	plate.name = "Plate"
	plate.show_behind_parent = true
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(face); HeroUI.place(face,Rect2(0,0,rect.size.x,plate_height*(1.0-lip)))
	if not caption.is_empty():
		var face_height := plate_height*(1.0-lip)
		var width := rect.size.x-caption_offset.x-8.0
		var label := text(face,caption,Rect2(caption_offset+Vector2(4,0),Vector2(width,face_height)),role,fit(caption,role,font_size,width),str(spec.ink),HORIZONTAL_ALIGNMENT_CENTER)
		label.name = "Caption"
	var normal: Texture2D = plate.texture
	var pressed: Texture2D = load(OFFICE+str(spec.file)+"_pressed.png")
	var sink := maxf(1.0,plate_height*lip*0.5)
	result.button_down.connect(func(): plate.texture = pressed; face.position.y = sink; key_shadow.modulate.a = 0.5)
	result.button_up.connect(func(): plate.texture = normal; face.position.y = 0.0; key_shadow.modulate.a = 1.0)
	result.mouse_entered.connect(func(): if not result.disabled: plate.modulate = Color(1.06,1.06,1.06))
	result.mouse_exited.connect(func(): plate.modulate = Color(1,1,1,plate.modulate.a))
	result.draw.connect(func():
		plate.modulate.a = 0.5 if result.disabled else 1.0
		face.modulate.a = 0.5 if result.disabled else 1.0
		key_shadow.visible = not result.disabled
	)
	return result

# Caption of a key, for screens that update it after building.
static func key_label(button: Button) -> Label:
	return button.get_node_or_null("Face/Caption") as Label

# Polaroid card (76x97) with a photo and the caption inside its bottom strip.
static func polaroid(parent: Node, texture: Texture2D, caption: String, selected: bool, action: Callable = Callable(), locked: bool = false) -> Button:
	var card := key(parent,"",Rect2(0,0,76,97),action,"row") if presentation else HeroImageSkin.button(parent,"",Rect2(0,0,76,97),action,"plain")
	card.custom_minimum_size = Vector2(76,97)
	card.size = Vector2(76,97)
	var face: Node = card.get_node("Face") if presentation else card
	if presentation: (card.get_node("Plate") as CanvasItem).hide()
	var card_shadow := shadow(face,Rect2(4,4,68,90),4.0,0.34)
	art(face,ART+("photo_frame_selected_tall.png" if selected else "photo_frame_tall.png"),Rect2(0,0,76,97)).name = "PolaroidFrame"
	var photo := Rect2(13,15,51,50) if selected else Rect2(12,11,53,53)
	if texture != null:
		var picture := HeroUI.fixed_art(face,texture,photo.grow(-2))
		picture.name = "PolaroidPhoto"
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if locked: picture.modulate = Color(0.35,0.37,0.42,0.75)
	if locked: art(face,OFFICE+"lock_overlay.png",photo).name = "PolaroidLock"
	text(face,caption,Rect2(5,68,66,22),"control",fit(caption,"control",12,66.0,9),MUTED if locked else INK,HORIZONTAL_ALIGNMENT_CENTER).name = "PolaroidCaption"
	if not presentation:
		card.button_down.connect(func(): card.modulate = Color(0.94,0.94,0.94); card_shadow.modulate.a = 0.5)
		card.button_up.connect(func(): card.modulate = Color.WHITE; card_shadow.modulate.a = 1.0)
	return card

# 한서아's sticky note, slightly askew.
static func postit(parent: Node, rect: Rect2, caption: String, color: String = "yellow", angle_degrees: float = -5.0) -> Control:
	var note := Control.new()
	note.name = "DeskNote"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(note); HeroUI.place(note,rect)
	note.pivot_offset = rect.size*0.5
	note.rotation = deg_to_rad(angle_degrees)
	shadow(note,Rect2(rect.size*Vector2(0.07,0.07),rect.size*Vector2(0.86,0.86)),5.0,0.3)
	art(note,ART+"postit_"+color+".png",Rect2(Vector2.ZERO,rect.size))
	text(note,caption,Rect2(rect.size*Vector2(0.12,0.24),rect.size*Vector2(0.76,0.52)),"brand",14,INK,HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER}).name = "DeskNoteText"
	return note

# Red rubber stamp, rotated.
static func stamp(parent: Node, caption: String, rect: Rect2, angle: float = -0.12) -> Control:
	var holder := Control.new()
	holder.name = "DeskStamp"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	holder.pivot_offset = rect.size*0.5
	holder.rotation = angle
	art(holder,ART+"stamp_round_red.png",Rect2(Vector2.ZERO,rect.size))
	var label := text(holder,caption,Rect2(Vector2.ZERO,rect.size),"brand",fit(caption,"brand",int(rect.size.y*0.32),rect.size.x*0.7,8),"#d23b3b",HORIZONTAL_ALIGNMENT_CENTER)
	label.modulate.a = 0.9
	return holder

# Coin/receipt chip: painted chip with an icon and a value.
static func chip(parent: Node, rect: Rect2, icon: Texture2D, value: String, node_name: String = "DeskChip") -> Label:
	var holder := Control.new()
	holder.name = node_name+"Chip"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	if presentation:
		_presentation_surface(holder,"glass_row.png",Rect2(Vector2.ZERO,rect.size),"row")
	else:
		shadow(holder,Rect2(4,3,rect.size.x-8,rect.size.y-6),3.0,0.3)
		nine(holder,OFFICE+"chip_currency.png",Rect2(Vector2.ZERO,rect.size),Vector4(56,20,56,20),rect.size.y/112.0)
	if icon != null:
		var icon_size := rect.size.y-14.0
		HeroUI.fixed_art(holder,icon,Rect2(14,7,icon_size,icon_size)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var label := text(holder,value,Rect2(rect.size.y+8,2,rect.size.x-rect.size.y-20,rect.size.y-6),"number",fit(value,"number",20,rect.size.x-rect.size.y-20),INK)
	label.name = node_name
	return label

# Painted progress bar (bar_frame + bar_fill). `ratio` 0..1.
static func bar(parent: Node, rect: Rect2, ratio: float) -> Control:
	var holder := Control.new()
	holder.name = "DeskBar"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	var bar_scale := rect.size.y/64.0
	nine(holder,OFFICE+"bar_frame.png",Rect2(Vector2.ZERO,rect.size),Vector4(24,16,24,16),bar_scale)
	var inset := Vector2(5,4)*rect.size.y/24.0
	var fill_width := maxf(0.0,(rect.size.x-inset.x*2.0)*clampf(ratio,0.0,1.0))
	if fill_width > rect.size.y*0.5:
		nine(holder,OFFICE+"bar_fill.png",Rect2(inset,Vector2(fill_width,rect.size.y-inset.y*2.0)),Vector4(20,12,20,12),(rect.size.y-inset.y*2.0)/64.0)
	return holder

# Warm paper-coloured scrollbar for desk scroll areas.
static func scrollbar(scroll: ScrollContainer) -> void:
	var v_bar := scroll.get_v_scroll_bar()
	v_bar.add_theme_stylebox_override("scroll",_bar_style(Color(0.14,0.22,0.36,0.12) if presentation else Color(0.47,0.38,0.26,0.16)))
	for state_name in ["grabber","grabber_highlight","grabber_pressed"]:
		v_bar.add_theme_stylebox_override(state_name,_bar_style(Color(accent(scroll)) if presentation else Color("#c9a77a")))

static func _bar_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(3)
	style.content_margin_left = 3.0; style.content_margin_right = 3.0
	return style
