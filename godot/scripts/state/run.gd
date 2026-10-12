class_name HeroRun
extends RefCounted

signal event(id: String)
signal audio_event(id: String, context: Dictionary)
signal visual_event(payload: Dictionary)
signal phase_changed

var data: Dictionary
var run_id: String
var guild_support: Dictionary = HeroGuildSupport.empty()
var setup: Dictionary
var map: Dictionary
var character: Dictionary
var phase := "preparing"
var previous_phase := "waveActive"
var wave := 1
var elapsed := 0.0
var combat_time := 0.0
var currency := 0.0
var wallet := 0.0
var collected := 0.0
var kills := 0
var sequence := 0
# Transient identity for presentation objects; never advances gameplay IDs/RNG.
var _visual_sequence := 0
var player: Dictionary
var stats: Dictionary
var modifiers: Array = []
var item_effects: Array = []
var item_state: Dictionary = {}
var difficulty: Dictionary
var owned: Array = []
var items: Dictionary = {}
var enemies: Array = []
var pickups: Array = []
# Account loot (협회 코인, 생환석) on the ground and already picked up this run.
var loot_pickups: Array = []
var loot := {"associationCoins":0,"revivalStones":{"low":0,"mid":0,"high":0}}
var bullets: Array = []
var hostile: Array = []
var hazards: Array = []
var structures: Array = []
var effects: Array = []
var pending: Array = []
var pending_branch := ""
var item_stock: Array = []
var weapon_stock: Array = []
var item_rerolls := 0
var weapon_rerolls := 0
var free_rerolls_remaining := 0
var revivals_used := 0
var post_elapsed := 0.0
var wallet_flights: Array = []
var available_weapons: Array = []
var available_items: Array = []
var base_modifiers: Array = []
var settled := false
var reward := 0
var reward_tickets := 0
var last_countdown := 6
var spawn_state: Dictionary = {}
var telemetry: Dictionary = {}
# Transient HUD banner (elite kill supply, surge); never enters checkpoints.
var notice := {"text":"","time":-100.0}
# This week's lead monster; derived from setup.week.
var _weekly := ""

func _init(content: Dictionary, selection: Dictionary, meta: Dictionary) -> void:
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	data = content
	setup = selection.duplicate(true)
	map = data.maps[setup.map].duplicate(true)
	character = data.characters[setup.character]
	# Fixed for the whole Run, also across a weekly reset and a checkpoint resume.
	_weekly = HeroRoster.weekly_monster(data,int(setup.get("week",-1)))
	# One elite body per Run; it is drawn once and saved with the setup.
	if not data.enemies.has(str(setup.get("elite",""))): setup["elite"] = HeroRoster.draw_elite(map)
	guild_support = HeroGuildSupport.snapshot(data,meta) if bool(data.get("features",{}).get("guild",true)) else HeroGuildSupport.empty()
	base_modifiers = HeroMeta.modifiers(data, meta, setup)
	free_rerolls_remaining = int(data.shop.freeRerollsPerRun) if "reroll" in meta.account.unlockedFeatureIds else 0
	recalculate()
	player = {"pos":Vector2.ZERO,"hp":stats.maxHp,"invulnerability":0.0,"facing":1.0,"moving":false}
	difficulty = HeroStats.difficulty(data, int(setup.depth), map, setup.weekly)
	owned = [{"id":setup.weapon,"level":1,"branch":"","cooldown":0.0}]
	telemetry = HeroTelemetry.create()
	telemetry["balanceVersionAtStart"] = str(data.balance.version)
	telemetry["associationUpgradesAtStart"] = meta.association.upgrades.duplicate(true)
	telemetry["startingStats"] = stats.duplicate(true)
	telemetry["resumedCheckpoint"] = false
	for id in data.weapons:
		var weapon: Dictionary = data.weapons[id]
		if weapon.get("signatureOwnerId", setup.character) != setup.character: continue
		if meta.sharedWeapons.get(id, {}).get("unlocked", false): available_weapons.append(id)
	for id in data.items:
		if not data.items[id].get("requiresUnlock", false) or id in meta.account.unlockedItemIds: available_items.append(id)
	phase = "waveActive"

func recalculate() -> void:
	modifiers = base_modifiers + HeroGuildSupport.item_modifiers(data,items,guild_support)
	var old_max: float = stats.get("maxHp", character.baseStats.maxHp) if stats != null else character.baseStats.maxHp
	stats = HeroStats.calculate(character.baseStats, modifiers, data.statRules)
	item_effects.clear()
	for id in items:
		for i in range(int(items[id])): item_effects.append_array(data.items[id].specialEffects)
	item_state["dirty"] = true
	if player != null and not player.is_empty(): player.hp = minf(stats.maxHp, player.hp / old_max * stats.maxHp)

