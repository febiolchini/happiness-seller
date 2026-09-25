extends Node

## Strumento: fotografa la stazione degli autobus su MAIN STREET, a sblocco
## avvenuto.
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/BusShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"

## [dove sta il protagonista, ora, nome, livello di zoom, secondi di attesa]
## Il protagonista sul marciapiede di MAIN STREET, davanti al varco fra le due
## aiuole. Le attese servono agli autobus: arrivano e ripartono ogni pochi
## secondi, e scatti ravvicinati li prendono a meta' manovra.
const SHOTS := [
	[Vector2(6344, 256), 8.5, "bus_largo", 2, 2.0],
	[Vector2(6344, 256), 8.5, "bus_vicino", 3, 6.0],
	[Vector2(6344, -150), 8.5, "bus_stazione", 4, 3.0],
	[Vector2(6344, 256), 21.5, "bus_sera", 3, 4.0],
	[Vector2(6344, 256), 23.5, "bus_notte", 2, 3.0],
]

func _ready() -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	GameState.current.set_flag(SeedRun.UNLOCK_FLAG, true)
	# Senza il contatto di Kevin: la stazione c'e' lo stesso, e' lo sportello
	# che resta chiuso. Lo scatto dice anche questo.
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var city := CITY.instantiate()
	add_child(city)
	await get_tree().process_frame
	var station := city.find_child("BusStation", true, false)
	print("stazione in citta': %s, sportello aperto: %s" % [
		station != null, station != null and station.can_open()])
	var player: Node2D = city.get_node("Player")
	var camera: Camera2D = city.get_node("Camera2D")
	for shot in SHOTS:
		player.global_position = shot[0]
		camera.set_level(int(shot[3]))
		GameState.current.time_of_day = float(shot[1])
		GameState.current.weather = "clear"
		GameState.clock_running = false
		await get_tree().create_timer(float(shot[4])).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT_DIR, str(shot[2])]
		get_viewport().get_texture().get_image().save_png(path)
		print("scatto: %s" % path)
	get_tree().quit()
