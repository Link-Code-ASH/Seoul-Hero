class_name HeroCombatPresentation
extends Node2D

const EFFECT_SCENE = preload("res://scenes/combat/timed_vfx.tscn")
const PROJECTILE_SCENE = preload("res://scenes/combat/projectile_visual.tscn")
var _run: HeroRun
var _ground := Node2D.new()
var _actors := Node2D.new()
var _projectiles := Node2D.new()
var _effects := Node2D.new()
var _numbers := HeroDamageNumbers.new()
var _bombard_marks := HeroBombardMarks.new()
var _active: Dictionary = {}
var _actor_pool: Dictionary = {}
var _shots: Dictionary = {}
var _shot_heights: Dictionary = {}
var _shot_pool: Array = []
var _effect_pool: Array = []
var _playing: Array = []
var _presets: Dictionary = {}
var visible_world := Rect2(-640,-360,1280,720)

func _ready() -> void:
	add_child(_ground); _ground.add_child(_bombard_marks); add_child(_actors); add_child(_projectiles); add_child(_effects); add_child(_numbers)
	# Ground effects must remain above HeroWorld's floor, below every actor.
	_ground.z_index = 0; _actors.z_index = 1
	_actors.y_sort_enabled = true; _projectiles.z_index = 3; _effects.z_index = 4; _numbers.z_index = 5
	_presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/effects.json"))

func bind(state: HeroRun) -> void:
	if _run != null and _run.visual_event.is_connected(present): _run.visual_event.disconnect(present)
	clear(); _run = state
	if _run != null:
		_run.visual_event.connect(present)
		var actor := _take_actor("player","characters",_run.setup.character)
		actor.update_state(_run.player,0,108)

func _take_actor(key: String, group: String, id: String, structure: bool = false) -> Node2D:
	var pool_key := group+":"+id
	var profile: Dictionary = Content.visuals.get(group,{}).get(id,{})
	var pool: Array = _actor_pool.get(pool_key,[])
	var actor: Node2D
	if not pool.is_empty(): actor = pool.pop_back()
	elif structure:
		actor = HeroGroundedVisual.new()
		if Content.data.weapons[id].structure.kind == "aura": _ground.add_child(actor)
		else: _actors.add_child(actor)
	elif profile.get("rig","") == "sd": actor = HeroSDVisual.new(); _actors.add_child(actor)
	else: actor = HeroGroundedVisual.new(); _actors.add_child(actor)
	if actor is HeroSDVisual: actor.configure(key,profile)
	else: actor.configure(id,structure)
	actor.set_meta("pool",pool_key); _active[key] = actor
	return actor

func _release_actor(key: String) -> void:
	var actor: Node2D = _active[key]
	actor.visible = false
	var pool_key: String = actor.get_meta("pool")
	if not _actor_pool.has(pool_key): _actor_pool[pool_key] = []
	_actor_pool[pool_key].append(actor); _active.erase(key)

func _sync_actor(key: String, group: String, id: String, state: Dictionary, height: float, dt: float, seen: Dictionary, structure: bool = false) -> void:
	seen[key] = true
	var actor: Node2D = _active.get(key)
	if actor == null: actor = _take_actor(key,group,id,structure)
	# Reviving reuses the same foot coordinate, never leaves a dead visual active.
	if key == "player" and actor.dead and state.hp > 0: actor = _reset_player(key,group,id)
	actor.set_meta("height",height)
	actor.update_state(state,dt,height)
	actor.visible = visible_world.grow(140).has_point(state.pos)

func _reset_player(key: String, group: String, id: String) -> Node2D:
	_release_actor(key)
	return _take_actor(key,group,id)

