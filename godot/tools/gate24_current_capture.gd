extends Node

# Current shop only; synthetic in-memory profile. No main scene, simulation,
# economy callbacks, user-save reads or writes. Required flags enforce isolation.
var output := "res://../design/ui-image-skins/office-day-01/gate24-bright-01/before"
var records: Array = []

func _ready() -> void:
	_capture.call_deferred()

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _freeze(node: Node) -> void:
	node.set_process(false)
	for child in node.get_children(): _freeze(child)

func _shot(run: HeroRun, tab: bool, noop: Callable) -> void:
	var screen := HeroShopScreen.build(run,tab,noop,noop,noop,noop)
	get_tree().root.add_child(screen)
	await _frames(5)
	for tween: Tween in get_tree().get_processed_tweens(): tween.custom_step(1.0)
	_freeze(screen)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	assert(image.get_size() == Vector2i(915,412))
	var filename := "shop-weapons.png" if tab else "shop-items.png"
	assert(image.save_png(output.path_join(filename)) == OK)
	var offers: Array = []
	for offer in run.weapon_stock if tab else run.item_stock:
		var model := HeroShopScreen._offer_model(run,offer,tab,false)
		offers.append({"id":offer.id,"name":model.name,"summary":model.summary,"note":model.note,"price":model.price,"locked":model.locked,"tier":model.tier,"canBuy":model.can_buy})
	records.append({"file":filename,"tab":"weapons" if tab else "items","offers":offers})
	get_tree().root.remove_child(screen)
	screen.queue_free()
	await _frames(2)

func _capture() -> void:
	await _frames(1)
	assert("--ui-preview" in OS.get_cmdline_user_args())
	assert("--guild-office-preview" in OS.get_cmdline_user_args())
	assert(not Profile.writable)
	DisplayServer.window_set_size(Vector2i(915,412))
	await _frames(3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	Profile.meta.guild = HeroGuildState.create(Content.data,1000.0)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.weekly(Content.data,Profile.meta,1780704000.0)
	for id in Profile.meta.sharedWeapons: Profile.meta.sharedWeapons[id].unlocked = true
	var selection := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId,"elite":"haetaeHead","week":2961}
	var run := HeroRun.new(Content.data.duplicate(true),selection,Profile.meta)
	run.phase = "shop"
	run.wave = 6
	run.currency = 240
	run.owned = [{"id":"manaBolt","level":2,"branch":"","cooldown":0.0},{"id":"guardianDaggers","level":1,"branch":"","cooldown":0.0},{"id":"piercingShot","level":1,"branch":"","cooldown":0.0}]
	run.items = {"energyDrink":1,"riceBall":1}
	run.recalculate()
	run.player.hp = run.stats.maxHp
	run.weapon_stock = [{"id":"manaBolt","level":3,"locked":false},{"id":"manaSword","level":1,"locked":true},{"id":"chainLightning","level":1,"locked":false},{"id":"autoTurret","level":1,"locked":false}]
	run.item_stock = [{"id":"energyDrink","level":0,"locked":false},{"id":"riceBall","level":0,"locked":false},{"id":"gloves","level":0,"locked":true},{"id":"battery","level":0,"locked":false}]
	var noop := func(_value = null,_other = null): pass
	await _shot(run,true,noop)
	await _shot(run,false,noop)
	var report := {"size":[915,412],"source":"current HeroShopScreen.build","saveReads":false,"saveWrites":false,"simulation":false,"economyCallbacks":false,"audioCallbacks":false,"wave":run.wave,"currency":run.currency,"setup":selection,"ownedWeapons":run.owned,"ownedItems":run.items,"captures":records}
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("GATE24 current captures: ",ProjectSettings.globalize_path(output))
	get_tree().quit()
