extends Node

# Run-structure verification: the fixed four-monster cast, the weekly shuffle-bag monster and its three patterns,
# the Run's elite draw, 땅울림 hops, the boss scatter, featured elites, the Wave 14
# surge, the elite supply and gate depth paging. Ticks the real simulation on an
# isolated in-memory profile. Requires --ui-preview so no profile or checkpoint is ever written.
const REGULARS := ["crawler","spitter","runner","bulwark"]
# Shared with src/data/BalanceBaseline.test.ts: weeks 2961, 2962, 2963 and 2973.
const WEEKLY_VECTORS := ["summoner","splitter","lampFirefly","splitter"]
# A week that deals each weekly monster, for the captures.
const WEEKLY_WEEKS := {"summoner":2961,"splitter":2962,"lampFirefly":2963}
# Words an arrival or escape announcement would carry.
const ANNOUNCEMENTS := ["정예","보스","BOSS","출현","도망","달아"]
var _output := ""
var _checks: Array = []
var _world: HeroWorld
var _canvas := CanvasLayer.new()
var _noop := func(_value = null,_other = null): pass

func _ready() -> void:
	_main.call_deferred()

func _check(title: String, passed: bool, detail = "") -> void:
	_checks.append({"check":title,"passed":passed,"detail":str(detail)})
	print("[%s] %s %s" % ["ok" if passed else "FAIL",title,str(detail)])

# elite: the Run's elite body ("" draws one at random); week < 0 plays without a weekly monster.
func _state(depth: int, wave: int, elapsed: float, elite: String = "charger", week: int = -1) -> Dictionary:
	var setup := {"map":"seoul","depth":depth,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId,"week":week}
	if not elite.is_empty(): setup["elite"] = elite
	var run := HeroRun.new(Content.data.duplicate(true),setup,Profile.meta)
	run.wave = wave; run.elapsed = elapsed; run.combat_time = 100.0 + elapsed
	return {"run":run,"sim":HeroSimulation.new(run)}
# hud != null renders every tick so the presentation follows the simulation.
func _advance(state: Dictionary, seconds: float, hud: Control = null) -> void:
	var run: HeroRun = state.run
	for index in range(ceili(seconds * 60.0)):
		if run.phase == "waveActive": run.player.hp = run.stats.maxHp
		state.sim.tick(1.0 / 60.0,Vector2.ZERO)
		if hud != null:
			HeroCombatUI.update_hud(hud,run)
			await get_tree().process_frame

func _hud(run: HeroRun) -> Control:
	if _world.run != run: _world.run = run
	_world.visible = true
	var hud := HeroCombatUI.hud(run,_noop)
	_canvas.add_child(hud)
	return hud

# also: a second file name for the same frame (the textured-skin recaptures).
func _shot(screen: Control, id: String, combat: bool = false, also: String = "") -> void:
	_world.visible = combat
	if screen.get_parent() == null: _canvas.add_child(screen)
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	image.save_png(_output.path_join(id + ".png"))
	if not also.is_empty(): image.save_png(_output.path_join(also + ".png"))
	_canvas.remove_child(screen); screen.free()

func _hud_copy(hud: Control) -> Array:
	return hud.find_children("*","Label",true,false).map(func(label): return label.text)

# The HUD carries no elite or boss name and no HP bar besides the player's.
func _nameless(hud: Control, run: HeroRun) -> bool:
	var names: Array = run.enemies.filter(func(enemy): return enemy.get("featured",false) or enemy.boss).map(func(enemy): return str(enemy.get("title",run.data.enemies[enemy.definition].name)))
	var bars: Array = hud.find_children("*","ProgressBar",true,false)
	return hud.find_child("ElitePlates",true,false) == null and bars.size() == 1 and bars[0].name == "HealthBar" and not _hud_copy(hud).any(func(text): return names.any(func(title): return title in text))

# Nothing announces an elite or boss arriving or an elite escaping.
func _silent(hud: Control, run: HeroRun) -> bool:
	return str(run.notice.text).is_empty() and not _hud_copy(hud).any(func(text): return ANNOUNCEMENTS.any(func(word): return word in text))

func _free_offers(run: HeroRun) -> Array:
	return run.item_stock.filter(func(slot): return slot.get("free",false))

func _to_shop(state: Dictionary) -> void:
	var run: HeroRun = state.run
	run.elapsed = run.wave_data().duration - 0.02
	await _advance(state,0.1)
	await _advance(state,1.1)

func _combat_shot(id: String, state: Dictionary, seconds: float) -> HeroRun:
	var hud := _hud(state.run)
	await _advance(state,seconds,hud)
	await _shot(hud,id,true)
	return state.run

# Ticks until done.call() is true or the time runs out; returns whether it became true.
func _until(state: Dictionary, seconds: float, done: Callable, hud: Control = null) -> bool:
	for index in range(ceili(seconds * 60.0)):
		if done.call(): return true
		await _advance(state,1.0 / 60.0,hud)
	return done.call()

# A lone monster beside the player on an otherwise empty field.
func _duel(id: String, offset: Vector2, wave: int = 6) -> Dictionary:
	var state := _state(1,wave,1.0)
	state.run.owned.clear()
	state.sim.spawn.next_spawn = 999.0
	state["enemy"] = HeroSpawn.spawn(state.run,id,false,1.0,1.0,[],state.run.player.pos + offset)
	return state

