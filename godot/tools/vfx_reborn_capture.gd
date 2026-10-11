extends Node

# Render the production presenters with moving, in-memory fixtures. This scene
# never advances the simulation or writes a profile/checkpoint.
var _output := "res://exports/vfx-reborn-01"
var _only := ""
var _run: HeroRun
var _world: HeroWorld
var _canvas := CanvasLayer.new()
var _view: Control
var _fx: HeroUIEffects
var _records: Array = []
var _checks: Array = []
var _original_meta: Dictionary
var _scene := ""
var _elapsed := 0.0
var _slash_interval := 30

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("VFX capture requires --ui-preview."); get_tree().quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		if arg.begins_with("--scene="): _only = arg.trim_prefix("--scene=")
	DisplayServer.window_set_size(Vector2i(915,412))
	for frame in range(3): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_original_meta = Profile.meta
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.weekly(Content.data,Profile.meta,Time.get_unix_time_from_system())
	for group in ["characters","sharedWeapons","blessings"]:
		for id in Profile.meta[group]: Profile.meta[group][id].unlocked = true
	Profile.meta.wallet.associationCoins = 12480; Profile.meta.wallet.supplyTickets = 12
	add_child(_canvas)
	for name in ["slash","chain","projectiles","orbit","bombard","installations","enemy-actions","pickups","rewards","hits","walk","dense"]:
		if not _only.is_empty() and _only != name: continue
		await _combat_scene(name)
		var frames := _slash_interval*8 if name == "slash" else 90
		for frame in range(frames): await _frame(name,frame,1.0/30.0)
		await _probe_lifecycle(name)
	for name in ["lobby","selection","shop","growth","supply","result"]:
		if not _only.is_empty() and _only != name: continue
		await _ui_scene(name)
		for frame in range(60): await _frame(name,frame,1.0/30.0)
		await _probe_ui(name)
	await _clear_scene()
	Profile.meta = _original_meta
	if not _only.is_empty() and FileAccess.file_exists(_output.path_join("capture.json")):
		var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_output.path_join("capture.json")))
		for record in prior.get("scenes",[]):
			if record.id != _only: _records.append(record)
		for check in prior.get("checks",[]):
			if not str(check.id).begins_with(_only+":"): _checks.append(check)
	var report := {"size":[915,412],"fps":30,"saveWrites":false,"combatSimulation":false,"productionRenderer":true,"scenes":_records,"checks":_checks,"weapons":Content.data.weapons.keys(),"enemies":Content.data.enemies.keys(),"budgets":{"effects":64,"particles":192,"projectiles":160,"uiParticles":48,"lobbyParticles":160}}
	var file := FileAccess.open(_output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("VFX_REBORN_CAPTURE ",JSON.stringify({"scenes":_records.size(),"checks":_checks,"output":ProjectSettings.globalize_path(_output)}))
	get_tree().quit()

func _clear_scene() -> void:
	if is_instance_valid(_fx): _fx.queue_free()
	if is_instance_valid(_view): _view.queue_free()
	if is_instance_valid(_world): _world.queue_free()
	_world = null; _view = null; _fx = null
	await get_tree().process_frame

func _begin(name: String) -> void:
	_scene = name; _elapsed = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output.path_join(name)))
	_records.append({"id":name,"frames":0,"maximumEffects":0,"maximumParticles":0,"maximumShots":0})

