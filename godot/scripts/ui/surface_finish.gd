class_name HeroSurfaceFinish
extends Control

var palette_id := "light"
var _finish: ShaderMaterial
var _hover: Tween

# A rounded rim, lower bevel and broad gloss make a solid enamel game control.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.14,0.48,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.21),Color(1,1,1,0.10),Color(1,1,1,0.012),Color(0.1,0.21,0.31,0.12)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient; texture.width = 8; texture.height = 64
	texture.fill_from = Vector2(0.5,0); texture.fill_to = Vector2(0.5,1)
	var layer := TextureRect.new(); layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finish = ShaderMaterial.new(); _finish.shader = load("res://shaders/ui_finish.gdshader")
	layer.material = _finish; add_child(layer)
	resized.connect(_resize); _resize()
	if get_parent() is Container:
		get_parent().sort_children.connect(func(): _fill_frame.call_deferred())
		_fill_frame.call_deferred()
	if get_parent() is Button:
		get_parent().mouse_entered.connect(func(): _shine(1.0))
		get_parent().mouse_exited.connect(func(): _shine(0.0))
		get_parent().button_down.connect(func(): _shine(0.35))
		get_parent().button_up.connect(func(): _shine(0.0))

func _fill_frame() -> void:
	# PanelContainer otherwise lays this decorative layer inside content padding.
	position = Vector2.ZERO
	size = get_parent().size

func _resize() -> void:
	_finish.set_shader_parameter("surface_size",size)
	var surface_parent := get_parent() as Control
	var style := surface_parent.get_theme_stylebox("normal" if surface_parent is Button else "panel") as StyleBoxFlat
	if style != null: _finish.set_shader_parameter("corner_radius",float(style.corner_radius_top_left))
	queue_redraw()

func _shine(value: float) -> void:
	if is_instance_valid(_hover): _hover.kill()
	_hover = create_tween()
	_hover.tween_method(func(amount: float): _finish.set_shader_parameter("shine",amount),float(_finish.get_shader_parameter("shine")),value,0.12)

func _draw() -> void:
	if size.x < 12 or size.y < 12: return
	draw_line(Vector2(17,3),Vector2(size.x-17,3),Color(1,1,1,0.64),1)
	draw_line(Vector2(17,size.y-5),Vector2(size.x-17,size.y-5),Color(0.12,0.23,0.33,0.27),2)