func _roster_checks() -> void:
	var map: Dictionary = Content.data.maps.seoul
	var week := int(Profile.meta.weeklyGate.weekKey)

	# The cast: four regulars at every floor, nothing swapped in by depth.
	var same := true
	var only_regulars := true
	var totals: Array = []
	var base := _state(1,1,0.0)
	for depth in [1,10,20,30,37]:
		var deep := _state(depth,1,0.0)
		for wave in range(1,21):
			base.run.wave = wave; deep.run.wave = wave
			var entries: Array = deep.run.wave_data().enemies
			same = same and entries == base.run.wave_data().enemies and deep.run.wave_data().get("boss",{}) == base.run.wave_data().get("boss",{})
			only_regulars = only_regulars and not entries.is_empty() and entries.all(func(entry): return entry.enemyId in REGULARS)
			var total := 0.0
			for entry in entries: total += float(entry.weight)
			totals.append(roundi(total))
	_check("Every wave 1-20 fields only the four regulars at weight 100",only_regulars and totals.all(func(total): return total == 100))
	_check("The cast is identical at depth 1, 10, 20, 30 and 37",same)
	_check("Regular patterns are 근거리, 원거리, 돌진 and 땅울림",REGULARS.map(func(id): return HeroArchive.BEHAVIORS[Content.data.enemies[id].behavior]) == ["근거리","원거리","돌진","땅울림"])
	_check("No depth milestone adds a monster or swaps the boss",Content.data.milestones.all(func(entry): return not entry.has("enemyAdditions") and not entry.has("bossId")) and not map.has("roster"))
	_check("Depth 20 boss is still the gatekeeper",_state(20,20,0.0).run.wave_data().boss.enemyId == "gatekeeper" and _state(37,20,0.0).run.wave_data().boss.enemyId == "gatekeeper")
	_check("Depth scaling is kept",is_equal_approx(_state(10,1,0.0).run.difficulty.hp / _state(1,1,0.0).run.difficulty.hp,1.54) and _state(20,1,0.0).run.difficulty.eliteModifiers == ["ARMORED","BERSERK","REGENERATING"] and _state(20,1,0.0).run.difficulty.spawn > _state(19,1,0.0).run.difficulty.spawn * 1.07)
	var boss_wave: Dictionary = map.waveDefinitions[19]
	var before_boss: Dictionary = map.waveDefinitions[18]
	_check("Boss wave spawns at wave 19's density",is_equal_approx(boss_wave.interval,before_boss.interval) and int(boss_wave.batch) == int(before_boss.batch) and int(boss_wave.maxEnemies) == int(before_boss.maxEnemies) and boss_wave.enemies == before_boss.enemies)

	# Elites: two per map, one drawn per Run, 1 / 2 / 2 of the same body.
	_check("광화문 elite pool is the charger and the haetae head",map.elitePool == ["charger","haetaeHead"])
	var drawn := {}
	var consistent := true
	for index in range(40):
		var state := _state(1,7,0.0,"")
		var elite: String = state.run.setup.elite
		drawn[elite] = true
		for wave in [7,14,20]:
			state.run.wave = wave
			consistent = consistent and state.run.wave_data().elites.all(func(entry): return entry.enemyId == elite and entry.get("featured",false))
	_check("Each run draws one of the two elites for all its elite waves",consistent and drawn.size() == 2 and drawn.keys().all(func(id): return id in map.elitePool),drawn.keys())
	var counts: Array = []
	for wave in map.waveDefinitions:
		if wave.has("elites"): counts.append([int(wave.waveNumber),wave.elites.size()])
	_check("Elite counts are wave 7: 1, wave 14: 2, wave 20: 2",counts == [[7,1],[14,2],[20,2]],counts)
	var hp_ok := true
	for elite in map.elitePool:
		var state := _state(1,7,0.0,elite)
		for pair in [[7,1560.0],[14,775.0],[20,1000.0]]:
			state.run.wave = pair[0]
			for entry in state.run.wave_data().elites:
				hp_ok = hp_ok and is_equal_approx(float(entry.hpMultiplier) * float(Content.data.enemies[elite].maxHp),pair[1])
	_check("Either elite has 1560 HP on wave 7, 775 each on wave 14 and 1000 each on wave 20",hp_ok)
	var resumed := HeroRun.new(Content.data,_state(1,7,0.0,"haetaeHead").run.setup,Profile.meta)
	_check("The elite draw is saved with the run setup",resumed.setup.elite == "haetaeHead")
	_check("Depth 10 adds CURSED_AURA to the featured elite, depth 9 does not","CURSED_AURA" in _state(10,7,0.0).run.wave_data().elites[0].modifiers and _state(9,7,0.0).run.wave_data().elites[0].modifiers.is_empty())

	# Weekly monster: one for all maps, fixed inside a week, leading six waves.
	var pool: Array = Content.data.weeklyMonster.pool
	var reserve: Array = Content.data.weeklyMonster.reserve
	# The feature switch (WEEKLY_MONSTER.enabled); the pick itself is checked with it forced on.
	var weekly_on: bool = Content.data.weeklyMonster.enabled
	var forced := {"weeklyMonster":Content.data.weeklyMonster.merged({"enabled":true},true)}
	var boundary := (week + 1) * 604800.0 + 244800.0
	var meta_probe := {"weeklyGate":{"weekKey":"","ruleId":"","remainingRuleIds":[]}}
	HeroMeta.weekly(Content.data,meta_probe,boundary - 1.0)
	var before_key: String = meta_probe.weeklyGate.weekKey
	HeroMeta.weekly(Content.data,meta_probe,boundary)
	_check("Weekly key turns over at Sunday 05:00 KST",int(before_key) == week and int(meta_probe.weeklyGate.weekKey) == week + 1 and Time.get_datetime_dict_from_unix_time(int(boundary)).weekday == Time.WEEKDAY_SATURDAY and Time.get_datetime_dict_from_unix_time(int(boundary)).hour == 20,"%s -> %s" % [before_key,meta_probe.weeklyGate.weekKey])
	var current := HeroRoster.weekly_monster(forced,week)
	_check("Weekly pool is one 소환, one 분열 and one 자폭 monster",pool.map(func(id): return HeroArchive.BEHAVIORS[Content.data.enemies[id].behavior]) == ["소환","분열","자폭"],pool)
	_check("The three weekly, ten reserve monsters and the haetae head have art and motion",reserve.size() == 10 and not reserve.any(func(id): return id in pool) and (pool + reserve + ["haetaeHead"]).all(func(id): return Content.data.enemies.has(id) and id not in REGULARS and Content.visuals.enemies.has(id) and Content.actor_texture(Content.visuals.enemies[id]).atlas != null and Content.data.enemyPresentation.has(id)),reserve)
	_check("Weekly monster matches the web data module",[2961,2962,2963,2973].map(func(value): return HeroRoster.weekly_monster(forced,value)) == WEEKLY_VECTORS,[2961,2962,2963,2973].map(func(value): return HeroRoster.weekly_monster(forced,value)))
	# Shuffle bag over 1200 bags (3600 weeks).
	var bags_ok := true
	var no_repeat := true
	var orders := {}
	var turns := {}
	for bag in range(1200):
		var dealt: Array = range(3).map(func(offset): return HeroRoster.weekly_monster(forced,bag * 3 + offset))
		bags_ok = bags_ok and pool.all(func(id): return dealt.count(id) == 1)
		no_repeat = no_repeat and HeroRoster.weekly_monster(forced,bag * 3 + 3) != dealt[2]
		orders[",".join(dealt)] = int(orders.get(",".join(dealt),0)) + 1
		for id in dealt: turns[id] = int(turns.get(id,0)) + 1
	_check("Every bag of three weeks deals each weekly monster exactly once",bags_ok and current in pool and HeroRoster.weekly_monster(forced,-1).is_empty(),turns)
	_check("No monster leads two weeks in a row, across bag boundaries too",no_repeat)
	_check("The bag is reshuffled: all six orders come up",orders.size() == 6 and orders.values().all(func(count): return count >= 120),orders)
	_check("Capture weeks deal one weekly monster each",pool.all(func(id): return HeroRoster.weekly_monster(forced,int(WEEKLY_WEEKS[id])) == id))
	_check("The switch decides whether a week has a monster",HeroRoster.weekly_monster(Content.data,week).is_empty() != weekly_on,"enabled=%s" % str(weekly_on))
	var lead_ok := true
	for depth in [1,20]:
		var weekly_run: HeroRun = _state(depth,1,0.0,"charger",week).run
		for wave in range(1,21):
			weekly_run.wave = wave; base.run.wave = wave
			var entries: Array = weekly_run.wave_data().enemies
			var total := 0.0
			for entry in entries: total += float(entry.weight)
			lead_ok = lead_ok and is_equal_approx(total,100.0)
			if weekly_on and wave in [3,6,9,12,15,18]: lead_ok = lead_ok and entries[0].enemyId == current and is_equal_approx(entries[0].weight,35.0) and entries.size() == base.run.wave_data().enemies.size() + 1
			else: lead_ok = lead_ok and entries == base.run.wave_data().enemies
	_check("The weekly monster leads waves 3/6/9/12/15/18 at weight 35 and no other wave" if weekly_on else "Switched off, waves 3/6/9/12/15/18 keep the authored four regulars",lead_ok)
	var run: HeroRun
	if not weekly_on:
		run = await _combat_shot("rework-01-wave03-regulars-only",_state(1,3,0.0,"charger",week),11.0)
		var met := {}
		for enemy in run.enemies: met[enemy.definition] = true
		_check("Wave 3 spawns only the four regulars",not met.is_empty() and met.keys().all(func(id): return id in REGULARS),met.keys())
	else:
		# One Wave 3 per weekly monster, each in a week that deals it.
		for id in pool:
			run = await _combat_shot("rework-01-wave03-weekly-%s" % str(id).to_lower(),_state(1,3,0.0,"charger",int(WEEKLY_WEEKS[id])),16.0)
			var met := {}
			for enemy in run.enemies: met[enemy.definition] = true
			_check("Wave 3 spawns the weekly %s beside the regulars" % id,run.wave_data().enemies[0].enemyId == id and met.has(id) and met.keys().all(func(other): return other == id or other in REGULARS or other == Content.data.enemies[id].get("childId","")),met.keys())
	await _pattern_checks()

	# 땅울림: hop in place through the warning, blast at touchdown, same 3 s cadence.
	var duel := _duel("bulwark",Vector2(70,-10))
	var hud := _hud(duel.run)
	var quake: Dictionary = duel.enemy
	var hopped := await _until(duel,1.0,func(): return quake.action == "hop",hud)
	var origin: Vector2 = quake.pos
	var started: float = duel.run.elapsed
	_check("In range the 땅울림 monster starts a hop with a 100 px warning",hopped and duel.run.hazards.size() == 1 and is_equal_approx(duel.run.hazards[0].radius,100.0) and absf(duel.run.hazards[0].delay - 1.0) < 0.03,duel.run.hazards)
	await _until(duel,1.0,func(): return quake.timer <= 0.3,hud)
	var actor: HeroGroundedVisual = _world.find_children("*","HeroGroundedVisual",true,false).filter(func(node): return node.visible and node.position.is_equal_approx(quake.pos)).front()
	_check("The single sprite is off the ground mid-hop",actor != null and actor.sprite.position.y < -quake.radius * 3.4 * 0.25,actor.sprite.position if actor else "no actor")
	hud = await _keep_shot(hud,"rework-02-quake-hop-midair")
	await _until(duel,1.0,func(): return quake.action != "hop",hud)
	_check("The blast lands at touchdown where the hop began",absf(duel.run.elapsed - started - 1.0) < 0.05 and duel.run.hazards.is_empty() and quake.pos.is_equal_approx(origin) and duel.run.effects.any(func(effect): return effect.kind == "explosion" and effect.pos.is_equal_approx(origin)),"%.2fs" % (duel.run.elapsed - started))
	_check("The next 땅울림 comes 3 s after the last one began",is_equal_approx(quake.timer,2.0),quake.timer)
	for frame in range(4): await _advance(duel,1.0 / 60.0,hud)
	await _shot(hud,"rework-02b-quake-touchdown",true)

	# Elite 땅울림: wider, and a second hop and blast right after the first.
	duel = _duel("haetaeHead",Vector2(110,0))
	var haetae: Dictionary = duel.enemy
	var hops := 0
	var last := ""
	var radii: Array = []
	for index in range(240):
		await _advance(duel,1.0 / 60.0)
		if haetae.action == "hop" and last != "hop": hops += 1; radii.append(duel.run.hazards.back().radius)
		last = haetae.action
	_check("The haetae head hops twice with a 150 px blast each",hops == 2 and radii == [150.0,150.0],"%d hops %s" % [hops,str(radii)])

	# Elite 돌진: one warning, two dashes in a row.
	duel = _duel("charger",Vector2(260,0))
	var charger: Dictionary = duel.enemy
	var dashes := 0
	last = ""
	for index in range(200):
		await _advance(duel,1.0 / 60.0)
		if charger.action == "dash" and last != "dash": dashes += 1
		last = charger.action
	_check("The charger dashes twice after its warning, then rests",dashes == 2 and charger.action == "move" and charger.timer > 0.5,"%d dashes" % dashes)
	duel = _duel("runner",Vector2(200,0))
	var runner: Dictionary = duel.enemy
	dashes = 0; last = ""
	for index in range(150):
		await _advance(duel,1.0 / 60.0)
		if runner.action == "dash" and last != "dash": dashes += 1
		last = runner.action
	_check("The regular runner still dashes once",dashes == 1,"%d dashes" % dashes)

	# Wave 7: the Run's one elite, either body.
	for elite in map.elitePool:
		run = await _combat_shot("rework-0%d-wave07-elite-%s" % [3 + map.elitePool.find(elite),elite.to_lower()],_state(1,7,9.0,elite),4.5)
		var elites := HeroFeaturedElites.alive(run)
		_check("Wave 7 fields one %s elite with about 1560 HP" % elite,elites.size() == 1 and elites[0].definition == elite and absf(elites[0].maxHp - 1560.0 * run.difficulty.hp) < 2.0 and elites[0].elite,elites.map(func(enemy): return [enemy.definition,enemy.maxHp]))

	# Wave 14: two of the same elite.
	run = await _combat_shot("rework-05-wave14-two-identical-elites",_state(1,14,7.0,"haetaeHead"),12.0)
	var pair := HeroFeaturedElites.alive(run)
	_check("Wave 14 fields two identical elites",pair.size() == 2 and pair[0].definition == "haetaeHead" and pair[1].definition == "haetaeHead",pair.map(func(enemy): return enemy.definition))

	# Wave 20: the boss, two elites and the regulars together; the boss only scatters bullets.
	var final := _state(1,20,0.0,"charger")
	run = final.run
	hud = _hud(run)
	await _advance(final,1.2,hud)
	_check("The boss arriving puts no text on screen",run.enemies.any(func(enemy): return enemy.boss) and _silent(hud,run),_hud_copy(hud))
	hud = await _keep_shot(hud,"rework-06a-wave20-boss-arrives-no-text")
	var travelled := 0.0
	var most_bullets := 0
	var boss: Dictionary = {}
	var previous := Vector2.ZERO
	var shot := false
	for index in range(24 * 60):
		await _advance(final,1.0 / 60.0,hud)
		if boss.is_empty():
			boss = run.enemies.filter(func(enemy): return enemy.boss).front()
			previous = boss.pos
		if boss.action == "volley": travelled += boss.pos.distance_to(previous)
		previous = boss.pos
		most_bullets = maxi(most_bullets,run.hostile.size())
		# Third ring of a volley once both elites are on the field.
		if not shot and run.elapsed > 19.0 and boss.action == "volley" and int(boss.repeats) == 2 and run.hostile.size() >= 20:
			shot = true
			hud = await _keep_shot(hud,"rework-06-wave20-boss-elites-scatter")
	var escorts := HeroFeaturedElites.alive(run)
	var regulars: Array = run.enemies.filter(func(enemy): return not enemy.boss and not enemy.get("featured",false))
	_check("Wave 20 has the boss, two identical elites and regular monsters at once",shot and run.enemies.filter(func(enemy): return enemy.boss).size() == 1 and escorts.size() == 2 and escorts.all(func(enemy): return enemy.definition == "charger") and regulars.size() >= 15 and regulars.all(func(enemy): return enemy.definition in REGULARS),"%d regulars, %d elites" % [regulars.size(),escorts.size()])
	var patterns: Array = Content.data.enemies.gatekeeper.bossPatterns
	_check("The gatekeeper has one pattern: a turning bullet scatter, no summon",patterns.size() == 1 and patterns[0].type == "spiral" and int(boss.summons) == 0 and int(boss.pattern) >= 3 and most_bullets >= int(patterns[0].count) * 3,"%d volleys, %d bullets at most" % [int(boss.pattern),most_bullets])
	_check("The gatekeeper keeps moving while it fires",travelled > 100.0,"%.0f px during volleys" % travelled)
	_check("The boss wave shows no name and only the player's HUD bar",_nameless(hud,run),_hud_copy(hud))
	boss.hp = 0.0
	await _advance(final,0.05)
	_check("Killing the boss clears the stage with elites still alive",run.phase == "stageClear")
	_canvas.remove_child(hud); hud.free()

	# Gate screen: 이번 주 몬스터.
	var draft := {"map":"seoul","depth":10,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId,"week":week}
	var gate := HeroGateScreen.build(draft,0,_noop,_noop,_noop,{})
	_canvas.add_child(gate)
	await get_tree().process_frame
	var strip := gate.find_child("WeeklyAppearances",true,false) as Control
	var portrait := gate.find_child("WeeklyAppearance_0",true,false) as TextureRect
	var labels: Array = strip.find_children("*","Label",true,false).map(func(label): return label.text) if strip else []
	if not weekly_on: _check("Switched off, the gate screen shows no weekly monster",strip == null and portrait == null and not gate.find_children("*","Label",true,false).any(func(label): return "이번 주 몬스터" in label.text))
	else: _check("Gate screen shows this week's single monster with its portrait",strip != null and portrait != null and portrait.texture != null and portrait.get_meta("content_id") == current and gate.find_child("WeeklyAppearance_1",true,false) == null and "이번 주 몬스터" in labels and str(Content.data.enemies[current].name) in labels,labels)
	if weekly_on: _check("The strip stays on screen in the night-ops row skin",strip != null and get_viewport().get_visible_rect().encloses(strip.get_global_rect()) and strip.get_meta("material_key","") == "ops/row" and strip.find_children("*","Label",true,false).all(func(label): return strip.get_global_rect().encloses(label.get_global_rect())))
	await _shot(gate,"rework-07-gate-weekly-monster" if weekly_on else "rework-07-gate-no-weekly-monster")
	draft.erase("week")
	var plain := HeroGateScreen.build(draft,0,_noop,_noop,_noop,{})
	_canvas.add_child(plain)
	# Deferred layout callbacks of the screen run before it is freed.
	for frame in range(2): await get_tree().process_frame
	_check("No strip without a weekly key",plain.find_child("WeeklyAppearances",true,false) == null)
	_canvas.remove_child(plain); plain.free()

	# Archive: the map's cast only, with the new pattern name.
	var view := {"group":"enemies","id":"haetaeHead","page":2,"growthPage":0,"map":"seoul","scroll":0}
	var listed: Array = HeroArchive.entries(view)
	var cast: Array = REGULARS + map.elitePool + ["gatekeeper"] + (pool if weekly_on else [])
	_check("Archive lists only the %d monsters met in 광화문" % cast.size(),listed.size() == cast.size() and cast.all(func(id): return id in listed) and not reserve.any(func(id): return id in listed),listed)
	if weekly_on:
		var weekly_view := {"group":"enemies","id":"lampFirefly","page":2,"growthPage":0,"map":"seoul","scroll":maxi(0,(listed.find("lampFirefly") / 5 - 1) * 81)}
		var weekly_page := HeroArchive.build(weekly_view,_noop,_noop)
		_canvas.add_child(weekly_page)
		for frame in range(3): await get_tree().process_frame
		var weekly_copy: Array = weekly_page.find_child("ArchiveDetails",true,false).find_children("*","Label",true,false).map(func(label): return label.text)
		_check("Archive shows the weekly 자폭 monster",str(Content.data.enemies.lampFirefly.name) in weekly_copy and weekly_copy.any(func(text): return "자폭" in text),weekly_copy.slice(0,4))
		await _shot(weekly_page,"rework-08b-archive-weekly-lampfirefly")
	var archive := HeroArchive.build(view,_noop,_noop)
	_canvas.add_child(archive)
	for frame in range(3): await get_tree().process_frame
	var copy: Array = archive.find_child("ArchiveDetails",true,false).find_children("*","Label",true,false).map(func(label): return label.text)
	_check("Archive names the pattern 땅울림, never 탱커",copy.any(func(text): return "땅울림" in text) and "해태 균열두" in copy and not copy.any(func(text): return "탱커" in text or "중장갑" in text),copy.slice(0,4))
	await _shot(archive,"rework-08-archive-haetaehead")
	_check("No save writes",not Profile.writable)

