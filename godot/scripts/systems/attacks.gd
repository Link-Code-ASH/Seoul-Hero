class_name HeroAttacks
extends RefCounted

var grid: HeroSpatial

func _init(index: HeroSpatial) -> void:
	grid = index

func nearest(run: HeroRun, position: Vector2, reach: float, excluded: Array = []) -> Dictionary:
	var best := {}
	var distance := reach
	for enemy in grid.nearby(position, reach):
		if enemy.hp <= 0 or enemy.id in excluded: continue
		var d: float = enemy.pos.distance_to(position)
		if d <= distance: distance = d; best = enemy
	return best

func context(run: HeroRun, stats: Dictionary, weapon_id: String) -> Dictionary:
	return {"contextId":run.next_id(),"criticalChance":stats.criticalChance,"criticalDamage":stats.criticalDamage,"lifesteal":stats.lifesteal,"healingRemaining":minf(run.data.statRules.lifestealPerAttack,run.stats.maxHp * run.data.statRules.lifestealMaxHpFraction),"weapon":weapon_id}

func update(run: HeroRun, dt: float) -> void:
	for slot in run.owned:
		# Idle time must not become an attack debt when a target enters range.
		slot.cooldown = maxf(0.0, slot.cooldown - dt)
		var definition: Dictionary = run.data.weapons[slot.id]
		var stats := run.weapon_stats(slot)
		if definition.has("structure"):
			if slot.cooldown <= 0: _place(run, slot, definition, stats)
			continue
		if definition.behavior == "orbit":
			_orbit(run, slot, stats)
			continue
		if slot.cooldown > 0: continue
		var target := nearest(run, run.player.pos, stats.range)
		if target.is_empty(): continue
		slot.cooldown = stats.cooldown
		var origin: Vector2 = run.player.pos
		var angle: float = (target.pos - origin).angle()
		var attack := context(run, stats, slot.id)
		attack["sourceActor"] = "player"; attack["targetActor"] = str(target.id)
		attack["targetDistance"] = origin.distance_to(target.pos)
		run.visual_event.emit({"kind":"actorAttack","actorId":"player","pos":origin,"angle":angle,"radius":stats.range,"weaponId":slot.id})
		match definition.behavior:
			"projectile":
				fire(run, definition, stats, target, origin, attack)
			"slash":
				for i in range(int(stats.repeatCount)):
					run.pending.append({"kind":"slash","pos":origin,"angle":angle,"stats":stats,"context":attack,"remaining":i * stats.repeatInterval})
				run.event.emit("slashAttack")
			"chain":
				run.audio_weapon(slot.id, "initial", {"attackId":attack.contextId})
				var audio_stages: Dictionary = run.data.get("audioConnections", {}).get("weaponStages", {}).get(slot.id, {})
				var hop_limit := int(audio_stages.get("maxHopsPerAttack", 0))
				var hop_cue := str(audio_stages.get("hop", ""))
				var hop_interval := float(run.data.sfx.get(hop_cue, {}).get("interval", 0.045))
				var from: Vector2 = origin
				var visited: Array = []
				var enemy: Dictionary = target
				for i in range(int(stats.projectileCount)):
					if enemy.is_empty(): break
					run.effect("chain", from, 30.0, 0.0, 0.0, enemy.pos,{"delay":i*0.025,"hopIndex":i,"sourceActor":"player" if i == 0 else str(visited.back()),"targetActor":str(enemy.id)})
					if i > 0 and i <= hop_limit:
						run.audio_weapon(slot.id, "hop", {"attackId":attack.contextId,"hopIndex":i,"delay":i * hop_interval})
					visited.append(enemy.id)
					hit(run, enemy, stats.damage, attack)
					from = enemy.pos
					enemy = nearest(run, from, stats.chainRange, visited)
				run.event.emit("chainAttack")
			"bombard":
				for i in range(int(stats.projectileCount)):
					var position: Vector2 = target.pos + Vector2.from_angle(randf() * TAU) * i * 18.0
					run.pending.append({"kind":"bombard","pos":origin,"target":position,"stats":stats,"context":attack,"remaining":run.data.weaponConfig.bombardVisualDuration + stats.explosionDelay + i * 0.08,"duration":run.data.weaponConfig.bombardVisualDuration + stats.explosionDelay + i * 0.08})
				run.audio_weapon(slot.id, "launch", {"attackId":attack.contextId})
				run.event.emit("bombardAttack")
	_process_pending(run, dt)
	_projectiles(run, dt)
	_structures(run, dt)
	_deaths(run)

