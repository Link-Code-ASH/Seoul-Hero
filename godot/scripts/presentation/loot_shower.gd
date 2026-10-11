class_name HeroLootShower
extends Control

# Menu-side reward rain: reward icons burst out of a source, bounce on an
# invisible floor, then fly into the card or row that lists them.
# Purely visual. Rewards are already paid before this runs.
signal finished
const GRAVITY := 1500.0
const MAX_PIECES := 72
const MINT := Color(0.42,0.95,0.82)
const GOLD := Color(1.0,0.84,0.45)
var capture_clock := false
var source_node: Control
var source_offset := Vector2(0,-24)
var floor_drop := 74.0
var on_arrive: Callable
var _groups: Array = []
var _pieces: Array = []
var _rings: Array = []
var _sparks: Array = []
var _punch: Dictionary = {}
var _arrived: Dictionary = {}
var _source := Vector2.ZERO
var _age := 0.0
var _spawned := false
var _done := false
var _rng := RandomNumberGenerator.new()
var _born_frame := 0

# groups: [{texture, amount, target: Control}]. on_arrive(index) fires once per group.
static func play(host: Control, from: Control, groups: Array, arrive: Callable = Callable(), seed_value: int = 7) -> HeroLootShower:
	var shower := HeroLootShower.new()
	shower.source_node = from
	shower.on_arrive = arrive
	shower._groups = groups
	shower._rng.seed = seed_value
	shower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shower.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shower.z_index = 20
	host.add_child(shower)
	shower._born_frame = Engine.get_process_frames()
	shower.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return shower

func _process(dt: float) -> void:
	if not capture_clock: advance(dt)

func advance(dt: float) -> void:
	if _done: return
	_age += dt
	# Wait for real layout frames so the source and targets have their final rects.
	if not _spawned:
		if Engine.get_process_frames() < _born_frame+2: return
		if is_instance_valid(source_node) and not source_node.get_global_rect().has_area(): return
		_age = 0.0
		_spawn()
	for piece in _pieces: _advance_piece(piece,dt)
	for ring in _rings: ring.t += dt
	_rings = _rings.filter(func(ring): return ring.t < 0.45)
	for spark in _sparks:
		spark.t += dt
		spark.vel.y += GRAVITY*0.35*dt
		spark.pos += spark.vel*dt
	_sparks = _sparks.filter(func(spark): return spark.t < 0.5)
	for target in _punch.keys():
		if not is_instance_valid(target):
			_punch.erase(target)
			continue
		_punch[target] = maxf(0.0,float(_punch[target])-dt*5.0)
		target.pivot_offset = target.size*0.5
		target.scale = Vector2.ONE*(1.0+0.22*sin(float(_punch[target])*PI*0.5))
	if _age > 0.3 and _rings.is_empty() and _sparks.is_empty() and _pieces.all(func(piece): return piece.state == 3):
		_finish()
	queue_redraw()

func _spawn() -> void:
	_spawned = true
	_source = (source_node.get_global_rect().get_center() if is_instance_valid(source_node) else get_global_rect().get_center())+source_offset
	var counts: Array[int] = []
	var total := 0
	for group in _groups:
		var count := clampi(2+int(log(float(maxi(1,int(group.get("amount",1)))))/log(2.0)),3,10)
		counts.append(count)
		total += count
	var squeeze := minf(1.0,float(MAX_PIECES)/maxf(1.0,float(total)))
	var serial := 0
	for index in _groups.size():
		var count := maxi(1,int(round(counts[index]*squeeze)))
		for _n in count:
			var angle := _rng.randf_range(-1.0,1.0)
			_pieces.append({
				"group":index,"texture":_groups[index].get("texture"),
				"pos":_source,"vel":Vector2(angle*_rng.randf_range(220,420),-_rng.randf_range(430,760)),
				"rot":_rng.randf_range(-0.6,0.6),"spin":_rng.randf_range(-7.0,7.0),
				"size":_rng.randf_range(24.0,32.0),"launch":serial*0.012,
				"home_at":0.62+serial*0.012+_rng.randf_range(0.0,0.35)+index*0.05,
				"state":0,"t":0.0,"from":Vector2.ZERO,"trail":_source,
			})
			serial += 1
	_rings.append({"pos":_source,"t":0.0,"big":true})
	Sound.cue("walletSweep")

