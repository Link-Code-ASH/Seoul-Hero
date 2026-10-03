class_name HeroGroundedVisual
extends Node2D

# Single-image monsters share four legless motions. Installed devices use their
# own grounded profile and do not receive the monster's squash or locomotion.
const LOCOMOTION = preload("res://shaders/enemy_locomotion.gdshader")
const INSTALLATION_GLOW = preload("res://shaders/installation_glow.gdshader")
const FIELD_FLOW = preload("res://shaders/field_flow.gdshader")
var sprite := Sprite2D.new()
var shadow := Sprite2D.new()
var _cast_shadow := Sprite2D.new()
var _aura: Array[Sprite2D] = []
var _texture: Texture2D
var _height := 60.0
var dead := false
var death_age := 0.0
var _elite := false
var _hp := 1.0
var _is_structure := false
var _motion: Dictionary = {}
var _material: ShaderMaterial
var _last_position := Vector2.ZERO
var _initialized := false
var _phase := 0.0
var _walk_amount := 0.0
var _hit_age := 0.0
var _hit_direction := Vector2.ZERO
var _attack_age := 0.0
var _warning := 0.0
var _facing := 1.0
var _installation: Dictionary = {}
var _installation_material: ShaderMaterial
var _field_materials: Array[ShaderMaterial] = []
var _structure_kind := ""

func _ready() -> void:
	add_child(_cast_shadow)
	_cast_shadow.texture = load("res://assets/visuals/vfx/contact_shadow.png")
	_cast_shadow.visible = false
	add_child(shadow)
	shadow.texture = load("res://assets/visuals/vfx/contact_shadow.png")
	for i in range(2):
		var layer := Sprite2D.new(); add_child(layer); _aura.append(layer)
	add_child(sprite)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func configure(id: String, is_structure: bool = false) -> void:
	_is_structure = is_structure; dead = false; death_age = 0
	_initialized = false; _phase = 0; _walk_amount = 0; _hit_age = 0; _attack_age = 0; _warning = 0; _facing = 1
	var data: Dictionary = Content.data.weapons[id].structure if is_structure else Content.data.enemies[id].visual
	var visual: Dictionary = Content.visuals.get("structures" if is_structure else "enemies",{}).get(id,{})
	_texture = Content.actor_texture(visual) if visual.get("rig","") in ["legless","grounded"] else Content.trimmed_texture(data.sprite)
	sprite.texture = _texture; visible = true; modulate = Color.WHITE
	sprite.centered = false; sprite.offset = Vector2(-_texture.get_width()*0.5,-_texture.get_height())
	_motion = Content.data.enemyPresentation.get(id,{}) if not is_structure else {}
	sprite.material = null; _material = null
	if not is_structure:
		_material = ShaderMaterial.new(); _material.shader = LOCOMOTION
		if _texture is AtlasTexture:
			_material.set_shader_parameter("region_origin",_texture.region.position/_texture.atlas.get_size())
			_material.set_shader_parameter("region_span",_texture.region.size/_texture.atlas.get_size())
		_material.set_shader_parameter("body_wave",float(_motion.get("bodyWave",0.0)))
		_material.set_shader_parameter("wing_motion",float(_motion.get("wingMotion",0.0)))
		sprite.material = _material
	for layer in _aura: layer.visible = false
	_cast_shadow.visible = false
	_installation = visual if is_structure else {}
	_structure_kind = str(data.get("kind","")) if is_structure else ""
	_installation_material = null; _field_materials.clear()
	if is_structure:
		_installation_material = ShaderMaterial.new(); _installation_material.shader = INSTALLATION_GLOW
		sprite.material = _installation_material
		_cast_shadow.visible = true
		if _structure_kind == "aura":
			for layer in _aura:
				layer.texture = Content.trimmed_texture(str(_installation.get("fieldSprite","manaFieldAura")))
				layer.visible = true
				var field_material := ShaderMaterial.new(); field_material.shader = FIELD_FLOW
				if layer.texture is AtlasTexture:
					field_material.set_shader_parameter("region_origin",layer.texture.region.position/layer.texture.atlas.get_size())
					field_material.set_shader_parameter("region_span",layer.texture.region.size/layer.texture.atlas.get_size())
				layer.material = field_material; _field_materials.append(field_material)

