extends Node

## Strumento: fotografa il filmato del furgone che lascia la città.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/CutsceneShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CUTSCENE := preload("res://scenes/ui/VanCutscene.tscn")
const OUT_DIR := "user://shots"

## ora, tempo, nome del file
const SHOTS := [
	[13.0, "clear", "furgone_giorno"],
	[19.0, "clear", "furgone_tramonto"],
	[22.5, "clear", "furgone_notte"],
]

func _ready() -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	GameState.clock_running = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for shot in SHOTS:
		GameState.current.time_of_day = float(shot[0])
		GameState.current.weather = str(shot[1])
		var cutscene := CUTSCENE.instantiate()
		cutscene.setup("IL FURGONE LASCIA LA CITTA")
		add_child(cutscene)
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT_DIR, str(shot[2])]
		get_viewport().get_texture().get_image().save_png(path)
		print("scatto: %s" % path)
		cutscene.queue_free()
		await get_tree().process_frame
	get_tree().quit()
