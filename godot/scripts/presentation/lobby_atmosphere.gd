class_name HeroLobbyAtmosphere
extends Control

const CATALOG := "res://data/visuals/lobby_atmospheres.json"
const MAX_PARTICLES := 160
const REFERENCE := Vector2(915,412)

var scene_id := "premiumLobbyEnergy"
var _layers: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _clock := 0.0
var _last_size := REFERENCE
var _mist: GradientTexture2D
var _app_hidden := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size.x <= 0 or size.y <= 0: size = REFERENCE
	_last_size = size
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var definition: Dictionary = catalog.get(scene_id,catalog.premiumLobbyEnergy)
	for layer: Dictionary in definition.layers:
		_layers.append(layer)
		var count := mini(int(layer.count),MAX_PARTICLES - _particles.size())
		for i in range(count):
			var floor_y: float = randf_range(0.58,0.98) if layer.kind == "ripple" else randf()
			_particles.append({"layer":_layers.size()-1,"position":Vector2(randf()*size.x,floor_y*size.y),"depth":randf_range(0.45,1.0),"phase":randf()*TAU,"cycle":randf(),"turn":randf_range(-1.0,1.0)})
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.5,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.4),Color(1,1,1,0.12),Color(1,1,1,0)])
	_mist = GradientTexture2D.new()
	_mist.gradient = gradient
	_mist.width = 128; _mist.height = 64
	_mist.fill = GradientTexture2D.FILL_RADIAL
	_mist.fill_from = Vector2(0.5,0.5); _mist.fill_to = Vector2(1,0.5)
	resized.connect(_resize_particles)
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()

func _visibility_changed() -> void:
	set_process(is_visible_in_tree() and not _app_hidden)

func _resize_particles() -> void:
	if size.x <= 0 or size.y <= 0: return
	var ratio := size / _last_size
	for particle in _particles:
		particle.position *= ratio
	_last_size = size
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _app_hidden: return
	var dt := minf(delta,0.04)
	_clock += dt
	var pixel_scale := minf(size.x / REFERENCE.x,size.y / REFERENCE.y)
	for particle in _particles:
		var layer: Dictionary = _layers[particle.layer]
		var velocity := Vector2(float(layer.velocity[0]),float(layer.velocity[1]))
		particle.cycle = fmod(float(particle.cycle) + dt * float(layer.get("cycle_speed",0.2)),1.0)
		match str(layer.kind):
			"snow","leaf": velocity.x += sin(_clock * 0.8 + particle.phase) * 14.0
			"light": velocity.x += sin(_clock * 0.65 + particle.phase) * 9.0
			"dust": velocity.y += sin(_clock + particle.phase) * 5.0
			"ripple":
				if particle.cycle < dt * float(layer.cycle_speed):
					particle.position = Vector2(randf()*size.x,randf_range(0.58,0.98)*size.y)
		particle.position += velocity * dt * particle.depth * pixel_scale
		var margin_x := float(layer["size"]) if layer.kind == "mist" else 40.0
		var margin_y := margin_x * 0.3 if layer.kind == "mist" else 30.0
		particle.position.x = wrapf(particle.position.x,-margin_x*pixel_scale,size.x+margin_x*pixel_scale)
		particle.position.y = wrapf(particle.position.y,-margin_y*pixel_scale,size.y+margin_y*pixel_scale)
	queue_redraw()

func _draw() -> void:
	var pixel_scale := minf(size.x / REFERENCE.x,size.y / REFERENCE.y)
	for particle in _particles:
		var layer: Dictionary = _layers[particle.layer]
		var at: Vector2 = particle.position
		var depth: float = particle.depth
		var color := Color(str(layer.color))
		var radius: float = float(layer["size"]) * depth * pixel_scale
		color.a *= depth
		# Layer-specific traveling emphasis strengthens depth without adding particles.
		var rhythm: float = float(layer.get("rhythm",0.0))
		color.a *= 1.0-rhythm+rhythm*(0.5+0.5*sin(_clock*float(layer.get("rhythm_speed",0.7))+particle.phase))
		match str(layer.kind):
			"rain": draw_line(at,at+Vector2(-0.25,1.0)*radius,color,maxf(0.65,pixel_scale*0.7),true)
			"ripple":
				color.a *= sin(particle.cycle*PI)
				draw_set_transform(at,0,Vector2(1.0,0.3))
				draw_arc(Vector2.ZERO,radius*(0.2+particle.cycle),0,TAU,16,color,maxf(0.6,pixel_scale*0.7),true)
				draw_set_transform(Vector2.ZERO)
			"wind":
				color.a *= 0.55+0.45*sin(_clock+particle.phase)
				draw_line(at,at+Vector2(radius,sin(_clock+particle.phase)*2.0*pixel_scale),color,maxf(0.6,pixel_scale*0.6),true)
			"leaf":
				draw_set_transform(at,_clock*particle.turn+particle.phase)
				draw_colored_polygon(PackedVector2Array([Vector2(-radius,0),Vector2(0,-radius*0.4),Vector2(radius,0),Vector2(0,radius*0.4)]),color)
				draw_set_transform(Vector2.ZERO)
			"snow","dust": draw_circle(at,radius,color)
			"light":
				color.a *= 0.6+0.4*sin(_clock*1.4+particle.phase)
				draw_circle(at,radius,color)
				color.a *= 0.2
				draw_circle(at,radius*3.0,color)
			"mist":
				color.a *= 0.8+0.2*sin(_clock*0.3+particle.phase)
				if _mist: draw_texture_rect(_mist,Rect2(at-Vector2(radius,radius*0.3),Vector2(radius*2.0,radius*0.6)),false,color)
			"gate_pulse":
				var center := Vector2(float(layer.anchor[0]),float(layer.anchor[1]))*size
				color.a *= sin(particle.cycle*PI)
				draw_set_transform(center,0,Vector2(0.7,1.0))
				draw_arc(Vector2.ZERO,radius*(0.82+particle.cycle*0.18),0,TAU,48,color,pixel_scale*2.0,true)
				draw_set_transform(Vector2.ZERO)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_app_hidden = true; set_process(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_app_hidden = false
		if is_node_ready(): _visibility_changed()
