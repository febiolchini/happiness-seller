extends Node

## Strumento: fotografa un attraversamento.
##
## Serve per la stessa ragione di `ui_shot.gd`: il modo in cui una persona
## cammina si giudica guardandola, non leggendo il codice che la muove. Fa
## avanti e indietro su MAIN STREET finchè non gli tocca aspettare un'auto
## davvero, e scatta in quel momento — il resto della camminata si vede già.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/WalkShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CITY := preload("res://scenes/levels/City.tscn")
const OUT_DIR := "user://shots"

func _ready() -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	var data := GameState.current
	data.cash = 4820
	data.day = 6
	data.time_of_day = 14.0
	data.chapter = "capitolo_uno"
	data.set_flag("intro_seen", true)
	data.set_flag("expand_advised", true)
	data.set_flag("staff_unlocked", true)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var city := CITY.instantiate()
	add_child(city)
	await get_tree().process_frame
	var player: CharacterBody2D = city.get_node("Player")
	var camera: Camera2D = city.get_node("Camera2D")
	camera.set_level(5)

	# Un attraversamento su MAIN STREET, davanti a casa.
	var road: Rect2 = CityMap.ROADS_H[0]
	var x := CityMap.home_doorstep().x
	player.global_position = Vector2(x, road.position.y - 20.0)
	await get_tree().create_timer(1.0).timeout

	# Avanti e indietro finchè non capita di doverlo aspettare davvero: il
	# fotogramma che serve è quello, il resto lo si vede già camminando.
	var north := Vector2(x, road.position.y - 20.0)
	var south := Vector2(x, road.end.y + 20.0)
	var shots := 0
	for round in 12:
		city._order_move(south if round % 2 == 0 else north)
		for i in 60:
			await get_tree().create_timer(0.1).timeout
			if player.is_waiting_to_cross() and shots < 2:
				shots += 1
				await _scatta("walk_attesa_%d" % shots)
			if not player.is_moving():
				break
		if shots >= 2:
			break
	await _scatta("walk_strada")
	print("fatto")
	get_tree().quit()

func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, nome])
	print("scatto: %s" % nome)
