extends Node

# 2026-10-10 simplification check: loads every script, exercises draws / run loot /
# settlement on an in-memory profile and captures the four affected screens.
# Requires --ui-preview so no profile or checkpoint is ever written.
var _output := "res://exports/simplify-2026-10-10"
var _canvas := CanvasLayer.new()
var _world: HeroWorld
var _failed := 0
var _noop := func(_value = null,_other = null): return null

func _ready() -> void:
	_main.call_deferred()

func _check(title: String, passed: bool, detail = "") -> void:
	if not passed: _failed += 1
	print("[%s] %s %s" % ["ok" if passed else "FAIL",title,str(detail)])

func _scripts(path: String, broken: Array) -> int:
	var count := 0
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".gd"): continue
		count += 1
		var script := load(path.path_join(file)) as GDScript
		if script == null or not script.can_instantiate(): broken.append(path.path_join(file))
	for folder in DirAccess.get_directories_at(path): count += _scripts(path.path_join(folder),broken)
	return count

func _shot(screen: Control, id: String, combat: bool = false) -> void:
	_world.visible = combat
	_canvas.add_child(screen)
	for frame in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_output.path_join(id+".png"))
	_canvas.remove_child(screen); screen.free()

func _main() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Simplify capture requires --ui-preview to block save writes.")
		get_tree().quit(1); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
	_output = ProjectSettings.globalize_path(_output)
	DirAccess.make_dir_recursive_absolute(_output)
	DisplayServer.window_set_size(Vector2i(915,412))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	var broken: Array = []
	var total := _scripts("res://scripts",broken)
	_check("Every script compiles",broken.is_empty(),"%d scripts, broken %s" % [total,str(broken)])

	var original: Dictionary = Profile.meta
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.apply_starter(Content.data,Profile.meta)
	HeroMeta.weekly(Content.data,Profile.meta,Time.get_unix_time_from_system())
	Profile.meta.settings.developerMode = false
	Profile.meta.wallet.associationCoins = 1240
	var meta: Dictionary = Profile.meta
	_world = HeroWorld.new(); add_child(_world); _world.visible = false
	add_child(_canvas)
	for frame in range(3): await get_tree().process_frame

	# Feature switches and draws.
	_check("Guild, recovery, supply, fragments and daily gift are off",["guild","offlineReward","supplyBox","fragments","dailyGift"].all(func(key): return not Content.enabled(key)) and Content.enabled("revivalStones"),Content.data.features)
	var starter: Dictionary = Content.data.draws.starter
	_check("New profile owns only the starters",Content.data.characters.keys().all(func(id): return bool(meta.characters[id].unlocked) == (id in starter.characters)) and Content.data.weapons.keys().all(func(id): return bool(meta.sharedWeapons[id].unlocked) == (id in starter.weapons)))
	var probe: Dictionary = meta.duplicate(true)
	var before := HeroMeta.draw_candidates(Content.data,probe,"weapon")
	var drawn := HeroMeta.draw(Content.data,probe,"weapon")
	_check("Weapon draw unlocks one locked weapon for 200 coins",drawn in before and probe.sharedWeapons[drawn].unlocked and int(probe.wallet.associationCoins) == 1240-int(Content.data.draws.costs.weapon),drawn)
	probe.wallet.associationCoins = 0
	_check("Draw without coins does nothing",HeroMeta.draw(Content.data,probe,"character").is_empty())

	await _shot(HeroMetaScreens.lobby(_noop),"01-lobby")
	await _shot(HeroMetaScreens.build("association",{"associationId":"draw:character"},_noop,_noop),"02-association-draw-character")
	await _shot(HeroMetaScreens.build("association",{"associationId":"draw:weapon"},_noop,_noop),"03-association-draw-weapon")
	var draft := {"map":"seoul","depth":3,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":meta.weeklyGate.ruleId}
	meta.gateProgression.highestUnlockedDepth = 7
	meta.gateProgression.characters.awakener = {"highestClearedDepth":6,"rewardedThroughDepth":6,"bestWaveByDepth":{"7":13}}
	await _shot(HeroGateScreen.build(draft,1,_noop,_noop,_noop,{}),"04-gate-floor-select")

	# Combat: real simulation, then one coin and one 생환석 forced onto the ground.
	seed(20261010)
	var run := HeroRun.new(Content.data.duplicate(true),draft,meta)
	var sim := HeroSimulation.new(run)
	run.wave = 3
	_world.run = run
	var hud := HeroCombatUI.hud(run,_noop)
	_canvas.add_child(hud); _world.visible = true
	for index in range(360):
		run.player.hp = run.stats.maxHp
		sim.tick(1.0/60.0,Vector2.ZERO)
		if index % 6 == 0:
			HeroCombatUI.update_hud(hud,run)
			await get_tree().process_frame
	var reach: float = float(run.stats.pickupRange)+46.0
	run.loot_pickups.append({"type":"coin","amount":1,"pos":run.player.pos+Vector2(-reach*0.6,reach*0.9)})
	run.loot_pickups.append({"type":"revivalStone","grade":"low","amount":1,"pos":run.player.pos+Vector2(reach,30)})
	run.loot_pickups.append({"type":"revivalStone","grade":"mid","amount":1,"pos":run.player.pos+Vector2(reach+52,-34)})
	HeroCombatUI.update_hud(hud,run)
	_canvas.remove_child(hud)
	await _shot(hud,"05-combat-loot-on-ground",true)

	# Kill drops, pickup, wave-end sweep and settlement.
	var boss := {"boss":true,"pos":run.player.pos+Vector2(300,0)}
	run.loot_pickups.clear()
	HeroAttacks._drop_loot(run,boss)
	_check("A boss kill always drops 협회 코인",run.loot_pickups.any(func(drop): return drop.type == "coin" and int(drop.amount) == int(Content.data.runLoot.coin.boss.amount)),run.loot_pickups)
	run.loot_pickups.append({"type":"revivalStone","grade":"high","amount":1,"pos":run.player.pos+Vector2(400,0)})
	run.loot_pickups.append({"type":"coin","amount":2,"pos":run.player.pos})
	sim.tick(1.0/60.0,Vector2.ZERO)
	_check("Touching a coin banks it in run.loot",int(run.loot.associationCoins) == 2,run.loot)
	sim.end_wave()
	var expected := 2+int(Content.data.runLoot.coin.boss.amount)
	_check("Wave end sweeps the rest",run.loot_pickups.is_empty() and int(run.loot.associationCoins) == expected and int(run.loot.revivalStones.get("high",0)) >= 1,run.loot)
	hud = HeroCombatUI.hud(run,_noop)
	HeroCombatUI.update_hud(hud,run)
	await _shot(hud,"06-combat-loot-collected",true)
	var wallet_before := int(meta.wallet.associationCoins)
	var stones_before := int(meta.wallet.revivalStones.get("high",0))
	var reward := HeroMeta.settle(Content.data,meta,run,"death")
	_check("Settlement pays exactly the picked-up loot",reward == expected and int(meta.wallet.associationCoins) == wallet_before+expected and int(meta.wallet.revivalStones.get("high",0)) == stones_before+int(run.loot.revivalStones.high),"reward %d, wallet %d -> %d" % [reward,wallet_before,int(meta.wallet.associationCoins)])
	await _shot(HeroCombatUI.result(run,_noop),"07-result")
	# Screens that are hidden or unchanged must still build without script errors.
	var hidden: Array = [HeroMetaScreens.build("settings",{},_noop,_noop)]
	for kind in ["character","weapon","blessing"]:
		hidden.append(HeroMetaScreens.build("growth",{"kind":kind,"id":Content.data[HeroMeta.DRAW_KINDS[kind][0]].keys()[0]},_noop,_noop))
	for step in [0,2,3,4,5]:
		hidden.append(HeroGateScreen.build(draft,step,_noop,_noop,_noop,{"inspected":{},"scroll":{}}))
	for screen in hidden:
		_canvas.add_child(screen)
		for frame in range(2): await get_tree().process_frame
		_canvas.remove_child(screen); screen.queue_free()
	await get_tree().process_frame
	_check("No save writes",not Profile.writable)

	Profile.meta = original
	print("SIMPLIFY_CAPTURE %s; failed %d" % [_output,_failed])
	get_tree().quit(0 if _failed == 0 else 1)
