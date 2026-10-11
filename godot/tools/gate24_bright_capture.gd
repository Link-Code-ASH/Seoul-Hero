extends Node

# Approved shop skin only. Synthetic memory state; no main scene, simulation,
# economy callbacks, audio playback, or user-save reads/writes. The original
# gate24_current_capture and its before/ files remain unchanged.
var output := "res://../design/ui-image-skins/office-day-01/gate24-bright-01/runtime"
var records: Array = []
var input_records: Array = []
var callback_calls := 0

func _ready() -> void:
	_capture.call_deferred()

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _freeze(node: Node) -> void:
	node.set_process(false)
	for child in node.get_children(true): _freeze(child)

func _fixture() -> HeroRun:
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
	return run

func _idle_pointer() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2,410)
	Input.parse_input_event(motion)

func _buttons(node: Node, filename: String) -> void:
	if node is Button and (str(node.name).begins_with("ShopPurchase_") or str(node.name).begins_with("ShopLock_") or str(node.name) in ["ShopWeaponsTab","ShopItemsTab","ShopReroll","ShopPause"]):
		assert(node.size.y >= 44.0)
		assert(node.size.x >= 44.0)
		var box: Rect2 = node.get_global_rect()
		assert(box.position.x >= 0 and box.position.y >= 0 and box.end.x <= 915 and box.end.y <= 412)
		input_records.append({"file":filename,"name":str(node.name),"rect":[box.position.x,box.position.y,box.size.x,box.size.y],"disabled":node.disabled})
	for child in node.get_children(true): _buttons(child,filename)

func _shot(run: HeroRun, tab: bool, filename: String, state: String = "normal") -> void:
	var noop := func(_value = null,_other = null): callback_calls += 1
	var screen := HeroShopScreen.build(run,tab,noop,noop,noop,noop)
	get_tree().root.add_child(screen)
	_idle_pointer()
	await _frames(5)
	for tween: Tween in get_tree().get_processed_tweens(): tween.custom_step(1.0)
	# Hover and a held press never emit the Button.pressed release signal.
	# The scene is removed before releasing, so purchase/reroll callbacks cannot run.
	var control := screen.find_child("ShopPurchase_0",true,false) as Button
	if state in ["hover","pressed"]:
		assert(control != null and not control.disabled)
		var center := control.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = center
		Input.parse_input_event(motion)
		await _frames(3)
		if state == "pressed":
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.position = center
			press.pressed = true
			Input.parse_input_event(press)
			await _frames(2)
	elif state == "details":
		HeroShopScreen._offer_popup(screen,HeroShopScreen._offer_model(run,run.item_stock[0],false,false))
		await _frames(3)
	_freeze(screen)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	assert(image.get_size() == Vector2i(915,412))
	assert(image.save_png(output.path_join(filename)) == OK)
	_buttons(screen,filename)
	var offers: Array = []
	for offer in run.weapon_stock if tab else run.item_stock:
		var model := HeroShopScreen._offer_model(run,offer,tab,false)
		offers.append({"id":offer.get("id",""),"name":model.name,"summary":model.summary,"note":model.note,"price":model.price,"locked":model.locked,"tier":model.tier,"canBuy":model.can_buy,"free":model.get("free",false),"empty":model.get("empty",false)})
	records.append({"file":filename,"tab":"weapons" if tab else "items","state":state,"currency":run.currency,"offers":offers})
	get_tree().root.remove_child(screen)
	screen.queue_free()
	await _frames(2)
	if state == "pressed":
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = Vector2(2,410)
		release.pressed = false
		Input.parse_input_event(release)
	_idle_pointer()
	await _frames(2)
	assert(callback_calls == 0)

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
	await _shot(_fixture(),true,"shop-weapons.png")
	await _shot(_fixture(),false,"shop-items.png")
	await _shot(_fixture(),false,"shop-items-hover.png","hover")
	await _shot(_fixture(),false,"shop-items-pressed.png","pressed")
	await _shot(_fixture(),false,"shop-items-return.png")
	await _shot(_fixture(),false,"shop-items-details.png","details")
	var states := _fixture()
	states.currency = 0
	states.item_stock = [{"id":"energyDrink","level":0,"locked":false,"free":true},{"id":"","level":0,"locked":false},{"id":"gloves","level":0,"locked":true},{"id":"battery","level":0,"locked":false}]
	await _shot(states,false,"shop-items-stock-states.png")
	var report := {"size":[915,412],"source":"native HeroShopScreen.build","saveReads":false,"saveWrites":false,"simulation":false,"economyCallbacks":false,"audioCallbacks":false,"callbackCalls":callback_calls,"wave":6,"currency":240,"captures":records,"inputRegions":input_records,"verificationScope":"import/script errors, static shop layout and material states only; no gameplay QA"}
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("GATE24 bright captures: ",ProjectSettings.globalize_path(output))
	get_tree().quit()