func _advance_piece(piece: Dictionary, dt: float) -> void:
	piece.t += dt
	match int(piece.state):
		0:
			if piece.t >= piece.launch: piece.state = 1
		1:
			piece.vel.y += GRAVITY*dt
			piece.pos += piece.vel*dt
			piece.rot += piece.spin*dt
			var floor_y := _source.y+floor_drop
			if piece.pos.y > floor_y and piece.vel.y > 0.0:
				piece.pos.y = floor_y
				piece.vel = Vector2(piece.vel.x*0.6,-piece.vel.y*0.36)
				piece.spin *= 0.5
			if piece.t >= piece.home_at:
				piece.state = 2
				piece.from = piece.pos
				piece.t = 0.0
		2:
			var target := _target(int(piece.group))
			var k := clampf(piece.t/0.34,0.0,1.0)
			var curve := k*k
			var start: Vector2 = piece.from
			var lift: Vector2 = start.lerp(target,0.5)+Vector2(0,-90)
			piece.trail = piece.pos
			piece.pos = start.lerp(lift,curve).lerp(lift.lerp(target,curve),curve)
			piece.rot = lerp_angle(piece.rot,0.0,k)
			if k >= 1.0:
				piece.state = 3
				_arrive(int(piece.group),target)

func _target(index: int) -> Vector2:
	var control = _groups[index].get("target")
	if control is Control and is_instance_valid(control) and control.is_visible_in_tree():
		return (control as Control).get_global_rect().get_center()
	return _source

func _arrive(index: int, point: Vector2) -> void:
	_rings.append({"pos":point,"t":0.0,"big":false})
	for _n in 4:
		_sparks.append({"pos":point,"vel":Vector2.from_angle(_rng.randf_range(-PI,0.0))*_rng.randf_range(90,190),"t":0.0})
	var control = _groups[index].get("target")
	if control is Control and is_instance_valid(control): _punch[control] = 1.0
	Sound.cue("magicStoneCollected")
	if not _arrived.has(index):
		_arrived[index] = true
		if on_arrive.is_valid(): on_arrive.call(index)

func _finish() -> void:
	_done = true
	# Every group is revealed even if its target was off screen or freed.
	for index in _groups.size():
		if not _arrived.has(index):
			_arrived[index] = true
			if on_arrive.is_valid(): on_arrive.call(index)
	for target in _punch.keys():
		if is_instance_valid(target): target.scale = Vector2.ONE
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	for target in _punch.keys():
		if is_instance_valid(target): target.scale = Vector2.ONE

func _local(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse()*point

func _draw() -> void:
	if not _spawned: return
	# Source flash with slow rays, fading over the first 0.7s.
	var flash := 1.0-smoothstep(0.05,0.75,_age)
	if flash > 0.0:
		var center := _local(_source)
		for ray in 10:
			var angle := ray*TAU/10.0+_age*0.9
			var tip := center+Vector2.from_angle(angle)*(70.0+50.0*flash)
			var wing := Vector2.from_angle(angle+PI*0.5)*9.0
			draw_colored_polygon(PackedVector2Array([center+wing,tip,center-wing]),Color(GOLD,0.22*flash))
		draw_circle(center,46.0*flash+8.0,Color(GOLD,0.28*flash))
		draw_circle(center,22.0*flash+4.0,Color(1,1,1,0.55*flash))
	for ring in _rings:
		var k := float(ring.t)/0.45
		var radius := (90.0 if ring.big else 26.0)*(0.25+0.75*k)
		draw_arc(_local(ring.pos),radius,0.0,TAU,32,Color(MINT if not ring.big else GOLD,0.8*(1.0-k)),3.0*(1.0-k)+1.0,true)
	for spark in _sparks:
		var k := float(spark.t)/0.5
		_star(_local(spark.pos),5.0*(1.0-k)+1.0,Color(1.0,0.95,0.7,1.0-k))
	for piece in _pieces:
		var state := int(piece.state)
		if state == 0 or state == 3: continue
		var at := _local(piece.pos)
		if state == 2: draw_line(_local(piece.trail),at,Color(MINT,0.55),3.0,true)
		var side := float(piece.size)*(1.0-0.35*clampf(float(piece.t)/0.34,0.0,1.0) if state == 2 else 1.0)
		draw_circle(at,side*0.62,Color(GOLD,0.16))
		draw_set_transform(at,float(piece.rot),Vector2.ONE)
		var texture = piece.texture
		if texture is Texture2D:
			var dims := (texture as Texture2D).get_size()
			var fit := side/maxf(1.0,maxf(dims.x,dims.y))
			var drawn := dims*fit
			draw_texture_rect(texture,Rect2(-drawn*0.5,drawn),false)
		else:
			draw_circle(Vector2.ZERO,side*0.38,GOLD)
			draw_circle(Vector2.ZERO,side*0.24,Color(1,0.95,0.75))
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for n in 8:
		points.append(at+Vector2.from_angle(n*TAU/8.0)*(radius if n%2 == 0 else radius*0.35))
	draw_colored_polygon(points,color)