func sync(dt: float) -> void:
	if _run == null: return
	var seen := {}
	var player_state: Dictionary = _run.player.duplicate(); player_state.age = _run.combat_time
	_sync_actor("player","characters",_run.setup.character,player_state,108,dt,seen)
	for enemy in _run.enemies: _sync_actor(str(enemy.id),"enemies",enemy.definition,enemy,enemy.radius*3.4,dt,seen)
	for entity in _run.structures:
		var state: Dictionary = entity.duplicate()
		var kind: String = _run.data.weapons[entity.weapon].structure.kind
		var height := 50.0 if kind == "turret" else 30.0 if kind == "mine" else 40.0
		if kind == "aura":
			var slots: Array = _run.owned.filter(func(slot): return slot.id == entity.weapon)
			if not slots.is_empty(): state.visualRadius = _run.weapon_stats(slots[0]).blastRadius
		_sync_actor("structure:"+entity.weapon+str(entity.pos),"structures",entity.weapon,state,height,dt,seen,true)
	for key in _active.keys():
		if seen.has(key): continue
		var actor: Node2D = _active[key]
		if actor.dead and actor.death_age < 0.44:
			actor.update_state({"pos":actor.position},dt,float(actor.get_meta("height",108)))
		else: _release_actor(key)
	_sync_projectiles(dt)
	_numbers.tick(dt)
	for effect in _playing:
		_follow_effect_anchors(effect)
		effect.tick(dt)
	for effect in _playing.duplicate():
		if effect.finished: _playing.erase(effect); _effect_pool.append(effect)

func _shot(key: String, texture: Texture2D, point: Vector2, angle: float, dimensions: Vector2, dt: float, seen: Dictionary, profile_key: String = "default") -> void:
	if texture == null: return
	seen[key] = true
	var shot: HeroProjectileVisual = _shots.get(key)
	if shot == null:
		if _shots.size() >= 160: return
		shot = _shot_pool.pop_back() if not _shot_pool.is_empty() else PROJECTILE_SCENE.instantiate()
		if not shot.is_inside_tree(): _projectiles.add_child(shot)
		shot.configure(texture,_projectile_dimensions(dimensions),_weapon_profile(profile_key)); _shots[key] = shot
	shot.scale = Vector2.ONE
	shot.update_state(point,angle,dt)
	shot.visible = visible_world.grow(100).has_point(point)

func _weapon_profile(key: String) -> Dictionary:
	var profiles: Dictionary = _presets.get("weapons",{})
	return profiles.get(key,profiles.get("default",{}))

func _projectile_dimensions(dimensions: Vector2) -> Vector2:
	return dimensions * float(_presets.get("projectiles",{}).get("displayScale",1.5))

func finish_player_death(dt: float) -> void:
	var actor: Node2D = _active.get("player")
	if actor != null and actor.dead and actor.death_age < 0.42:
		actor.update_state({"pos":actor.position,"hp":0.0},dt,float(actor.get_meta("height",108)))

