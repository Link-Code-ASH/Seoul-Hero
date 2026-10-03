class_name HeroTimedVfx
extends Node2D

var age := 0.0
var duration := 0.3
var finished := false
var _kind := ""
var _radius := 20.0
var _arc := 1.0472
var _layers: Array = []
var _sprites: Array[Sprite2D] = []
var _chain_materials: Array[ShaderMaterial] = []
var _slash_material: ShaderMaterial
var _preset: Dictionary = {}
var _particles := CPUParticles2D.new()
var _target := Vector2.ZERO
var _angle := 0.0
var _chain_display_scale := 1.0

func _ready() -> void:
	add_child(_particles)
	_particles.emitting = false
	_particles.local_coords = true
	_particles.one_shot = true
	_particles.lifetime = 0.32
	_particles.explosiveness = 1.0
	_particles.direction = Vector2.RIGHT
	_particles.spread = 180
	_particles.gravity = Vector2(0,45)
	_particles.initial_velocity_min = 26; _particles.initial_velocity_max = 90
	_particles.scale_amount_min = 0.005; _particles.scale_amount_max = 0.013
	_particles.texture = Content.texture("res://assets/visuals/vfx/spark.png")
	var color := Gradient.new()
	color.colors = PackedColorArray([Color(0.8,0.94,1,0.8),Color(0.5,0.8,1,0)])
	_particles.color_ramp = color
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new(); sprite.texture = texture
	add_child(sprite); _sprites.append(sprite)
	return sprite

func configure(payload: Dictionary, preset: Dictionary) -> void:
	for sprite in _sprites: sprite.free()
	_sprites.clear(); _chain_materials.clear(); _layers.clear(); _slash_material = null
	_preset = preset
	age = -float(payload.get("delay",0)); finished = false; visible = true
	_kind = payload.kind; position = payload.pos; _angle = payload.get("angle",0.0)
	_radius = payload.get("radius",20.0); _arc = payload.get("arc",1.0472)
	_target = payload.get("target",position)-position
	duration = preset.get("duration",0.3)
	_chain_display_scale = float(preset.get("displayScale",1.0))
	if _kind == "chain" and payload.has("hopIndex"):
		age = -float(payload.hopIndex)*float(preset.get("hopDelay",0.045))
	_particles.emitting = false
	if _kind == "slash":
		rotation = _angle
		# A white canvas supplies UVs only. The shader continuously forms the
		# curved leading edge and retracting tail; no painted chunk is rotated.
		var canvas := GradientTexture2D.new()
		var white := Gradient.new(); white.colors = PackedColorArray([Color.WHITE,Color.WHITE])
		canvas.gradient = white; canvas.width = 2; canvas.height = 2
		var sprite := _sprite(canvas)
		sprite.scale = Vector2.ONE*_radius*1.06
		_slash_material = ShaderMaterial.new()
		_slash_material.shader = load("res://shaders/slash_sweep.gdshader")
		_slash_material.set_shader_parameter("arc",_arc)
		_slash_material.set_shader_parameter("sweep_fraction",float(preset.get("sweepFraction",0.62)))
		_slash_material.set_shader_parameter("tail_fraction",float(preset.get("tailFraction",0.64)))
		_slash_material.set_shader_parameter("ribbon_width",float(preset.get("ribbonWidth",0.042)))
		_slash_material.set_shader_parameter("glow_strength",float(preset.get("glowStrength",0.24)))
		sprite.material = _slash_material
	elif _kind == "chain":
		rotation = 0
		# One painted ribbon per hop. Its X extent is exactly source -> target;
		# the 1.7 visual enlargement affects only its thickness, never reach.
		for i in range(2):
			var sprite := _sprite(Content.trimmed_texture("vfxChain"))
			var material := ShaderMaterial.new(); material.shader = load("res://shaders/chain_link.gdshader")
			material.set_shader_parameter("edge_tint",Color.html(str(preset.get("edgeColor","264eb8"))))
			material.set_shader_parameter("edge_width",float(preset.get("edgeWidth",0.045)))
			var atlas := sprite.texture as AtlasTexture
			if atlas != null:
				material.set_shader_parameter("region_origin",atlas.region.position/atlas.atlas.get_size())
				material.set_shader_parameter("region_span",atlas.region.size/atlas.atlas.get_size())
			sprite.material = material; _chain_materials.append(material)
	else:
		rotation = _angle if _kind == "muzzle" else 0.0
		_layers = preset.get("layers",[])
		for layer in _layers:
			var sprite := _sprite(Content.texture(layer.texture) if str(layer.texture).begins_with("res://") else Content.trimmed_texture(layer.texture))
			if _kind in ["mine","explosion"] and layer.texture not in ["vfxDeath"]:
				sprite.self_modulate = Color(0.8,0.64,1) if _kind == "mine" else Color(1,0.82,0.61)
	var amount := int(preset.get("particles",0))
	if amount > 0:
		_particles.texture = Content.texture("res://assets/visuals/vfx/debris.png" if _kind in ["mine","explosion","death"] else "res://assets/visuals/vfx/spark.png")
		_particles.amount = mini(amount,12)
		_particles.color = Color(0.75,0.62,1) if _kind == "mine" else Color(1,0.77,0.44) if _kind == "explosion" else Color(0.7,0.9,1)
		_particles.speed_scale = 1.0
		_particles.restart(); _particles.emitting = true
	tick(0)

func tick(dt: float) -> void:
	if finished: return
	_particles.speed_scale = 0.0 if dt <= 0 else 1.0
	age += dt
	if age >= duration:
		finished = true; visible = false; _particles.emitting = false
		return
	visible = age >= 0.0
	if not visible: return
	if _kind == "slash":
		_slash_material.set_shader_parameter("progress",clampf(age/duration,0.0,1.0))
	elif _kind == "chain":
		var reach := clampf(age/float(_preset.get("travelTime",0.05)),0.0,1.0)
		var fade := 1.0-smoothstep(0.28,1.0,age/duration)
		var thickness := minf(float(_preset.get("thickness",18.0))*_chain_display_scale,maxf(2.0,_target.length()*0.55))
		for i in range(_sprites.size()):
			var sprite := _sprites[i]
			sprite.position = _target*0.5
			sprite.rotation = _target.angle()
			var image_size := sprite.texture.get_size()
			sprite.scale = Vector2(_target.length()/image_size.x,thickness*(1.0 if i == 0 else 0.46)/image_size.y)
			_chain_materials[i].set_shader_parameter("progress",reach)
			_chain_materials[i].set_shader_parameter("phase",age*float(_preset.get("flickerSpeed",55.0)))
			_chain_materials[i].set_shader_parameter("opacity",fade*(0.95 if i == 0 else 0.55))
			_chain_materials[i].set_shader_parameter("core",float(i))
	else:
		for i in range(_layers.size()):
			var layer: Dictionary = _layers[i]; var sprite := _sprites[i]
			var start: float = layer.start; var end: float = layer.end
			sprite.visible = age >= start and age < end
			if not sprite.visible: continue
			var t := clampf((age-start)/(end-start),0,1)
			var expansion := 1.0-pow(1.0-t,3.0)
			var size := _radius*2.0*lerpf(layer.from,layer.to,expansion)
			sprite.scale = Vector2.ONE*size/maxf(sprite.texture.get_width(),sprite.texture.get_height())
			sprite.position = Vector2(layer.get("offset",0),-t*float(layer.get("rise",0)))
			sprite.modulate.a = float(layer.alpha)*(1.0-smoothstep(0.22,1,t))*minf(1,(age-start)/0.018)

func reset() -> void:
	finished = true; visible = false; _particles.emitting = false
