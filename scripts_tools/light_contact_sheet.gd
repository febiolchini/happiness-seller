extends Node

## Strumento: fotografa la città a una manciata di ore e di condizioni meteo, e
## salva i PNG in `user://shots/`.
##
## Serve a tarare `daylight.gd` e `weather.gd`. La luce di un gioco si aggiusta
## guardandola, e guardarla a mano vorrebbe dire aprire la partita e aspettare
## sei minuti reali per vedere una giornata: qui si mettono le ore sull'orologio
## a mano e si scatta.
##
## Si lancia **con la finestra**, non headless: senza rendering non c'è niente
## da leggere.
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/LightContactSheet.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"

## Le stanze da fotografare, con l'ora e il tempo che servono a far vedere
## quello che c'è da guardare: il taglio di sole, la pioggia sul vetro, il
## rosso delle lampade in cantina.
const ROOMS := [
	["res://scenes/rooms/Kitchen.tscn", 9.0, "clear", "20_cucina_mattina"],
	["res://scenes/rooms/Kitchen.tscn", 17.0, "clear", "21_cucina_pomeriggio"],
	["res://scenes/rooms/Kitchen.tscn", 22.0, "clear", "22_cucina_notte"],
	["res://scenes/rooms/Kitchen.tscn", 14.0, "storm", "23_cucina_temporale"],
	["res://scenes/rooms/Entrance.tscn", 10.0, "clear", "24_ingresso_mattina"],
	["res://scenes/rooms/Entrance.tscn", 21.0, "rain", "25_ingresso_pioggia"],
	["res://scenes/rooms/Basement.tscn", 13.0, "clear", "26_cantina"],
]

## I momenti da fotografare: ora, tempo, e come si chiama il file.
const SHOTS := [
	[7.0, "clear", "01_mattina"],
	[13.0, "clear", "02_mezzogiorno"],
	[17.5, "clear", "03_pomeriggio"],
	[19.2, "clear", "04_tramonto"],
	[20.6, "clear", "05_crepuscolo"],
	[23.0, "clear", "06_notte"],
	[4.0, "clear", "07_notte_fonda"],
	[13.0, "overcast", "08_coperto"],
	[13.0, "rain", "09_pioggia"],
	[21.0, "rain", "10_pioggia_notte"],
	[13.0, "storm", "11_temporale"],
	[8.0, "fog", "12_nebbia"],
]

## Quanti secondi reali aspettare prima di scattare: pioggia e pozze arrivano
## per gradi (vedi `EASE_SPEED`), e uno scatto immediato le prenderebbe a metà.
const SETTLE := 1.6

func _ready() -> void:
	# I test hanno la loro cartella per non sporcare i salvataggi veri, e questo
	# strumento per lo stesso motivo ha la sua.
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var city := CITY.instantiate()
	add_child(city)
	await get_tree().process_frame

	for shot in SHOTS:
		GameState.current.time_of_day = float(shot[0])
		GameState.current.weather = str(shot[1])
		# L'orologio della partita va fermato a ogni giro: se continuasse a
		# scorrere, fra il momento in cui si scrive l'ora e quello in cui si
		# scatta passerebbero venti minuti di gioco.
		GameState.clock_running = false
		await get_tree().create_timer(SETTLE).timeout
		GameState.current.time_of_day = float(shot[0])
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [OUT_DIR, str(shot[2])]
		image.save_png(path)
		print("scatto: %s  (%s, ore %.1f)" % [path, shot[1], float(shot[0])])

	city.queue_free()
	await get_tree().process_frame

	for shot in ROOMS:
		var room: Node = load(str(shot[0])).instantiate()
		GameState.current.time_of_day = float(shot[1])
		GameState.current.weather = str(shot[2])
		# Qualche lampada comprata, o la cantina si vede come a inizio partita.
		GameState.current.cash = 5000
		Shop.buy(GameState.current, "lamps")
		Shop.buy(GameState.current, "lamps")
		add_child(room)
		GameState.clock_running = false
		await get_tree().create_timer(SETTLE).timeout
		GameState.current.time_of_day = float(shot[1])
		await RenderingServer.frame_post_draw
		var shot_image := get_viewport().get_texture().get_image()
		var room_path := "%s/%s.png" % [OUT_DIR, str(shot[3])]
		shot_image.save_png(room_path)
		print("scatto: %s  (%s, ore %.1f)" % [room_path, shot[2], float(shot[1])])
		room.queue_free()
		await get_tree().process_frame

	# Il menu principale usa la città come sfondo, con `interactive = false` e
	# senza partita in corso: è il primo posto in cui gira tutta la catena della
	# luce, e va guardato anche lui.
	var menu: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(SETTLE).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/30_menu.png" % OUT_DIR)
	print("scatto: %s/30_menu.png" % OUT_DIR)
	menu.queue_free()
	await get_tree().process_frame

	print("fatto: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()