func _sync_projectiles(dt: float) -> void:
	var seen := {}
	for bullet in _run.bullets:
		var key: String = "bullet:"+str(bullet.get("visualId",str(bullet.context.contextId)+":"+str(bullet.angle)))
		var heights := _flight_heights(key,bullet.context,bullet.angle,Vector2(24,13))
		var reach := maxf(1.0,float(bullet.context.get("targetDistance",bullet.range)))
		var progress := clampf(bullet.distance/reach,0,1)
		var point: Vector2 = bullet.pos + heights[0].lerp(heights[1],progress)
		var direction: Vector2 = bullet.velocity.normalized() + (heights[1]-heights[0])/reach if progress < 1 else bullet.velocity.normalized()
		# Point-blank targets inside the launch clearance show impact rather than a backwards flight.
		if direction.dot(bullet.velocity) <= 0: continue
		_shot(key,Content.trimmed_texture(bullet.sprite),point,direction.angle(),Vector2(24,13),dt,seen,str(bullet.context.get("weaponId",bullet.context.get("weapon","default"))))
	for i in range(_run.hostile.size()):
		var bullet: Dictionary = _run.hostile[i]
		if not bullet.has("visualId"): bullet.visualId = _run.next_visual_id()
		_shot("hostile:"+str(bullet.visualId),Content.trimmed_texture("hostileBolt"),bullet.pos,bullet.velocity.angle(),Vector2(22,15),dt,seen,"hostile")
	var marks: Array[Dictionary] = []
	for i in range(_run.pending.size()):
		var attack: Dictionary = _run.pending[i]
		if attack.kind != "bombard": continue
		var key := "bombard:"+str(attack.context.contextId)+":"+str(attack.target)
		var heights := _flight_heights(key,attack.context,(attack.target-attack.pos).angle(),Vector2(48,48))
		# The shell lobs over the short visual flight, then sits on the mark until the delayed blast.
		var elapsed: float = attack.duration-attack.remaining
		var flight := minf(float(_run.data.weaponConfig.get("bombardVisualDuration",0.546)),float(attack.duration))
		var t := clampf(elapsed/maxf(0.001,flight),0,1)
		var fuse := clampf((elapsed-flight)/maxf(0.001,float(attack.duration)-flight),0,1)
		var apex := clampf(attack.pos.distance_to(attack.target)*0.6,90.0,190.0)
		var lift := 4.0*apex*t*(1.0-t)
		var ground: Vector2 = attack.pos.lerp(attack.target,t)
		# Area explosions land on the ground; their radius remains a ground-plane radius.
		var point: Vector2 = ground+heights[0]*(1.0-t)-Vector2(0,lift+12.0*t)
		_shot(key,Content.trimmed_texture("bombardShell"),point,elapsed*7.0,Vector2(48,48),dt,seen,"manaBombard")
		var shot: HeroProjectileVisual = _shots.get(key)
		if shot != null:
			var swell := 1.0+0.18*sin(t*PI)
			if t >= 1.0: swell = 1.0+0.12*fuse+0.07*sin(elapsed*lerpf(12.0,30.0,fuse))
			shot.scale = Vector2.ONE*swell
		marks.append({"ground":ground,"height":lift/apex,"target":attack.target,"radius":float(attack.get("stats",{}).get("blastRadius",110.0)),"approach":t,"fuse":fuse})
	_bombard_marks.show_marks(marks)
	for slot in _run.owned:
		if _run.data.weapons[slot.id].behavior != "orbit": continue
		var stats := _run.weapon_stats(slot)
		var orbit_center: Vector2 = _run.player.pos + _orbit_display_offset(float(stats.range))
		for i in range(int(stats.projectileCount)):
			var angle: float = _run.combat_time*_run.data.weaponConfig.orbitAngularSpeed+TAU*i/stats.projectileCount
			# An orbiting shuriken is the attack projectile, never a held weapon.
			var definition: Dictionary = _run.data.weapons[slot.id]
			_shot("orbit:"+slot.id+str(i),Content.trimmed_texture(definition.visual.get("sprite","guardianShuriken")),orbit_center+Vector2.from_angle(angle)*stats.range,_run.combat_time*_run.data.weaponConfig.shurikenSpinSpeed,Vector2(40,40),dt,seen,slot.id)
	for key in _shots.keys():
		if seen.has(key): continue
		var shot: HeroProjectileVisual = _shots[key]; shot.reset(); _shot_pool.append(shot); _shots.erase(key)
	for key in _shot_heights.keys():
		if not seen.has(key): _shot_heights.erase(key)

func _orbit_display_offset(radius: float) -> Vector2:
	var actor: Node2D = _active.get("player")
	if actor == null: return _offset("player")
	var bounds: Rect2 = actor.visual_bounds()
	var center := bounds.get_center()
	# The orbit is centered on the visible doll rather than its foot coordinate.
	# Even a rotating tip must pass above the head at the top of the orbit.
	var half_diagonal := _projectile_dimensions(Vector2(40,40)).length()*0.5
	var gap := 6.0/maxf(0.001,transform.get_scale().x)
	center.y = minf(center.y,bounds.position.y+radius-half_diagonal-gap)
	return center

func _offset(id: String, socket: String = "impact") -> Vector2:
	var actor: Node2D = _active.get(id)
	if actor != null: return actor.socket_offset(socket)
	if id == "player": return Vector2(0,-47)
	if id.begins_with("structure:"): return Vector2(0,-24)
	if _run != null:
		for enemy in _run.enemies:
			if str(enemy.id) == id: return Vector2(0,-enemy.radius*3.4*0.46)
	return Vector2(0,-24)

