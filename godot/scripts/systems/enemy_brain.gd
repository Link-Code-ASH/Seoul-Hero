class_name HeroEnemyBrain
extends RefCounted

static func move(run: HeroRun, enemy: Dictionary, target: Vector2, dt: float, speed: float = -1.0) -> void:
	var before: Vector2 = enemy.pos
	enemy.pos = HeroArena.approach(enemy.pos,target,(enemy.speed if speed < 0 else speed)*dt,enemy.radius,run.map,enemy.action != "dash")
	if absf(enemy.pos.x - before.x) > 0.01: enemy.facing = signf(enemy.pos.x - before.x)

static func update(run: HeroRun, dt: float, grid: HeroSpatial) -> void:
	var rules: Dictionary = run.data.enemyRules
	# Summons append to the live array; iterate a snapshot to preserve one tick per actor.
	for enemy in run.enemies.duplicate():
		if enemy.hp <= 0: continue
		enemy.age += dt; enemy.timer -= dt; enemy.flash = maxf(0.0, enemy.flash - dt)
		enemy.hp = minf(enemy.maxHp, enemy.hp + enemy.maxHp * enemy.regeneration * dt)
		var definition: Dictionary = run.data.enemies[enemy.definition]
		var distance: float = enemy.pos.distance_to(run.player.pos)
		match definition.behavior:
			"charge","ambush": _charge(run, enemy, definition, dt, distance)
			"boss": _boss(run, enemy, definition, dt)
			"ranged":
				if enemy.action == "warning":
					if enemy.timer <= 0:
						_attack_pose(run, enemy)
						shoot(run, enemy.pos, (enemy.aim - enemy.pos).angle(), enemy.damage, enemy)
						enemy.action = "move"; enemy.timer = rules.rangedCooldown
				else:
					if distance < rules.rangedDistance * 0.7: move(run, enemy, enemy.pos * 2.0 - run.player.pos, dt)
					elif distance > rules.rangedDistance: move(run, enemy, run.player.pos, dt)
					if enemy.timer <= 0 and distance < rules.rangedDistance * 1.5:
						enemy.aim = run.player.pos; enemy.timer = rules.rangedWarning; enemy.action = "warning"
						_visual_action(run,enemy,"enemyWarning","windup",rules.projectileRadius,rules.rangedWarning,enemy.aim,"projectile")
			"tank": _quake(run, enemy, definition, dt, distance)
			"bomber":
				if enemy.action == "warning":
					if enemy.timer <= 0:
						_attack_pose(run, enemy)
						area(run, enemy.pos, rules.bomberRadius, 0.0, enemy.damage,enemy,"selfDestruct")
						enemy.hp = 0; enemy.rewardEligible = false
				elif distance <= rules.bomberTrigger:
					enemy.action = "warning"; enemy.timer = rules.bomberWarning
					run.audio_action("selfDestructWarning", _audio_details(run, enemy, "windup"))
					_visual_action(run,enemy,"selfDestructWarning","windup",rules.bomberRadius,rules.bomberWarning,enemy.pos,"selfDestruct")
				else: move(run, enemy, run.player.pos, dt)
			"support":
				move(run, enemy, run.player.pos, dt)
				if enemy.timer <= 0:
					run.audio_action("supportOrSummonCast", _audio_details(run, enemy, "cast"))
					_visual_action(run,enemy,"supportCast","cast",rules.supportRadius,0.0,enemy.pos,"heal")
					_attack_pose(run, enemy)
					for other in grid.nearby(enemy.pos, rules.supportRadius):
						if other.id != enemy.id and other.pos.distance_to(enemy.pos) <= rules.supportRadius: other.hp = minf(other.maxHp, other.hp + other.maxHp * rules.supportHealFraction)
					enemy.timer = rules.supportInterval
			"summoner":
				if distance > rules.rangedDistance: move(run, enemy, run.player.pos, dt)
				# A summon rule keeps casting while few of its own minions live; without one the lifetime cap applies.
				var rule: Dictionary = definition.get("summon",{})
				var room := int(rules.maxSummonsPerEnemy) - int(enemy.summons)
				if not rule.is_empty(): room = int(rule.alive) - run.enemies.filter(func(other): return other.get("parent",-1) == enemy.id and other.hp > 0).size()
				if enemy.timer <= 0 and distance < rules.rangedDistance * 1.5 and room > 0:
					run.audio_action("supportOrSummonCast", _audio_details(run, enemy, "cast"))
					_visual_action(run,enemy,"supportCast","cast",rules.summonOffset,0.0,enemy.pos,"summon")
					_attack_pose(run, enemy)
					summon(run, enemy, definition.get("childId", "swarm"), mini(room,int(rule.get("count",2))),rule.is_empty())
					enemy.timer = float(rule.get("interval",rules.summonInterval))
			"defender":
				enemy.armor = enemy.baseArmor + (rules.defenderArmor if fmod(enemy.age, rules.defenderCycle) < rules.defenderGuard else 0.0)
				move(run, enemy, run.player.pos, dt)
			"skirmish","swarm":
				var direction: Vector2 = (run.player.pos - enemy.pos).normalized()
				if definition.behavior == "skirmish": direction = direction.rotated(sin(enemy.age * 5 + enemy.id) * rules.weaveAmplitude)
				else:
					var separation := Vector2.ZERO
					var count := 0
					for other in grid.nearby(enemy.pos, rules.swarmRadius):
						var d: float = enemy.pos.distance_to(other.pos)
						if d > 0 and d < rules.swarmRadius: separation += (enemy.pos - other.pos).normalized() * (1.0 - d / rules.swarmRadius)
						count += 1
						if count >= rules.swarmNeighbors: break
					var adjusted := direction + separation * 0.42
					if adjusted.length() >= 0.2: direction = adjusted.normalized()
				move(run, enemy, enemy.pos + direction * 200.0, dt)
			_: move(run, enemy, run.player.pos, dt)
		if enemy.aura:
			enemy.auraTimer -= dt
			if enemy.auraTimer <= 0:
				_attack_pose(run, enemy)
				area(run, enemy.pos, rules.auraRadius, rules.auraWarning, rules.auraDamage,enemy,"aura"); enemy.auraTimer = rules.auraInterval
		if enemy.pos.distance_to(run.player.pos) < enemy.radius + run.character.radius:
			if run.player.invulnerability <= 0: _attack_pose(run, enemy)
			damage_player(run, enemy.damage,enemy.definition,{"sourceActor":str(enemy.id),"sourcePosition":enemy.pos,"monsterId":enemy.definition,"behavior":definition.behavior})

