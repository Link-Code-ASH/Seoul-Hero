extends SceneTree

# Required compatibility checks for the new spent-item checkpoint field; no disk writes.
func _initialize() -> void:
	var legacy := HeroRunCheckpoint.migrate({"version":1,"state":{"phase":"shop","currency":42}})
	assert(legacy.version == 2 and legacy.state.currency == 42)
	assert(legacy.state.item_state.get("lastStandSpent",false) == false)
	var used := {"version":2,"state":{"item_state":{"lastStandSpent":true,"shieldSpent":true,"wave":3,"idle":0.5,"killCount":7,"pickups":11,"lastPickup":24.0,"retaliated":18.0}}}
	var resumed := HeroRunCheckpoint.migrate(JSON.parse_string(JSON.stringify(used)))
	assert(resumed.state.item_state.lastStandSpent and resumed.state.item_state.shieldSpent,"Resume must not recharge a consumed survival/shield item")
	assert(resumed.state.item_state.killCount == 7 and resumed.state.item_state.pickups == 11,"Partial heal counters survive resume")
	assert(HeroRunCheckpoint.migrate(null).is_empty())
	assert(HeroRunCheckpoint.migrate({"version":2,"state":{"item_state":[]}}).is_empty())
	assert(HeroRunCheckpoint.migrate({"version":2,"state":{"item_state":{"pickups":"broken"}}}).is_empty())
	assert(HeroRunCheckpoint.migrate({"version":2,"state":{"item_state":{"lastStandSpent":1}}}).is_empty())
	var future := {"version":3,"state":{}}
	assert(HeroRunCheckpoint.is_future(future) and HeroRunCheckpoint.migrate(future).is_empty(),"Future checkpoints must be rejected without rewriting")
	print("Checkpoint QA passed: v1 migration, v2 consumed effects/counters, malformed fallback, future protection")
	quit()
