extends Node

## Strumento: fotografa THE FLATS di giorno e di notte.
##
## Serve a guardare i disegni del quartiere dove stanno davvero — in mezzo alle
## strade, accanto ai vicini e al protagonista — invece che uno per uno fuori
## contesto: la taglia di un edificio si giudica solo così.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/FlatsShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"

## La camera insegue il protagonista, quindi per guardare altrove si sposta lui:
## dove sta il giocatore, non dove punta la camera. Ed è giusto anche per il
## risultato — negli scatti c'è sempre un personaggio accanto agli edifici, che
## è l'unico metro buono per capire se sono della taglia giusta.
##
## posizione del protagonista, ora, tempo, nome del file, livello di zoom
## (indice in `net_scales` di `camera_zoom.gd`; -1 lascia quello di default)
const SHOTS := [
	[Vector2(320, 264), 13.0, "clear", "flats_main_giorno", -1],
	[Vector2(320, 264), 22.5, "clear", "flats_main_notte", -1],
	[Vector2(-100, 968), 13.0, "clear", "flats_cross_ovest_giorno", -1],
	[Vector2(-100, 968), 22.5, "clear", "flats_cross_ovest_notte", -1],
	[Vector2(528, 968), 13.0, "clear", "flats_officina_giorno", -1],
	[Vector2(528, 968), 22.5, "clear", "flats_officina_notte", -1],
	[Vector2(300, 1100), 13.0, "clear", "flats_alimentari_giorno", -1],
	[Vector2(300, 1100), 22.5, "clear", "flats_alimentari_notte", -1],
	[Vector2(370, 390), 13.0, "clear", "flats_sud_giorno", -1],
	[Vector2(370, 390), 22.5, "clear", "flats_sud_notte", -1],
	# Il campo da football abbandonato. Il largo (livello 4 = scala netta 1)
	# serve perche' il campo e' largo 736 px e alla vista di default se ne
	# vedono 640: la gradinata ci sta tutta solo allargando.
	[Vector2(304, 700), 13.0, "clear", "campo_giorno", 4],
	[Vector2(304, 700), 13.0, "clear", "campo_vicino", -1],
	[Vector2(304, 700), 22.5, "clear", "campo_notte", 4],
]

## Quanto aspettare dopo aver spostato il protagonista: la camera lo raggiunge
## smorzando (vedi `FOLLOW_SPEED` in `camera_zoom.gd`), e uno scatto immediato
## la prenderebbe a metà strada.
const SETTLE := 1.5

func _ready() -> void:
	# Come gli altri strumenti: cartella di salvataggio sua, per non lasciare
	# partite finte in mezzo a quelle del giocatore.
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
		if livello >= 0:
			camera.set_level(livello)
		else:
			camera.set_level(camera.default_level)
		GameState.current.time_of_day = float(shot[1])
		GameState.current.weather = str(shot[2])
		# L'orologio va fermato a ogni giro: se continuasse a scorrere, fra il
		# momento in cui si scrive l'ora e quello in cui si scatta passerebbero
		# venti minuti di gioco.
		GameState.clock_running = false
		await get_tree().create_timer(SETTLE).timeout
		GameState.current.time_of_day = float(shot[1])
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT_DIR, str(shot[3])]
		get_viewport().get_texture().get_image().save_png(path)
		print("scatto: %s  (%s, ore %.1f)" % [path, shot[2], float(shot[1])])

	print("fatto: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()
