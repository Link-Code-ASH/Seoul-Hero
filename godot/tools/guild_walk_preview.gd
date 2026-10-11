extends Node

var profile: Dictionary
var art: Dictionary
var folder: String
var canvas := CanvasLayer.new()

func _ready() -> void:
	_show.call_deferred()

func _show() -> void:
	if Profile.writable: get_tree().quit(1); return
	folder = ProjectSettings.globalize_path("res://../design/ui-image-skins/guild-walk-01")
	var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/guild.json"))
	art = {"rooms":Content.texture(visuals.rooms.file),"states":Content.texture(visuals.states.file),"facilityOrder":visuals.rooms.facility_order,"tiers":visuals.rooms.tiers}
	art.structure = Content.texture(visuals.walk.file)
	art.structureRegions = visuals.walk.regions
	DisplayServer.window_set_size(Vector2i(915,412)); add_child(canvas)
	profile = Content.data.defaultMeta.duplicate(true); HeroMeta.initialize(Content.data,profile)
	profile.guild = HeroGuildState.create(Content.data,Time.get_unix_time_from_system())
	HeroMeta.weekly(Content.data,profile,Time.get_unix_time_from_system())
	if "--guild-walk-preview" not in OS.get_cmdline_user_args():
		await _capture("01-initial",{"walk":{"x":210.0,"floor":0}})
	_expanded()
	if "--guild-walk-preview" in OS.get_cmdline_user_args():
		DisplayServer.window_set_title("서울 히어로 · 걷는 길드 시안 · 저장하지 않음")
		var screen := _screen({"walk":{"x":480.0,"floor":0}})
		screen.read_only = false
		canvas.add_child(screen)
		return
	await _capture("02-expanded",{"walk":{"x":1050.0,"floor":1}})
	await _capture("03-management",{"panel":"facility","slot":5,"panelOpen":true,"walk":{"x":560.0,"floor":1}})
	await _capture("04-overview",{"walk":{"x":500.0,"floor":0}},true)
	print("Guild walk layouts: ",folder,"; isolated profile; writes: false")
	get_tree().quit()

func _expanded() -> void:
	var g: Dictionary = profile.guild
	g.wallet = {"coins":1480,"materials":360,"researchData":85,"speedupTickets":4}
	var slot := 0
	for id in g.facilities:
		g.facilities[id] = {"level":7 if id=="office" else 5 if id=="production" else 3 if id in ["research","expedition","recovery"] else 1,"slot":slot}; slot += 1
	g.employees[0].assignment = "production"; g.employees[1].assignment = "expedition"
	g.employees.append({"id":"staffJiWoo","assignment":"research","level":3,"experience":16.0})
	g.jobs = [{"id":"1","type":"construction","targetId":"workshop","targetLevel":2,"slot":5,"startedAt":Time.get_unix_time_from_system(),"endsAt":Time.get_unix_time_from_system()+280,"employeeIds":[]}]
	g.nextJobId = 2
	g.pendingRewards.coins = 248

func _screen(ui: Dictionary) -> HeroGuildWalkScreen:
	var state := {"panel":"facility","slot":0,"employee":"","expedition":"cityScout","selectedStaff":[],"panelOpen":false}
	state.merge(ui,true)
	return HeroGuildWalkScreen.create(profile,func(action,args): return HeroGuildRules.act(Content.data,profile,action,args,Time.get_unix_time_from_system()),func(): get_tree().quit(),func(): pass,art,state)

func _capture(id: String, ui: Dictionary, overview: bool = false) -> void:
	var screen := _screen(ui)
	canvas.add_child(screen)
	if overview: screen.world.set_overview(true); screen._render()
	screen.world.snap_camera()
	for frame in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := get_tree().root.get_texture().get_image()
	shot.save_png(folder.path_join(id+".png")); shot.save_jpg(folder.path_join(id+".jpg"),0.88)
	canvas.remove_child(screen); screen.queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var screen := canvas.get_child(0) as HeroGuildWalkScreen if canvas.get_child_count()>0 else null
		if screen and not screen.close_management(): get_tree().quit()
