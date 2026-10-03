extends Node

# Frozen, in-memory fixtures advance presentation time only. No combat tick,
# purchases, profile writes, or checkpoints are executed.
var _output := "res://exports/combat-feedback"
var _only_scene := ""
var _world: HeroWorld
var _run: HeroRun
var _records: Array = []

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Combat capture requires --ui-preview.")
		get_tree().quit(1); return
	DisplayServer.window_set_size(Vector2i(915,412))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		if argument.begins_with("--scene="): _only_scene = argument.trim_prefix("--scene=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	for frame in range(3): await get_tree().process_frame
	await _scene("slash")
	_run.player.pos = Vector2(310,-10)
	_run.enemies = [_enemy(1,"spitter",Vector2(440,-25)),_enemy(2,"crawler",Vector2(402,70))]
	_world._combat.sync(0)
	_run.effect("slash",_run.player.pos,140.0,-0.18,PI/3.0,Vector2.ZERO,{"sourceActor":"player","weaponId":"manaSword"})
	for frame in range(18): await _frame("slash",frame,1.0/60.0)
	await _scene("chain")
	_run.player.pos = Vector2(-215,35)
	_run.enemies = [_enemy(1,"bulwark",Vector2(-10,-5)),_enemy(2,"spitter",Vector2(103,35)),_enemy(3,"crawler",Vector2(166,-73))]
	_world._combat.sync(0)
	var points := [_run.player.pos,_run.enemies[0].pos,_run.enemies[1].pos,_run.enemies[2].pos]
	for hop in range(3):
		_run.effect("chain",points[hop],10,0,1.0472,points[hop+1],{"sourceActor":"player" if hop == 0 else str(hop),"targetActor":str(hop+1),"hopIndex":hop})
	for frame in range(21): await _frame("chain",frame,1.0/60.0)
	await _scene("installations")
	_run.player.pos = Vector2(80,185)
	_run.enemies = [_enemy(1,"crawler",Vector2(-80,162)),_enemy(2,"spitter",Vector2(135,218)),_enemy(3,"glassJelly",Vector2(230,155))]
	_run.owned = [{"id":"manaField","level":1,"branch":"","cooldown":0.0}]
	_run.structures = [{"weapon":"manaField","pos":Vector2(0,150),"age":0.5},{"weapon":"mineLayer","pos":Vector2(-170,230),"age":0.5},{"weapon":"mineLayer","pos":Vector2(170,250),"age":0.5}]
	for frame in range(48): await _frame("installations",frame,0.1)
	await _scene("projectiles")
	_run.player.pos = Vector2(-110,35)
	_run.enemies = [_enemy(1,"spitter",Vector2(135,15))]
	_run.owned = [{"id":"guardianDaggers","level":1,"branch":"","cooldown":0.0}]
	_run.bullets = [{"visualId":1,"context":{"contextId":1,"sourceActor":"player","targetActor":"1","targetDistance":250},"pos":Vector2(-35,25),"distance":75.0,"range":300.0,"velocity":Vector2.RIGHT*300,"angle":0.0,"sprite":"manaBolt"}]
	_run.hostile = [{"pos":Vector2(42,-30),"velocity":Vector2(-240,0)}]
	_run.pending = [{"kind":"bombard","remaining":0.5,"duration":1.0,"target":Vector2(120,115),"pos":Vector2(-110,35),"context":{"contextId":2,"sourceActor":"player"}}]
	for frame in range(20): await _frame("projectiles",frame,0.05)
	var file := FileAccess.open(_output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[915,412],"saveWrites":false,"combatSimulation":false,"productionRenderer":true,"scenes":_records,"projectileDisplayScale":1.5,"shop":Content.data.shop},"\t"))
	print("Combat presentation captures: ",ProjectSettings.globalize_path(_output))
	get_tree().quit()

func _scene(name: String) -> void:
	if is_instance_valid(_world):
		_world.queue_free()
		await get_tree().process_frame
	var meta: Dictionary = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,meta)
	var setup := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaSword","blessing":"","weekly":""}
	_run = HeroRun.new(Content.data,setup,meta)
	_run.owned.clear()
	_world = HeroWorld.new(); add_child(_world)
	_world.set_process(false); _world.run = _run
	_world._update_camera()
	_world._combat.transform = _world._drawing_transform
	_world._combat.visible_world = _world._drawing_transform.affine_inverse()*get_viewport().get_visible_rect()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output.path_join(name)))
	_records.append({"id":name,"frames":0})

func _enemy(id: int, definition: String, point: Vector2) -> Dictionary:
	var data: Dictionary = Content.data.enemies[definition]
	return {"id":id,"definition":definition,"pos":point,"radius":data.radius,"hp":data.maxHp,"maxHp":data.maxHp,"elite":false,"boss":false,"age":1.0}

func _frame(name: String, frame: int, dt: float) -> void:
	if not _only_scene.is_empty() and name != _only_scene: return
	_run.combat_time += dt
	for entity in _run.structures: entity.age += dt
	_world._combat.sync(dt)
	if name == "projectiles" and frame == 4:
		var actor: Node2D = _world._combat._active.player
		var bounds: Rect2 = actor.visual_bounds()
		var top_shot: HeroProjectileVisual = null
		for key in _world._combat._shots:
			if not str(key).begins_with("orbit:"): continue
			var shot: HeroProjectileVisual = _world._combat._shots[key]
			if top_shot == null or shot.position.y < top_shot.position.y: top_shot = shot
		if top_shot != null:
			var shot_bounds: Rect2 = top_shot._core.transform*top_shot._core.get_rect()
			shot_bounds.position += top_shot.position-_run.player.pos
			_records.back().topOrbitHeadGapPx = (bounds.position.y-shot_bounds.end.y)*_world._scale
	_world.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var file := _output.path_join(name).path_join("%03d.png" % frame)
	get_viewport().get_texture().get_image().save_png(file)
	_records.back().frames += 1