func fire(run: HeroRun, definition: Dictionary, stats: Dictionary, target: Dictionary, origin: Vector2, attack: Dictionary = {}) -> void:
	var base_angle: float = (target.pos - origin).angle()
	if attack.is_empty(): attack = context(run, stats, definition.id)
	attack["sourceActor"] = "structure:"+definition.id+str(origin) if definition.has("structure") else "player"
	attack["targetActor"] = str(target.id); attack["targetDistance"] = origin.distance_to(target.pos)
	var launched := false
	for i in range(int(stats.projectileCount)):
		if run.bullets.size() >= int(run.data.game.combat.maxProjectiles): break
		var spread: float = stats.get("spreadAngle", run.data.game.combat.projectileSpread * maxf(1.0, stats.projectileCount - 1))
		var angle: float = base_angle + (0.0 if stats.projectileCount <= 1 else (i / (stats.projectileCount - 1.0) - 0.5) * spread)
		var visual_id := run.next_id()
		launched = true
		run.bullets.append({"visualId":visual_id,"pos":origin,"previous":origin,"velocity":Vector2.from_angle(angle) * stats.projectileSpeed,"damage":stats.damage,"radius":stats.projectileRadius,"distance":0.0,"range":stats.range,"remaining":stats.duration,"penetration":int(stats.penetration),"hits":[],"context":attack,"sprite":definition.visual.get("sprite", "manaBolt"),"angle":angle})
		run.effect("muzzle", origin, 25.0, angle,1.0472,Vector2.ZERO,{"sourceActor":attack.sourceActor,"visualId":visual_id,"context":attack})
	if launched: run.audio_weapon(definition.id, "launch", {"attackId":attack.contextId})
	run.event.emit("turretFired" if definition.has("structure") else "piercingAttack" if "PIERCING" in definition.capabilities and definition.id != "manaBolt" else "weaponFired")

func hit(run: HeroRun, enemy: Dictionary, damage: float, attack: Dictionary) -> void:
	if enemy.hp <= 0: return
	if not attack.get("itemProc",false): damage *= HeroItemEffects.damage_multiplier(run,enemy,run.player.pos)
	var critical: bool = randf() < attack.criticalChance
	var actual: float = damage * (attack.criticalDamage if critical else 1.0) * 100.0 / (100.0 + maxf(0.0, enemy.armor))
	actual = minf(actual, enemy.hp)
	enemy.hp -= actual; enemy.flash = 0.09
	run.visual_event.emit({"kind":"actorHit","actorId":str(enemy.id),"pos":enemy.pos,"direction":(enemy.pos - run.player.pos).normalized()})
	HeroTelemetry.hit(run,attack.weapon,actual,critical,enemy.hp <= 0)
	var healing: float = maxf(0.0, minf(minf(actual * attack.lifesteal, attack.healingRemaining), run.stats.maxHp - run.player.hp))
	if run.player.hp > 0: run.player.hp += healing; attack.healingRemaining -= healing
	run.effect("critical" if critical else "impact", enemy.pos, 32.0 if critical else 20.0,0.0,1.0472,Vector2.ZERO,{"targetActor":str(enemy.id)})
	run.event.emit("critical" if critical else "enemyHit")

func area(run: HeroRun, position: Vector2, radius: float, damage: float, attack: Dictionary) -> void:
	for enemy in grid.nearby(position, radius):
		if enemy.pos.distance_to(position) <= radius: hit(run, enemy, damage, attack)

