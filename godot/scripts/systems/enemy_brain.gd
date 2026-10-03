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
			"tank":
				move(run, enemy, run.player.pos, dt)
				if enemy.timer <= 0 and distance < rules.tankRadius:
					_attack_pose(run, enemy)
					area(run, enemy.pos, rules.tankRadius, rules.tankWarning, enemy.damage); enemy.timer = rules.tankCooldown
			"bomber":
				if enemy.action == "warning":
					if enemy.timer <= 0:
						_attack_pose(run, enemy)
						area(run, enemy.pos, rules.bomberRadius, 0.0, enemy.damage)
						enemy.hp = 0; enemy.rewardEligible = false
				elif distance <= rules.bomberTrigger:
					enemy.action = "warning"; enemy.timer = rules.bomberWarning
					run.audio_action("selfDestructWarning", _audio_details(run, enemy, "windup"))
				else: move(run, enemy, run.player.pos, dt)
			"support":
				move(run, enemy, run.player.pos, dt)
				if enemy.timer <= 0:
					run.audio_action("supportOrSummonCast", _audio_details(run, enemy, "cast"))
					_attack_pose(run, enemy)
					for other in grid.nearby(enemy.pos, rules.supportRadius):
						if other.id != enemy.id and other.pos.distance_to(enemy.pos) <= rules.supportRadius: other.hp = minf(other.maxHp, other.hp + other.maxHp * rules.supportHealFraction)
					enemy.timer = rules.supportInterval
			"summoner":
				if distance > rules.rangedDistance: move(run, enemy, run.player.pos, dt)
				if enemy.timer <= 0:
					run.audio_action("supportOrSummonCast", _audio_details(run, enemy, "cast"))
					_attack_pose(run, enemy)
					summon(run, enemy, definition.get("childId", "swarm"), 2)
					enemy.timer = rules.summonInterval
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
				area(run, enemy.pos, rules.auraRadius, rules.auraWarning, rules.auraDamage); enemy.auraTimer = rules.auraInterval
		if enemy.pos.distance_to(run.player.pos) < enemy.radius + run.character.radius:
			if run.player.invulnerability <= 0: _attack_pose(run, enemy)
			damage_player(run, enemy.damage,enemy.definition)

static func _audio_details(run: HeroRun, enemy: Dictionary, stage: String, pattern: String = "") -> Dictionary:
	var definition: Dictionary = run.data.enemies[enemy.definition]
	return {"attackId":str(enemy.id) + ":" + str(run.combat_time),"enemyId":str(enemy.id),"monsterId":enemy.definition,"behavior":definition.behavior,"stage":stage,"pattern":pattern}

static func _attack_pose(run: HeroRun, enemy: Dictionary) -> void:
	run.visual_event.emit({"kind":"actorAttack","actorId":str(enemy.id),"pos":enemy.pos,"angle":(run.player.pos-enemy.pos).angle()})

static func _charge(run: HeroRun, enemy: Dictionary, definition: Dictionary, dt: float, distance: float) -> void:
	var rules: Dictionary = run.data.enemyRules
	var charge: Dictionary = definition.get("charge", {"triggerRange":rules.chargeTriggerRange,"warning":rules.ambushWarning if definition.behavior == "ambush" else rules.chargeWarning,"duration":rules.chargeDuration,"speed":rules.ambushSpeed if definition.behavior == "ambush" else rules.chargeSpeed,"cooldown":rules.ambushCooldown if definition.behavior == "ambush" else rules.chargeCooldown})
	if enemy.action == "warning":
		if enemy.timer <= 0:
			_attack_pose(run, enemy)
			enemy.action = "dash"; enemy.timer = charge.duration
	elif enemy.action == "dash":
		move(run, enemy, enemy.aim, dt, charge.speed * run.data.enemyMoveScale)
		if enemy.timer <= 0: enemy.action = "move"; enemy.timer = charge.cooldown
	elif enemy.timer <= 0 and distance < charge.triggerRange:
		enemy.aim = run.player.pos; enemy.action = "warning"; enemy.timer = charge.warning
		run.audio_action("chargeWindup", _audio_details(run, enemy, "windup"))
	elif definition.behavior == "ambush": move(run, enemy, enemy.pos + (run.player.pos - enemy.pos).normalized().rotated(0.6) * 200.0, dt)
	else: move(run, enemy, run.player.pos, dt)
	enemy.alpha = 0.4 if definition.behavior == "ambush" and enemy.action == "move" else 1.0

static func _boss(run: HeroRun, enemy: Dictionary, definition: Dictionary, dt: float) -> void:
	var pattern: Dictionary = definition.bossPatterns[int(enemy.pattern) % definition.bossPatterns.size()]
	if enemy.action == "dash":
		move(run, enemy, enemy.aim, dt, run.data.enemyRules.chargeSpeed * run.data.enemyMoveScale)
		if enemy.timer <= 0: enemy.action = "move"; enemy.timer = pattern.cooldown; enemy.pattern += 1
	elif enemy.action == "warning":
		if enemy.timer > 0: return
		run.audio_action("bossMajorAttack", _audio_details(run, enemy, "execute", pattern.type))
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
			if pattern.type == "aoe": area(run, enemy.aim, pattern.radius, pattern.warning, enemy.damage * pattern.damageMultiplier)

static func summon(run: HeroRun, parent: Dictionary, id: String, count: int) -> void:
	for i in range(mini(count, int(run.data.enemyRules.maxSummonsPerEnemy) - int(parent.summons))):
		var position: Vector2 = parent.pos + Vector2.from_angle(randf() * TAU) * run.data.enemyRules.summonOffset
		if not HeroSpawn.spawn(run, id, false, 1.0, 1.0, [], position, true).is_empty(): parent.summons += 1

static func shoot(run: HeroRun, origin: Vector2, angle: float, damage: float, source: Dictionary = {}) -> void:
	if run.hostile.size() >= int(run.data.enemyRules.maxHostileProjectiles): return
	run.hostile.append({"pos":origin,"velocity":Vector2.from_angle(angle) * run.data.enemyRules.bulletSpeed,"damage":damage,"remaining":run.data.enemyRules.projectileLifetime,"radius":run.data.enemyRules.projectileRadius})
	if not source.is_empty(): run.audio_action("projectileLaunch", _audio_details(run, source, "launch"))

static func area(run: HeroRun, origin: Vector2, radius: float, delay: float, damage: float) -> void:
	if run.hazards.size() < int(run.data.enemyRules.maxHazards): run.hazards.append({"pos":origin,"radius":radius,"delay":delay,"damage":damage})

static func damage_player(run: HeroRun, damage: float, source: String = "enemyProjectile") -> void:
	if run.phase != "waveActive" or run.player.invulnerability > 0 or run.player.hp <= 0: return
	run.player.invulnerability = run.data.game.combat.invulnerabilitySeconds
	if randf() < run.stats.dodge: return
	damage = HeroItemEffects.incoming(run,damage)
	var actual := minf(run.player.hp,damage * 100.0 / (100.0 + run.stats.armor))
	run.player.hp = maxf(0.0, run.player.hp - actual)
	HeroItemEffects.hurt(run)
	HeroTelemetry.player_hit(run,actual,source)
	run.visual_event.emit({"kind":"actorHit","actorId":"player","pos":run.player.pos,"direction":Vector2.DOWN})
	run.event.emit("playerHit")
	if run.player.hp <= 0:
		run.visual_event.emit({"kind":"actorDeath","actorId":"player","pos":run.player.pos})
		run.phase = "revivalChoice"
		run.phase_changed.emit()
