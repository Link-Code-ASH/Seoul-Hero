class_name HeroTimedVfx
extends Node2D

const SLASH_SHADER = preload("res://shaders/slash_sweep.gdshader")
const CHAIN_SHADER = preload("res://shaders/chain_link.gdshader")
const PULSE_SHADER = preload("res://shaders/effect_pulse.gdshader")
const MAX_PARTICLES := 12
var age := 0.0
var duration := 0.3
var finished := false
var _kind := ""
var _radius := 20.0
var _arc := 1.0472
var _angle := 0.0
var _target := Vector2.ZERO
var _origin := Vector2.ZERO
var _preset: Dictionary = {}
var _layers: Array = []
var _sprites: Array[Sprite2D] = []
var _materials: Array[Dictionary] = []
var _procedural_slots: Array[Dictionary] = []
var _used := 0
var _main_material: ShaderMaterial
var _canvas: GradientTexture2D
var _tint := Color.WHITE
var _particle_sprites: Array[Sprite2D] = []
var _particle_states: Array[Dictionary] = []
var _particle_count := 0
var _rng := RandomNumberGenerator.new()
var _activation := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas = GradientTexture2D.new()
	var white := Gradient.new()
	white.colors = PackedColorArray([Color.WHITE,Color.WHITE])
	_canvas.gradient = white; _canvas.width = 2; _canvas.height = 2

func _texture(key: String) -> Texture2D:
	return Content.texture(key) if key.begins_with("res://") else Content.trimmed_texture(key)

