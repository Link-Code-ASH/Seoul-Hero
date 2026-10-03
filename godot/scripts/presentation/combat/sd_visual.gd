class_name HeroSDVisual
extends Node2D

# One empty-handed PNG, shared silhouette motion. No bones or weapon-specific poses.
const SHARED_MOTION = preload("res://shaders/sd_feet.gdshader")
var profile: Dictionary = {}
var actor_id := ""
var dead := false
var death_age := 0.0
var sprite := Sprite2D.new()
var shadow := Sprite2D.new()
var _material: ShaderMaterial
var _texture: Texture2D
var _last_position := Vector2.ZERO
var _initialized := false
var _phase := 0.0
var _walk := 0.0
var _facing := 1.0
var _hit_age := 0.0
var _hit_direction := Vector2.ZERO
var _attack_age := 0.0
var _height := 86.4

func _ready() -> void:
	add_child(shadow); add_child(sprite)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shadow.texture = load("res://assets/visuals/vfx/contact_shadow.png")

func configure(id: String, visual: Dictionary) -> void:
	actor_id = id; profile = visual; dead = false; death_age = 0
	_initialized = false; _phase = 0; _walk = 0; _facing = 1
	_hit_age = 0; _attack_age = 0; _hit_direction = Vector2.ZERO
	_texture = Content.actor_texture(profile)
	sprite.texture = _texture
	sprite.centered = false
	sprite.offset = Vector2(-_texture.get_width()*0.5,-_texture.get_height())
	_material = ShaderMaterial.new(); _material.shader = SHARED_MOTION
	if _texture is AtlasTexture:
		_material.set_shader_parameter("region_origin",_texture.region.position/_texture.atlas.get_size())
		_material.set_shader_parameter("region_span",_texture.region.size/_texture.atlas.get_size())
	_material.set_shader_parameter("feet_top",float(profile.get("feetTop",0.83)))
	_material.set_shader_parameter("foot_lift",float(profile.get("footLift",0.03)))
	_material.set_shader_parameter("hand_motion",float(profile.get("handMotion",0.016)))
	var hands: Array = profile.get("handRegions",[[0.16,0.69,0.24,0.22],[0.64,0.70,0.24,0.21]])
	for i in range(2):
		var rect: Array = hands[i]
		_material.set_shader_parameter("hand_left" if i == 0 else "hand_right",Vector4(rect[0],rect[1],rect[2],rect[3]))
	sprite.material = _material
	visible = true; modulate = Color.WHITE
	sprite.modulate = Color.WHITE; sprite.rotation = 0; sprite.position = Vector2.ZERO

func update_state(state: Dictionary, dt: float, height: float) -> void:
	position = state.get("pos",position)
	if float(state.get("hp",1.0)) <= 0 and not dead: action("actorDeath",{})
	_height = height*float(profile.get("displayScale",0.8))
	var displacement := position-_last_position if _initialized else Vector2.ZERO
	_last_position = position; _initialized = true
	var speed := displacement.length()/dt if dt > 0 else 0.0
	if state.has("facing") and absf(float(state.facing)) > 0.01:
		_facing = signf(float(state.facing))
	if dt > 0:
		var moving: bool = speed > 2.0 and state.get("action","move") != "idle" and not dead
		_walk = move_toward(_walk,1.0 if moving else 0.0,dt*12)
		# Vertical travel keeps the last horizontal facing; effects aim separately.
		if not state.has("facing") and moving and absf(displacement.x) > absf(displacement.y)*0.25:
			_facing = signf(displacement.x)
		_phase += dt*TAU*float(profile.get("cadence",2.2))*clampf(speed/185.0,0.55,1.5)*_walk
		_hit_age = maxf(0,_hit_age-dt); _attack_age = maxf(0,_attack_age-dt)
	var beat := sin(_phase)
	var bounce := absf(beat)*float(profile.get("bounce",2.2))*_walk
	var breath := sin(float(state.get("age",0))*2.4)*0.004*(1-_walk)
	var reaction := sin(_attack_age/0.12*PI)
	var shape := Vector2(1+reaction*0.035,1+breath-reaction*0.025)
	var base := _height/_texture.get_height()
	sprite.scale = Vector2(base*_facing,base)*shape
	sprite.rotation = beat*0.025*_walk
	sprite.position = Vector2(0,-bounce-reaction*0.7)+_hit_direction*sin(_hit_age/0.16*PI)*2.0
	_material.set_shader_parameter("phase",_phase)
	_material.set_shader_parameter("idle_phase",float(state.get("age",0))*2.4)
	_material.set_shader_parameter("walk_amount",_walk)
	_material.set_shader_parameter("limb_amount",1.0 if not dead else 0.0)
	_material.set_shader_parameter("hit_flash",sin(_hit_age/0.16*PI)*0.7)
	var shadow_size: Array = profile.get("shadow",[48,14])
	var visual_scale := _height/float(profile.get("height",98))
	shadow.scale = Vector2(shadow_size[0],shadow_size[1])*visual_scale/shadow.texture.get_size()
	shadow.modulate.a = 0.58-bounce*0.025
	sprite.modulate = Color.WHITE
	if dead:
		death_age += dt
		var fade := clampf(death_age/0.42,0,1)
		sprite.scale *= Vector2(1+fade*0.15,1-fade*0.55)
		sprite.rotation = _facing*fade*0.3
		sprite.position = Vector2.ZERO
		sprite.modulate.a = 1-fade; shadow.modulate.a *= 1-fade
		_material.set_shader_parameter("walk_amount",0.0)

func action(kind: String, payload: Dictionary) -> void:
	match kind:
		"actorAttack":
			if not dead: _attack_age = 0.12
		"actorHit":
			if not dead:
				_hit_age = 0.16
				_hit_direction = payload.get("direction",Vector2.RIGHT).normalized()
		"actorDeath":
			dead = true; death_age = 0; _attack_age = 0; _hit_age = 0

func socket_offset(socket: String = "impact") -> Vector2:
	var anchor: Array = profile.get("sockets",{}).get(socket,[0,-0.45])
	return sprite.transform*Vector2(float(anchor[0])*_texture.get_width(),float(anchor[1])*_texture.get_height())

func visual_bounds() -> Rect2:
	return sprite.transform*sprite.get_rect()