static func _audio_details(run: HeroRun, enemy: Dictionary, stage: String, pattern: String = "") -> Dictionary:
	var definition: Dictionary = run.data.enemies[enemy.definition]
	return {"attackId":str(enemy.id) + ":" + str(run.combat_time),"enemyId":str(enemy.id),"monsterId":enemy.definition,"behavior":definition.behavior,"stage":stage,"pattern":pattern}

static func _visual_action(run: HeroRun, enemy: Dictionary, kind: String, stage: String, radius: float, duration: float = 0.0, target: Vector2 = Vector2.INF, pattern: String = "", position: Vector2 = Vector2.INF) -> void:
	var payload := _audio_details(run,enemy,stage,pattern)
	var aim: Vector2 = enemy.get("aim",run.player.pos) if target == Vector2.INF else target
	payload.merge({"kind":kind,"actorId":str(enemy.id),"contextId":payload.attackId,"sourceActor":str(enemy.id),"targetActor":"" if kind == "supportCast" else "player","pos":enemy.pos if position == Vector2.INF else position,"sourcePosition":enemy.pos,"target":aim,"radius":radius,"duration":duration,"angle":(aim-enemy.pos).angle()},true)
	run.visual_event.emit(payload)

static func _attack_pose(run: HeroRun, enemy: Dictionary) -> void:
	_visual_action(run,enemy,"actorAttack","attack",enemy.radius,0.0,run.player.pos)

