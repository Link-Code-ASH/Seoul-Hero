class_name HeroItemEffects
extends RefCounted

# Run-only trigger state; definitions and numbers come from src/data/items.
static func update(run: HeroRun, dt: float) -> void:
	var state := run.item_state
	if state.get("wave",0) != run.wave:
		state.wave = run.wave; state.shieldSpent = false
	state.idle = 0.0 if run.player.get("moving",false) else float(state.get("idle",0.0))+dt
	var dynamic: Array = []
	for effect in run.item_effects:
		if effect.type != "conditionalStat": continue
		var value := 0.0
		match effect.condition:
			"stationary": value = effect.value if state.idle >= effect.threshold else 0.0
			"moving": value = effect.value if run.player.get("moving",false) else 0.0
			"injured": value = minf(effect.limit,floorf((1-run.player.hp/run.stats.maxHp)/effect.threshold)*effect.value)
			"wealth": value = minf(effect.limit,floorf(run.currency/effect.threshold)*effect.value)
			"dawn": value = effect.value if run.elapsed < effect.threshold else 0.0
			"pickupSprint": value = effect.value if run.combat_time-float(state.get("lastPickup",-999.0)) < effect.threshold else 0.0
		if value != 0: dynamic.append({"stat":effect.stat,"operation":"add","value":value})
	if dynamic != state.get("dynamic",[]) or state.get("dirty",false):
		state.dynamic = dynamic; state.dirty = false
		run.stats = HeroStats.calculate(run.character.baseStats,run.modifiers+dynamic,run.data.statRules)

static func damage_multiplier(run: HeroRun, enemy: Dictionary, origin: Vector2) -> float:
	var bonus := 0.0
	for effect in run.item_effects:
		if effect.type != "conditionalDamage": continue
		var active := false
		match effect.condition:
			"opening": active = enemy.hp >= enemy.maxHp
			"execute": active = enemy.hp/enemy.maxHp <= effect.threshold
			"close": active = origin.distance_to(enemy.pos) <= effect.threshold
			"distant": active = origin.distance_to(enemy.pos) >= effect.threshold
		if active: bonus += effect.value
	return 1.0+bonus

static func heal(run: HeroRun, value: float) -> void:
	if run.player.hp > 0: run.player.hp = minf(run.stats.maxHp,run.player.hp+value)

static func killed(run: HeroRun) -> void:
	run.item_state.killCount = int(run.item_state.get("killCount",0))+1
	for effect in run.item_effects:
		if effect.type == "killHeal" and int(run.item_state.killCount)%int(effect.every) == 0: heal(run,effect.value)

static func picked_up(run: HeroRun, units: int) -> void:
	var before := int(run.item_state.get("pickups",0))
	run.item_state.pickups = before+units; run.item_state.lastPickup = run.combat_time
	for effect in run.item_effects:
		if effect.type == "pickupHeal":
			var triggers := int(run.item_state.pickups/effect.every)-int(before/effect.every)
			heal(run,effect.value*triggers)

static func incoming(run: HeroRun, damage: float) -> float:
	for effect in run.item_effects:
		if effect.type == "firstShield" and not run.item_state.get("shieldSpent",false):
			run.item_state.shieldSpent = true; damage *= 1.0-effect.value
	return damage

static func hurt(run: HeroRun) -> void:
	for effect in run.item_effects:
		if effect.type == "lastStand" and run.player.hp <= 0 and not run.item_state.get("lastStandSpent",false):
			run.item_state.lastStandSpent = true; run.player.hp = 1; run.player.invulnerability = effect.value
		if effect.type == "retaliate" and run.combat_time-float(run.item_state.get("retaliated",-999.0)) >= effect.cooldown:
			run.item_state.retaliated = run.combat_time
			run.pending.append({"kind":"itemBurst","pos":run.player.pos,"radius":effect.radius,"damage":effect.value,"remaining":0.0,"context":{"weapon":"item:revengeFuse","criticalChance":0.0,"criticalDamage":1.0,"lifesteal":0.0,"healingRemaining":0.0,"itemProc":true}})
