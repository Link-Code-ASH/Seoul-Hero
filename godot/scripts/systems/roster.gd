class_name HeroRoster
extends RefCounted

# What one Run adds to the fixed Wave table: this week's monster and the Run's elite.
# Mirrors weeklyMonster/resolveGateWave in src/data/gateProgression.ts; both must
# name the same monster for a week.

# This week's monster for every map; week is the weekly gate key (Sunday 05:00 KST).
# The pool is a shuffle bag: every pool-size weeks each monster comes up once in a
# random order, and no monster comes up two weeks in a row.
# "" while weeklyMonster.enabled is false (WEEKLY_MONSTER in src/data/gateProgression.ts):
# no Wave gets a weekly lead and the gate screen shows no weekly monster.
static func weekly_monster(data: Dictionary, week: int) -> String:
	var rule: Dictionary = data.get("weeklyMonster",{})
	var pool: Array = rule.get("pool",[])
	if not rule.get("enabled",false) or pool.is_empty() or week < 0: return ""
	var size := pool.size()
	var bag := floori(week / float(size))
	var order := _weekly_bag(pool,bag)
	# A bag never opens with the monster that closed the one before; swapping the first two slots leaves its own last slot alone.
	if size > 2 and order[0] == _weekly_bag(pool,bag - 1)[size - 1]:
		var first: String = order[0]
		order[0] = order[1]; order[1] = first
	return order[posmod(week,size)]

# The pool in the order one bag deals it.
static func _weekly_bag(pool: Array, bag: int) -> Array:
	# Park–Miller, kept below 2^53 so the web data module draws the same numbers.
	# The xorshift between two steps breaks the straight line that neighbouring bag numbers would otherwise draw along.
	var state := _weekly_step(posmod(bag * 131,2147483646) + 1)
	var order: Array = pool.duplicate()
	for index in range(order.size() - 1,0,-1):
		state = _weekly_step(state)
		var other := state % (index + 1)
		var swapped: String = order[index]
		order[index] = order[other]; order[other] = swapped
	return order

static func _weekly_step(state: int) -> int:
	state = state * 48271 % 2147483647
	state = (state ^ (state >> 15)) % 2147483646 + 1
	return state * 48271 % 2147483647

# Puts the weekly monster in the lead slot of its Waves; the authored slots shrink to fit.
static func lead(data: Dictionary, entries: Array, wave: int, monster: String) -> void:
	var rule: Dictionary = data.get("weeklyMonster",{})
	if monster.is_empty() or not rule.get("waves",[]).any(func(number): return int(number) == wave): return
	if entries.any(func(entry): return entry.enemyId == monster): return
	var share := float(rule.share)
	var total := 0.0
	for entry in entries:
		total += float(entry.weight)
		entry.weight *= 1.0 - share
	entries.push_front({"enemyId":monster,"weight":total * share})

# The elite body a new Run meets on all its elite Waves.
static func draw_elite(map: Dictionary) -> String:
	var pool: Array = map.get("elitePool",[])
	return "" if pool.is_empty() else str(pool.pick_random())