static func _charge(run: HeroRun, enemy: Dictionary, definition: Dictionary, dt: float, distance: float) -> void:
	var rules: Dictionary = run.data.enemyRules
	var charge: Dictionary = definition.get("charge", {"triggerRange":rules.chargeTriggerRange,"warning":rules.ambushWarning if definition.behavior == "ambush" else rules.chargeWarning,"duration":rules.chargeDuration,"speed":rules.ambushSpeed if definition.behavior == "ambush" else rules.chargeSpeed,"cooldown":rules.ambushCooldown if definition.behavior == "ambush" else rules.chargeCooldown})
	if enemy.action == "warning":
		if enemy.timer <= 0:
			_attack_pose(run, enemy)
			enemy.action = "dash"; enemy.timer = charge.duration
	elif enemy.action == "dash":
		move(run, enemy, enemy.aim, dt, charge.speed * run.data.enemyMoveScale)
		if enemy.timer <= 0:
			enemy["repeats"] = int(enemy.get("repeats",1)) - 1
			if enemy.repeats > 0:
				# A repeated dash re-aims after a short second warning.
				var again := float(charge.get("repeatWarning",0.3))
				enemy.aim = run.player.pos; enemy.action = "warning"; enemy.timer = again
				_visual_action(run,enemy,"chargeWarning","windup",enemy.radius,again,enemy.aim,"charge")
			else: enemy.action = "move"; enemy.timer = charge.cooldown
	elif enemy.timer <= 0 and distance < charge.triggerRange:
		enemy.aim = run.player.pos; enemy.action = "warning"; enemy.timer = charge.warning
		enemy["repeats"] = int(charge.get("repeats",1))
		run.audio_action("chargeWindup", _audio_details(run, enemy, "windup"))
		_visual_action(run,enemy,"chargeWarning","windup",enemy.radius,charge.warning,enemy.aim,"charge")
	elif definition.behavior == "ambush": move(run, enemy, enemy.pos + (run.player.pos - enemy.pos).normalized().rotated(0.6) * 200.0, dt)
	else: move(run, enemy, run.player.pos, dt)
	enemy.alpha = 0.4 if definition.behavior == "ambush" and enemy.action == "move" else 1.0

# 땅울림: walk in, hop in place through the warning, the blast lands at touchdown.
static func _quake(run: HeroRun, enemy: Dictionary, definition: Dictionary, dt: float, distance: float) -> void:
	var rules: Dictionary = run.data.enemyRules
	var quake: Dictionary = definition.get("quake",{})
	var radius := float(quake.get("radius",rules.tankRadius))
	var warning := float(quake.get("warning",rules.tankWarning))
	if enemy.action == "hop":
		if enemy.timer > 0: return
		_attack_pose(run, enemy)
		enemy["repeats"] = int(enemy.get("repeats",1)) - 1
		enemy.action = "move"
		# The cooldown runs from the start of the hop, as it did before the hop existed.
		enemy.timer = float(quake.get("repeatDelay",0.7)) if enemy.repeats > 0 else maxf(0.2,float(quake.get("cooldown",rules.tankCooldown)) - warning)
		return
	move(run, enemy, run.player.pos, dt)
	var pending := int(enemy.get("repeats",0)) > 0
	if enemy.timer > 0 or (not pending and distance >= radius): return
	if not pending: enemy["repeats"] = int(quake.get("repeats",1))
	enemy.action = "hop"; enemy.timer = warning; enemy["hop"] = warning
	area(run, enemy.pos, radius, warning, enemy.damage,enemy,"tank")

