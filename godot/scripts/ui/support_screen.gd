class_name HeroSupportScreen
extends HeroMobileScreen

# Approved support surfaces and layout shared by the two independent screens.
# Reward mutation stays in main/meta rules; this class only owns presentation.
const PANEL := Rect2(564,88,328,298)
var kind := ""
var state := "ready"
var go: Callable
var act: Callable
var presentation: HeroSupportPresentation
var _info: Control
var _requesting := false
var _labels: Array[Label] = []
var _missing: Array[String] = []
var capture_clock := false:
	set(value):
		capture_clock = value
		if is_instance_valid(presentation): presentation.capture_clock = value

func _ready() -> void:
	super._ready()
	theme = HeroImageSkin.theme()
	set_meta("hero_ui_palette","image_skin")
	set_meta("approved_image_skin",true)
	var background_id := "supportRecoveryBackground" if kind == "recovery" else "supportSupplyBackground"
	var background := HeroUI.background(self,background_id)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if background.texture == null: _missing.append(background_id)
	var header := HeroImageSkin.header(self,"회수" if kind == "recovery" else "보급",func():
		if is_instance_valid(presentation): presentation.cancel()
		if go.is_valid(): go.call("lobby")
	)
	var back := header.find_child("HeaderBack",true,false) as Button
	if back != null: back.name = "SupportBack"
	presentation = HeroSupportPresentation.new()
	presentation.kind = kind
	presentation.capture_clock = capture_clock
	presentation.size = REFERENCE
	add_child(presentation)
	build_info()

func build_info() -> void:
	pass

func info_panel() -> Control:
	if is_instance_valid(_info):
		_info.hide()
		_info.queue_free()
	_info = Control.new()
	_info.size = REFERENCE
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	HeroImageSkin.material(_info,"support/panel",PANEL)
	return _info

func copy(parent: Node, caption: String, rect: Rect2, role: String = "body", font_size: int = 14, color_role: String = "ink", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var result := HeroImageSkin.text(parent,caption,rect,role,font_size,color_role,align,wrap,{"valign":VERTICAL_ALIGNMENT_CENTER})
	_labels.append(result)
	return result

func heading(parent: Node, caption: String, rect: Rect2, font_size: int = 18) -> Label:
	return copy(parent,caption,rect,"heading",font_size)

func art(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var result := HeroUI.image(parent,texture,0,0)
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	HeroUI.place(result,rect)
	return result

func button(parent: Node, caption: String, rect: Rect2, action: Callable, font_size: int = 16, primary: bool = false) -> Button:
	return HeroImageSkin.image_button(parent,caption,rect,action,"ops/primary" if primary else "ops/secondary",font_size)

func is_busy() -> bool:
	return is_instance_valid(presentation) and presentation.is_busy()

func advance_for_capture(dt: float) -> void:
	presentation.advance(dt)

func _notification(what: int) -> void:
	if not is_instance_valid(presentation): return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]: presentation.suspend(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]: presentation.suspend(false)

func _exit_tree() -> void:
	if is_instance_valid(presentation): presentation.cancel()

func diagnostics() -> Dictionary:
	var issues: Array = []
	for label in _labels:
		if not is_instance_valid(label) or not label.is_visible_in_tree(): continue
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var height := label.get_line_count()*font.get_height(font_size)+maxi(0,label.get_line_count()-1)*2
		var width := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		if height > label.size.y+1 or (label.autowrap_mode == TextServer.AUTOWRAP_OFF and width > label.size.x+1):
			issues.append({"text":label.text,"size":[label.size.x,label.size.y],"required":[width,height]})
	var missing := _missing.duplicate()
	if is_instance_valid(presentation): missing.append_array(presentation.missing_art)
	return {"kind":kind,"state":state,"size":[915,412],"fitIssues":issues,"missingArt":missing,"runtimeConnected":true,"saveWrites":Profile.writable,"presentation":presentation.snapshot() if is_instance_valid(presentation) else {}}