func _process_pending(run: HeroRun, dt: float) -> void:
	var kept: Array = []
	for attack in run.pending:
		attack.remaining -= dt
		if attack.remaining > 0: kept.append(attack); continue
		if attack.kind == "itemBurst":
			area(run,attack.pos,attack.radius,attack.damage,attack.context)
			run.effect("shockwave",attack.pos,attack.radius)
			continue
		var stats: Dictionary = attack.stats
		if attack.kind == "bombard":
			run.audio_weapon(attack.context.weapon, "impact", {"attackId":attack.context.contextId})
			area(run, attack.target, stats.blastRadius, stats.damage, attack.context)
			run.effect("explosion", attack.target, stats.blastRadius)
			run.event.emit("bombardAttack")
		else:
			run.audio_weapon(attack.context.weapon, "attack", {"attackId":attack.context.contextId})
			var arc: float = stats.attackAngle * stats.areaScale
			var reach: float = stats.range
			for enemy in grid.nearby(attack.pos, reach):
				var direction: Vector2 = enemy.pos - attack.pos
				if direction.length() <= reach and absf(angle_difference(attack.angle, direction.angle())) <= arc * 0.5:
					hit(run, enemy, stats.damage, attack.context)
			run.effect("slash", attack.pos, reach, attack.angle, arc,Vector2.ZERO,{"sourceActor":"player","weaponId":attack.context.weapon})
	run.pending = kept

func _projectiles(run: HeroRun, dt: float) -> void:
	var kept: Array = []
	for bullet in run.bullets:
		bullet.previous = bullet.pos
		bullet.pos += bullet.velocity * dt
		bullet.distance += bullet.velocity.length() * dt; bullet.remaining -= dt
		if bullet.distance > bullet.range or bullet.remaining <= 0: continue
		var candidates := grid.nearby((bullet.pos + bullet.previous) * 0.5, bullet.velocity.length() * dt * 0.5 + bullet.radius + 80.0)
		candidates.sort_custom(func(a,b): return a.pos.distance_squared_to(bullet.previous) < b.pos.distance_squared_to(bullet.previous))
		for enemy in candidates:
			if enemy.hp <= 0 or enemy.id in bullet.hits: continue
			var point := Geometry2D.get_closest_point_to_segment(enemy.pos, bullet.previous, bullet.pos)
			if point.distance_to(enemy.pos) > enemy.radius + bullet.radius: continue
			bullet.hits.append(enemy.id)
			hit(run, enemy, bullet.damage, bullet.context)
			bullet.penetration -= 1
			if bullet.penetration < 0: break
		if bullet.penetration >= 0: kept.append(bullet)
	run.bullets = kept

func _orbit(run: HeroRun, slot: Dictionary, stats: Dictionary) -> void:
	if not slot.has("orbitHits"): slot.orbitHits = {}
	if slot.cooldown <= 0:
		slot.cooldown = stats.cooldown
		slot["orbitContext"] = context(run, stats, slot.id)
	var count := int(stats.projectileCount)
	for i in range(count):
		var angle: float = run.combat_time * run.data.weaponConfig.orbitAngularSpeed + i * TAU / count
		var position: Vector2 = run.player.pos + Vector2.from_angle(angle) * stats.range
		for enemy in grid.nearby(position, run.data.weaponConfig.orbitHitRadius + 80.0):
			var key := str(i) + ":" + str(enemy.id)
			if enemy.pos.distance_to(position) <= run.data.weaponConfig.orbitHitRadius + enemy.radius and run.combat_time - slot.orbitHits.get(key, -999.0) >= stats.cooldown:
				hit(run, enemy, stats.damage, slot.orbitContext)
				slot.orbitHits[key] = run.combat_time
				run.audio_weapon(slot.id, "contact", {"attackId":slot.orbitContext.contextId})
				run.event.emit("orbitAttack")
	if slot.orbitHits.size() > 1000:
		for key in slot.orbitHits.keys():
			if run.combat_time - slot.orbitHits[key] > 5.0: slot.orbitHits.erase(key)

