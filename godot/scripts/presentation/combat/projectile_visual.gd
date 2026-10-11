class_name HeroProjectileVisual
extends Node2D

# Pooled projectiles retain one continuous ribbon rather than body copies.
const TRAIL_SHADER = preload("res://shaders/projectile_trail.gdshader")
const MAX_POINTS := 8
var _core := Sprite2D.new()
var _halo := Sprite2D.new()
var _ribbon := Polygon2D.new()
var _samples: Array[Dictionary] = []
var _previous := Vector2.ZERO
var _age := 0.0
var _initialized := false
var _color := Color("71e7e0")
var _width := 4.0
var _lifetime := 0.13

func _ready() -> void:
	var white := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color.WHITE])
	white.gradient = gradient; white.width = 64; white.height = 16
	_ribbon.texture = white
	var material := ShaderMaterial.new(); material.shader = TRAIL_SHADER
	_ribbon.material = material
	add_child(_ribbon)
	var glow := GradientTexture2D.new()
	var glow_gradient := Gradient.new()
	glow_gradient.colors = PackedColorArray([Color(1,1,1,0.7),Color(1,1,1,0)])
	glow.gradient = glow_gradient; glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5,0.5); glow.fill_to = Vector2(0.5,1.0)
	glow.width = 32; glow.height = 32; _halo.texture = glow
	add_child(_halo); add_child(_core)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func configure(texture: Texture2D, diameter: Vector2, profile: Dictionary = {}) -> void:
	_core.texture = texture
	_core.scale = diameter / texture.get_size()
	_color = Color(str(profile.get("trailColor","#71e7e0")))
	_width = float(profile.get("trailWidth",4.0))
	_lifetime = maxf(0.025,float(profile.get("trailLifetime",0.13)))
	_halo.scale = diameter*1.65/32.0
	_halo.modulate = Color(_color,float(profile.get("halo",0.22)))
	reset(); visible = true

func reset() -> void:
	_samples.clear(); _age = 0; _initialized = false
	_ribbon.polygon = PackedVector2Array(); visible = false

func update_state(point: Vector2, angle: float, dt: float) -> void:
	position = point; _core.rotation = angle; _halo.rotation = angle
	if not _initialized:
		_previous = point; _initialized = true
		_samples.append({"point":point,"age":_age})
	if dt > 0:
		_age += dt
		var distance := point.distance_to(_previous)
		if distance > 300: _samples.clear()
		elif distance > 0.2:
			var steps := clampi(int(ceil(distance/7.0)),1,MAX_POINTS-1)
			for step in range(1,steps+1):
				var fraction := step/float(steps)
				_samples.push_front({"point":_previous.lerp(point,fraction),"age":_age-dt*(1.0-fraction)})
				if _samples.size()>MAX_POINTS: _samples.pop_back()
		for index in range(_samples.size()-1,-1,-1):
			if _age-float(_samples[index].age) >= _lifetime: _samples.remove_at(index)
		_previous = point
	_update_ribbon(point)

func _update_ribbon(point: Vector2) -> void:
	var count := _samples.size()
	if count < 2:
		_ribbon.polygon = PackedVector2Array(); return
	var polygon := PackedVector2Array(); var uv := PackedVector2Array()
	var colors := PackedColorArray()
	polygon.resize(count*2); uv.resize(count*2); colors.resize(count*2)
	for index in range(count):
		var sample: Dictionary = _samples[index]
		var head: Vector2 = point if index == 0 else _samples[index-1].point
		var tail: Vector2 = sample.point if index == count-1 else _samples[index+1].point
		var tangent := (head-tail).normalized()
		if tangent.is_zero_approx(): tangent = Vector2.RIGHT
		var freshness := clampf(1.0-(_age-float(sample.age))/_lifetime,0,1)
		var taper := pow(freshness,0.7)* (1.0-index/float(count)*0.7)
		var normal := Vector2(-tangent.y,tangent.x)*_width*taper*0.5
		var local: Vector2 = sample.point-point
		polygon[index] = local+normal; polygon[count*2-1-index] = local-normal
		uv[index] = Vector2(index/float(count-1)*64,0)
		uv[count*2-1-index] = Vector2(index/float(count-1)*64,16)
		colors[index] = Color(_color,freshness*0.72)
		colors[count*2-1-index] = colors[index]
	_ribbon.polygon = polygon; _ribbon.uv = uv; _ribbon.vertex_colors = colors
