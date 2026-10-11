extends Node

var meta: Dictionary
var art: Dictionary
var canvas := CanvasLayer.new()
var output := "res://exports/guild-offices-runtime"
var pixels := Vector2i(915,412)

func _ready() -> void:
	_show.call_deferred()

func _show() -> void:
	if Profile.writable: get_tree().quit(1); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--size="):
			var dimensions := argument.trim_prefix("--size=").split("x")
			pixels = Vector2i(int(dimensions[0]),int(dimensions[1]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DisplayServer.window_set_size(pixels)
	add_child(canvas)
	var visual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/guild.json"))
	art = {"rooms":Content.texture(visual.rooms.file),"states":Content.texture(visual.states.file),"facilityOrder":visual.rooms.facility_order,"tiers":visual.rooms.tiers,"structure":Content.texture(visual.walk.file),"structureRegions":visual.walk.regions}
	meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,meta)
	meta.guild = HeroGuildState.create(Content.data,Time.get_unix_time_from_system())
	await _capture("01-initial",{})
	_expand()
	await _capture("02-expanded",{})
	await _capture("03-management",{"panelOpen":true,"selectedFacility":"workshop","slot":5,"officeTab":"management","officeTabs":{"workshop":"management"}})
	await _capture("04-staff",{"panelOpen":true,"selectedFacility":"workshop","slot":5,"officeTab":"staff","officeTabs":{"workshop":"staff"}})
	await _capture("05-jobs",{"panelOpen":true,"selectedFacility":"revival","slot":6,"officeTab":"jobs","officeTabs":{"revival":"jobs"}})
	await _capture("06-office",{"panelOpen":true,"selectedFacility":"office","slot":0,"officeTab":"management","officeTabs":{"office":"management"},"officePanel:office:management:":335})
	await _capture("07-staff-selected",{"panelOpen":true,"selectedFacility":"workshop","slot":5,"officeTab":"staff","officeTabs":{"workshop":"staff"},"employee":str(meta.guild.employees[0].id)})
	await _capture("08-hire",{"panelOpen":true,"selectedFacility":"office","slot":0,"officeTab":"staff","officeTabs":{"office":"staff"},"officeDetail":"hire"})
	await _capture("09-empty-room",{"panelOpen":true,"selectedFacility":"","slot":8})
	await _capture("10-assign",{"panelOpen":true,"selectedFacility":"research","slot":1,"officeTab":"staff","officeTabs":{"research":"staff"},"officeDetail":"assign"})
	print("Approved guild office runtime captures: ",output,"; isolated memory profile; saves: false")
	get_tree().quit()

func _expand() -> void:
	var g: Dictionary = meta.guild
	g.wallet = {"coins":1680,"materials":420,"researchData":96,"speedupTickets":5,"constructionParts":60,"electronicParts":40,"manaCatalysts":40,"bioReagents":20}
	var slot := 0
	for id in Content.data.guildManagement.facilities:
		g.facilities[id] = {"level":7 if id=="office" else 4 if id in ["research","workshop"] else 7 if id=="production" else 1,"slot":slot}
		slot += 1
	HeroGuildState.sync_unlocked_floors(Content.data,g)
	g.employees[0].assignment = "workshop"
	g.employees[1].assignment = "production"
	g.employees.append({"id":"staffJiWoo","assignment":"research","level":3,"experience":16.0})
	var now := Time.get_unix_time_from_system()
	g.jobs = [{"id":"1","type":"construction","targetId":"revival","targetLevel":2,"slot":6,"startedAt":now,"endsAt":now+7200,"employeeIds":[]}]
	g.nextJobId = 2
	g.pendingRewards.coins = 248

func _capture(id: String, ui: Dictionary) -> void:
	var state := {"panel":"facility","slot":0,"employee":"","expedition":"cityScout","selectedStaff":[],"panelOpen":false}
	state.merge(ui,true)
	var screen := HeroGuildOfficeScreen.create(meta,func(_action,_args): return false,func(): pass,func(): pass,art,state)
	screen.read_only = true
	canvas.add_child(screen)
	for frame in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(id+".png"))
	canvas.remove_child(screen)
	screen.queue_free()
