extends Node

## Strumento: fotografa il paesaggio intorno alla città.
##
## Il bordo della mappa si guarda in due modi molto diversi, e vanno giudicati
## tutti e due: dalla vista d'insieme (scala netta 0,25), dove è l'orizzonte
## che chiude la città, e da vicino, camminando fino all'ultimo isolato, dove un
## pixel di mondo è due pixel di schermo e il paesaggio deve reggere il
## dettaglio. Più la notte, perché la tinta della sera passa anche di lì.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/BorderShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"

## posizione del protagonista, ora, nome del file, livello di zoom (indice in
## `net_scales` di `camera_zoom.gd`). Le posizioni sono calcolate sui bordi
## della città in `_ready()`, qui ci sono solo i nomi dei punti.
const SHOTS := [
	["angolo_no", 13.0, "bordo_insieme", 0],
	["angolo_se", 13.0, "bordo_insieme_se", 0],
	["angolo_se", 21.5, "bordo_insieme_notte", 0],
	["angolo_no", 13.0, "bordo_angolo", 1],
	["ovest", 13.0, "bordo_ovest_largo", 2],
	["ovest", 13.0, "bordo_ovest_vicino", 4],
	["nord", 13.0, "bordo_nord_vicino", 4],
	["sud", 13.0, "bordo_sud_vicino", 4],
	["uscita_est", 13.0, "bordo_uscita_est", 3],
	["uscita_est", 21.5, "bordo_uscita_est_notte", 3],
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

	var w := CityMap.WORLD_BOUNDS
	var exit_east: Rect2 = CityMap.exit_roads()[1]["rect"]
	var points := {
		"angolo_se": w.end - Vector2(300, 300),
		"angolo_no": w.position + Vector2(300, 300),
		"ovest": Vector2(w.position.x + 60, w.get_center().y + 700),
		"nord": Vector2(w.get_center().x + 900, w.position.y + 60),
		"sud": Vector2(w.get_center().x - 1300, w.end.y - 60),
		"uscita_est": Vector2(w.end.x - 80, exit_east.get_center().y + 60),
	}

	for shot in SHOTS:
		player.global_position = points[shot[0]]
		camera.set_level(int(shot[3]))
		GameState.current.time_of_day = float(shot[1])
		GameState.current.weather = "clear"
		GameState.clock_running = false
		await get_tree().create_timer(SETTLE).timeout
		GameState.current.time_of_day = float(shot[1])
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT_DIR, str(shot[2])]
		get_viewport().get_texture().get_image().save_png(path)
		print("scatto: %s" % path)

	print("fatto: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()