# Dedicated boss pattern: never stops circling while it scatters turning rings of bullets.
static func _boss_spiral(run: HeroRun, enemy: Dictionary, pattern: Dictionary, dt: float) -> void:
	var toward: Vector2 = (run.player.pos - enemy.pos).normalized()
	var before: Vector2 = enemy.pos
	var pace: float = enemy.speed * (1.0 if enemy.action == "move" else 0.6)
	if before.distance_to(run.player.pos) > float(pattern.radius): move(run, enemy, run.player.pos, dt, pace)
	else:
		move(run, enemy, enemy.pos + toward.rotated(1.35 * float(enemy.get("orbit",1.0))) * 200.0, dt, pace)
		# Circle the other way when the arena edge blocks the path.
		if enemy.pos.distance_to(before) < pace * dt * 0.4: enemy["orbit"] = -float(enemy.get("orbit",1.0))
	if enemy.timer > 0: return
	if enemy.action == "move":
		enemy.aim = run.player.pos; enemy.action = "warning"; enemy.timer = pattern.warning
		_visual_action(run,enemy,"enemyWarning","windup",enemy.radius,pattern.warning,enemy.aim,"volley")
		return
	var rings := int(pattern.get("volleys",1))
	if enemy.action == "warning":
		enemy.action = "volley"; enemy["repeats"] = rings
		run.audio_action("bossMajorAttack", _audio_details(run, enemy, "execute", "volley"))
		_visual_action(run,enemy,"bossAttack","execute",enemy.radius,0.0,run.player.pos,"volley")
	_attack_pose(run, enemy)
	var turn: float = (rings - int(enemy.repeats)) * float(pattern.get("turn",0.0))
	for i in range(int(pattern.count)): shoot(run, enemy.pos, turn + TAU * i / float(pattern.count), enemy.damage * pattern.damageMultiplier, enemy)
	enemy.repeats -= 1
	if enemy.repeats > 0: enemy.timer = float(pattern.get("interval",0.4))
	else: enemy.action = "move"; enemy.timer = pattern.cooldown; enemy.pattern += 1

static func _boss(run: HeroRun, enemy: Dictionary, definition: Dictionary, dt: float) -> void:
	var pattern: Dictionary = definition.bossPatterns[int(enemy.pattern) % definition.bossPatterns.size()]
	if pattern.type == "spiral": _boss_spiral(run, enemy, pattern, dt); return
	if enemy.action == "dash":
		move(run, enemy, enemy.aim, dt, run.data.enemyRules.chargeSpeed * run.data.enemyMoveScale)
		if enemy.timer <= 0: enemy.action = "move"; enemy.timer = pattern.cooldown; enemy.pattern += 1
	elif enemy.action == "warning":
		if enemy.timer > 0: return
		run.audio_action("bossMajorAttack", _audio_details(run, enemy, "execute", pattern.type))
		_visual_action(run,enemy,"bossAttack","execute",float(pattern.get("radius",enemy.radius)),run.data.enemyRules.chargeDuration if pattern.type == "charge" else 0.0,enemy.aim,pattern.type)
		_attack_pose(run, enemy)
		if pattern.type == "charge": enemy.action = "dash"; enemy.timer = run.data.enemyRules.chargeDuration; return
		if pattern.type == "volley":
			for i in range(int(pattern.count)): shoot(run, enemy.pos, (enemy.aim - enemy.pos).angle() + (i - (pattern.count - 1) * 0.5) * 0.22, enemy.damage * pattern.damageMultiplier, enemy)
		if pattern.type == "summon": summon(run, enemy, pattern.get("childId", "swarm"), int(pattern.count))
		enemy.action = "move"; enemy.timer = pattern.cooldown; enemy.pattern += 1
	else:
		move(run, enemy, run.player.pos, dt)
		if enemy.timer <= 0:
			enemy.aim = run.player.pos; enemy.action = "warning"; enemy.timer = pattern.warning
			if pattern.type == "aoe": area(run, enemy.aim, pattern.radius, pattern.warning, enemy.damage * pattern.damageMultiplier,enemy,pattern.type)
			else: _visual_action(run,enemy,"chargeWarning" if pattern.type == "charge" else "enemyWarning","windup",enemy.radius,pattern.warning,enemy.aim,pattern.type)

# capped: the parent's lifetime limit of enemyRules.maxSummonsPerEnemy applies.
static func summon(run: HeroRun, parent: Dictionary, id: String, count: int, capped: bool = true) -> void:
	if capped: count = mini(count, int(run.data.enemyRules.maxSummonsPerEnemy) - int(parent.summons))
	for i in range(count):
		var position: Vector2 = parent.pos + Vector2.from_angle(randf() * TAU) * run.data.enemyRules.summonOffset
		var child := HeroSpawn.spawn(run, id, false, 1.0, 1.0, [], position, true)
		if child.is_empty(): continue
		child["parent"] = parent.id
		parent.summons += 1

