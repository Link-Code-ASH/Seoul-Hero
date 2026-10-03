class_name HeroRunCheckpoint
extends RefCounted

const VERSION := 2

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
	result.version = version
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