func launch_offset(id: String, angle: float, dimensions: Vector2 = Vector2(24,13)) -> Vector2:
	var actor: Node2D = _active.get(id)
	if actor == null or id.begins_with("structure:"): return _offset(id,"muzzle")
	var bounds: Rect2 = actor.visual_bounds()
	var direction := Vector2.from_angle(angle)
	# Expand by the rotated projectile half-size so its rear edge also clears the body.
	var half := bounds.size*0.5 + Vector2(absf(cos(angle))*dimensions.x+absf(sin(angle))*dimensions.y,absf(sin(angle))*dimensions.x+absf(cos(angle))*dimensions.y)*0.5
	var distance := minf(half.x/absf(direction.x) if absf(direction.x)>0.0001 else INF,half.y/absf(direction.y) if absf(direction.y)>0.0001 else INF)
	var gap := 2.0/maxf(0.001,transform.get_scale().x)
	return bounds.get_center()+direction*(distance+gap)

func _flight_heights(key: String, context: Dictionary, angle: float, dimensions: Vector2) -> Array:
	if not _shot_heights.has(key):
		_shot_heights[key] = [launch_offset(context.get("sourceActor","player"),angle,_projectile_dimensions(dimensions)),_offset(context.get("targetActor",""))]
	return _shot_heights[key]

func present(payload: Dictionary) -> void:
	payload = payload.duplicate()
	var kind: String = payload.kind
	if kind == "cleanup": clear(); return
	if kind.begins_with("actor"):
		var key: String = payload.actorId
		var actor: Node2D = _active.get(key)
		if actor == null and kind == "actorDeath" and payload.has("definition"):
			actor = _take_actor(key,"enemies",payload.definition)
			actor.position = payload.pos
			actor.set_meta("height",_run.data.enemies[payload.definition].radius*3.4)
		if actor != null:
			actor.action(kind,payload)
			if kind == "actorHit" and payload.has("damage") and actor.visible:
				var head: Vector2 = actor.position+Vector2(0,actor.visual_bounds().position.y-4)
				_numbers.add(head,float(payload.damage),bool(payload.get("critical",false)))
		return
	if kind == "structureActivate":
		var installation: Node2D = _active.get(str(payload.get("sourceActor","")))
		if installation != null: installation.action(kind,payload)
	if kind in ["muzzle","enemyProjectile"]:
		var angle: float = payload.get("angle",0.0)
		if payload.has("visualId") and payload.has("context"):
			payload.pos += _flight_heights("bullet:"+str(payload.visualId),payload.context,angle,Vector2(24,13))[0]
		else: payload.pos += launch_offset(payload.get("sourceActor","player"),angle,_projectile_dimensions(Vector2(24,13)))
	elif kind in ["impact","critical","death"] and payload.has("targetActor"): payload.pos += _offset(payload.targetActor)
	elif kind == "pickup" and payload.has("targetActor"): payload.target += _offset(payload.targetActor)
	elif kind == "slash": payload.pos += _offset(payload.get("sourceActor","player"),"impact")
	elif kind == "chain":
		var source_actor: String = str(payload.get("sourceActor","player"))
		var target_actor: String = str(payload.get("targetActor",""))
		var target_point: Vector2 = payload.target + _offset(target_actor)
		if source_actor == "player": payload.pos += launch_offset(source_actor,(target_point-payload.pos).angle(),Vector2(8,8))
		else: payload.pos += _offset(source_actor)
		payload.target = target_point
	if not _presets.has(kind): return
	if not visible_world.grow(float(_presets.limits.get("outsideMargin",140))).has_point(payload.pos) and kind != "chain": return
	var preset: Dictionary = _presets[kind].duplicate(true)
	var stage_variant: Dictionary = preset.get("stageVariants",{}).get(str(payload.get("stage","")),{})
	preset.merge(stage_variant,true)
	var priority := int(preset.get("priority",0))
	if kind in ["enemyWarning","chargeWarning","selfDestructWarning"]: priority = maxi(priority,8)
	if kind in ["impact","critical"] and str(payload.get("targetActor","")) == "player": priority = maxi(priority,7)
	if float(payload.get("duration",0)) > 0: preset.duration = payload.duration
	var profile := _weapon_profile(str(payload.get("weaponId","hostile" if kind == "enemyProjectile" else "default")))
	if kind in ["muzzle","enemyProjectile"]: preset.color = profile.get("muzzleColor",preset.get("color","#b9fff5"))
	elif kind == "impact": preset.color = profile.get("impactColor",preset.get("color","#b9fff5"))
	if _playing.size() >= int(_presets.limits.active):
		var lowest: HeroTimedVfx = null
		for candidate in _playing:
			if int(candidate.get_meta("priority",0)) < priority and (lowest == null or int(candidate.get_meta("priority",0)) < int(lowest.get_meta("priority",0))): lowest = candidate
		if lowest == null: return
		_playing.erase(lowest); lowest.reset(); _effect_pool.append(lowest)
	var effect: HeroTimedVfx = _effect_pool.pop_back() if not _effect_pool.is_empty() else EFFECT_SCENE.instantiate()
	var effect_layer: Node2D = _ground if bool(preset.get("grounded",preset.get("ground",false))) else _effects
	if not effect.is_inside_tree(): effect_layer.add_child(effect)
	elif effect.get_parent() != effect_layer: effect.reparent(effect_layer,false)
	var used := 0
	for active in _playing: used += int(active.get_meta("particles",0))
	preset.particles = mini(int(preset.get("particles",0)),maxi(0,int(_presets.limits.particles)-used))
	effect.set_meta("particles",preset.particles)
	effect.set_meta("priority",priority)
	effect.set_meta("chainSource",str(payload.get("sourceActor","")) if kind == "chain" else "")
	effect.set_meta("chainTarget",str(payload.get("targetActor","")) if kind == "chain" else "")
	effect.set_meta("lastSource",Vector2(payload.pos))
	effect.set_meta("lastTarget",Vector2(payload.get("target",payload.pos)))
	effect.set_meta("anchorActor",str(payload.get("sourceActor","")) if bool(preset.get("followActor",false)) else "")
	effect.configure(payload,preset); _playing.append(effect)
	if kind == "chargeWarning": effect.rotation = float(payload.get("angle",0.0))

