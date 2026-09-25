extends Node

## Strumento: fotografa le schermate dell'interfaccia.
##
## Serve per la stessa ragione di `flats_shot.gd`: l'unico modo di giudicare una
## schermata è vederla piena di dati veri, alla risoluzione vera, non leggere il
## codice che la costruisce.
##
## Si lancia **con la finestra**, non headless:
##
##     Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/UiShot.tscn
##
## I PNG finiscono in `%APPDATA%/Godot/app_userdata/Happiness Seller/shots`.

const CITY := preload("res://scenes/levels/City.tscn")
const MANAGEMENT := preload("res://scenes/ui/ManagementWindow.tscn")
const REAL_ESTATE := preload("res://scenes/ui/RealEstateWindow.tscn")
const SEED_WHOLESALE := preload("res://scenes/ui/SeedWholesaleWindow.tscn")
const GUIDE := preload("res://scenes/ui/GuideBook.tscn")
const ORG_NAME := preload("res://scripts/ui/org_name_window.gd")
const OUT_DIR := "user://shots"

## Una partita a metà strada: con la cassa a zero e nessun vaso, metà schermate
## del gestionale sarebbero righe vuote e non direbbero niente su come stanno
## insieme. Questi numeri servono a riempirle.
func _prepara() -> void:
	GameState.save_dir = "user://tool_saves"
	GameState.new_game()
	var data := GameState.current
	data.cash = 4820
	data.day = 6
	data.time_of_day = 15.4
	data.heat = 34.0
	data.plot_slots = 6
	# Prologo già chiuso: senza, appena si arriva in strada parte un fumetto che
	# coprirebbe mezza schermata in ogni scatto.
	data.chapter = "capitolo_uno"
	data.set_flag("staff_unlocked", true)
	data.set_flag("intro_seen", true)
	data.set_flag("expand_advised", true)
	data.set_flag(SeedRun.UNLOCK_FLAG, true)
	GameState.clock_running = false

func _ready() -> void:
	_prepara()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var city := CITY.instantiate()
	add_child(city)
	await get_tree().process_frame
	var player: Node2D = city.get_node("Player")
	player.global_position = Vector2(320, 300)
	await get_tree().create_timer(1.2).timeout
	await _scatta("ui_hud")

	# Il gestionale va su una tela sua e non appeso alla City come fa
	# `room_hotspot.gd`: in strada c'è una Camera2D, e un Control figlio di un
	# Node2D si porta dietro la trasformazione della camera: la finestra
	# finirebbe da qualche parte fuori schermo. Nelle stanze, dove il PC si apre
	# davvero, la camera non si muove e il problema non c'è.
	var tela := CanvasLayer.new()
	tela.layer = 6
	add_child(tela)
	var window := MANAGEMENT.instantiate()
	tela.add_child(window)
	await get_tree().create_timer(0.4).timeout
	for indice in 5:
		if indice >= window._tabs.size():
			break
		window._select_tab(indice)
		await get_tree().create_timer(0.3).timeout
		await _scatta("ui_pc_%d_%s" % [indice, window._tabs[indice].to_lower()])

	window.queue_free()
	await get_tree().process_frame
	var agenzia := REAL_ESTATE.instantiate()
	tela.add_child(agenzia)
	await get_tree().create_timer(0.4).timeout
	await _scatta("ui_agenzia")

	agenzia.queue_free()
	await get_tree().process_frame
	var grossista := SEED_WHOLESALE.instantiate()
	tela.add_child(grossista)
	await get_tree().create_timer(0.4).timeout
	await _scatta("ui_grossista")

	grossista.queue_free()
	await get_tree().process_frame
	var guida := GUIDE.instantiate()
	tela.add_child(guida)
	await get_tree().create_timer(0.4).timeout
	await _scatta("ui_guida")

	guida.queue_free()
	await get_tree().process_frame
	var nome := CanvasLayer.new()
	nome.set_script(ORG_NAME)
	add_child(nome)
	await get_tree().create_timer(0.4).timeout
	await _scatta("ui_nome_banda")

	nome.queue_free()
	await get_tree().process_frame
	var dialogo = city.get_node("DialogueBox")
	dialogo.open("OFFICER BEATTY", "Keep your nose clean around here.", [
		{"label": "Sell 5 g for 40 $"}, {"label": "Goodbye"}])
	await get_tree().create_timer(0.4).timeout
	await _scatta("ui_dialogo")

	# Il resoconto a gioco chiuso e i messaggini dell'HUD: sono le righe piene
	# di cifre e punteggiatura, cioè quelle che dicono se il pennello regge.
	dialogo.close()
	GameState.notify(tr("NOTE_STAFF_HARVESTED") % 42)
	GameState.notify(tr("NOTE_HARVESTED") % 20)
	var resoconto := GameState.message(tr("MSG_AWAY_SPEAKER"), "\n".join(PackedStringArray([
		tr("AWAY_HEADER") % UiFormat.play_time(840.0),
		"%s 883 21:07  ->  %s 886 08:07" % [tr("HUD_DAY"), tr("HUD_DAY")],
		"",
		tr("AWAY_HARVEST") % 1242,
		tr("AWAY_SOLD") % [108, UiFormat.money(1548)],
		tr("AWAY_CUT") % UiFormat.money(87),
		tr("AWAY_WAGES") % UiFormat.money(891),
	])))
	await get_tree().create_timer(0.4).timeout
	await _scatta("ui_resoconto")
	resoconto.queue_free()

	print("fatto: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()

func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUT_DIR, nome]
	get_viewport().get_texture().get_image().save_png(path)
	print("scatto: %s" % path)
