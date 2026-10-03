class_name HeroSimulation
extends RefCounted

var run: HeroRun
var grid := HeroSpatial.new()
var spawn := HeroSpawn.new()
var attacks := HeroAttacks.new(grid)

func _init(state: HeroRun) -> void:
	run = state
	if not state.spawn_state.is_empty():
		spawn.next_spawn = state.spawn_state.get("nextSpawn",0.0)
		spawn.triggered = state.spawn_state.get("triggeredElites",[])
		spawn.boss_spawned = state.spawn_state.get("bossSpawned",false)
		return
	# Reopened boss/elites are already present; do not duplicate scheduled actors.
	if state.elapsed > 0:
		spawn.boss_spawned = state.wave == int(state.map.bossWave)
		var wave := state.wave_data()
		for i in range(wave.get("elites", []).size()):
			if wave.elites[i].at <= state.elapsed: spawn.triggered.append(i)

func tick(dt: float, movement: Vector2, body_limits: Rect2 = Rect2()) -> void:
	if run.phase == "postWave":
		run.post_elapsed += dt
		if run.post_elapsed >= 1.0:
			run.phase = "shop"; run.wallet_flights.clear()
			HeroShop.refresh(run, true); HeroShop.refresh(run, false)
			run.phase_changed.emit()
		return
	if run.phase != "waveActive": return
	run.elapsed += dt; run.combat_time += dt
	var direction := movement.limit_length(1.0)
	run.player.moving = direction.length_squared() > 0.01
	HeroItemEffects.update(run,dt)
	if absf(direction.x) > 0.01: run.player.facing = signf(direction.x)
	run.player.pos += direction * run.stats.moveSpeed * dt
	run.player.pos = HeroArena.resolve(run.player.pos,run.character.radius,run.map)
	if body_limits.has_area(): run.player.pos = run.player.pos.clamp(body_limits.position,body_limits.end)
	run.player.invulnerability = maxf(0.0, run.player.invulnerability - dt)
	run.player.hp = minf(run.stats.maxHp, run.player.hp + run.stats.hpRegeneration * dt)
	spawn.update(run, dt)
	HeroTelemetry.tick(run)
	run.spawn_state = {"nextSpawn":spawn.next_spawn,"triggeredElites":spawn.triggered.duplicate(),"bossSpawned":spawn.boss_spawned}
	grid.rebuild(run.enemies)
	HeroEnemyBrain.update(run, dt, grid)
	if run.phase != "waveActive": return
	grid.rebuild(run.enemies)
	attacks.update(run, dt)
	_hostile(dt)
	if run.phase != "waveActive": return
	_pickups(dt)
	for effect in run.effects: effect.age += dt
	run.effects = run.effects.filter(func(effect): return effect.age < effect.duration)
	var remaining := maxf(0.0, run.wave_data().duration - run.elapsed)
	if remaining <= 5.0 and int(ceil(remaining)) < run.last_countdown and run.wave != int(run.map.bossWave):
		run.last_countdown = int(ceil(remaining)); run.event.emit("waveCountdownTick")
	if run.wave == int(run.map.bossWave):
		if spawn.boss_spawned and not run.enemies.any(func(enemy): return enemy.boss and enemy.hp > 0):
			run.previous_phase = run.phase; run.phase = "stageClear"; run.clear_combat(); run.event.emit("stageClear"); run.phase_changed.emit()
	elif remaining <= 0: end_wave()

func _hostile(dt: float) -> void:
	var kept: Array = []
	for bullet in run.hostile:
		var previous: Vector2 = bullet.pos
		bullet.pos += bullet.velocity * dt; bullet.remaining -= dt
		if bullet.remaining <= 0: continue
		var closest := Geometry2D.get_closest_point_to_segment(run.player.pos, previous, bullet.pos)
		if closest.distance_to(run.player.pos) <= run.character.radius + bullet.radius: HeroEnemyBrain.damage_player(run, bullet.damage)
		else: kept.append(bullet)
	run.hostile = kept
	kept = []
	for hazard in run.hazards:
		hazard.delay -= dt
		if hazard.delay > 0: kept.append(hazard); continue
		if hazard.pos.distance_to(run.player.pos) <= hazard.radius: HeroEnemyBrain.damage_player(run, hazard.damage)
		run.effect("explosion", hazard.pos, hazard.radius)
	run.hazards = kept

func _pickups(dt: float) -> void:
	var kept: Array = []
	for pickup in run.pickups:
		var distance: float = pickup.pos.distance_to(run.player.pos)
		if distance < run.stats.pickupRange:
			pickup.pos = pickup.pos.move_toward(run.player.pos, run.data.game.combat.pickupAttractionSpeed * dt)
		if pickup.pos.distance_to(run.player.pos) <= run.character.radius + run.data.game.combat.pickupRadius:
			var bonus := minf(pickup.units, run.wallet)
			run.wallet -= bonus
			var amount: float = pickup.value * run.stats.currencyGain + bonus
			run.currency += amount; run.collected += amount
			HeroTelemetry.wave(run).magicStone += amount
			run.telemetry.walletRecovered += bonus
			if bonus > 0: run.effect("walletBonus", run.player.pos - Vector2(0,65), 15.0)
			run.event.emit("magicStoneCollected")
			HeroItemEffects.picked_up(run,int(pickup.units))
		else: kept.append(pickup)
	run.pickups = kept

func end_wave() -> void:
	if run.phase != "waveActive": return
	run.wallet_flights = run.pickups.duplicate(true)
	for pickup in run.pickups: run.wallet += pickup.value
	run.pickups.clear()
	run.clear_combat(); grid.cells.clear()
	run.phase = "postWave"; run.post_elapsed = 0.0
	run.event.emit("waveCompleted")
	if not run.wallet_flights.is_empty(): run.event.emit("walletSweep")
	run.phase_changed.emit()

func next_wave() -> bool:
	if run.phase != "shop" or not run.pending_branch.is_empty(): return false
	run.wave += 1; run.elapsed = 0.0; run.post_elapsed = 0.0; run.last_countdown = 6
	run.player.hp = run.stats.maxHp; run.player.invulnerability = 0.0
	run.clear_combat(); grid.cells.clear(); spawn.reset()
	run.spawn_state.clear()
	for slot in run.owned: slot.cooldown = 0.0; slot.erase("orbitHits"); slot.erase("orbitContext")
	run.phase = "waveActive"
	run.event.emit("waveStarted"); run.phase_changed.emit()
	return true