func update_state(state: Dictionary, dt: float, height: float) -> void:
	position = state.pos
	if _is_structure:
		_update_installation(state,height)
		return
	_height = height * float(_motion.get("displayScale",1.0))
	var delta := position-_last_position
	var speed := delta.length()/maxf(dt,0.001) if _initialized and dt > 0 else 0.0
	if not _initialized: _phase = float(state.get("id",0))*0.73
	if state.has("facing"): _facing = float(state.facing)
	elif _initialized and absf(delta.x) > 0.01: _facing = signf(delta.x)
	_last_position = position; _initialized = true
	_walk_amount = move_toward(_walk_amount,1.0 if speed > 2.0 else 0.0,dt*7.0)
	# Warnings settle the shape before the existing gameplay dash; faster movement
	# advances the same loop rather than selecting a separate per-enemy animation.
	var pace := clampf(speed/90.0,0.7,1.8)
	if state.get("action","") == "warning": pace = 0.5
	_phase += dt*float(_motion.get("frequency",3.0))*pace
	_hit_age = maxf(0,_hit_age-dt); _attack_age = maxf(0,_attack_age-dt)
	_warning = move_toward(_warning,1.0 if state.get("action","") == "warning" else 0.0,dt*8.0)
	var base := _height/_texture.get_height()
	var shape := Vector2.ONE
	var offset := Vector2.ZERO
	var lean := 0.0
	var beat := sin(_phase)
	var lift := 0.0
	if not _is_structure:
		var squash := float(_motion.get("squash",0.03))
		var bob := float(_motion.get("bob",4.0))*_height/60.0
		var sway := float(_motion.get("sway",0.5))*_height/60.0
		var activity := lerpf(0.2,1.0,_walk_amount)
		match _motion.get("mode","float"):
			"hop":
				# First half of a cycle is airborne, second half is a soft landing.
				var airborne := maxf(0.0,beat)
				var landing := maxf(0.0,-beat)
				lift = airborne*bob*activity
				var compression := landing*squash*activity
				shape = Vector2(1+compression-airborne*squash*.28,1-compression+airborne*squash*.32)
				offset.x = cos(_phase)*sway*_walk_amount
				lean = beat*float(_motion.get("roll",.012))*_walk_amount
			"fly":
				lift = bob*(1.0+(sin(_phase*.75)+1.0)*.45)
				offset.x = cos(_phase*.55)*sway
				shape = Vector2(1+beat*squash*.35,1-beat*squash*.35)
				lean = sin(_phase*.55)*float(_motion.get("roll",.02))
			"slither":
				lift = maxf(0.0,beat)*bob*_walk_amount
				offset.x = sin(_phase*.7)*sway*_walk_amount
				shape = Vector2(1+beat*squash*activity,1-beat*squash*.55*activity)
				lean = sin(_phase*.7)*float(_motion.get("roll",.015))*activity
			_: # float and bossFloat share the same buoyant body rhythm.
				lift = bob*(.6+(beat+1.0)*.5)
				offset.x = cos(_phase*.7)*sway
				shape = Vector2(1+beat*squash,1-beat*squash)
				lean = beat*float(_motion.get("roll",.012))
		# Mild common idle breathing keeps every design alive without walking joints.
		shape.y *= 1.0+sin(_phase*.6)*0.009
		shape *= Vector2(1+_warning*.13,1-_warning*.12)
		lift *= 1.0-_warning*.55
		if state.get("action","") == "dash":
			shape *= Vector2(1.16,.88); lean -= _facing*.06
		var attack := sin(clampf(_attack_age/.22,0,1)*PI)
		shape *= Vector2(1+attack*.075,1-attack*.06)
		offset.x += _facing*attack*_height*.025
		lean -= _facing*attack*.035
		offset += _hit_direction*sin(clampf(_hit_age/.14,0,1)*PI)*3.5
		_material.set_shader_parameter("phase",_phase)
		_material.set_shader_parameter("walk_amount",_walk_amount)
		_material.set_shader_parameter("hit_flash",1.0 if _hit_age > 0 or state.get("flash",0)>0 else 0.0)
	offset.y -= lift
	sprite.scale = Vector2(base*_facing,base)*shape
	sprite.position = offset; sprite.rotation = lean
	sprite.modulate = Color(1,.80,.75).lerp(Color.WHITE,1-_warning) if not _is_structure else Color(.92,.96,1)
	sprite.modulate.a = state.get("alpha",1.0)
	var hover := clampf(lift/maxf(_height*.3,1),0,.45)
	shadow.scale = Vector2(_height*.57*(1-hover),_height*.17*(1-hover*.5))/shadow.texture.get_size()
	shadow.modulate.a = float(_motion.get("shadowAlpha",.7))*(1-hover*.65)*float(state.get("alpha",1.0))
	if dead:
		death_age += dt
		var fade := clampf(death_age/.36,0,1)
		sprite.scale *= Vector2(1+fade*.16,1-fade*.75)
		sprite.position.y *= 1-fade; sprite.rotation += _facing*fade*.12
		sprite.modulate.a *= 1-fade; shadow.modulate.a *= 1-fade
		if _material != null: _material.set_shader_parameter("walk_amount",0.0)
	_hp = state.get("hp",1.0)/maxf(1,state.get("maxHp",1.0)); _elite = state.get("elite",false) or state.get("boss",false)
	queue_redraw()

