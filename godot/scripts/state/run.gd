class_name HeroRun
extends RefCounted

signal event(id: String)
signal audio_event(id: String, context: Dictionary)
signal visual_event(payload: Dictionary)
signal phase_changed

var data: Dictionary
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
var post_elapsed := 0.0
var wallet_flights: Array = []
var available_weapons: Array = []
var available_items: Array = []
var base_modifiers: Array = []
var settled := false
var reward := 0
var last_countdown := 6
var spawn_state: Dictionary = {}
var telemetry: Dictionary = {}

func _init(content: Dictionary, selection: Dictionary, meta: Dictionary) -> void:
	data = content
	setup = selection.duplicate(true)
	map = data.maps[setup.map].duplicate(true)
	character = data.characters[setup.character]
	base_modifiers = HeroMeta.modifiers(data, meta, setup)
	recalculate()
	player = {"pos":Vector2.ZERO,"hp":stats.maxHp,"invulnerability":0.0,"facing":1.0,"moving":false}
	difficulty = HeroStats.difficulty(data, int(setup.depth), map, setup.weekly)
	owned = [{"id":setup.weapon,"level":1,"branch":"","cooldown":0.0}]
	telemetry = HeroTelemetry.create()
	for id in data.weapons:
		var weapon: Dictionary = data.weapons[id]
		if weapon.get("signatureOwnerId", setup.character) != setup.character: continue
		if not weapon.get("requiresUnlock", false) or meta.sharedWeapons.get(id, {}).get("unlocked", false): available_weapons.append(id)
	for id in data.items:
		if not data.items[id].get("requiresUnlock", false) or id in meta.account.unlockedItemIds: available_items.append(id)
	phase = "waveActive"

func recalculate() -> void:
	modifiers = base_modifiers + HeroStats.item_modifiers(data.items, items)
	var old_max: float = stats.get("maxHp", character.baseStats.maxHp) if stats != null else character.baseStats.maxHp
	stats = HeroStats.calculate(character.baseStats, modifiers, data.statRules)
	item_effects.clear()
	for id in items:
		for i in range(int(items[id])): item_effects.append_array(data.items[id].specialEffects)
	item_state["dirty"] = true
	if player != null and not player.is_empty(): player.hp = minf(stats.maxHp, player.hp / old_max * stats.maxHp)

func weapon_stats(slot: Dictionary) -> Dictionary:
	return HeroStats.resolve_weapon(data.weapons[slot.id], slot, stats, item_effects, data.weaponConfig, character.get("trait", {}))

func wave_data() -> Dictionary:
	var result: Dictionary = map.waveDefinitions[wave - 1].duplicate(true)
	for milestone in data.milestones:
		if milestone.depth > setup.depth: continue
		for addition in milestone.get("enemyAdditions", []):
			if wave >= addition.fromWave and not result.enemies.any(func(entry): return entry.enemyId == addition.enemyId): result.enemies.append({"enemyId":addition.enemyId,"weight":addition.weight})
		if wave == int(map.bossWave) and milestone.has("bossId"): result.boss = {"enemyId":milestone.bossId}
	return result

func next_id() -> int:
	sequence += 1
	return sequence

# Presentation-only events; they never enter checkpoints or gameplay state.
func audio_weapon(weapon_id: String, stage: String, details: Dictionary = {}) -> void:
	var connections: Dictionary = data.get("audioConnections", {})
	var stages: Dictionary = connections.get("weaponStages", {}).get(weapon_id, {})
	var cue_id := str(stages.get(stage, ""))
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
