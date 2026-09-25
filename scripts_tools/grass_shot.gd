extends Node

## Strumento: fotografa il prato a strati dell'isolato di casa.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/GrassShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.
## L'ultimo scatto fa camminare il protagonista in mezzo al prato e lo prende a
## metà strada: serve a vedere la scia dell'erba che si rialza.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"

## posizione del protagonista, ora, tempo, nome del file, livello di zoom
const SHOTS := [
	[Vector2(320, 264), 13.0, "clear", "erba_casa_largo", 2],
	[Vector2(300, -330), 13.0, "clear", "erba_dietro_giorno", -1],
	[Vector2(300, -330), 18.9, "clear", "erba_dietro_tramonto", -1],
	[Vector2(660, -330), 22.5, "clear", "erba_lampioni_notte", -1],
	[Vector2(300, -330), 13.0, "clear", "erba_vicino", 5],
	[Vector2(4712, 3600), 13.0, "clear", "erba_hillside_clinica", 2],
	[Vector2(5500, 2600), 13.0, "clear", "erba_hillside_giorno", -1],
	[Vector2(5500, 2600), 13.0, "clear", "erba_hillside_largo", 1],
	[Vector2(5500, 2600), 22.5, "clear", "erba_hillside_notte", 2],
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

	for shot in SHOTS:
		player.global_position = shot[0]
		var livello := int(shot[4])
		camera.set_level(livello if livello >= 0 else camera.default_level)
		GameState.current.time_of_day = float(shot[1])
		GameState.current.weather = str(shot[2])
		GameState.clock_running = false
		await get_tree().create_timer(SETTLE).timeout
		GameState.current.time_of_day = float(shot[1])
		await RenderingServer.frame_post_draw
		_save(str(shot[3]))

	# La scia: da sinistra a destra, a passo d'uomo, scatto a metà.
	GameState.current.weather = "clear"
	GameState.current.time_of_day = 13.0
	camera.set_level(5)
	player.global_position = Vector2(180, -300)
	await get_tree().create_timer(SETTLE).timeout
	var t := 0.0
	while t < 1.4:
		var delta := get_process_delta_time()
		player.global_position += Vector2(70.0, 0.0) * delta
		t += delta
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("erba_scia")
	get_tree().quit()

func _save(name_: String) -> void:
	var path := "%s/%s.png" % [OUT_DIR, name_]
	get_viewport().get_texture().get_image().save_png(path)
	print("scatto: %s" % path)
