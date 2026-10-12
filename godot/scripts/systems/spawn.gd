class_name HeroSpawn
extends RefCounted

var next_spawn := 0.0
var triggered: Array = []
var boss_spawned := false
var surge_started := false
var featured_kills := 0

func reset() -> void:
	next_spawn = 0.0; triggered.clear(); boss_spawned = false; surge_started = false; featured_kills = 0

func update(run: HeroRun, dt: float) -> void:
	var wave := run.wave_data()
	# The boss Wave keeps its elites and ordinary spawns beside the boss.
	if run.wave == int(run.map.bossWave) and not boss_spawned:
		spawn(run, wave.get("boss", {}).get("enemyId", "gatekeeper"), true)
		boss_spawned = true
	var surge := HeroFeaturedElites.surge(run)
	if not surge.is_empty() and not surge_started:
		# Enemies already on the field also pay the surge reward.
		surge_started = true
		for enemy in run.enemies: enemy.reward *= float(surge.rewardMultiplier)
		run.announce("%s!" % surge.name)
	for i in range(wave.get("elites", []).size()):
		var elite: Dictionary = wave.elites[i]
		if run.elapsed >= elite.at and i not in triggered:
			triggered.append(i)
			var spawned := spawn(run, elite.enemyId, false, elite.hpMultiplier, elite.rewardMultiplier, elite.get("modifiers", []))
			if elite.get("featured",false) and not spawned.is_empty(): HeroFeaturedElites.spawned(run,spawned,elite)
	next_spawn -= dt
	if next_spawn > 0: return
	var curse := minf(run.data.curseRules.maxIntensity, 1.0 + run.stats.curse * run.data.curseRules.spawnPerPoint)
	next_spawn += wave.interval / (run.difficulty.spawn * curse * HeroFeaturedElites.spawn_rate(run))
	var weights: Array = wave.enemies
	for i in range(mini(int(wave.batch), maxi(0, int(wave.maxEnemies) - run.enemies.size()))):
		var chosen := HeroMeta.weighted(weights)
		var mods: Array = []
		var chance := minf(0.75, run.difficulty.eliteChance + minf(run.data.curseRules.maxEliteChance, run.stats.curse * run.data.curseRules.eliteChancePerPoint))
		if randf() < chance:
			mods.append(run.difficulty.eliteModifiers.pick_random() if not run.difficulty.eliteModifiers.is_empty() else "FAST")
		spawn(run, chosen.enemyId, false, 1.0, 1.0, mods)

static func edge_position(run: HeroRun) -> Vector2:
	var extent := Vector2(run.map.arenaWidth, run.map.arenaHeight) * 0.5 - Vector2(25,25)
	var perimeter := (extent.x + extent.y) * 4.0
	var best := Vector2.ZERO
	var furthest := -1.0
	for i in range(24):
		var position: Vector2
		var distance := randf() * perimeter
		if distance < extent.x * 2.0: position = Vector2(-extent.x + distance, -extent.y)
		elif distance < extent.x * 2.0 + extent.y * 2.0: position = Vector2(extent.x, -extent.y + distance - extent.x * 2.0)
		elif distance < extent.x * 4.0 + extent.y * 2.0: position = Vector2(extent.x - (distance - extent.x * 2.0 - extent.y * 2.0), extent.y)
		else: position = Vector2(-extent.x, extent.y - (distance - extent.x * 4.0 - extent.y * 2.0))
		var separation := position.distance_to(run.player.pos)
		if separation > furthest: furthest = separation; best = position
		if separation >= 300.0: return position
	return best

static func spawn(run: HeroRun, definition_id: String, boss: bool = false, hp_multiplier: float = 1.0, reward_multiplier: float = 1.0, mods: Array = [], position: Vector2 = Vector2.INF, summoned: bool = false) -> Dictionary:
	if not run.data.enemies.has(definition_id) or run.enemies.size() >= 500: return {}
	var definition: Dictionary = run.data.enemies[definition_id]
	var bonus := {"hp":hp_multiplier,"reward":reward_multiplier,"damage":1.0,"speed":1.0,"size":1.0,"armor":0.0,"regeneration":0.0,"aura":false}
	for id in mods:
		var mod: Dictionary = run.data.elites[id]
		for key in ["hp","reward","damage","speed","size"]: bonus[key] *= mod[key]
		bonus.armor += mod.armor; bonus.regeneration += mod.regeneration; bonus.aura = bonus.aura or mod.aura
	var curse: Dictionary = run.data.curseRules
	var hp: float = definition.maxHp * bonus.hp * run.difficulty.hp * minf(curse.maxIntensity, 1.0 + run.stats.curse * curse.hpPerPoint)
	var speed: float = definition.moveSpeed * (0.65 if definition_id == "swarm" else run.data.enemyMoveScale) * bonus.speed * run.difficulty.speed * minf(curse.maxIntensity, 1.0 + run.stats.curse * curse.speedPerPoint)
	var enemy := {"id":run.next_id(),"definition":definition_id,"pos":edge_position(run) if position == Vector2.INF else position,"hp":hp,"maxHp":hp,"radius":definition.radius * bonus.size,"speed":speed,"damage":definition.contactDamage * bonus.damage * run.difficulty.damage * minf(curse.maxIntensity,1.0 + run.stats.curse * curse.damagePerPoint),"reward":definition.magicStoneDrop * bonus.reward * run.difficulty.reward * (run.data.enemyRules.summonedRewardMultiplier if summoned else 1.0),"boss":boss,"elite":not boss and (not mods.is_empty() or hp_multiplier > 1.0),"armor":bonus.armor,"baseArmor":bonus.armor,"regeneration":bonus.regeneration,"aura":bonus.aura,"auraTimer":run.data.enemyRules.auraInterval,"action":"move","timer":0.0,"age":0.0,"aim":Vector2.ZERO,"pattern":0,"repeats":0,"summons":0,"flash":0.0,"alpha":1.0,"facing":1.0,"rewardEligible":true}
	# Persist child provenance so summons never inherit ordinary account-loot rolls.
	enemy["summoned"] = summoned
	enemy.reward *= float(HeroFeaturedElites.surge(run).get("rewardMultiplier",1.0))
	run.enemies.append(enemy)
	if boss: run.event.emit("bossSpawned")
	elif enemy.elite: run.event.emit("eliteSpawned")
	return enemy