func _place(run: HeroRun, slot: Dictionary, definition: Dictionary, stats: Dictionary) -> void:
	var limit: int = definition.structure.maxCount
	for effect in run.item_effects:
		if effect.type == "structureLimit" and effect.tag in definition.capabilities: limit += effect.value
	var blessing: Dictionary = run.data.blessings.get(run.setup.blessing, {})
	if definition.capabilities.has("STRUCTURE") and blessing.has("structureLimitAtLevel") and run.setup.get("blessingLevel", 0) >= blessing.structureLimitAtLevel: limit += 1
	if run.structures.filter(func(entity): return entity.weapon == slot.id).size() >= limit or run.structures.size() >= 48: return
	var position := Vector2.ZERO
	for i in range(24):
		position = Vector2(randf_range(-run.map.arenaWidth * 0.5 + 45.0,run.map.arenaWidth * 0.5 - 45.0),randf_range(-run.map.arenaHeight * 0.5 + 45.0,run.map.arenaHeight * 0.5 - 45.0))
		if position.distance_to(run.player.pos) > 160.0 and run.structures.all(func(entity): return entity.pos.distance_to(position) > 60.0): break
	run.structures.append({"weapon":slot.id,"pos":position,"cooldown":0.0,"age":0.0})
	slot.cooldown = minf(definition.structure.placementInterval, stats.cooldown) if definition.structure.kind == "mine" else definition.structure.placementInterval
	var placement_audio := {"attackId":slot.id + ":place:" + str(run.combat_time)}
	if definition.structure.kind == "mine":
		run.audio_weapon(slot.id, "place", placement_audio)
		run.event.emit("minePlaced")
	elif definition.structure.kind == "aura":
		run.audio_weapon(slot.id, "activate", placement_audio)
		run.event.emit("fieldActivated")

func _structures(run: HeroRun, dt: float) -> void:
	var kept: Array = []
	for entity in run.structures:
		var slot: Dictionary = run.owned.filter(func(weapon): return weapon.id == entity.weapon)[0]
		var definition: Dictionary = run.data.weapons[entity.weapon]
		var stats := run.weapon_stats(slot)
		entity.cooldown -= dt; entity.age += dt
		var remove := false
		if entity.cooldown <= 0:
			if definition.structure.kind == "turret":
				var target := nearest(run, entity.pos, stats.range)
				if not target.is_empty(): fire(run, definition, stats, target, entity.pos); entity.cooldown = stats.cooldown
			else:
				var triggered: bool = definition.structure.kind == "aura" or grid.nearby(entity.pos, definition.structure.triggerRadius + 80.0).any(func(enemy): return enemy.hp > 0 and enemy.pos.distance_to(entity.pos) <= definition.structure.triggerRadius + enemy.radius)
				if triggered:
					area(run, entity.pos, stats.blastRadius, stats.damage, context(run, stats, slot.id))
					entity.cooldown = stats.cooldown
					if definition.structure.kind == "mine":
						run.audio_weapon(slot.id, "impact", {"attackId":slot.id + ":impact:" + str(run.combat_time)})
						run.effect("mine",entity.pos,stats.blastRadius); run.event.emit("mineExploded"); remove = true
		if not remove: kept.append(entity)
	run.structures = kept

func _deaths(run: HeroRun) -> void:
	var dead: Array = run.enemies.filter(func(enemy): return enemy.hp <= 0)
	run.enemies = run.enemies.filter(func(enemy): return enemy.hp > 0)
	for enemy in dead:
		var definition: Dictionary = run.data.enemies[enemy.definition]
		run.visual_event.emit({"kind":"actorDeath","actorId":str(enemy.id),"definition":enemy.definition,"pos":enemy.pos})
		run.effect("death", enemy.pos, enemy.radius * 2.0)
		if not enemy.rewardEligible: continue
		run.kills += 1
		HeroItemEffects.killed(run)
		HeroTelemetry.death(run,enemy.definition)
		if run.pickups.size() < int(run.data.game.combat.maxPickups): run.pickups.append({"pos":enemy.pos,"value":enemy.reward,"units":1.0})
		else:
			var pickup: Dictionary = run.pickups.back()
			pickup.value += enemy.reward; pickup.units += 1.0
		run.event.emit("enemyKilled")
		if definition.behavior == "splitter": HeroEnemyBrain.summon(run, enemy, definition.get("childId", "swarm"), int(run.data.enemyRules.splitCount))