func _update_installation(state: Dictionary, height: float) -> void:
	# Art is a low device in a three-quarter view. Its reviewed ground footprint
	# anchors to the placement point; the nearer feet extend naturally below it.
	_height = float(_installation.get("height",height))
	var age: float = maxf(0.0,float(state.get("age",0.0)))
	var appearance := smoothstep(0.0,0.35,age)
	var opacity := float(state.get("alpha",1.0))
	var base := _height/_texture.get_height()
	var anchor: Array = _installation.get("groundAnchor",[.5,1.0])
	sprite.offset = -_texture.get_size()*Vector2(anchor[0],anchor[1])
	sprite.scale = Vector2.ONE*base; sprite.position = Vector2.ZERO; sprite.rotation = 0.0
	sprite.modulate = Color(1,1,1,opacity)
	_installation_material.set_shader_parameter("pulse",sin(age*float(_installation.get("glowFrequency",1.7)))*0.5+0.5)
	var contact: Array = _installation.get("contactShadow",[_height*1.3,_height*.36])
	var cast: Array = _installation.get("castShadow",[_height*1.5,_height*.44])
	var cast_offset: Array = _installation.get("shadowOffset",[_height*.18,2.0])
	shadow.position = Vector2(0,-1)
	shadow.scale = Vector2(contact[0],contact[1])/shadow.texture.get_size()
	shadow.modulate = Color(.23,.30,.38,.80*opacity)
	_cast_shadow.position = Vector2(cast_offset[0],cast_offset[1])
	_cast_shadow.scale = Vector2(cast[0],cast[1])/_cast_shadow.texture.get_size()
	_cast_shadow.modulate = Color(.30,.37,.44,.36*opacity)
	if _structure_kind == "aura":
		var radius := float(state.get("visualRadius",130.0))
		var projection := float(_installation.get("fieldProjection",.60))
		var period := maxf(3.0,float(_installation.get("spreadPeriod",4.8)))
		var tint: Array = _installation.get("fieldTint",[.78,.90,1.0])
		var field_opacity := float(_installation.get("fieldOpacity",.13))
		var wave_opacity := float(_installation.get("fieldWaveOpacity",.16))
		for i in range(_aura.size()):
			var layer := _aura[i]
			var phase := fposmod(age/period+float(i)*.5,1.0)
			var spread := lerpf(.76,1.0,smoothstep(0.0,1.0,phase))
			# Each wave fades at both ends before restarting. UV flow is slow inside
			# the fixed ground ellipse, so there is no rapidly spinning upright disc.
			var envelope := sin(phase*PI)
			layer.position = Vector2.ZERO; layer.rotation = 0.0
			layer.scale = Vector2(radius*2.0*spread,radius*2.0*spread*projection)/layer.texture.get_size()
			layer.modulate = Color(tint[0],tint[1],tint[2],(field_opacity+envelope*wave_opacity)*appearance*opacity)
			_field_materials[i].set_shader_parameter("flow_angle",age*float(_installation.get("flowSpeed",.035))*(1.0 if i == 0 else -.65))
	_elite = false
	queue_redraw()

func action(kind: String, payload: Dictionary) -> void:
	match kind:
		"actorDeath": dead = true; death_age = 0
		"actorHit": _hit_age = .14; _hit_direction = payload.get("direction",Vector2.RIGHT)
		"actorAttack": _attack_age = .22

func socket_offset(_socket: String = "muzzle") -> Vector2:
	return sprite.transform*Vector2(0,-_texture.get_height()*.48)

func visual_bounds() -> Rect2:
	return sprite.transform*sprite.get_rect()

func _draw() -> void:
	if not _elite: return
	var width := _height*.6
	draw_line(Vector2(-width/2,-_height-8),Vector2(width/2,-_height-8),Color(.08,.11,.14,.8),4)
	draw_line(Vector2(-width/2,-_height-8),Vector2(-width/2+width*_hp,-_height-8),Color(.94,.72,.28),3)