func _color(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is Color: return value
	if value is String: return Color.html(str(value))
	if value is Array and value.size() >= 3:
		return Color(float(value[0]),float(value[1]),float(value[2]),float(value[3]) if value.size()>3 else 1.0)
	if value is int:
		return Color(float((value>>16)&255)/255.0,float((value>>8)&255)/255.0,float(value&255)/255.0)
	return fallback

func _sprite(texture: Texture2D) -> Sprite2D:
	if _used >= _sprites.size():
		var created := Sprite2D.new()
		add_child(created); _sprites.append(created); _materials.append({})
	var sprite := _sprites[_used]
	_used += 1
	sprite.texture = texture; sprite.material = null
	sprite.position = Vector2.ZERO; sprite.rotation = 0.0; sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE; sprite.self_modulate = Color.WHITE; sprite.visible = true
	return sprite

func _material(index: int, shader: Shader, key: String) -> ShaderMaterial:
	if not _materials[index].has(key):
		var created := ShaderMaterial.new(); created.shader = shader
		_materials[index][key] = created
	return _materials[index][key] as ShaderMaterial

func configure(payload: Dictionary, preset: Dictionary) -> void:
	# Keep children, materials and particle slots across activations of this pool node.
	for sprite in _sprites: sprite.visible = false
	for particle in _particle_sprites: particle.visible = false
	_used = 0; _procedural_slots.clear(); _layers.clear(); _main_material = null
	_preset = preset
	age = -float(payload.get("delay",0.0)); finished = false
	_kind = str(payload.get("kind","impact"))
	position = payload.get("pos",Vector2.ZERO); _angle = float(payload.get("angle",0.0))
	_origin = position
	_radius = maxf(2.0,float(payload.get("radius",preset.get("radius",20.0))))
	_arc = float(payload.get("arc",1.0472))
	_target = payload.get("target",position)-position
	duration = maxf(0.02,float(preset.get("duration",0.3)))
	if float(payload.get("duration",0.0)) > 0.0: duration = float(payload.duration)
	_tint = _color(payload.get("color",preset.get("color","#81d6ff")))
	modulate = Color.WHITE; scale = Vector2.ONE
	set_meta("kind",_kind)
	set_meta("sourceActor",str(payload.get("sourceActor","")))
	set_meta("targetActor",str(payload.get("targetActor","")))
	set_meta("weaponId",str(payload.get("weaponId","")))
	if _kind == "chain" and payload.has("hopIndex"):
		age = -float(payload.hopIndex)*float(preset.get("hopDelay",0.045))
	rotation = _angle if _kind in ["slash","muzzle","enemyProjectile","chargeWarning"] else 0.0
	if _kind == "slash":
		var sprite := _sprite(_canvas)
		sprite.scale = Vector2.ONE*_radius*1.06
		_main_material = _material(0,SLASH_SHADER,"slash")
		sprite.material = _main_material
		_main_material.set_shader_parameter("arc",_arc)
		_main_material.set_shader_parameter("duration",duration)
		_main_material.set_shader_parameter("sweep_seconds",float(preset.get("sweepSeconds",0.18)))
		_main_material.set_shader_parameter("ribbon_width",float(preset.get("ribbonWidth",0.042)))
		_main_material.set_shader_parameter("tail_fraction",float(preset.get("tailFraction",0.64)))
		_main_material.set_shader_parameter("glow_strength",float(preset.get("glowStrength",0.24)))
		var ends: Array = preset.get("strokeEnds",[0.18,0.20,0.23])
		_main_material.set_shader_parameter("stroke_ends",Vector3(ends[0],ends[1],ends[2]))
		var delays: Array = preset.get("secondaryDelays",[0.025,0.055])
		var radii: Array = preset.get("secondaryRadii",[0.90,0.80])
		var brightness: Array = preset.get("secondaryBrightness",[0.40,0.23])
		_main_material.set_shader_parameter("secondary_delays",Vector2(delays[0],delays[1]))
		_main_material.set_shader_parameter("secondary_radii",Vector2(radii[0],radii[1]))
		_main_material.set_shader_parameter("secondary_brightness",Vector2(brightness[0],brightness[1]))
		_main_material.set_shader_parameter("stroke_color",_tint)
	elif _kind == "chain":
		var sprite := _sprite(_canvas)
		_main_material = _material(0,CHAIN_SHADER,"chain")
		sprite.material = _main_material
		_main_material.set_shader_parameter("edge_tint",_color(preset.get("edgeColor","#264eb8")))
	else:
		_layers = preset.get("layers",[])
		for layer in _layers:
			var sprite := _sprite(_texture(str(layer.texture)))
			sprite.self_modulate = _color(layer.get("color",_tint))
		var procedural: Variant = preset.get("procedural",[])
		if procedural is Dictionary: procedural = [procedural]
		for item in procedural:
			var settings: Dictionary = item
			var index := _used
			var sprite := _sprite(_canvas)
			var material := _material(index,PULSE_SHADER,"pulse")
			sprite.material = material
			material.set_shader_parameter("mode",int(settings.get("mode",0)))
			material.set_shader_parameter("ring_width",float(settings.get("width",0.024)))
			material.set_shader_parameter("spokes",float(settings.get("spokes",8.0)))
			material.set_shader_parameter("effect_color",_color(settings.get("color",_tint)))
			material.set_shader_parameter("opacity",float(settings.get("alpha",1.0)))
			_procedural_slots.append({"index":index,"settings":settings,"material":material})
	_configure_particles(payload)
	tick(0.0)

func update_chain_endpoints(source: Vector2, target: Vector2) -> void:
	if _kind != "chain" or finished: return
	position = source; _target = target-source
	_tick_chain()

func _configure_particles(payload: Dictionary) -> void:
	_particle_count = clampi(int(_preset.get("particles",0)),0,MAX_PARTICLES)
	_particle_states.clear()
	var style: Dictionary = _preset.get("particleStyle",{})
	_activation += 1
	# This RNG is presentation-only and never advances the combat RNG.
	_rng.seed = int(payload.get("seed",hash(str(payload.get("contextId",payload.get("attackId",_activation)))+_kind+str(position))))
	var texture := _texture(str(style.get("texture","res://assets/visuals/vfx/spark.png")))
	for i in range(_particle_count):
		if i >= _particle_sprites.size():
			var particle := Sprite2D.new(); add_child(particle); _particle_sprites.append(particle)
		var particle := _particle_sprites[i]
		particle.texture = texture; particle.visible = false
		var start := float(style.get("start",0.018))+float(i)*float(style.get("stagger",0.002))
		var lifetime := minf(float(style.get("lifetime",0.24)),maxf(0.02,duration-start))
		var aimed := bool(style.get("aimed",false))
		var heading := (_angle if rotation == 0.0 else 0.0) if aimed else 0.0
		heading += deg_to_rad(_rng.randf_range(-float(style.get("spread",180.0)),float(style.get("spread",180.0))))
		var speed := float(style.get("speed",75.0))*_rng.randf_range(0.55,1.0)
		var velocity := Vector2.from_angle(heading)*speed
		_particle_states.append({"start":start,"life":lifetime,"velocity":velocity,
			"gravity":Vector2(0,float(style.get("gravity",35.0))),
			"size":float(style.get("size",5.0))*_rng.randf_range(0.70,1.0),
			"endSize":float(style.get("endSize",1.0)),
			"spin":_rng.randf_range(-8.0,8.0),"rotation":_rng.randf_range(-PI,PI),
			"origin":Vector2.ZERO,"started":false,"mode":str(style.get("emitMode","center")),
			"color":_color(style.get("color",_tint)),"alpha":float(style.get("alpha",0.85))})

func _tick_particles() -> void:
	for i in range(_particle_count):
		var sprite := _particle_sprites[i]
		var state := _particle_states[i]
		var elapsed: float = age-float(state.start)
		sprite.visible = elapsed >= 0.0 and elapsed < float(state.life)
		if not sprite.visible: continue
		if not bool(state.started):
			state.started = true
			if str(state.mode) == "endpoint": state.origin = position+_target
			elif str(state.mode) == "slash":
				var sweep := clampf(float(state.start)/(float(_preset.get("sweepSeconds",0.18))*0.82),0.0,1.0)
				state.origin = Vector2.from_angle(_arc*(smoothstep(0.0,1.0,sweep)-0.5))*_radius*(0.755+0.17*smoothstep(0.0,1.0,sweep))
		var t := elapsed/float(state.life)
		var origin: Vector2 = state.origin-position if str(state.mode) == "endpoint" else state.origin
		sprite.position = origin+state.velocity*elapsed+state.gravity*elapsed*elapsed*0.5
		sprite.rotation = float(state.rotation)+float(state.spin)*elapsed
		var size := lerpf(float(state.size),float(state.endSize),t)
		sprite.scale = Vector2.ONE*size/maxf(sprite.texture.get_width(),sprite.texture.get_height())
		sprite.modulate = state.color
		sprite.modulate.a *= float(state.alpha)*minf(1.0,elapsed/0.012)*(1.0-smoothstep(0.10,1.0,t))

func tick(dt: float) -> void:
	if finished: return
	age += maxf(0.0,dt)
	if age >= duration:
		reset()
		return
	visible = age >= 0.0
	if not visible: return
	if _kind == "pickup":
		var travel := clampf(age/maxf(0.02,duration*0.72),0,1)
		position = _origin+_target*(1.0-pow(1.0-travel,2.0))
	if _kind == "slash":
		_main_material.set_shader_parameter("elapsed",age)
	elif _kind == "chain":
		_tick_chain()
	else:
		_tick_layers()
	_tick_particles()

func _tick_chain() -> void:
	if _main_material == null: return
	var sprite := _sprites[0]
	var length := _target.length()
	var thickness := minf(float(_preset.get("thickness",22.0))*float(_preset.get("displayScale",1.7)),maxf(2.0,length*0.55))
	sprite.position = _target*0.5; sprite.rotation = _target.angle()
	sprite.scale = Vector2(length*0.5,thickness*0.5)
	var travel := maxf(0.005,float(_preset.get("travelTime",0.05)))
	var reached := clampf(age/travel,0.0,1.0)
	var arrival := smoothstep(travel-0.01,travel,age)*(1.0-smoothstep(travel+0.012,travel+0.085,age))
	_main_material.set_shader_parameter("progress",reached)
	_main_material.set_shader_parameter("phase",age*float(_preset.get("flickerSpeed",55.0)))
	_main_material.set_shader_parameter("aspect",length/maxf(1.0,thickness))
	_main_material.set_shader_parameter("arrival",arrival)
	_main_material.set_shader_parameter("opacity",1.0-smoothstep(0.40,1.0,age/duration))

func _tick_layers() -> void:
	for i in range(_layers.size()):
		var layer: Dictionary = _layers[i]
		var sprite := _sprites[i]
		var start := float(layer.get("start",0.0)); var end := float(layer.get("end",duration))
		sprite.visible = age >= start and age < end
		if not sprite.visible: continue
		var t := clampf((age-start)/maxf(0.001,end-start),0.0,1.0)
		var expansion := 1.0-pow(1.0-t,3.0)
		var diameter := _radius*2.0*lerpf(float(layer.get("from",0.35)),float(layer.get("to",1.0)),expansion)
		diameter *= 1.0+sin(t*PI)*float(layer.get("overshoot",0.0))
		var projection := float(layer.get("projection",1.0))
		sprite.scale = Vector2(diameter,diameter*projection)/maxf(sprite.texture.get_width(),sprite.texture.get_height())
		sprite.position = Vector2(float(layer.get("offset",0.0))+t*float(layer.get("drift",0.0)),-t*float(layer.get("rise",0.0)))
		sprite.rotation = lerpf(float(layer.get("rotationFrom",0.0)),float(layer.get("rotationTo",0.0)),expansion)
		sprite.modulate.a = float(layer.get("alpha",1.0))*(1.0-smoothstep(float(layer.get("fadeFrom",0.30)),1.0,t))*minf(1.0,(age-start)/float(layer.get("fadeIn",0.018)))
	for slot in _procedural_slots:
		var settings: Dictionary = slot.settings
		var sprite := _sprites[int(slot.index)]
		var start := float(settings.get("start",0.0)); var end := float(settings.get("end",duration))
		sprite.visible = age >= start and age < end
		if not sprite.visible: continue
		var projection := float(settings.get("projection",1.0))
		var size := _radius*float(settings.get("scale",1.0))*1.06
		sprite.scale = Vector2(size,size*projection)
		sprite.position = Vector2(float(settings.get("offsetX",0.0)),float(settings.get("offsetY",0.0)))
		var material: ShaderMaterial = slot.material
		material.set_shader_parameter("progress",clampf((age-start)/maxf(0.001,end-start),0.0,1.0))
		material.set_shader_parameter("phase",age)

func reset() -> void:
	finished = true; visible = false
	for sprite in _sprites: sprite.visible = false
	for particle in _particle_sprites: particle.visible = false
	_particle_count = 0; _particle_states.clear()
	_target = Vector2.ZERO
	set_meta("sourceActor",""); set_meta("targetActor","")