func _follow_effect_anchors(effect: HeroTimedVfx) -> void:
	if str(effect.get_meta("kind","")) == "chain":
		var source_id := str(effect.get_meta("chainSource",""))
		var target_id := str(effect.get_meta("chainTarget",""))
		var source: Vector2 = effect.get_meta("lastSource",effect.position)
		var target: Vector2 = effect.get_meta("lastTarget",effect.position)
		if _active.has(target_id) and not _active[target_id].dead: target = _active[target_id].position+_offset(target_id)
		if _active.has(source_id) and not _active[source_id].dead:
			source = _active[source_id].position
			source += launch_offset(source_id,(target-source).angle(),Vector2(8,8)) if source_id == "player" else _offset(source_id)
		effect.set_meta("lastSource",source); effect.set_meta("lastTarget",target)
		effect.update_chain_endpoints(source,target)
	else:
		var anchor := str(effect.get_meta("anchorActor",""))
		if _active.has(anchor) and not _active[anchor].dead: effect.position = _active[anchor].position
		elif not anchor.is_empty() and str(effect.get_meta("kind","")) in ["chargeWarning","selfDestructWarning"]: effect.reset()

func clear() -> void:
	for key in _active.keys(): _release_actor(key)
	for effect in _playing: effect.reset(); _effect_pool.append(effect)
	_playing.clear()
	for shot in _shots.values(): shot.reset(); _shot_pool.append(shot)
	_shots.clear()
	_shot_heights.clear()
	_numbers.clear()
	_bombard_marks.show_marks([])
