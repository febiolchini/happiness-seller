extends Node

## Strumento: fotografa la steak house di fronte al grossista, col suo
## parcheggio e le auto che entrano ed escono.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/SteakhouseShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"

## [dove sta il protagonista, ora, nome, livello di zoom (indice in `net_scales`),
## secondi di attesa prima dello scatto]
## Il protagonista sta davanti alla porta del ristorante, dove le auto non
## passano: cosi' non ne ferma nessuna. Gli scatti della sequenza sono a
## qualche secondo l'uno dall'altro, per prendere le manovre a meta'.
const SHOTS := [
	[Vector2(4712, -205), 13.0, "steak_largo", 2, 1.5],
	[Vector2(4712, -205), 13.0, "steak_giorno", 3, 1.5],
	[Vector2(4712, -205), 13.0, "steak_giorno_b", 3, 3.0],
	[Vector2(4712, -205), 13.0, "steak_giorno_c", 3, 3.0],
	[Vector2(4712, -205), 13.0, "steak_giorno_d", 3, 3.0],
	[Vector2(4712, -205), 13.0, "steak_giorno_e", 3, 3.0],
	[Vector2(4712, -205), 20.5, "steak_sera", 3, 4.0],
	[Vector2(4712, -205), 22.5, "steak_notte", 3, 3.0],
	[Vector2(4712, -205), 13.0, "steak_vicino", 4, 1.5],
	# Gli alberi del parcheggio da vicino, e la casa con la staccionata con
	# l'albero nel giardinetto accanto alla casa gialla.
	[Vector2(4712, -130), 13.0, "alberi_parcheggio", 4, 2.5],
	[Vector2(4712, -130), 22.0, "alberi_parcheggio_notte", 3, 2.0],
	# Il cespuglio da vicino, due volte a poco tempo di distanza: se i due
	# scatti sono uguali, il cespuglio non si muove.
	[Vector2(4628, -40), 13.0, "cespuglio_a", 5, 2.0],
	[Vector2(4628, -40), 13.0, "cespuglio_b", 5, 0.6],
	[Vector2(-120, 968), 13.0, "casa_staccionata", 3, 2.0],
	[Vector2(-120, 968), 13.0, "casa_staccionata_vicino", 4, 2.0],
	[Vector2(-120, 968), 22.0, "casa_staccionata_notte", 3, 2.0],
	# La casetta azzurra su WESTGATE AVENUE, dietro alla casa con la
	# staccionata: il protagonista sul marciapiede davanti al cancelletto.
	[Vector2(-374, 664), 13.0, "casa_blu", 3, 2.0],
	[Vector2(-374, 664), 13.0, "casa_blu_vicino", 4, 2.0],
	[Vector2(-374, 664), 22.0, "casa_blu_notte", 3, 2.0],
]

func _ready() -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	# Il grossista entra in citta' solo a sblocco avvenuto: senza, dall'altra
	# parte della strada non c'e' niente e lo scatto non dice se stanno bene
	# insieme.
	GameState.current.set_flag(SeedRun.UNLOCK_FLAG, true)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var city := CITY.instantiate()
	add_child(city)
	await get_tree().process_frame
	var player: Node2D = city.get_node("Player")
	var camera: Camera2D = city.get_node("Camera2D")
	for shot in SHOTS:
		player.global_position = shot[0]
		camera.set_level(int(shot[3]))
		GameState.current.time_of_day = float(shot[1])
		GameState.current.weather = "clear"
		GameState.clock_running = false
		await get_tree().create_timer(float(shot[4])).timeout
		GameState.current.time_of_day = float(shot[1])
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT_DIR, str(shot[2])]
		get_viewport().get_texture().get_image().save_png(path)
		print("scatto: %s" % path)
	get_tree().quit()