# 분열: a killed splitter leaves smaller copies of itself; the last generation leaves none.
static func split(run: HeroRun, parent: Dictionary, rule: Dictionary) -> void:
	var generation := int(parent.get("generation",0))
	if generation >= int(rule.generations): return
	var count := int(rule.count)
	var turn := randf() * TAU
	for index in range(count):
		var side := Vector2.from_angle(turn + TAU * index / count)
		var child := HeroSpawn.spawn(run, parent.definition, false, 1.0, 1.0, [], HeroArena.resolve(parent.pos + side * parent.radius * 1.2,parent.radius,run.map), true)
		if child.is_empty(): continue
		child["generation"] = generation + 1
		child.maxHp = parent.maxHp * float(rule.hp); child.hp = child.maxHp
		child.radius = parent.radius * float(rule.size)
		child.damage = parent.damage * float(rule.damage)
		child.reward = parent.reward * float(rule.reward)
		child.facing = signf(side.x) if absf(side.x) > 0.01 else parent.facing

static func shoot(run: HeroRun, origin: Vector2, angle: float, damage: float, source: Dictionary = {}) -> void:
	if run.hostile.size() >= int(run.data.enemyRules.maxHostileProjectiles): return
	var visual_id := run.next_visual_id()
	run.hostile.append({"visualId":visual_id,"pos":origin,"velocity":Vector2.from_angle(angle) * run.data.enemyRules.bulletSpeed,"damage":damage,"remaining":run.data.enemyRules.projectileLifetime,"radius":run.data.enemyRules.projectileRadius})
	if not source.is_empty(): run.audio_action("projectileLaunch", _audio_details(run, source, "launch"))
	var payload: Dictionary = _audio_details(run,source,"launch") if not source.is_empty() else {"stage":"launch"}
	payload.merge({"kind":"enemyProjectile","contextId":payload.get("attackId",-1),"visualId":visual_id,"sourceActor":str(source.id) if not source.is_empty() else "","targetActor":"player","pos":origin,"angle":angle,"radius":run.data.enemyRules.projectileRadius,"duration":0.0},true)
	run.visual_event.emit(payload)

static func area(run: HeroRun, origin: Vector2, radius: float, delay: float, damage: float, source: Dictionary = {}, pattern: String = "") -> void:
	if run.hazards.size() >= int(run.data.enemyRules.maxHazards): return
	run.hazards.append({"pos":origin,"radius":radius,"delay":delay,"damage":damage})
	if delay > 0 and not source.is_empty(): _visual_action(run,source,"enemyWarning","windup",radius,delay,origin,pattern,origin)

static func damage_player(run: HeroRun, damage: float, source: String = "enemyProjectile", presentation: Dictionary = {}) -> void:
	if run.phase != "waveActive" or run.player.invulnerability > 0 or run.player.hp <= 0: return
	run.player.invulnerability = run.data.game.combat.invulnerabilitySeconds
	if randf() < run.stats.dodge: return
	damage = HeroItemEffects.incoming(run,damage)
	var actual := minf(run.player.hp,damage * 100.0 / (100.0 + run.stats.armor))
	run.player.hp = maxf(0.0, run.player.hp - actual)
	HeroItemEffects.hurt(run)
	HeroTelemetry.player_hit(run,actual,source)
	var visual := {"kind":"actorHit","actorId":"player","targetActor":"player","stage":"impact","pos":run.player.pos,"direction":Vector2.DOWN,"source":source}
	visual.merge(presentation,true)
	if presentation.has("sourcePosition"):
		var hit_direction: Vector2 = (run.player.pos-presentation.sourcePosition).normalized()
		visual["direction"] = hit_direction
		visual["angle"] = hit_direction.angle()
	run.visual_event.emit(visual)
	run.audio_cue("playerHit", presentation)
	run.event.emit("playerHit")
	if run.player.hp <= 0:
		run.visual_event.emit({"kind":"actorDeath","actorId":"player","targetActor":"player","stage":"death","pos":run.player.pos})
		run.phase = "revivalChoice"
		run.phase_changed.emit()