func _combat_scene(name: String) -> void:
	await _clear_scene(); _begin(name)
	var setup := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaSword","blessing":"","weekly":""}
	_run = HeroRun.new(Content.data,setup,Profile.meta); _run.owned.clear()
	_run.currency = 235; _run.wallet = 46
	_world = HeroWorld.new(); add_child(_world); _world.set_process(false); _world.run = _run
	_world._update_camera(); _world._combat.transform = _world._drawing_transform
	_world._combat.visible_world = _world._drawing_transform.affine_inverse()*get_viewport().get_visible_rect()
	var noop := func(): pass
	_view = HeroCombatUI.hud(_run,noop); _canvas.add_child(_view)
	_run.player.pos = Vector2(-70,50)
	_run.enemies = [_enemy(1,"crawler",Vector2(60,35)),_enemy(2,"spitter",Vector2(215,-30)),_enemy(3,"bulwark",Vector2(320,65))]
	match name:
		"slash":
			_run.player.pos = Vector2.ZERO; _run.enemies.clear()
			_slash_interval = maxi(12,ceili(float(_run.weapon_stats({"id":"manaSword","level":1,"branch":""}).cooldown)*30))
		"chain": _run.player.pos = Vector2(-330,90)
		"orbit": _run.owned = [{"id":"guardianDaggers","level":2,"branch":"","cooldown":0.0}]
		"installations":
			_run.player.pos = Vector2(80,80)
			_run.owned = [{"id":"manaField","level":1,"branch":"","cooldown":0.0}]
			_run.structures = [{"weapon":"manaField","pos":Vector2(0,120),"age":0.0},{"weapon":"mineLayer","pos":Vector2(-240,130),"age":0.0},{"weapon":"autoTurret","pos":Vector2(230,110),"age":0.0}]
		"enemy-actions":
			_run.player.pos = Vector2(0,190)
			_run.enemies = [_enemy(1,"bomber",Vector2(-320,-30)),_enemy(2,"runner",Vector2(-140,-25)),_enemy(3,"mender",Vector2(35,-20))]
			var bosses: Array = Content.data.enemies.keys().filter(func(id): return Content.data.enemies[id].get("behavior","")=="boss")
			if not bosses.is_empty(): _run.enemies.append(_enemy(4,str(bosses[0]),Vector2(240,65)))
			_run.hazards = [{"pos":Vector2(-330,150),"radius":60.0}]
		"pickups":
			_run.enemies.clear()
			for index in range(10): _run.pickups.append({"pos":Vector2(-270+index*55,70+sin(index)*50),"value":1.0})
		"walk":
			_run.player.pos = Vector2(-150,60); _run.enemies.clear()
			# On-screen stick, held as if a finger were dragging it.
			var stick := HeroMovement.new(); stick.name = "Stick"; _view.add_child(stick)
			stick.active = true; stick.finger = 0; stick.origin = Vector2(150,320)
		"hits":
			_run.player.pos = Vector2(-260,60)
			_run.enemies = [_enemy(1,"crawler",Vector2(-40,10)),_enemy(2,"spitter",Vector2(90,-60)),_enemy(3,"bulwark",Vector2(170,80)),_enemy(4,"runner",Vector2(40,140))]
		"rewards":
			_run.player.pos = Vector2(-60,40); _run.enemies.clear()
			for index in range(6): _run.enemies.append(_enemy(index+1,"crawler",Vector2(-330+index*120,-110+(index%2)*60)))
			for index in range(5): _run.pickups.append({"pos":Vector2(-300+index*140,150),"value":1.0+index*4.0,"units":1.0})
		"dense":
			_run.owned = []
			for id in ["manaSword","guardianDaggers","manaBolt","chainLightning","mineLayer","manaField"]:
				_run.owned.append({"id":id,"level":2,"branch":"","cooldown":0.0})
			_run.structures = [{"weapon":"manaField","pos":Vector2(20,70),"age":0.0}]
			_run.enemies.clear()
			var ids: Array = Content.data.enemies.keys()
			for index in range(19): _run.enemies.append(_enemy(index+1,str(ids[index]),Vector2(-420+(index%7)*140,-100+int(index/7)*120)))
	_world._combat.sync(0)

func _enemy(id: int, definition: String, point: Vector2) -> Dictionary:
	var data: Dictionary = Content.data.enemies[definition]
	return {"id":id,"definition":definition,"pos":point,"radius":data.radius,"hp":data.maxHp,"maxHp":data.maxHp,"elite":false,"boss":false,"age":0.0}

func _frame(name: String, frame: int, dt: float) -> void:
	_elapsed += dt
	if is_instance_valid(_world):
		_animate_combat(name,frame,dt)
		_run.combat_time += dt
		for entity in _run.structures: entity.age += dt
		for enemy in _run.enemies: enemy.age += dt
		_world._combat.sync(dt); _world.queue_redraw()
		HeroCombatUI.update_hud(_view,_run)
		var particles := 0
		for effect in _world._combat._playing: particles += int(effect.get_meta("particles",0))
		_records.back().maximumEffects = maxi(int(_records.back().maximumEffects),_world._combat._playing.size())
		_records.back().maximumParticles = maxi(int(_records.back().maximumParticles),particles)
		_records.back().maximumShots = maxi(int(_records.back().maximumShots),_world._combat._shots.size())
	elif is_instance_valid(_fx):
		_animate_ui(name,frame)
		_fx.advance_for_capture(dt)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output.path_join(name).path_join("%03d.png" % frame))
	_records.back().frames += 1

