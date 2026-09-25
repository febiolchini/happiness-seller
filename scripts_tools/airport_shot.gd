extends Node

## Strumento: fotografa l'aeroporto, e la sua giornata un momento alla volta.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/AirportShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.
## Gli scatti della sequenza sono dati in SECONDI della sequenza e non in ore:
## l'ora si ricava con `AirportPlan.hour_at()`, cosi' spostando l'orario di
## partenza gli scatti restano sugli stessi momenti.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"
const CENTER := Vector2(1760, 7824)

## [dove guarda, secondi della sequenza (o ora se negativo: -ora), nome, zoom]
const SHOTS := [
	[CENTER, -6.0, "aero_mattina", 2],
	[CENTER, -6.0, "aero_largo", 1],
	[Vector2(300, 8250), 6.0, "aero_avvicinamento", 2],
	[Vector2(1000, 8250), 12.5, "aero_atterraggio", 3],
	[Vector2(1800, 8250), 18.0, "aero_frenata", 3],
	[Vector2(2300, 7900), 30.0, "aero_rullaggio", 3],
	[Vector2(1880, 7760), 45.0, "aero_hangar", 3],
	[Vector2(2100, 7800), 51.0, "aero_mezzi", 3],
	[Vector2(1800, 7760), 61.0, "aero_scala", 4],
	[Vector2(1700, 7850), 72.0, "aero_bimotore", 3],
	[Vector2(2150, 7800), 78.0, "aero_mezzi_via", 3],
	[Vector2(2150, 7850), 81.0, "aero_virata", 4],
	[Vector2(1800, 8000), 88.0, "aero_decollo", 3],
	[Vector2(2000, 7760), 96.0, "aero_jet_gira", 3],
	[Vector2(2350, 7950), 106.0, "aero_jet_rullaggio", 3],
	[Vector2(2000, 8250), 119.0, "aero_jet_pista", 3],
	[Vector2(1000, 8250), 125.0, "aero_jet_decollo", 2],
	[Vector2(0, 8250), 131.0, "aero_jet_salita", 1],
	[Vector2(1000, 8250), 154.3 + 12.5, "aero_secondo_atterraggio", 3],
	[CENTER, -22.5, "aero_notte", 2],
	[CENTER, -3.3, "aero_reset", 2],
]

const SETTLE := 1.5

func _ready() -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var city := CITY.instantiate()
	add_child(city)
	await get_tree().process_frame
	var player: Node2D = city.get_node("Player")
	var camera: Camera2D = city.get_node("Camera2D")
	print("sequenza: %.1f s, dalle %.2f alle %.2f" % [AirportPlan.duration(),
		AirportPlan.START_HOUR, AirportPlan.hour_at(AirportPlan.duration())])
	var tappe := AirportPlan.milestones()
	for actor in tappe:
		print("  %s: %s" % [actor, str(tappe[actor])])
	for shot in SHOTS:
		player.global_position = shot[0]
		camera.set_level(int(shot[3]))
		var when := float(shot[1])
		var hour := -when if when < 0.0 else AirportPlan.hour_at(when)
		GameState.current.time_of_day = hour
		GameState.current.weather = "clear"
		GameState.clock_running = false
		await get_tree().create_timer(SETTLE).timeout
		GameState.current.time_of_day = hour
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT_DIR, str(shot[2])]
		get_viewport().get_texture().get_image().save_png(path)
		print("scatto: %s (ore %.2f)" % [path, hour])
	get_tree().quit()