# The three weekly patterns, each on a lone monster: 소환, 분열, 자폭.
func _pattern_checks() -> void:
	var rules: Dictionary = Content.data.enemyRules
	# 소환: one small minion every few seconds while fewer than three of its own live.
	var duel := _duel("summoner",Vector2(220,0))
	var hud := _hud(duel.run)
	var summoner: Dictionary = duel.enemy
	var rule: Dictionary = Content.data.enemies.summoner.summon
	var minions := func(): return duel.run.enemies.filter(func(enemy): return enemy.get("parent",-1) == summoner.id and enemy.hp > 0)
	var casts: Array = []
	var most := 0
	for index in range(13 * 60):
		var before := int(summoner.summons)
		await _advance(duel,1.0 / 60.0,hud)
		if int(summoner.summons) > before: casts.append(duel.run.elapsed)
		most = maxi(most,minions.call().size())
	var gaps: Array = range(1,casts.size()).map(func(index): return casts[index] - casts[index - 1])
	_check("The summoner calls one minion every %s s up to %d living" % [str(rule.interval),int(rule.alive)],casts.size() == int(rule.alive) and most == int(rule.alive) and gaps.all(func(gap): return absf(gap - float(rule.interval)) < 0.05),"%d casts, gaps %s" % [casts.size(),str(gaps)])
	_check("Its minions are small and pay a quarter",minions.call().all(func(enemy): return enemy.definition == "swarm" and enemy.radius < summoner.radius * 0.7 and is_equal_approx(enemy.reward,Content.data.enemies.swarm.magicStoneDrop * float(rules.summonedRewardMultiplier))))
	hud = await _keep_shot(hud,"rework-09-pattern-summon")
	minions.call()[0].hp = 0.0
	var again := await _until(duel,float(rule.interval) + 0.2,func(): return minions.call().size() == int(rule.alive) and int(summoner.summons) == int(rule.alive) + 1,hud)
	_check("A killed minion is replaced by the next cast",again,"%d summoned in all" % int(summoner.summons))
	_canvas.remove_child(hud); hud.free()

	# 분열: two smaller copies on death, each of which splits once more.
	duel = _duel("splitter",Vector2(170,0))
	hud = _hud(duel.run)
	var split: Dictionary = Content.data.enemies.splitter.split
	var parent: Dictionary = duel.enemy
	var parent_hp: float = parent.maxHp
	var parent_radius: float = parent.radius
	var parent_reward: float = parent.reward
	await _advance(duel,0.4,hud)
	parent.hp = 0.0
	await _advance(duel,0.1,hud)
	var first: Array = duel.run.enemies.duplicate()
	_check("A killed splitter leaves two smaller splitters",first.size() == 2 and first.all(func(enemy): return enemy.definition == "splitter" and int(enemy.generation) == 1 and is_equal_approx(enemy.maxHp,parent_hp * float(split.hp)) and is_equal_approx(enemy.radius,parent_radius * float(split.size)) and is_equal_approx(enemy.reward,parent_reward * float(split.reward)) and not enemy.elite),first.map(func(enemy): return [enemy.maxHp,enemy.radius]))
	await _advance(duel,0.5,hud)
	hud = await _keep_shot(hud,"rework-10-pattern-split-first")
	for enemy in first: enemy.hp = 0.0
	await _advance(duel,0.1,hud)
	var second: Array = duel.run.enemies.duplicate()
	_check("Each of them splits once more into two smaller ones",second.size() == 4 and second.all(func(enemy): return enemy.definition == "splitter" and int(enemy.generation) == 2 and is_equal_approx(enemy.radius,parent_radius * float(split.size) * float(split.size))),second.map(func(enemy): return [enemy.maxHp,enemy.radius]))
	await _advance(duel,0.5,hud)
	hud = await _keep_shot(hud,"rework-11-pattern-split-second")
	for enemy in second: enemy.hp = 0.0
	await _advance(duel,0.1,hud)
	_check("The second split is the last: seven kills, nothing left",duel.run.enemies.is_empty() and duel.run.kills == 7,"%d left, %d kills" % [duel.run.enemies.size(),duel.run.kills])
	_canvas.remove_child(hud); hud.free()

	# 자폭: runs up, flashes for a second in place, then blasts an area and is gone.
	duel = _duel("lampFirefly",Vector2(300,0))
	hud = _hud(duel.run)
	var bomber: Dictionary = duel.enemy
	var from: Vector2 = bomber.pos
	var lit := await _until(duel,4.0,func(): return bomber.action == "warning",hud)
	var fuse_start: float = duel.run.elapsed
	var fuse_pos: Vector2 = bomber.pos
	_check("The bomber runs up and lights its fuse within %d px" % int(rules.bomberTrigger),lit and from.distance_to(fuse_pos) > 150.0 and fuse_pos.distance_to(duel.run.player.pos) <= float(rules.bomberTrigger) + 2.0 and duel.run.hazards.is_empty(),"%.0f px from the player" % fuse_pos.distance_to(duel.run.player.pos))
	await _advance(duel,0.55,hud)
	var actor: HeroGroundedVisual = _world.find_children("*","HeroGroundedVisual",true,false).filter(func(node): return node.visible and node.position.is_equal_approx(bomber.pos)).front()
	_check("It flashes in place while the fuse burns",bomber.action == "warning" and bomber.pos.is_equal_approx(fuse_pos) and actor != null and actor.sprite.modulate.g < 0.9,actor.sprite.modulate if actor else "no actor")
	hud = await _keep_shot(hud,"rework-12-pattern-bomber-flash")
	var blasts := func(): return duel.run.effects.filter(func(effect): return effect.kind == "explosion" and effect.pos.is_equal_approx(fuse_pos))
	var burst := await _until(duel,1.0,func(): return not blasts.call().is_empty(),hud)
	_check("After about 1 s it blasts a %d px area and is gone without a reward" % int(rules.bomberRadius),burst and absf(duel.run.elapsed - fuse_start - float(rules.bomberWarning)) < 0.05 and is_equal_approx(blasts.call()[0].radius,float(rules.bomberRadius)) and duel.run.kills == 0 and duel.run.pickups.is_empty(),"%.2fs" % (duel.run.elapsed - fuse_start))
	for frame in range(5): await _advance(duel,1.0 / 60.0,hud)
	_check("The spent bomber leaves the field",duel.run.enemies.is_empty())
	await _shot(hud,"rework-13-pattern-bomber-blast",true)