func _emit(kind: String, pos: Vector2, radius: float, extra: Dictionary = {}) -> void:
	var payload := {"kind":kind,"pos":pos,"radius":radius,"angle":0.0,"arc":PI*0.75,"target":pos,"sourceActor":"player","seed":137}
	payload.merge(extra,true); _run.visual_event.emit(payload)

func _animate_combat(name: String, frame: int, dt: float) -> void:
	for enemy in _run.enemies:
		enemy.pos.y += sin(_elapsed*2.0+enemy.id)*dt*12
	match name:
		"slash":
			if frame%_slash_interval == 0: _emit("slash",_run.player.pos,140,{"angle":int(frame/_slash_interval)*TAU/8,"weaponId":"manaSword"})
		"chain":
			if frame%30 == 0:
				var points := [_run.player.pos,_run.enemies[0].pos,_run.enemies[1].pos,_run.enemies[2].pos]
				for hop in range(3): _emit("chain",points[hop],10,{"target":points[hop+1],"sourceActor":"player" if hop == 0 else str(hop),"targetActor":str(hop+1),"hopIndex":hop,"weaponId":"chainLightning"})
		"projectiles":
			if frame%18 == 0:
				var weapons := ["manaBolt","piercingShot","manaShotgun","autoTurret"]
				for index in range(4):
					var start := Vector2(-420,-100+index*90)
					var context := {"contextId":frame*10+index,"sourceActor":"","weapon":weapons[index],"targetDistance":850.0}
					var stats := _run.weapon_stats({"id":weapons[index],"level":1,"branch":""})
					var count := int(stats.projectileCount)
					for pellet in range(count):
						var angle := (pellet/float(maxi(1,count-1))-0.5)*float(stats.get("spreadAngle",0.16)) if count>1 else 0.0
						_run.bullets.append({"visualId":_run.next_visual_id(),"context":context,"pos":start,"distance":0.0,"range":1000.0,"velocity":Vector2.from_angle(angle)*(350+index*75),"angle":angle,"sprite":Content.data.weapons[weapons[index]].visual.get("sprite","manaBolt")})
					_emit("muzzle",start,16,{"weaponId":weapons[index],"sourceActor":""})
				_run.hostile.append({"visualId":_run.next_visual_id(),"pos":Vector2(440,180),"velocity":Vector2(-400,-65)})
		"bombard":
			# Real timing: 0.546s lob plus the 0.9s explosion delay, blast on the last frame.
			if frame%45 == 0:
				_run.pending = [{"kind":"bombard","remaining":1.4,"duration":1.4,"target":Vector2(155,80),"pos":_run.player.pos,"stats":{"blastRadius":110.0},"context":{"contextId":frame,"sourceActor":"player","weapon":"manaBombard"}}]
			if frame%45 == 42: _emit("explosion",Vector2(155,80),110,{"weaponId":"manaBombard"})
		"installations":
			if frame == 0:
				for entity in _run.structures: _emit("structurePlace",entity.pos,45,{"weaponId":entity.weapon,"stage":"place","sourceActor":""})
			if frame%30 == 0: _emit("structureActivate",Vector2(0,120),150,{"weaponId":"manaField","stage":"pulse","sourceActor":""})
			if frame%45 == 24: _emit("mine",Vector2(-240,130),95,{"weaponId":"mineLayer"})
		"enemy-actions":
			if frame%45 == 0:
				_emit("enemyWarning",Vector2(30,150),65,{"duration":0.65,"sourceActor":"","target":Vector2(30,150)})
				_emit("chargeWarning",_run.enemies[1].pos,70,{"duration":0.6,"sourceActor":"2","angle":PI/3})
				_emit("selfDestructWarning",_run.enemies[0].pos,60,{"duration":0.75,"sourceActor":"1"})
			if frame%45 == 22:
				_emit("supportCast",_run.enemies[2].pos,85,{"sourceActor":"3"})
				_emit("bossAttack",Vector2(250,80),130,{"sourceActor":"4"})
				_emit("enemyProjectile",_run.enemies[0].pos,24,{"sourceActor":"1","angle":0.5})
		"pickups":
			if frame%7 == 0 and not _run.pickups.is_empty():
				var stone: Dictionary = _run.pickups.pop_front()
				_emit("pickup",stone.pos,22,{"target":_run.player.pos,"targetActor":"player"}); _emit("walletBonus",_run.player.pos,12)
				_run.currency += 1
		"walk":
			# Walk right, stop, turn and walk left, then walk up: start/stop, turn and vertical travel.
			var speed := 185.0*dt
			if frame < 30: _run.player.pos.x += speed; _run.player.facing = 1.0
			elif frame >= 45 and frame < 75: _run.player.pos.x -= speed; _run.player.facing = -1.0
			elif frame >= 75: _run.player.pos.y -= speed
			var stick: HeroMovement = _view.get_node_or_null("Stick")
			if stick:
				stick.direction = Vector2(1,0) if frame < 30 else (Vector2.ZERO if frame < 45 else (Vector2(-1,0) if frame < 75 else Vector2(0,-1)))
				stick.queue_redraw()
		"hits":
			# A steady stream of hits: every fifth one is critical; the sword sweeps too.
			if frame%5 == 0:
				var index := int(frame/5)%_run.enemies.size()
				var enemy: Dictionary = _run.enemies[index]
				var critical := int(frame/5)%5 == 4
				var direction: Vector2 = (enemy.pos-_run.player.pos).normalized()
				_emit("actorHit",enemy.pos,enemy.radius,{"actorId":str(enemy.id),"direction":direction,"damage":38.0 if critical else 12.0+index*3,"critical":critical})
				_emit("critical" if critical else "impact",enemy.pos,32 if critical else 20,{"targetActor":str(enemy.id),"angle":direction.angle(),"weaponId":"manaSword"})
			if frame%30 == 0: _emit("slash",_run.player.pos,190,{"angle":0.0,"weaponId":"manaSword"})
		"rewards":
			# Defeat one enemy every 12 frames: death pop, stone drop, then the stone flies in.
			if frame%12 == 0 and not _run.enemies.is_empty():
				var enemy: Dictionary = _run.enemies.pop_front()
				_emit("actorDeath",enemy.pos,enemy.radius,{"actorId":str(enemy.id),"definition":enemy.definition})
				_emit("death",enemy.pos,enemy.radius*2.0,{"targetActor":str(enemy.id),"stage":"death","sourceActor":""})
				_emit("stoneDrop",enemy.pos-Vector2(0,8),15,{"stage":"drop","sourceActor":""})
				_run.pickups.append({"pos":enemy.pos,"value":1.0,"units":1.0,"fly":frame+18})
			for stone in _run.pickups.duplicate():
				if stone.has("fly") and frame >= int(stone.fly):
					_run.pickups.erase(stone)
					_emit("pickup",stone.pos,22,{"target":_run.player.pos,"targetActor":"player"})
					_run.currency += 1
			if frame == 80:
				for index in range(6): _run.enemies.append(_enemy(index+11,"crawler",Vector2(-330+index*120,-110+(index%2)*60)))
		"dense":
			if frame%24 == 0:
				_emit("slash",_run.player.pos,140,{"angle":_elapsed,"weaponId":"manaSword"})
				_emit("chain",_run.player.pos,10,{"target":_run.enemies[3].pos,"targetActor":"4","weaponId":"chainLightning"})
				_emit("mine",Vector2(190,80),95,{"weaponId":"mineLayer"})
				_emit("enemyWarning",Vector2(-130,130),70,{"duration":0.6,"sourceActor":""})
			if frame%9 == 0:
				_emit("critical",_run.enemies[frame%19].pos,24,{"targetActor":str(frame%19+1)})
				_run.hostile.append({"visualId":_run.next_visual_id(),"pos":Vector2(420,-100),"velocity":Vector2(-450,130)})
			if frame%14 == 0:
				var context := {"contextId":frame,"sourceActor":"player","weapon":"manaBolt","targetDistance":600.0}
				_run.bullets.append({"visualId":_run.next_visual_id(),"context":context,"pos":_run.player.pos,"distance":0.0,"range":1000.0,"velocity":Vector2(440,-90),"angle":-0.2,"sprite":"manaBolt"})
	for bullet in _run.bullets:
		bullet.pos += bullet.velocity*dt; bullet.distance += bullet.velocity.length()*dt
	_run.bullets = _run.bullets.filter(func(bullet): return bullet.distance<1000)
	for bullet in _run.hostile: bullet.pos += bullet.velocity*dt
	_run.hostile = _run.hostile.filter(func(bullet): return bullet.pos.x>-600)
	for attack in _run.pending: attack.remaining -= dt
	_run.pending = _run.pending.filter(func(attack): return attack.remaining>0)

