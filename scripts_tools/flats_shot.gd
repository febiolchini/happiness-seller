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
	# L'isolato commerciale di DOWNTOWN accanto ai grattacieli.
	[Vector2(6344, 8470), 13.0, "clear", "isolato_dt_giorno", 4],
	[Vector2(6344, 8470), 22.0, "clear", "isolato_dt_notte", 4],
	# Lo STAR CASINO, l'isolato intero a sinistra del grossista.
	[Vector2(3920, 264), 13.0, "clear", "casino_giorno", 3],
	[Vector2(3920, 264), 22.0, "clear", "casino_notte", 3],
	# Il negozio di videogiochi e il cinema su CROSS STREET, col parcheggio.
	[Vector2(5500, 968), 13.0, "clear", "cinema_giorno", 4],
	[Vector2(5500, 968), 22.0, "clear", "cinema_notte", 4],
	# La casa gialla a sinistra del garage, con la girandola e la bandiera.
	[Vector2(100, 968), 13.0, "clear", "casa_gialla_giorno", -1],
	[Vector2(100, 968), 22.5, "clear", "casa_gialla_notte", -1],
	[Vector2(100, 968), 13.0, "storm", "casa_gialla_temporale", -1],
	[Vector2(528, 968), 13.0, "clear", "flats_officina_giorno", -1],
	[Vector2(528, 968), 22.5, "clear", "flats_officina_notte", -1],
	[Vector2(300, 1100), 13.0, "clear", "flats_alimentari_giorno", -1],
	[Vector2(300, 1100), 22.5, "clear", "flats_alimentari_notte", -1],
	[Vector2(370, 390), 13.0, "clear", "flats_sud_giorno", -1],
	[Vector2(370, 390), 22.5, "clear", "flats_sud_notte", -1],
	# L'isolato cinese, a est di MILL ROAD. Il largo (livello 4) serve perche'
	# la fila e' larga 655 px e alla vista di default se ne vedono 640: i
	# quattro edifici ci stanno tutti solo allargando, ed e' tutta la fila che
	# va guardata — il punto e' se si legge come un fabbricato solo.
	[Vector2(1215, 264), 13.0, "clear", "cinese_giorno", 4],
	[Vector2(1215, 264), 22.5, "clear", "cinese_notte", 4],
	[Vector2(980, 264), 13.0, "clear", "cinese_ristorante", -1],
	# Da vicino (scala netta 4): serve a giudicare il dettaglio, che a questa
	# scala e' l'unica cosa che si vede.
	[Vector2(980, 264), 13.0, "clear", "cinese_zoom", 7],
	# L'officina, la sola cosa in citta' che si muove: quattro scatti alle
	# quattro ore che contano — chiusa, mentre si alza, aperta, e mentre
	# scende. Se la serranda non e' dove deve stare, si vede qui.
	[Vector2(1683, 264), 6.8, "clear", "officina_chiusa", -1],
	[Vector2(1683, 264), 7.11, "clear", "officina_apre", -1],
	[Vector2(1683, 264), 13.0, "clear", "officina_aperta", -1],
	[Vector2(1683, 264), 19.41, "clear", "officina_chiude", -1],
	[Vector2(1683, 264), 21.5, "clear", "officina_notte", -1],
	[Vector2(1683, 264), 13.0, "clear", "officina_zoom", 7],
	# Il grossista dei semi, su MAIN STREET nel quartiere commerciale. Il largo
	# (livello 4) perché lo sprite è largo 632 px. Serve a controllare due cose
	# che si vedono solo qui: che il piede dell'edificio poggi sul marciapiede
	# del gioco — il modello non ne ha più uno suo — e che l'insegna stia sulla
	# sua fascia.
	[Vector2(4783, 264), 13.0, "clear", "grossista_giorno", 4],
	[Vector2(4783, 264), 22.5, "clear", "grossista_notte", 4],
	# La colonna est ridivisa in tre quartieri: commerciale in cima (col
	# grossista), hillside/benestanti in mezzo, downtown vuoto in fondo. Livello
	# di zoom 4 (largo) per vederli tutti e tre in un solo scatto.
	[Vector2(4712, 3520), 13.0, "clear", "quartieri_est", 4],
	# I due confini: commerciale/hillside su FOUNDRY ROW (y~1728) e
	# hillside/downtown su RIVER ROW (y~5712). Livello 2 (molto largo) per
	# vedere il cambio di colore del terreno da un lato all'altro della strada.
	[Vector2(4712, 1728), 13.0, "clear", "confine_commerciale_hillside", 2],
	[Vector2(4712, 5712), 13.0, "clear", "confine_hillside_downtown", 2],
	# I due grattacieli di DOWNTOWN, alle tre ore che contano: il riflesso del
	# sole deve attraversare le facciate da destra (mattina) a sinistra (sera).
	# Livello 1 (scala netta 0,25) perche' la Meridian e' alta 2316 px e alla
	# vista di default se ne vedrebbe un ottavo.
	[Vector2(5535, 8470), 8.0, "clear", "torri_mattina", 1],
	[Vector2(5535, 8470), 13.0, "clear", "torri_mezzogiorno", 1],
	[Vector2(5535, 8470), 18.2, "clear", "torri_sera", 1],
	[Vector2(5535, 8470), 22.0, "clear", "torri_notte", 1],
	[Vector2(5535, 8470), 13.0, "rain", "torri_pioggia", 1],
	[Vector2(5535, 8470), 13.0, "clear", "torri_piede", 4],
	# HOLLY LOFTS, il condominio d'angolo a ovest dei grattacieli: deve
	# poggiare sul marciapiede di COUNTY LINE e chiudere l'angolo su PORT
	# STREET. Il largo per vederlo intero accanto alla Meridian.
	[Vector2(4900, 8470), 13.0, "clear", "holly_giorno", 4],
	[Vector2(4900, 8470), 22.0, "clear", "holly_notte", 4],
	[Vector2(4800, 8470), 13.0, "clear", "holly_vicino", -1],
	# Il campo da football abbandonato. Il largo (livello 4 = scala netta 1)
	# serve perche' il campo e' largo 736 px e alla vista di default se ne
	# vedono 640: la gradinata ci sta tutta solo allargando.
	[Vector2(304, 700), 13.0, "clear", "campo_giorno", 4],
	[Vector2(304, 700), 13.0, "clear", "campo_vicino", -1],
	[Vector2(304, 700), 22.5, "clear", "campo_notte", 4],
	# UNION PARK, lo stadio, nell'isolato d'angolo fra EAST STREET e SOUTH
	# GATE. Il largo (livello 4) perché lo sprite è largo 646 px e alla vista di
	# default se ne vedono 640: il catino ci sta tutto solo allargando, ed è
	# tutto il catino che va guardato — il punto è se si legge come uno stadio.
	# Lo scatto vicino invece serve al cancello e allo stemma.
	[Vector2(3128, 6350), 13.0, "clear", "stadio_giorno", 4],
	[Vector2(3128, 6350), 22.5, "clear", "stadio_notte", 4],
	[Vector2(3128, 6350), 13.0, "clear", "stadio_vicino", -1],
	# Da EAST STREET, che è la strada per cui è stato messo lì: si deve vedere
	# il fianco del catino e DOWNTOWN dall'altra parte della carreggiata.
	[Vector2(3472, 6060), 13.0, "clear", "stadio_east_street", 4],
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