func weapon_stats(slot: Dictionary) -> Dictionary:
	var blessing: Dictionary = data.blessings.get(setup.get("blessing",""),{}) if int(setup.get("blessingLevel",0)) > 0 else {}
	var resolved := HeroStats.resolve_weapon(data.weapons[slot.id], slot, stats, item_effects, data.weaponConfig, character.get("trait", {}), blessing)
	resolved.damage = roundf(resolved.damage*guild_support.weaponDamageMultipliers.get(slot.id,1.0))
	return resolved

func wave_data() -> Dictionary:
	var result: Dictionary = map.waveDefinitions[wave - 1].duplicate(true)
	var depth := int(setup.depth)
	var featured_modifiers: Array = []
	for milestone in data.milestones:
		if milestone.depth > depth: continue
		featured_modifiers.append_array(milestone.get("featuredEliteModifiers", []))
	HeroRoster.lead(data,result.enemies,wave,_weekly)
	if result.has("elites"):
		result.elites = result.elites.filter(func(elite): return int(elite.get("minDepth",1)) <= depth)
		for elite in result.elites:
			if not elite.get("featured",false): continue
			if not str(setup.elite).is_empty(): elite.enemyId = setup.elite
			# hp is the depth-1 max HP whichever body the Run drew.
			if elite.has("hp"): elite.hpMultiplier = float(elite.hp) / float(data.enemies[elite.enemyId].maxHp)
			if not elite.has("modifiers"): elite["modifiers"] = []
			for id in featured_modifiers:
				if id not in elite.modifiers: elite.modifiers.append(id)
	return result

func announce(text: String) -> void:
	notice = {"text":text,"time":combat_time}

func next_id() -> int:
	sequence += 1
	return sequence

func next_visual_id() -> int:
	_visual_sequence += 1
	return _visual_sequence

# Presentation-only events; they never enter checkpoints or gameplay state.
func audio_cue(id: String, details: Dictionary = {}) -> void:
	if id.is_empty(): return
	audio_event.emit(id, details.duplicate(true))

func audio_weapon(weapon_id: String, stage: String, details: Dictionary = {}) -> void:
	var connections: Dictionary = data.get("audioConnections", {})
	var stages: Dictionary = connections.get("weaponStages", {}).get(weapon_id, {})
	var target: Variant = stages.get(stage, "")
	if target == null: return
	var cue_id := str(target)
	if cue_id.is_empty(): return
	var payload: Dictionary = details.duplicate(true)
	payload["weaponId"] = weapon_id
	payload["stage"] = stage
	payload["group"] = "combat"
	audio_event.emit(cue_id, payload)

func audio_action(action: String, details: Dictionary = {}) -> void:
	var connections: Dictionary = data.get("audioConnections", {})
	var cue_id := str(connections.get("enemyActions", {}).get(action, ""))
	if cue_id.is_empty(): return
	var payload: Dictionary = details.duplicate(true)
	payload["action"] = action
	payload["group"] = "combat"
	audio_event.emit(cue_id, payload)

func effect(kind: String, position: Vector2, radius: float = 35.0, angle: float = 0.0, arc: float = 1.0472, target: Vector2 = Vector2.ZERO, presentation: Dictionary = {}) -> void:
	if effects.size() >= int(data.weaponConfig.maxEffects): effects.pop_front()
	effects.append({"kind":kind,"pos":position,"target":target,"radius":radius,"angle":angle,"arc":arc,"age":0.0,"duration":0.4 if kind not in ["explosion","mine"] else 0.65})
	var payload := {"kind":kind,"pos":position,"target":target,"radius":radius,"angle":angle,"arc":arc}
	payload.merge(presentation,true)
	visual_event.emit(payload)

func clear_combat() -> void:
	visual_event.emit({"kind":"cleanup"})
	enemies.clear(); bullets.clear(); hostile.clear(); hazards.clear(); structures.clear(); pending.clear(); effects.clear()
	item_state["dynamic"] = []; item_state["dirty"] = true; item_state["idle"] = 0.0
	stats = HeroStats.calculate(character.baseStats,modifiers,data.statRules)

func pause() -> void:
	if phase in ["waveActive","shop","revivalChoice"]:
		previous_phase = phase
		phase = "paused"
		phase_changed.emit()

func resume() -> void:
	if phase == "paused":
		phase = previous_phase
		phase_changed.emit()
