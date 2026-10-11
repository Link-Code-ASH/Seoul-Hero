extends Node

# Staged screen rendering only. Synthetic in-memory state; no reward assignment.
var _output := "res://../design/ui-image-skins/economy-01/runtime"
var _view: Control
var _canvas := CanvasLayer.new()
var _original_meta: Dictionary

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	if "--ui-preview" not in OS.get_cmdline_user_args() or Profile.writable:
		push_error("Economy preview requires --ui-preview to disable profile writes.")
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
	DisplayServer.window_set_size(Vector2i(915,412))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_original_meta = Profile.meta
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	Profile.meta.settings.developerMode = false
	Profile.meta.wallet.associationCoins = 1240
	Profile.meta.association.upgrades = {"vitality":6,"armor":3,"attackSpeed":5,"mobility":4}
	for key in HeroGuildState.RESOURCES: Profile.meta.guild.wallet[key] = int(Content.data.guildManagement.initialWallet.get(key,0))+48
	Profile.meta.offlineReward.accumulatedSeconds = 9.25*3600.0
	for key in Content.data.offline.baseRewards: Profile.meta.offlineReward.pendingRewards[key] = int(Content.data.offline.baseRewards[key])*18
	add_child(_canvas)
	await _still("association",HeroEconomyUI.association(_go,_action,"attackSpeed"))
	var recovery := HeroEconomyRecoveryScreen.build(_go,_action)
	recovery.capture_clock = true
	await _still("recovery",recovery)
	var wallet_root := HeroImageSkin.root()
	HeroMetaScreens._image_backdrop(wallet_root,"metaAssociationOffice")
	HeroImageSkin.header(wallet_root,"길드 재화",Callable())
	HeroEconomyUI.wallet(wallet_root,Profile.meta)
	await _still("wallet",wallet_root)
	var supply_root := HeroImageSkin.root()
	HeroUI.background(supply_root,"supportSupplyBackground")
	HeroImageSkin.header(supply_root,"보급",Callable())
	HeroEconomyUI.probabilities(supply_root)
	await _still("probabilities",supply_root)
	if is_instance_valid(_view): _view.queue_free()
	Profile.meta = _original_meta
	print("ECONOMY_UI_PREVIEW ",ProjectSettings.globalize_path(_output))
	get_tree().quit()

func _still(id: String, screen: Control) -> void:
	if is_instance_valid(_view):
		_canvas.remove_child(_view)
		_view.queue_free()
	_view = screen
	_canvas.add_child(_view)
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output.path_join(id+".png"))

func _go(_destination: String) -> void:
	pass

func _action(_name: String, _value: Variant) -> Variant:
	return null
