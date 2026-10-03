extends Node

func _ready() -> void: _capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._deploy()
	if main.run == null:
		push_error("Gate entry did not create a Run"); get_tree().quit(1); return
	# Only a short render of the actual simulation; no meta changes or result settlement.
	await get_tree().create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://exports/combat-art/gate.png")
	print("Actual gate renderer: ",main.run.phase," / player ",main.run.setup.character," / enemies ",main.run.enemies.size())
	main.run.pause()
	await get_tree().process_frame
	get_tree().quit()
