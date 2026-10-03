class_name HeroMovement
extends Control

var direction := Vector2.ZERO
var origin := Vector2.ZERO
var current := Vector2.ZERO
var finger := -1
var active := false
var touch_radius := 52.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventScreenTouch:
		if event.pressed and finger < 0 and not _over_ui(event.position):
			finger = event.index; origin = event.position; current = origin; direction = Vector2.ZERO
		elif not event.pressed and event.index == finger: reset()
	elif event is InputEventScreenDrag and event.index == finger:
		current = event.position
		var delta := current - origin
		if delta.length() > touch_radius: origin = current - delta.normalized() * touch_radius
		direction = (current - origin) / touch_radius
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and finger < 0 and not _over_ui(event.position): finger = -2; origin = event.position; current = origin
		elif not event.pressed and finger == -2: reset()
	elif event is InputEventMouseMotion and finger == -2:
		current = event.position
		var delta := current - origin
		if delta.length() > touch_radius: origin = current - delta.normalized() * touch_radius
		direction = (current - origin) / touch_radius
	queue_redraw()

func _over_ui(position: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("input_blocker"):
		if node is Control and node.is_visible_in_tree() and node.get_global_rect().has_point(position): return true
	return false

func vector() -> Vector2:
	if not active: return Vector2.ZERO
	var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	return (keys if keys.length_squared() > 0 else direction).limit_length(1.0)

func reset() -> void:
	finger = -1; direction = Vector2.ZERO; queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED: reset()

func _draw() -> void:
	if finger == -1 or not active: return
	draw_circle(origin, touch_radius, Color(0.45,0.67,0.75,0.16))
	draw_arc(origin, touch_radius, 0, TAU, 64, Color(0.7,0.87,0.9,0.45), 1.4, true)
	draw_circle(origin + direction * touch_radius, 18, Color(0.66,0.85,0.88,0.5))
