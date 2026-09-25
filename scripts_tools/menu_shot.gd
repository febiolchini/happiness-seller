extends Node

## Strumento: fotografa i menu (principale, impostazioni, salvataggi, il menu
## a tre righe in partita) e il telefono aperto, sulla rubrica e in chat.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/MenuShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const OUT_DIR := "user://shots"
const MENUS := [
	["res://scenes/main/Main.tscn", "menu_principale"],
	["res://scenes/ui/Settings.tscn", "menu_impostazioni"],
	["res://scenes/ui/SaveSlots.tscn", "menu_salvataggi"],
]
const CITY := preload("res://scenes/levels/City.tscn")

func _ready() -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	var data := GameState.current
	data.cash = 4820
	data.chapter = "capitolo_uno"
	data.set_flag("intro_seen", true)
	# Un salvataggio almeno, cosi' la schermata dei salvataggi ha una riga.
	GameState.save_game()
	GameState.clock_running = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for menu in MENUS:
		var scena: Node = (load(str(menu[0])) as PackedScene).instantiate()
		add_child(scena)
		await get_tree().create_timer(1.0).timeout
		await _scatta(str(menu[1]))
		scena.queue_free()
		await get_tree().process_frame

	var city := CITY.instantiate()
	add_child(city)
	await get_tree().create_timer(1.2).timeout
	var menu: Control = city.get_node("HUD/Root/Menu")
	menu._toggle()
	await get_tree().create_timer(0.3).timeout
	await _scatta("menu_in_gioco")
	menu._toggle()

	var phone: Control = city.get_node("Phone/Screen")
	phone._toggle()
	await get_tree().create_timer(0.8).timeout
	await _scatta("telefono_rubrica")
	phone._go_chat(Chat.BRIAN)
	await get_tree().create_timer(0.6).timeout
	await _scatta("telefono_chat")
	print("fatto: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUT_DIR, nome]
	get_viewport().get_texture().get_image().save_png(path)
	print("scatto: %s" % path)