# Saves the frame and hands back a fresh HUD for the same run.
func _keep_shot(hud: Control, id: String) -> Control:
	var run: HeroRun = _world.run
	await _shot(hud,id,true)
	var next := _hud(run)
	HeroCombatUI.update_hud(next,run)
	return next
func _main() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Run-structure capture requires --ui-preview to block save writes.")
		get_tree().quit(1); return
	_output = ProjectSettings.globalize_path("res://").path_join("../design/run-structure-captures").simplify_path()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_output)
	DisplayServer.window_set_size(Vector2i(915,412))
	var original: Dictionary = Profile.meta
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	Profile.meta.guild = HeroGuildState.create(Content.data,1000.0)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.weekly(Content.data,Profile.meta,Time.get_unix_time_from_system())
	_world = HeroWorld.new(); add_child(_world); _world.visible = false
	add_child(_canvas)
	for frame in range(3): await get_tree().process_frame
	var rules: Dictionary = Content.data.featuredElites

	_check("Old fixed elites on waves 5/10/15 are gone",[5,10,15].all(func(wave): return not Content.data.maps.seoul.waveDefinitions[wave - 1].has("elites")))
	# Wave 7: announced elite; no name anywhere in the HUD, HP only on the overhead bar.
	var seven := _state(1,7,6.0)
	var run: HeroRun = seven.run
	var hud := _hud(run)
	await _advance(seven,3.9,hud)
	_check("No featured elite before its time",HeroFeaturedElites.alive(run).is_empty() and is_equal_approx(HeroFeaturedElites.spawn_rate(run),1.0))
	await _advance(seven,1.6,hud)
	var elites := HeroFeaturedElites.alive(run)
	var expected_hp: float = 1560.0 * run.difficulty.hp
	_check("Wave 7 featured elite spawned at 10s",elites.size() == 1 and elites[0].definition == "charger")
	if not elites.is_empty():
		_check("Wave 7 elite HP is about 30% of the gatekeeper",absf(elites[0].maxHp - expected_hp) < expected_hp * 0.02,"%.1f / target %.1f" % [elites[0].maxHp,expected_hp])
	_check("Ordinary spawn rate x0.7 while the elite lives",is_equal_approx(HeroFeaturedElites.spawn_rate(run),float(rules.spawnRateWhileAlive)))
	var banner := hud.find_child("EliteBanner",true,false) as Label
	_check("An elite arriving puts no text on screen",banner != null and banner.text.is_empty() and _silent(hud,run),_hud_copy(hud))
	_check("HUD has no elite nameplate, name or HP bar",_nameless(hud,run),_hud_copy(hud))
	await _shot(hud,"29-no-text-wave07-elite-arrives",true)

	# Uncaught elite flees with the Wave: no reward, no supply.
	var pickups_before := run.pickups.size()
	run.elapsed = run.wave_data().duration - 0.02
	await _advance(seven,0.1)
	_check("Wave timer ends the wave with the elite alive",run.phase == "postWave" and seven.sim.spawn.featured_kills == 0)
	hud = _hud(run)
	HeroCombatUI.update_hud(hud,run)
	_check("An elite escaping puts no text on screen",_silent(hud,run) and (hud.find_child("EliteBanner",true,false) as Label).text.is_empty(),_hud_copy(hud))
	await _shot(hud,"30-no-text-wave07-elite-escapes",true)
	await _advance(seven,1.1)
	_check("Fled elite grants no supply",run.phase == "shop" and _free_offers(run).is_empty() and pickups_before >= 0)

	# Killed elite: stone shower and one free rare-or-better item in the next shop.
	var kill := _state(1,7,9.9)
	run = kill.run
	await _advance(kill,0.3)
	elites = HeroFeaturedElites.alive(run)
	var stones_before := run.pickups.size()
	var value_before := 0.0
	for pickup in run.pickups: value_before += float(pickup.value)
	if not elites.is_empty(): elites[0].hp = 0.0
	await _advance(kill,0.04)
	var value_after := 0.0
	for pickup in run.pickups: value_after += float(pickup.value)
	_check("Elite kill is counted once",kill.sim.spawn.featured_kills == 1 and HeroFeaturedElites.tracked(run).is_empty())
	_check("Stone shower scatters about 30 kills' worth",run.pickups.size() >= stones_before + int(rules.showerStones) and value_after - value_before >= float(rules.showerValue) * run.difficulty.reward * 0.99,"+%d stones, +%.1f value (shower %.1f)" % [run.pickups.size() - stones_before,value_after - value_before,float(rules.showerValue)])
	await _to_shop(kill)
	var free := _free_offers(run)
	_check("Next shop offers exactly one free item",run.phase == "shop" and free.size() == 1)
	if not free.is_empty():
		var rarity: String = run.data.items[free[0].id].rarity
		_check("Free item is rare or better",rarity in rules.supplyRarities,"%s (%s)" % [free[0].id,rarity])
		var index := run.item_stock.find(free[0])
		run.currency = 0.0
		_check("Free item costs nothing and is purchasable at 0 stones",HeroShop.item_price(run,free[0]) == 0 and HeroShop.offer_block_reason(run,free[0],false).is_empty())
		var screen := HeroShopScreen.build(run,false,_noop,_noop,_noop,_noop)
		_canvas.add_child(screen)
		await get_tree().process_frame
		var label := screen.find_child("ShopFree",true,false) as Label
		var product := screen.find_child("ShopProduct_%d" % index,true,false) as Control
		_check("Free marker sits inside the existing card",label != null and label.text == "무료" and product != null and product.get_global_rect().encloses(label.get_global_rect()))
		run.currency = 64.0
		_canvas.remove_child(screen); screen.free()
		await _shot(HeroShopScreen.build(run,false,_noop,_noop,_noop,_noop),"03-shop-elite-supply")
		var kept_id: String = free[0].id
		run.currency = 500.0
		HeroShop.reroll(run,false)
		_check("Free item survives a reroll",run.item_stock[index].get("free",false) and run.item_stock[index].id == kept_id)
		run.currency = 0.0
		_check("Buying the free item succeeds and clears the slot",HeroShop.buy(run,index,false) and int(run.items.get(kept_id,0)) == 1 and is_zero_approx(run.currency) and _free_offers(run).is_empty())

	# Wave 14: two elites and the last-15-seconds surge.
	var surge := _state(1,14,7.5,"haetaeHead")
	run = surge.run
	await _advance(surge,7.0)
	elites = HeroFeaturedElites.alive(run)
	var titles: Array = elites.map(func(enemy): return enemy.definition)
	_check("Wave 14 spawns both featured elites",titles == ["haetaeHead","haetaeHead"],titles)
	if elites.size() == 2:
		_check("Wave 14 elite HP is 775 each",absf(elites[0].maxHp - 775.0 * run.difficulty.hp) < 2.0 and absf(elites[1].maxHp - 775.0 * run.difficulty.hp) < 2.0,"%.1f / %.1f" % [elites[0].maxHp,elites[1].maxHp])
	run.elapsed = 34.9
	await _advance(surge,0.03)
	var sample: Dictionary = {}
	for enemy in run.enemies:
		if not enemy.get("featured",false): sample = enemy; break
	var reward_before: float = sample.get("reward",0.0)
	_check("No surge before the last 15 seconds",HeroFeaturedElites.surge(run).is_empty() and not surge.sim.spawn.surge_started)
	hud = _hud(run)
	await _advance(surge,1.4,hud)
	var rule := HeroFeaturedElites.surge(run)
	_check("Surge is active in the last 15 seconds",not rule.is_empty() and rule.name == "균열 폭주" and surge.sim.spawn.surge_started)
	_check("Surge spawn rate x1.5 (x0.7 while elites live)",is_equal_approx(HeroFeaturedElites.spawn_rate(run),1.5 * (float(rules.spawnRateWhileAlive) if not HeroFeaturedElites.alive(run).is_empty() else 1.0)),HeroFeaturedElites.spawn_rate(run))
	if not sample.is_empty():
		_check("Living enemies pay x1.5 stones once the surge starts",is_equal_approx(sample.reward,reward_before * 1.5),"%.3f -> %.3f" % [reward_before,sample.reward])
	var fresh := HeroSpawn.spawn(run,"crawler")
	_check("Enemies spawned during the surge pay x1.5",is_equal_approx(fresh.reward,run.data.enemies.crawler.magicStoneDrop * run.difficulty.reward * 1.5),fresh.get("reward",0.0))
	var tag := hud.find_child("SurgeTag",true,false) as Label
	_check("HUD shows the surge tag",tag != null and tag.text.begins_with("균열 폭주"),tag.text if tag else "")
	_check("Two living elites add no nameplate, name or HP bar to the HUD",HeroFeaturedElites.alive(run).size() == 2 and _nameless(hud,run),_hud_copy(hud))
	var surge_backing := hud.find_child("SurgeBacking",true,false) as Control
	var elite_banner := hud.find_child("EliteBanner",true,false) as Control
	_check("Surge tag has a backing and clears the timer and the centre banner",tag != null and surge_backing != null and surge_backing.visible and surge_backing.get_global_rect().encloses(tag.get_global_rect()) and not tag.get_global_rect().intersects(elite_banner.get_global_rect()) and not tag.get_global_rect().intersects((hud.find_child("Timer",true,false) as Control).get_global_rect()),tag.get_global_rect() if tag else "")
	await _shot(hud,"28-no-nameplate-wave14-surge",true)
	for enemy in HeroFeaturedElites.alive(run): enemy.hp = 0.0
	await _advance(surge,0.04)
	_check("Killing every wave 14 elite upgrades the supply",surge.sim.spawn.featured_kills == 2 and HeroFeaturedElites.supply_rarities(run,2) == rules.sweepRarities and HeroFeaturedElites.supply_rarities(run,1) == rules.supplyRarities)
	await _to_shop(surge)
	free = _free_offers(run)
	_check("Wave 14 sweep supply is epic or better",free.size() == 1 and run.data.items[free[0].id].rarity in rules.sweepRarities,run.data.items[free[0].id].rarity if not free.is_empty() else "none")
	run.currency = 210.0
	# Forced shelf for the capture: the sweep supply as an EPIC item beside RARE, EPIC and LEGENDARY cards.
	var shelf := ["scarSeal","mineCase","splitter","stormCore"]
	var supply_index := maxi(0,run.item_stock.find(free[0]) if not free.is_empty() else 0)
	for slot in range(4): run.item_stock[slot] = {"id":shelf[slot],"locked":false,"level":0}
	run.item_stock[supply_index] = {"id":"scarSeal","locked":false,"level":0,"free":true}
	if supply_index != 0: run.item_stock[0] = {"id":"revengeFuse","locked":false,"level":0}
	var epic_shop := HeroShopScreen.build(run,false,_noop,_noop,_noop,_noop)
	var tiers: Array = range(4).map(func(slot): return str((epic_shop.find_child("ShopProduct_%d" % slot,true,false) as Control).get_meta("material_key","")))
	_check("EPIC offers use the epic card skin",range(4).all(func(slot): return (run.data.items[run.item_stock[slot].id].rarity == "EPIC") == (tiers[slot] == "night/card_epic")) and "night/card_epic" in tiers,tiers)
	_check("EPIC supply is free and purchasable",HeroShop.item_price(run,run.item_stock[supply_index]) == 0 and HeroShop.offer_block_reason(run,run.item_stock[supply_index],false).is_empty())
	await _shot(epic_shop,"09-shop-epic-supply-wave14")
	# Forced shelf: one card per item rarity above COMMON, each on its own skin.
	var rarity_shelf := ["battery","mineCase","splitter","stormCore"]
	for slot in range(4): run.item_stock[slot] = {"id":rarity_shelf[slot],"locked":false,"level":0}
	var rarity_shop := HeroShopScreen.build(run,false,_noop,_noop,_noop,_noop)
	tiers = range(4).map(func(slot): return str((rarity_shop.find_child("ShopProduct_%d" % slot,true,false) as Control).get_meta("material_key","")))
	_check("UNCOMMON, RARE, EPIC and LEGENDARY each use their own card skin",tiers == ["night/card_uncommon","night/card_rare","night/card_epic","night/card_legendary"] and ResourceLoader.exists("res://assets/ui/image-skin/night-operations-01/card_uncommon.png"),tiers)
	_check("Resonance prism is a single-stack EPIC",int(Content.data.items.resonancePrism.maxStacks) == 1 and Content.data.items.resonancePrism.rarity == "EPIC")
	await _shot(rarity_shop,"11-shop-five-rarities")

	# Item rarity data and the archive entry for an EPIC item.
	var counts := {}
	for item in Content.data.items.values(): counts[item.rarity] = int(counts.get(item.rarity,0)) + 1
	_check("Item rarities are 18 / 18 / 9 / 5 / 5",counts == {"COMMON":18,"UNCOMMON":18,"RARE":9,"EPIC":5,"LEGENDARY":5},counts)
	var epic_prices: Array = ["splitter","conductor","scarSeal","revengeFuse","resonancePrism"].map(func(id): return int(Content.data.items[id].basePrice))
	_check("The five EPIC items cost 60-69 stones",epic_prices.all(func(price): return price >= 60 and price <= 69) and ["splitter","conductor","scarSeal","revengeFuse","resonancePrism"].all(func(id): return Content.data.items[id].rarity == "EPIC"),epic_prices)
	_check("Shop rolls EPIC from wave 10 at weight 2.5",Content.data.shop.rarities.has("EPIC") and int(Content.data.shop.rarities.EPIC.wave) == 10 and is_equal_approx(Content.data.shop.rarities.EPIC.weight,2.5) and Content.data.items.values().all(func(item): return Content.data.shop.rarities.has(item.rarity)))
	_check("Supply is rare or better, sweep is epic or better",rules.supplyRarities == ["RARE","EPIC","LEGENDARY"] and rules.sweepRarities == ["EPIC","LEGENDARY"])
	var early := _state(1,9,0.0)
	var late := _state(1,10,0.0)
	_check("EPIC enters the shop pool at wave 10, not 9",not HeroShop._item_pool(early.run).any(func(item): return item.rarity == "EPIC") and HeroShop._item_pool(late.run).any(func(item): return item.rarity == "EPIC"))
	var view := {"group":"items","id":"scarSeal","page":0,"growthPage":0,"map":"seoul","scroll":0}
	var order: Array = HeroArchive.entries(view).map(func(id): return Content.data.items[id].rarity)
	var ranks: Array = order.map(func(rarity): return HeroArchive.RARITIES.keys().find(rarity))
	var sorted_ranks := ranks.duplicate(); sorted_ranks.sort()
	_check("Archive lists EPIC between RARE and LEGENDARY",ranks == sorted_ranks and order.count("EPIC") == 5 and HeroArchive.RARITIES.EPIC == "영웅")
	view.scroll = maxi(0,(HeroArchive.entries(view).find("scarSeal") / 5 - 1) * 81)
	var archive := HeroArchive.build(view,_noop,_noop)
	_canvas.add_child(archive)
	for frame in range(3): await get_tree().process_frame
	var labels: Array = archive.find_child("ArchiveDetails",true,false).find_children("*","Label",true,false).map(func(label): return label.text)
	_check("Archive detail names the EPIC rarity","영웅" in labels and "흉터 인장" in labels,labels.slice(0,3))
	await _shot(archive,"10-archive-epic-item")

	# Checkpoint shape: spawn bookkeeping survives a JSON round trip.
	var restored := _state(1,14,20.0)
	restored.run.spawn_state = JSON.parse_string(JSON.stringify({"nextSpawn":0.4,"triggeredElites":[0,1],"bossSpawned":false,"surgeStarted":false,"featuredKills":1}))
	var resumed := HeroSimulation.new(restored.run)
	await _advance({"run":restored.run,"sim":resumed},0.05)
	_check("Resumed run does not respawn triggered elites",HeroFeaturedElites.alive(restored.run).is_empty() and resumed.spawn.featured_kills == 1)

	# Gate depth paging beyond 20.
	var draft := {"map":"seoul","depth":5,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId}
	Profile.meta.gateProgression.highestUnlockedDepth = 12
	Profile.meta.gateProgression.characters.awakener = {"highestClearedDepth":11,"rewardedThroughDepth":11,"bestWaveByDepth":{"12":13}}
	var gate := HeroGateScreen.build(draft,1,_noop,_noop,_noop,{})
	_check("Depth screen is unchanged until depth 21 unlocks",gate.find_child("DepthPageNext",true,false) == null and gate.find_child("GateDepth_20",true,false) != null)
	gate.queue_free()
	Profile.meta.gateProgression.highestUnlockedDepth = 27
	Profile.meta.gateProgression.characters.awakener = {"highestClearedDepth":26,"rewardedThroughDepth":26,"bestWaveByDepth":{"27":13}}
	var picked: Array = []
	var change := func(key: String, value): picked.append([key,value])
	gate = HeroGateScreen.build(draft,1,change,_noop,_noop,{})
	_canvas.add_child(gate)
	await get_tree().process_frame
	var following := gate.find_child("DepthPageNext",true,false) as Button
	var top := gate.find_child("DepthHighest",true,false) as Button
	var previous := gate.find_child("DepthPagePrevious",true,false) as Button
	_check("First page offers next and highest, not previous",following != null and not following.disabled and top != null and not top.disabled and previous != null and previous.disabled)
	if following: following.pressed.emit()
	if top: top.pressed.emit()
	_check("Next selects depth 21 and highest jumps to 27",picked == [["depth",21],["depth",27]],picked)
	_canvas.remove_child(gate); gate.free()
	draft.depth = 23
	gate = HeroGateScreen.build(draft,1,change,_noop,_noop,{})
	_canvas.add_child(gate)
	await get_tree().process_frame
	var unlocked := gate.find_child("GateDepth_27",true,false) as Button
	var locked := gate.find_child("GateDepth_28",true,false) as Button
	previous = gate.find_child("DepthPagePrevious",true,false) as Button
	following = gate.find_child("DepthPageNext",true,false) as Button
	_check("Second page shows 21-40 with 27 open and 28 locked",gate.find_child("GateDepth_20",true,false) == null and unlocked != null and not unlocked.disabled and locked != null and locked.disabled)
	_check("Last page can only go back",previous != null and not previous.disabled and following != null and following.disabled)
	var touch := true
	for control in [previous,following,gate.find_child("DepthHighest",true,false)]:
		touch = touch and control != null and control.size.x >= 44 and control.size.y >= 44 and get_viewport().get_visible_rect().encloses(control.get_global_rect())
	_check("Paging controls keep 44px touch targets on screen",touch)
	await _shot(gate,"06-gate-depth-21-40")
	draft.depth = 27
	_check("Depth 27 remains a valid deployment depth",int(draft.depth) <= int(Profile.meta.gateProgression.highestUnlockedDepth) and HeroStats.difficulty(Content.data,27,Content.data.maps.seoul,draft.weekly).hp > 2.0)

	await _roster_checks()

	var failed: Array = _checks.filter(func(entry): return not entry.passed)
	var file := FileAccess.open(_output.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[915,412],"saveWrites":false,"isolatedProfile":true,"realSimulation":true,"passed":_checks.size() - failed.size(),"failed":failed.size(),"checks":_checks},"\t"))
	file.close()
	Profile.meta = original
	print("Run-structure captures: %s; checks %d passed, %d failed; Profile.writable=%s" % [_output,_checks.size() - failed.size(),failed.size(),str(Profile.writable)])
	get_tree().quit(0 if failed.is_empty() else 1)