func _probe_lifecycle(name: String) -> void:
	var combat := _world._combat
	_emit("impact",_run.player.pos,22,{"contextId":9999})
	combat.sync(0.04)
	var before: Array = combat._playing.map(func(effect): return effect.age)
	combat.sync(0)
	var after: Array = combat._playing.map(func(effect): return effect.age)
	_checks.append({"id":name+":pause","passed":not before.is_empty() and before==after})
	var record: Dictionary = _records.back()
	_checks.append({"id":name+":budgets","passed":record.maximumEffects<=64 and record.maximumParticles<=192 and record.maximumShots<=160})
	combat.clear()
	_checks.append({"id":name+":cleanup","passed":combat._playing.is_empty() and combat._shots.is_empty()})

func _ui_scene(name: String) -> void:
	await _clear_scene(); _begin(name)
	var noop := func(_value=null,_other=null): pass
	var setup := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaSword","blessing":"","weekly":""}
	_run = HeroRun.new(Content.data,setup,Profile.meta)
	match name:
		"lobby": _view = HeroLobbyScreen.build(noop,"premiumLobbyEnergy")
		"selection": _view = HeroGateScreen.build(setup,2,noop,noop,noop,{})
		"shop":
			_run.phase = "shop"; _run.currency = 150
			_run.weapon_stock = []
			for id in ["manaSword","manaBolt","chainLightning","mineLayer"]: _run.weapon_stock.append({"id":id,"level":1,"locked":id=="manaBolt"})
			_view = HeroCombatUI.shop(_run,true,noop,noop,noop,noop)
		"growth": _view = HeroMetaScreens.build("growth",{"kind":"character","id":"awakener"},noop,noop)
		"supply": _view = HeroMetaScreens.build("supply",{},noop,noop)
		"result":
			_run.phase = "stageClear"; _run.reward = 350; _run.wave = 20
			_view = HeroCombatUI.result(_run,noop)
	_canvas.add_child(_view)
	_fx = HeroUIEffects.new(); _canvas.add_child(_fx)
	_fx.bind_view(_view,name,true); _fx.set_process(false)

