extends Node

## Strumento: fotografa le quattro stanze di casa, di giorno e di notte.
##
## Serve per la stessa ragione di `ui_shot.gd`: i fondali di
## `blender_stanze.py` si giudicano solo dentro al gioco, con la luce
## dell'ora sopra, i vasi e le lampade al loro posto e il protagonista in
## piedi dove la camera l'ha messo. Per ogni stanza scatta anche due fotogrammi
## col lampadario tutto a sinistra e tutto a destra, per vedere il dondolio
## senza dover aspettare che parta da solo.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/RoomShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const OUT_DIR := "user://shots"
const ROOMS := {
	"ingresso": "res://scenes/rooms/Entrance.tscn",
	"cucina": "res://scenes/rooms/Kitchen.tscn",
	"cantina": "res://scenes/rooms/Basement.tscn",
	"garage": "res://scenes/rooms/Garage.tscn",
}

func _prepara(hour: float) -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	var data := GameState.current
	data.cash = 4820
	data.day = 6
	data.time_of_day = hour
	data.chapter = "capitolo_uno"
	data.set_flag("staff_unlocked", true)
	data.set_flag("intro_seen", true)
	data.set_flag("expand_advised", true)
	data.plot_slots = 18
	data.ensure_plots()
	data.upgrades["lamps"] = 3
	var now := GameState.total_hours()
	for i in data.plot_slots:
		if i % 4 == 3:
			continue
		Grow.plant(data.plots[i], Economy.DEFAULT_STRAIN, now - float(i) * 9.0)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for hour in [15.0, 22.5]:
		for room_key in ROOMS:
			_prepara(hour)
			var room: Node = load(ROOMS[room_key]).instantiate()
			add_child(room)
			GameState.clock_running = false
			await get_tree().create_timer(0.5).timeout
			var tag := "giorno" if hour < 20.0 else "notte"
			await _scatta("stanza_%s_%s" % [room_key, tag])
			if hour < 20.0:
				await _dondola(room, room_key)
			room.queue_free()
			await get_tree().process_frame
	print("fatto: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

## Ferma il lampadario nelle due pose estreme e scatta.
func _dondola(room: Node, room_key: String) -> void:
	var lamp: Sprite2D = room.get_node_or_null("Backdrop/Lampadario")
	if lamp == null:
		return
	lamp.set_process(false)
	for side in [0, lamp.hframes * lamp.vframes - 1]:
		lamp.frame = side
		await _scatta("stanza_%s_lampadario_%d" % [room_key, side])
	lamp.set_process(true)

func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUT_DIR, nome]
	get_viewport().get_texture().get_image().save_png(path)
	print("scatto: %s" % path)
