class_name HeroRunCheckpoint
extends RefCounted

const VERSION := 5

static func is_future(value: Variant) -> bool:
	return value is Dictionary and (value.get("version") is int or value.get("version") is float) and int(value.version) > VERSION

static func migrate(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("state") is Dictionary: return {}
	if not (value.get("version") is int or value.get("version") is float): return {}
	var version := int(value.version)
	if version < 1 or version > VERSION: return {}
	var result: Dictionary = value.duplicate(true)
	while version < VERSION:
		if version == 1:
			# v1 predates conditional items and has no spent-effect state.
			result.state["item_state"] = {}
			version = 2
		elif version == 2:
			# An existing run retains neutral support, never current account bonuses.
			result.state["guild_support"] = HeroGuildSupport.empty()
			version = 3
		elif version == 3:
			# A legacy file gets the same identity each time until it is rewritten.
			result.state["run_id"] = JSON.stringify(value).sha256_text()
			version = 4
		elif version == 4:
			# Do not grant today's association permit to a run already in progress.
			result.state["revivals_used"] = 0
			result.state["free_rerolls_remaining"] = 0
			version = 5
	result.version = version
	for key in ["revivals_used","free_rerolls_remaining"]:
		var count: Variant = result.state.get(key)
		if not (count is int or count is float) or not is_finite(float(count)): return {}
		if float(count) < 0 or float(count) > 1 or float(count) != floorf(float(count)): return {}
		result.state[key] = int(count)
	if not result.state.get("run_id") is String or result.state.run_id.length() not in [32,64] or not result.state.run_id.is_valid_hex_number(false): return {}
	if not HeroGuildSupport.valid(Content.data,result.state.get("guild_support")): return {}
	var runtime: Variant = result.state.get("item_state",{})
	if not runtime is Dictionary: return {}
	for key in ["lastStandSpent","shieldSpent"]:
		if runtime.has(key) and not runtime[key] is bool: return {}
	for key in ["wave","idle","killCount","pickups","lastPickup","retaliated"]:
		if not runtime.has(key): continue
		if not (runtime[key] is float or runtime[key] is int) or not is_finite(float(runtime[key])): return {}
		if key in ["wave","idle","killCount","pickups"] and float(runtime[key]) < 0: return {}
	# Recompute temporary stats on the first combat tick, retain consumed effects.
	runtime["dynamic"] = []; runtime["dirty"] = true
	result.state["item_state"] = runtime
	return result
