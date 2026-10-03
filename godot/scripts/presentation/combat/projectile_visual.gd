class_name HeroProjectileVisual
extends Node2D

var _core := Sprite2D.new()
var _trail: Array[Sprite2D] = []
var _samples: Array[Vector2] = []
var _previous := Vector2.ZERO
var _distance := 0.0
var _initialized := false

func _ready() -> void:
	for i in range(5):
		var sprite := Sprite2D.new(); add_child(sprite); _trail.append(sprite)
	add_child(_core)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func configure(texture: Texture2D, diameter: Vector2) -> void:
	_core.texture = texture
	_core.scale = diameter / texture.get_size()
	for sprite in _trail:
		sprite.texture = texture; sprite.scale = _core.scale*Vector2(0.65,0.55); sprite.visible = false
	_samples.clear(); _distance = 0; _initialized = false; visible = true

func update_state(point: Vector2, angle: float, dt: float) -> void:
	position = point; _core.rotation = angle
	if not _initialized:
		_previous = point; _initialized = true
	_distance += point.distance_to(_previous)
	if _distance >= 7.0 and dt > 0:
		_samples.push_front(_previous); _distance = 0
		if _samples.size() > _trail.size(): _samples.pop_back()
	_previous = point
	for i in range(_trail.size()):
		var sprite := _trail[i]
		sprite.visible = i < _samples.size()
		if not sprite.visible: continue
		sprite.position = _samples[i]-point; sprite.rotation = angle
		sprite.modulate = Color(0.7,0.87,1,(1.0-i/float(_trail.size()))*0.2)
