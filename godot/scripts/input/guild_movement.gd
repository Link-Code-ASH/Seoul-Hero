class_name HeroGuildMovement
extends Control

signal tapped(position: Vector2)
signal interaction

const TAP_DISTANCE := 8.0
const TOUCH_RADIUS := 52.0
const NO_POINTER := -1
const MOUSE_POINTER := -2

var active: bool = false:
	set(value):
		active = value
		if not value:
			reset()

var _surface: Control
var _finger: int = NO_POINTER
var _start: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO
var _dragging: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(surface: Control) -> void:
	reset()
	_surface = surface

func vector() -> Vector2:
	if not active:
		return Vector2.ZERO
	var left: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right: bool = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	if left or right or up or down:
		return Vector2(float(right) - float(left), float(down) - float(up)).limit_length(1.0)
	return _direction

func reset() -> void:
	_finger = NO_POINTER
	_direction = Vector2.ZERO
	_dragging = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		if event.index == _finger and event.canceled:
			reset()
		elif event.pressed:
			_begin(event.index, event.position)
		elif event.index == _finger:
			_release(event.position)
	elif event is InputEventScreenDrag and event.index == _finger:
		_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed:
			_begin(MOUSE_POINTER, event.position)
		elif _finger == MOUSE_POINTER:
			_release(event.position)
	elif event is InputEventMouseMotion and _finger == MOUSE_POINTER:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_move(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			interaction.emit()

func _begin(pointer: int, point: Vector2) -> void:
	if _finger != NO_POINTER or not _inside_surface(point) or _over_ui(point):
		return
	_finger = pointer
	_start = point
	_origin = point
	_current = point
	_direction = Vector2.ZERO
	_dragging = false

func _move(point: Vector2) -> void:
	_current = point
	if not _dragging and (_current - _start).length() >= TAP_DISTANCE * _surface_scale():
		_dragging = true
	if _dragging:
		var radius: float = TOUCH_RADIUS * _surface_scale()
		var delta: Vector2 = _current - _origin
		if delta.length() > radius:
			_origin = _current - delta.normalized() * radius
		_direction = ((_current - _origin) / radius).limit_length(1.0)
	queue_redraw()

func _release(point: Vector2) -> void:
	var is_tap: bool = not _dragging and (point - _start).length() < TAP_DISTANCE * _surface_scale()
	reset()
	if is_tap and _inside_surface(point) and not _over_ui(point):
		tapped.emit(point)

func _inside_surface(point: Vector2) -> bool:
	if not is_instance_valid(_surface) or not _surface.is_visible_in_tree():
		return false
	var local_point: Vector2 = _surface.get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, _surface.size).has_point(local_point)

func _surface_scale() -> float:
	if not is_instance_valid(_surface):
		return 1.0
	var transform: Transform2D = _surface.get_global_transform_with_canvas()
	return maxf(0.001, minf(transform.x.length(), transform.y.length()))

func _over_ui(point: Vector2) -> bool:
	for node: Node in get_tree().get_nodes_in_group("input_blocker"):
		if node is Control and node.is_visible_in_tree():
			var local_point: Vector2 = node.get_global_transform_with_canvas().affine_inverse() * point
			if Rect2(Vector2.ZERO, node.size).has_point(local_point):
				return true
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()

func _draw() -> void:
	if not active or not _dragging or _finger == NO_POINTER:
		return
	var transform: Transform2D = get_global_transform_with_canvas()
	var origin: Vector2 = transform.affine_inverse() * _origin
	var radius: float = TOUCH_RADIUS * _surface_scale() / maxf(0.001, transform.x.length())
	draw_circle(origin, radius, Color(0.45, 0.67, 0.75, 0.16))
	draw_arc(origin, radius, 0, TAU, 64, Color(0.7, 0.87, 0.9, 0.45), 1.4, true)
	draw_circle(origin + _direction * radius, radius * 18.0 / TOUCH_RADIUS, Color(0.66, 0.85, 0.88, 0.5))
