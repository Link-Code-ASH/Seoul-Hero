class_name HeroMobileScreen
extends Control

const REFERENCE := Vector2(915,412)

func _init() -> void:
	size = REFERENCE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

static func safe_rect(viewport: Vector2) -> Rect2:
	var result := Rect2(Vector2.ZERO,viewport)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var window := Vector2(DisplayServer.window_get_size())
		if safe.size.x > 0 and safe.size.y > 0 and window.x > 0 and window.y > 0:
			result = Rect2(Vector2(safe.position)/window*viewport,Vector2(safe.size)/window*viewport)
	return result

func _fit() -> void:
	var viewport := get_viewport_rect().size
	var safe := safe_rect(viewport)
	var available := safe.size
	var origin := safe.position
	var factor := minf(available.x / REFERENCE.x,available.y / REFERENCE.y)
	scale = Vector2.ONE * factor
	position = origin + (available - REFERENCE * factor) * 0.5
	size = REFERENCE
	# The interactive canvas fits the safe region; artwork still fills the display.
	for child in get_children():
		if child is Control and child.has_meta("full_bleed"):
			child.set_anchors_preset(Control.PRESET_TOP_LEFT)
			child.position = -position / factor
			child.size = viewport / factor
