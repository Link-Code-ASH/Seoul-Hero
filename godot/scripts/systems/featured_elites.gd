class_name HeroFeaturedElites
extends RefCounted

# Featured elites from the Wave table and the final-seconds surge. Their titles are data only; no name is shown in play.
# A featured elite slows ordinary spawns and pays a magic stone shower plus one free shop item
# (elite supply) when killed. Uncaught, it leaves with the Wave: no drop, no supply.
# Its arrival and its escape are not announced in text; only the kill supply and the surge are.

static func alive(run: HeroRun) -> Array:
	return run.enemies.filter(func(enemy): return enemy.get("featured",false) and enemy.hp > 0)

# Featured elites not yet counted as killed; snapshot this before attacks resolve.
static func tracked(run: HeroRun) -> Array:
	return run.enemies.filter(func(enemy): return enemy.get("featured",false) and not enemy.get("featuredDone",false))

# The active surge rule of the current Wave, or an empty dictionary.
static func surge(run: HeroRun) -> Dictionary:
	if run.phase != "waveActive": return {}
	var wave: Dictionary = run.map.waveDefinitions[run.wave - 1]
	var rule: Dictionary = wave.get("surge",{})
	if rule.is_empty() or float(wave.duration) - run.elapsed > float(rule.lastSeconds): return {}
	return rule

static func spawn_rate(run: HeroRun) -> float:
	var rate := float(surge(run).get("spawnMultiplier",1.0))
	if not alive(run).is_empty(): rate *= float(run.data.featuredElites.spawnRateWhileAlive)
	return rate

static func spawned(run: HeroRun, enemy: Dictionary, elite: Dictionary) -> void:
	enemy["featured"] = true
	enemy["title"] = str(elite.get("title",run.data.enemies[enemy.definition].name))

# Called once per killed featured elite, after its ordinary drop.
static func killed(run: HeroRun, enemy: Dictionary) -> void:
	enemy["featuredDone"] = true
	var rules: Dictionary = run.data.featuredElites
	var count := maxi(1,int(rules.showerStones))
	var value: float = float(rules.showerValue) * run.difficulty.reward * float(surge(run).get("rewardMultiplier",1.0)) / count
	for index in range(count):
		var offset := Vector2.from_angle(TAU * index / count + randf() * 0.4) * float(rules.showerRadius) * randf_range(0.35,1.0)
		var position := HeroArena.resolve(enemy.pos + offset,float(run.data.game.combat.pickupRadius),run.map)
		if run.pickups.size() < int(run.data.game.combat.maxPickups):
			run.pickups.append({"pos":position,"value":value,"units":1.0})
			run.visual_event.emit({"kind":"stoneDrop","stage":"drop","pos":position-Vector2(0,8),"radius":15.0,"duration":0.0})
		else: run.pickups.back().value += value
	run.announce("정예 처치 · 보급품 확보")

# Item rarities of the supply earned this Wave; empty when no featured elite died.
static func supply_rarities(run: HeroRun, kills: int) -> Array:
	if kills <= 0: return []
	var total: int = run.wave_data().get("elites",[]).filter(func(elite): return elite.get("featured",false)).size()
	var rules: Dictionary = run.data.featuredElites
	return rules.sweepRarities if total > 1 and kills >= total else rules.supplyRarities