func _probe_ui(name: String) -> void:
	_fx.show_effect("lock",{"rect":Rect2(25,30,90,55),"seed":7})
	var before: Array = _fx._effects.map(func(effect): return effect.age)
	_fx.advance_for_capture(0)
	_checks.append({"id":name+":uiPause","passed":not before.is_empty() and before==_fx._effects.map(func(effect): return effect.age)})
	for index in range(10): _fx.show_effect("lock",{"rect":Rect2(25,30,90,55),"seed":7})
	var snapshot := _fx.snapshot()
	_checks.append({"id":name+":uiBudget","passed":snapshot.particles<=48 and snapshot.effects<=20})
	_fx.queue_effect("growth",{"view_key":name,"rect":Rect2(25,30,90,55)})
	_fx.bind_view(_view,name+":other",false)
	await get_tree().process_frame
	_checks.append({"id":name+":screenExit","passed":_fx.snapshot().pending==0 and _fx.snapshot().effects==0})
	_fx.suspend(true)
	_checks.append({"id":name+":hidden","passed":_fx.snapshot().particles==0 and _fx.snapshot().effects==0})
	_fx.suspend(false); _fx.set_process(false)

func _animate_ui(name: String, frame: int) -> void:
	if frame%30 != 5: return
	var payload := {"anchor":"GateChoice_awakener","seed":42}
	match name:
		"selection": _fx.show_effect("select",payload); _fx.show_effect("detail",{"rect":Rect2(660,110,100,100),"seed":42})
		"shop": _fx.show_effect("acquire",{"anchor":"ShopProduct_0","seed":42}); _fx.show_effect("lock",{"anchor":"ShopProduct_1","seed":42})
		"growth": _fx.show_effect("growth",{"anchor":"GrowthArt","seed":42})
		"supply": _fx.show_effect("supply",{"anchor":"SupplyPreviewArt","seed":42})
		"result": _fx.show_effect("result",{"anchor":"ResultRewardArt","seed":42})
