extends Node

## Strumento: fotografa la vista dalla vetrata dell'ufficio (`WindowView`) da
## sola e grande, a tre ore, e salva anche il terreno e le montagne come li ha
## fotografati. Per regolare camera, foschia e cielo senza passare dalla stanza.
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/WindowViewShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const OUT_DIR := "user://shots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	GameState.save_dir = "user://tool_saves"
	for hour in [11.0, 19.4, 23.0]:
		GameState.new_game()
		GameState.current.time_of_day = hour
		GameState.clock_running = false
		var view := WindowView.new()
		view.setup(Rect2(0, 0, 418, 104), "MeridianTower", 21)
		add_child(view)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var vp: SubViewport = view.get_child(0)
		vp.get_texture().get_image().save_png("%s/vista_%02d.png" % [OUT_DIR, int(hour)])
		if hour == 11.0:
			for shot in ["GroundShot", "MountainShot"]:
				var node: SubViewport = view.get_node_or_null(shot)
				if node != null:
					node.get_texture().get_image().save_png("%s/vista_%s.png" % [OUT_DIR, shot])
		print("vista %s: %d sprite" % [hour, view._sprites.size()])
		view.queue_free()
		await get_tree().process_frame
	get_tree().quit()
