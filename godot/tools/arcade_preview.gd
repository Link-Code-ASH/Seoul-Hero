extends Node

# Four review images of native UI, without simulation, purchases or save writes.
func _ready() -> void:
	_render.call_deferred()

func _render() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Arcade preview requires --ui-preview to block save writes.")
		get_tree().quit(1); return
	var output := "res://exports/arcade-preview"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var draft := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId}
	var run := HeroRun.new(Content.data,draft,Profile.meta)
	run.data = run.data.duplicate(true)
	run.wave = 12; run.elapsed = 8; run.currency = 1280; run.wallet = 240
	run.phase = "shop"
	run.item_stock = []
	for id in ["energyDrink","riceBall","battery","phoenixMatch"]:
		run.item_stock.append({"id":id,"locked":id == "riceBall"})
	HeroShop.refresh(run,true)
	var noop := func(_value = null): pass
	await _capture(HeroCombatUI.shop(run,false,noop,noop,noop,noop),"shop",output)
	await _capture(HeroLobbyScreen.build(noop,"premiumLobbyWind"),"lobby",output)
	run.owned = []
	for id in ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard"]:
		run.owned.append({"id":id,"level":3,"cooldown":0.0,"branch":""})
	run.phase = "waveActive"
	run.pickups = [{"pos":Vector2(-190,40),"value":1},{"pos":Vector2(200,105),"value":4},{"pos":Vector2(170,-100),"value":1}]
	var index := 0
	for pair in [["crawler",Vector2(-310,70)],["runner",Vector2(220,190)],["swarm",Vector2(330,-100)]]:
		index += 1
		var definition: Dictionary = Content.data.enemies[pair[0]]
		run.enemies.append({"id":index,"definition":pair[0],"pos":pair[1],"radius":definition.radius,"hp":definition.maxHp,"maxHp":definition.maxHp,"age":0.0,"action":"move","facing":-1.0})
	var world := HeroWorld.new(); world.run = run; get_tree().root.add_child(world)
	await _capture(HeroCombatUI.hud(run,noop),"hud",output)
	get_tree().root.remove_child(world); world.queue_free()
	# Isolated preview data exercises visual states; never changes real content.
	run.phase = "shop"
	run.currency = 12345678; run.wallet = 1234567
	run.data.items.battery.name = "긴 상품명 · 과충전 마력 배터리"
	run.data.items.phoenixMatch.basePrice = 15000000
	await _capture(HeroCombatUI.shop(run,false,noop,noop,noop,noop),"shop-states",output)
	print("Arcade review images: ",ProjectSettings.globalize_path(output)," / Profile.writable: ",Profile.writable)
	get_tree().quit()

func _capture(screen: Control, id: String, output: String) -> void:
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_tree().root.get_texture().get_image().save_png(output.path_join(id+".png"))
	if result != OK: push_error("Failed to save arcade preview: "+id)
	get_tree().root.remove_child(screen); screen.queue_free()
