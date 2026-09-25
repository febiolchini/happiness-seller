extends Node

## Controlli automatici sul cuore del gestionale: coltivazione, economia,
## salvataggi, e un caricamento di ogni script e scena del progetto.
##
## Non c'è un framework di test qui dentro e per quello che serve non ce n'è
## bisogno: questa è una scena che gira, fa i controlli, stampa e si chiude.
##
## Si lancia senza aprire l'editor:
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/Tests.tscn
##
## Va lanciata come SCENA, non con `--script`: con `--script` gli autoload non
## vengono creati, quindi `GameState` non esiste e non c'è nessuna partita su
## cui lavorare.
##
## Il tempo di gioco si fa passare a mano con `_advance()` invece di aspettare
## l'orologio: un ciclo di coltivazione dura minuti reali, e un test che se li
## sta ad aspettare non lo lancia più nessuno.

## I controlli girano in una cartella tutta loro.
##
## Ogni partita creata da un test viene salvata su disco: girando sulla cartella
## vera, una manciata di esecuzioni riempirebbe l'elenco di partite finte, e
## "riprendi" al posto della partita del giocatore ne caricherebbe una di quelle
## (vuota, giorno 1, senza niente). È già successo, ed è il motivo per cui
## `GameState.save_dir` è una variabile.
const TEST_SAVE_DIR := "user://test_saves"

var _failures := 0

func _ready() -> void:
	await get_tree().process_frame
	GameState.clock_running = false
	GameState.save_dir = TEST_SAVE_DIR
	_wipe_saves()

	# I controlli si annunciano prima di partire, con quanto ci hanno messo.
	# Non è decorazione: alcuni durano secondi — la griglia dei percorsi si
	# costruisce due volte e si provano centinaia di tragitti — e senza questa
	# riga un controllo che si pianta è indistinguibile da uno lento, con
	# l'esecuzione ferma e lo schermo vuoto.
	for test in [
		["carica tutto", _test_everything_loads],
		["le tre lingue", _test_translations],
		["la luce del giorno", _test_daylight],
		["il meteo", _test_weather],
		["la giornata dell'aeroporto", _test_airport],
		["pianta della citta'", _test_city_layout],
		["percorsi", _test_navigation],
		["si cammina sul marciapiede", _test_sidewalks],
		["attraversare col traffico", _test_crossing],
		["partita nuova", _test_new_game],
		["ciclo di coltivazione", _test_grow_cycle],
		["la sete rovina la resa", _test_dryness_hurts_yield],
		["vendite", _test_selling],
		["clienti di strada", _test_street_customer],
		["ampliamento del seminterrato", _test_plot_expansion],
		["negozio online", _test_shop],
		["fine del prologo", _test_prologue],
		["il personale coltiva", _test_staff_growing],
		["i vasi nelle stanze", _test_room_plots],
		["chi coltiva dove", _test_grower_sites],
		["il personale vende", _test_staff_selling],
		["le paghe", _test_staff_wages],
		["posti dove vedersi", _test_meet_spots],
		["come si chiamano i posti", _test_place_names],
		["appuntamento con brian", _test_seed_deal],
		["salvataggio e ricaricamento", _test_save_roundtrip],
		["riprendi l'ultima partita", _test_continue_last],
		["mezzanotte", _test_day_rollover],
		["i quartieri ricchi", _test_district_price],
		["la bolletta della luce", _test_power_bill],
		["le tasse sulla proprieta", _test_property_tax],
		["l'ingrosso col furgone", _test_delivery],
		["il telefono", _test_phone_alerts],
		["la chat con brian", _test_chat],
		["il tempo a gioco chiuso", _test_offline],
		["l'agenzia immobiliare", _test_real_estate],
		["il grossista dei semi", _test_seed_run],
		["il contatto fuori stato di kevin", _test_bus_import],
		["il nome e il prestigio", _test_org_prestige],
	]:
		print("- %s" % test[0])
		var started := Time.get_ticks_msec()
		(test[1] as Callable).call()
		print("  %d ms" % (Time.get_ticks_msec() - started))

	# Non si lasciano in giro partite finte, nemmeno nella cartella dei test.
	_wipe_saves()
	GameState.save_dir = GameState.DEFAULT_SAVE_DIR

	if _failures == 0:
		print("TEST OK: tutti i controlli passati")
	else:
		print("TEST FALLITI: %d" % _failures)
	get_tree().quit()

func _wipe_saves() -> void:
	var dir := DirAccess.open(GameState.save_dir)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		print("  FAIL: %s" % label)

func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures += 1
		print("  FAIL: %s  (atteso %s, ottenuto %s)" % [label, expected, actual])

## Un controllo che deve trovare una lista vuota. Stampa i colpevoli invece del
## solo conteggio: con duecento edifici generati, sapere che cinque sono
## sbagliati senza sapere quali non serve a niente.
func _check_empty(offenders: Array, label: String) -> void:
	if offenders.is_empty():
		return
	_failures += 1
	var shown: Array = offenders.slice(0, 6)
	var suffix := "" if offenders.size() <= 6 else " (e altri %d)" % (offenders.size() - 6)
	print("  FAIL: %s  ->  %s%s" % [label, ", ".join(shown), suffix])

## Porta l'orologio di gioco avanti di N ore, come farebbe il tempo che passa.
func _advance(hours: float) -> void:
	var data := GameState.current
	data.time_of_day += hours
	while data.time_of_day >= 24.0:
		data.time_of_day -= 24.0
		data.day += 1

## Chiude i messaggi del telefono lasciati aperti da un controllo.
func _close_messages() -> void:
	for child in GameState.get_children():
		child.free()

func _fresh() -> SaveData:
	GameState.new_game()
	GameState.clock_running = false
	return GameState.current

# ---------------------------------------------------------------------------

## Carica ogni script e ogni scena del progetto.
##
## Serve perché un errore di sintassi si vede solo quando qualcosa carica quel
## file: un pezzo di UI aperto solo dal PC in cantina può restare rotto per
## giorni senza che nessuna prova lo tocchi. Questo controllo li apre tutti.
func _test_everything_loads() -> void:
	for path in _all_files("res://", [".gd", ".tscn"]):
		if load(path) == null:
			_failures += 1
			print("  FAIL: non si carica: %s" % path)

func _all_files(dir_path: String, extensions: Array) -> Array:
	var found: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for name in dir.get_directories():
		if name.begins_with("."):
			continue
		found.append_array(_all_files(dir_path.path_join(name), extensions))
	for name in dir.get_files():
		# Nei progetti esportati gli script arrivano come ".gd.remap": togliere
		# il suffisso lascia il percorso vero da caricare.
		var clean := name.trim_suffix(".remap")
		for extension in extensions:
			if clean.ends_with(extension):
				found.append(dir_path.path_join(clean))
				break
	return found

## La pianta della città: una quarantina di edifici a mano più un centinaio
## generati.
##
## Sono controlli che a occhio non si fanno. Un capannone che spunta in mezzo
## alla carreggiata o due case sovrapposte in fondo alla mappa si notano solo
## passando di lì per caso, e con cinque quartieri quel caso non capita mai.
func _test_city_layout() -> void:
	var buildings := CityMap.all_buildings()
	# Il riempimento automatico è spento (`BUILT_DISTRICTS` vuota), quindi in
	# città ci devono essere SOLO i punti di riferimento scritti a mano. Il
	# controllo utile non è più "è piena" ma "non è comparso niente che non
	# abbiamo messo noi": se qualcuno lo riaccende senza rivedere il
	# piazzamento, qui si vede subito.
	# Non un conteggio esatto: certi punti di riferimento compaiono solo dopo
	# uno sblocco (il grossista dei semi arriva col furgone — vedi
	# `unlock_flag` in `CityMap.BUILDINGS`), quindi il numero cambia con lo
	# stato della partita. Quello che deve restare vero è che in città non ci
	# sia finito NIENTE che non sia scritto a mano lì dentro.
	var known: Array = []
	for entry: Dictionary in CityMap.BUILDINGS:
		known.append(str(entry["id"]))
	var strangers: Array = []
	for entry in buildings:
		if not str(entry.get("id", "")) in known:
			strangers.append(entry.get("id", entry))
	_check_empty(strangers, "in città ci sono solo i punti di riferimento")
	_check(buildings.size() <= CityMap.BUILDINGS.size(),
		"e non ce n'è più d'uno per voce (%d edifici)" % buildings.size())
	var elsewhere: Array = []
	for entry in CityMap.BUILDINGS:
		# Il centro dell'ingombro e non la base: la base sta sul bordo di sotto,
		# e un edificio a filo del confine del quartiere finirebbe fuori per un
		# pixel senza che ci sia niente di storto.
		#
		# L'atteso è "THE FLATS" a meno che l'edificio non dichiari un altro
		# quartiere col campo `district` (vedi la clinica, in HILLSIDE): il
		# controllo utile non è più "tutto sta in un solo quartiere", è "ogni
		# edificio sta dove dice di stare".
		var expected: String = entry.get("district", "THE FLATS")
		if CityMap.district_at(CityMap.footprint(entry).get_center()) != expected:
			elsewhere.append(entry["id"])
	_check_empty(elsewhere, "ogni edificio sta nel quartiere che dichiara")

	var road_bands: Array[Rect2] = []
	for road: Rect2 in CityMap.ROADS_H + CityMap.ROADS_V:
		road_bands.append(road.grow(CityMap.SIDEWALK_DEPTH))

	var placed: Array[Rect2] = []
	var on_road: Array = []
	var overlapping: Array = []
	var outside: Array = []
	# Su TUTTE le voci scritte a mano, anche quelle ancora bloccate. Un edificio
	# che compare a meta' partita ha bisogno di un posto valido tanto quanto gli
	# altri, e controllarlo solo da sbloccato vorrebbe dire scoprire che sta in
	# mezzo alla strada il giorno in cui si sblocca.
	for entry in CityMap.BUILDINGS:
		var rect := CityMap.footprint(entry)
		for band in road_bands:
			if rect.intersects(band):
				on_road.append(entry["id"])
				break
		for other in placed:
			if rect.intersects(other):
				overlapping.append(entry["id"])
				break
		if not CityMap.WORLD_BOUNDS.encloses(rect):
			outside.append(entry["id"])
		placed.append(rect)
	_check_empty(on_road, "nessun edificio sull'asfalto o sul marciapiede")

	# La porta deve cadere sul marciapiede, e non e' un dettaglio di stile: e' il
	# controllo che dice se la riga di terra dell'edificio e' al posto giusto.
	#
	# Abbassando la `base` di un edificio la porta scivola in carreggiata, il
	# protagonista va a bussare in mezzo alla strada, e chi cammina sul
	# marciapiede davanti sparisce dietro la facciata — l'Y-sort mette avanti chi
	# ha la y piu' grande, e un passante a y 250 e' "dietro" a un muro che poggia
	# a y 260. A occhio non si vede niente di storto finche' non passa qualcuno,
	# e quando passa sembra un problema di livelli invece che di piantina.
	var doors_on_asphalt: Array = []
	for entry in CityMap.BUILDINGS:
		var door: Vector2 = entry["base"] + _entry_offset(entry)
		for road: Rect2 in CityMap.ROADS_H + CityMap.ROADS_V:
			if road.has_point(door):
				doors_on_asphalt.append("%s a %s" % [entry["id"], door])
				break
	_check_empty(doors_on_asphalt, "ogni porta sta sul marciapiede, non in carreggiata")
	_check_empty(overlapping, "nessun edificio sovrapposto a un altro")
	_check_empty(outside, "nessun edificio fuori dai confini del mondo")

	# Ogni edificio deve avere il suo PNG delle finestre accese.
	#
	# Senza, di notte è una sagoma nera in mezzo a una fila di case abitate, e
	# non se ne accorge nessuno finché non è notte davvero — cioè dopo una
	# giornata di gioco, con la memoria corta di chi ha appena aggiunto
	# l'edificio. Il controllo guarda anche che il file ci sia: un `lit` scritto
	# nella pianta e non generato da `import_flats_art.py` è lo stesso buio.
	var senza_luci: Array = []
	for entry in CityMap.BUILDINGS:
		if not entry.has("lit") or not ResourceLoader.exists(str(entry["lit"])):
			senza_luci.append(entry["id"])
	for art in CityMap.FILL_ART:
		if not art.has("lit") or not ResourceLoader.exists(str(art["lit"])):
			senza_luci.append(str(art["texture"]).get_file())
	_check_empty(senza_luci, "ogni edificio ha le sue finestre accese di notte")

	# I terreni particolari non devono finire sotto a un edificio né in strada.
	var lots_on_road: Array = []
	for lot in CityMap.LOTS:
		for band in road_bands:
			if (lot["rect"] as Rect2).intersects(band):
				lots_on_road.append("%s %s" % [lot["kind"], lot["rect"]])
				break
	_check_empty(lots_on_road, "nessun terreno particolare sopra a una strada")

	# I quartieri non si sovrappongono fra loro.
	var districts_overlap := 0
	for i in CityMap.DISTRICTS.size():
		for j in range(i + 1, CityMap.DISTRICTS.size()):
			if (CityMap.DISTRICTS[i]["rect"] as Rect2).intersects(CityMap.DISTRICTS[j]["rect"]):
				districts_overlap += 1
	_check_eq(districts_overlap, 0, "i quartieri non si sovrappongono")

	# Ogni corsia deve cadere dentro all'asfalto della sua strada: una corsia
	# sbagliata si vede come un'auto che viaggia sul marciapiede.
	var lanes_off_road := 0
	for lane in CityMap.lanes():
		var horizontal := str(lane["axis"]) == "h"
		var found := false
		for road: Rect2 in (CityMap.ROADS_H if horizontal else CityMap.ROADS_V):
			var from := road.position.y if horizontal else road.position.x
			var to := road.end.y if horizontal else road.end.x
			if float(lane["pos"]) > from and float(lane["pos"]) < to:
				found = true
				break
		if not found:
			lanes_off_road += 1
	_check_eq(lanes_off_road, 0, "ogni corsia sta sull'asfalto della sua strada")

	# Le tappe degli NPC devono stare sui marciapiedi, non in carreggiata.
	# Attraversare va bene, fermarsi in mezzo alla strada no.
	var stops_on_asphalt: Array = []
	var stops_outside: Array = []
	for entry in NpcRoster.NPCS:
		for point: Vector2 in entry["route"]:
			for road: Rect2 in CityMap.ROADS_H + CityMap.ROADS_V:
				if road.has_point(point):
					stops_on_asphalt.append("%s a %s" % [entry["id"], point])
					break
			if not CityMap.WORLD_BOUNDS.has_point(point):
				stops_outside.append("%s a %s" % [entry["id"], point])
	_check_empty(stops_on_asphalt, "nessun NPC si ferma in mezzo alla carreggiata")
	_check_empty(stops_outside, "nessun percorso esce dalla mappa")

	# I ruoli che servono al gioco devono esserci davvero.
	var roles := {}
	for entry in NpcRoster.NPCS:
		roles[entry["role"]] = int(roles.get(entry["role"], 0)) + 1
	_check(int(roles.get(NpcRoster.ROLE_BUYER, 0)) >= 4, "ci sono abbastanza clienti")
	_check(int(roles.get(NpcRoster.ROLE_COP, 0)) >= 1, "c'e' almeno una pattuglia")
	# Chi vende i semi NON sta nel roster: Brian esiste solo su appuntamento e
	# lo tira su `city.gd` leggendo `SeedDeal`. Uno fisso in strada vorrebbe
	# dire due fonti di semi, e la seconda renderebbe inutile la prima.
	_check_eq(
		int(roles.get(NpcRoster.ROLE_SEEDS, 0)), 0,
		"nessun venditore di semi fisso nel roster")

	# La casa iniziale e il punto di partenza devono restare d'accordo.
	var doorstep := CityMap.home_doorstep()
	var start := SaveData.new().player_position
	_check(doorstep.distance_to(start) < 8.0, "si parte davanti alla casa iniziale")

## I percorsi: si arriva dappertutto, e mai attraverso un muro.
##
## È il tipo di cosa che si scopre solo camminandoci sopra, e per accorgersi che
## un edificio in fondo alla mappa è diventato irraggiungibile bisognerebbe
## andarci apposta. Qui si prova ogni porta della città in un colpo solo.
func _test_navigation() -> void:
	var buildings := CityMap.all_buildings()
	var nav := CityNavigation.new()
	var started := Time.get_ticks_msec()
	nav.build(buildings)
	var build_ms := Time.get_ticks_msec() - started
	_check(build_ms < 3000, "la griglia si costruisce in fretta (%d ms)" % build_ms)

	var home := CityMap.home_doorstep()
	_check(nav.is_walkable(home), "si può stare davanti a casa")

	# Dentro a un edificio non ci si cammina.
	var solid: Array = []
	for entry in buildings:
		if nav.is_walkable(CityMap.footprint(entry).get_center()):
			solid.append(entry["id"])
	_check_empty(solid, "il centro di un edificio non è calpestabile")

	# Da casa si raggiunge ogni porta della città, e il percorso non passa
	# attraverso niente.
	#
	# I fondali dentro agli isolati non hanno una porta e sono saltati: stanno
	# murati dietro alla fila che dà sulla strada, non si cliccano e non si
	# visitano. Vedi `CityMap._fill_interior()`.
	var unreachable: Array = []
	var through_walls: Array = []
	for entry in buildings:
		if bool(entry.get("backdrop", false)):
			continue
		var door: Vector2 = entry["base"] + _entry_offset(entry)
		var path := nav.find_path(home, door)
		if path.is_empty():
			unreachable.append(entry["id"])
			continue
		for i in range(path.size() - 1):
			if not nav.is_clear(path[i], path[i + 1]):
				through_walls.append(entry["id"])
				break
	_check_empty(unreachable, "da casa si arriva a ogni edificio")
	_check_empty(through_walls, "nessun percorso attraversa un edificio")

	# Un edificio grosso va aggirato, non attraversato: il percorso da un lato
	# all'altro deve essere sensibilmente più lungo della linea d'aria.
	#
	# "Sensibilmente" è mezza larghezza dell'edificio, ricavata dall'ingombro e
	# non un fattore fisso: aggirarlo vuol dire per forza spostarsi di lato fino
	# a passarne il fianco, ed è l'unica cosa che questo controllo deve dire. Un
	# moltiplicatore scritto a mano invece descrive **quell'** edificio, e va
	# ritarato ogni volta che l'ingombro cambia — com'è successo accostando le
	# facciate, quando l'ingombro è passato dal disegno intero al solo muro.
	#
	# Si prova sul palazzo occupato, che è il pezzo più alto del quartiere: la
	# fabbrica, che stava qui prima, era un segnaposto della zona industriale e
	# non esiste più.
	var condo := Rect2()
	for entry in CityMap.BUILDINGS:
		if str(entry["id"]) == "Condo":
			condo = CityMap.footprint(entry)
	var north := Vector2(condo.get_center().x, condo.position.y - 40.0)
	var south := Vector2(condo.get_center().x, condo.end.y + 40.0)
	var around := nav.find_path(north, south)
	_check(not around.is_empty(), "si passa da un lato all'altro del palazzo")
	var walked := 0.0
	for i in range(around.size() - 1):
		walked += around[i].distance_to(around[i + 1])
	var straight := north.distance_to(south)
	_check(
		walked > straight + condo.size.x * 0.5,
		"il palazzo si aggira invece di attraversarlo (%d px contro %d in linea d'aria)"
			% [int(walked), int(straight)])

	# Attraversare mezza città deve funzionare e restare un percorso sensato.
	var far := nav.find_path(home, Vector2(4600, 3600))
	_check(not far.is_empty(), "si attraversa tutta la città")
	_check(far.size() < 200, "il percorso lungo resta semplificato (%d tappe)" % far.size())

## Si cammina sul marciapiede, non in mezzo alla strada.
##
## È la cosa che un percorso può sbagliare restando perfettamente valido: nessun
## muro attraversato, destinazione raggiunta, e il protagonista che se ne va per
## la carreggiata come un ubriaco. Non si controlla guardando una linea sola —
## una qualunque può dover attraversare — ma la SOMMA: su un campione di
## tragitti lunghi, quanti pixel si fanno su ogni terreno.
func _test_sidewalks() -> void:
	var nav := CityNavigation.new()
	nav.build(CityMap.all_buildings())

	# Lungo una strada, dallo stesso lato: qui di asfalto non ce n'è motivo,
	# a parte gli incroci che tagliano la strada di traverso.
	var road: Rect2 = CityMap.ROADS_H[0]
	var from := Vector2(road.position.x + 600.0, road.position.y - 16.0)
	var to := Vector2(road.position.x + 3000.0, road.position.y - 16.0)
	var ground := _surfaces(nav, nav.find_path(from, to))
	var along_total: float = ground["side"] + ground["road"] + ground["ground"]
	_check(
		ground["road"] / along_total < 0.15,
		"lungo una strada si sta sul marciapiede (asfalto %d%%)"
			% int(100.0 * ground["road"] / along_total))

	# Attraversare: dritti, non in diagonale lungo la carreggiata. Il pezzo
	# sull'asfalto non deve essere molto più largo della strada stessa.
	var across := _surfaces(nav, nav.find_path(
		Vector2(road.position.x + 600.0, road.position.y - 16.0),
		Vector2(road.position.x + 600.0, road.end.y + 16.0)))
	_check(
		across["road"] <= CityMap.ROAD_WIDTH * 1.4,
		"si attraversa perpendicolari (%d px di asfalto per una strada larga %d)"
			% [int(across["road"]), int(CityMap.ROAD_WIDTH)])

	# E su un campione di tragitti lunghi, la stragrande maggioranza dei passi
	# è su un marciapiede.
	seed(7)
	var doors: Array[Vector2] = []
	for entry in CityMap.all_buildings():
		if bool(entry.get("backdrop", false)):
			continue
		doors.append(CityMap.footprint(entry).get_center() + Vector2(0, 90))
	var totals := {"side": 0.0, "road": 0.0, "ground": 0.0}
	for i in 12:
		var path := nav.find_path(doors[randi() % doors.size()], doors[randi() % doors.size()])
		var part := _surfaces(nav, path)
		for key in totals:
			totals[key] = float(totals[key]) + float(part[key])
	var total: float = totals["side"] + totals["road"] + totals["ground"]
	_check(total > 0.0, "i tragitti di prova esistono")
	# Due terzi e non di più: un tragitto comincia e finisce davanti a una porta,
	# e quei due pezzi attraversano per forza il cortile dell'edificio. Quello
	# che si vuole escludere è l'asfalto, e infatti il numero severo è l'altro.
	_check(
		totals["side"] / total > 0.6,
		"in giro per la città si cammina sul marciapiede (%d%%)"
			% int(100.0 * totals["side"] / total))
	_check(
		totals["road"] / total < 0.15,
		"e poco sull'asfalto (%d%%)" % int(100.0 * totals["road"] / total))

## Quanti pixel di un percorso cadono su ciascun terreno.
func _surfaces(nav: CityNavigation, path: PackedVector2Array) -> Dictionary:
	var result := {"side": 0.0, "road": 0.0, "ground": 0.0}
	for i in range(path.size() - 1):
		var distance: float = path[i].distance_to(path[i + 1])
		var steps := maxi(1, int(distance / 8.0))
		for k in steps:
			var point: Vector2 = path[i].lerp(path[i + 1], float(k) / float(steps))
			var cost := nav.cost_at(point)
			var piece := distance / float(steps)
			if is_equal_approx(cost, CityNavigation.COST_SIDEWALK):
				result["side"] = float(result["side"]) + piece
			elif is_equal_approx(cost, CityNavigation.COST_ROAD):
				result["road"] = float(result["road"]) + piece
			else:
				result["ground"] = float(result["ground"]) + piece
	return result

## Si attraversa solo se non si viene investiti.
##
## Il conto è quello di `Traffic`: due intervalli di tempo che si sovrappongono
## o no. Qui si mettono le auto dove servono e si guarda la risposta, che è
## l'unico modo di provare una regola del genere senza stare a guardare la
## città per mezz'ora.
func _test_crossing() -> void:
	var scene: PackedScene = load("res://scenes/components/Car.tscn")
	_check(scene != null, "la scena dell'auto si carica")
	if scene == null:
		return
	# Una strada orizzontale finta: corsia a y=0, auto che va verso est.
	var lane := {
		"axis": "h", "pos": 0.0, "dir": 1, "from": -4000.0, "to": 4000.0,
		"cars": 1, "speed": 100.0,
	}
	var car: Car = scene.instantiate()
	add_child(car)
	car.setup(lane, 0.5, Car.VEHICLES[0])

	# Il pedone attraversa da sopra a sotto, passando per la corsia.
	var from := Vector2(0.0, -60.0)
	var to := Vector2(0.0, 60.0)
	var speed := 48.0

	car.position = Vector2(-1200.0, 0.0)
	_check(
		Traffic.crossing_clear([car], from, to, speed),
		"un'auto lontanissima non ferma nessuno")

	car.position = Vector2(-80.0, 0.0)
	_check(
		not Traffic.crossing_clear([car], from, to, speed),
		"un'auto addosso ferma al cordolo")

	car.position = Vector2(-260.0, 0.0)
	_check(
		not Traffic.crossing_clear([car], from, to, speed),
		"e anche una che arriva mentre si è in mezzo alla strada")

	# Appena passata: si parte subito, non si aspetta un semaforo che non c'è.
	car.position = Vector2(120.0, 0.0)
	_check(
		Traffic.crossing_clear([car], from, to, speed),
		"dietro a un'auto appena passata si parte subito")

	# Un'auto che arriva da lontano ma piano lascia passare; la stessa distanza
	# a velocità doppia no. È la differenza fra guardare i tempi e le distanze.
	car.position = Vector2(-330.0, 0.0)
	var slow := lane.duplicate()
	slow["speed"] = 40.0
	car.setup(slow, 0.5, Car.VEHICLES[0])
	car.position = Vector2(-330.0, 0.0)
	_check(
		Traffic.crossing_clear([car], from, to, speed),
		"a un'auto lenta si taglia la strada")
	var fast := lane.duplicate()
	fast["speed"] = 200.0
	car.setup(fast, 0.5, Car.VEHICLES[0])
	car.position = Vector2(-330.0, 0.0)
	_check(
		not Traffic.crossing_clear([car], from, to, speed),
		"alla stessa distanza, a una veloce no")

	# Una corsia che il tragitto non taglia non c'entra niente: un'auto che
	# passa su un'altra strada non deve fermare nessuno.
	car.setup(lane, 0.5, Car.VEHICLES[0])
	car.position = Vector2(-80.0, 0.0)
	_check(
		Traffic.crossing_clear([car], Vector2(0.0, 40.0), Vector2(200.0, 40.0), speed),
		"chi cammina parallelo alla corsia non la attraversa")

	# Le auto frenano per chi è sulla carreggiata, e NON per chi aspetta sul
	# marciapiede: è quello che impedisce lo stallo fra i due.
	var road: Rect2 = CityMap.ROADS_H[0]
	var walker := Node2D.new()
	add_child(walker)
	car.setup(lane, 0.5, Car.VEHICLES[0])
	car.watch = walker
	car.position = Vector2(road.get_center().x - 40.0, road.get_center().y)
	walker.global_position = road.get_center()
	_check(car._player_ahead(), "un'auto frena per chi le cammina davanti sull'asfalto")
	walker.global_position = Vector2(road.get_center().x, road.position.y - 16.0)
	_check(
		not car._player_ahead(),
		"e tira dritto per chi aspetta sul marciapiede")

	walker.queue_free()
	car.queue_free()

## Stessa regola di `city.gd`: serve al test per sapere dov'è la porta.
func _entry_offset(entry: Dictionary) -> Vector2:
	if entry.has("entry"):
		return entry["entry"]
	var size: Vector2 = entry["size"]
	match str(entry.get("front", "north")):
		"south":
			return Vector2(0, -size.y - 26.0)
		"west":
			return Vector2(size.x * 0.5 + 26.0, 0)
		"east":
			return Vector2(-size.x * 0.5 - 26.0, 0)
		_:
			return Vector2(0, 26.0)

func _test_new_game() -> void:
	var data := _fresh()
	_check_eq(data.cash, Economy.STARTING_CASH, "soldi iniziali")
	_check_eq(Economy.seeds_owned(data), Economy.STARTING_SEEDS, "semi iniziali")
	_check_eq(data.plot_slots, Economy.START_PLOTS, "vasi iniziali")
	_check_eq(data.plots.size(), Economy.START_PLOTS, "array dei vasi allineato")
	_check(Grow.is_empty(data.plot(0)), "il primo vaso parte vuoto")

func _test_grow_cycle() -> void:
	var data := _fresh()
	var plot := data.plot(0)
	Grow.plant(plot, Economy.DEFAULT_STRAIN, GameState.total_hours())
	_check_eq(Grow.stage(plot, GameState.total_hours()), Grow.Stage.SEEDLING, "appena piantato e' SEEDLING")

	var total: float = Economy.strain(Economy.DEFAULT_STRAIN)["grow_hours"]
	var halfway_checked := false
	# Giocatore diligente: si avanza a piccoli passi e si annaffia ogni volta
	# che la pianta ha sete. Così si verifica anche che `sync()` dia lo stesso
	# risultato spezzettata in venti passi o fatta in uno solo.
	var elapsed := 0.0
	while elapsed < total * 1.1:
		_advance(1.5)
		elapsed += 1.5
		var now := GameState.total_hours()
		Grow.sync(plot, now)
		if Grow.is_thirsty(plot, now):
			Grow.water(plot, now)
		if not halfway_checked and elapsed >= total * 0.5:
			halfway_checked = true
			_check(not Grow.is_ready(plot, now), "a metà ciclo non e' pronta")
			_check(Grow.hours_left(plot, now) > 0.0, "manca ancora tempo")
	_check(Grow.is_ready(plot, GameState.total_hours()), "a ciclo finito e' pronta")
	_check(is_equal_approx(Grow.quality(plot), 1.0), "curata bene, qualita' piena")

	var grams := Grow.harvest(plot, GameState.total_hours())
	_check_eq(grams, int(Economy.strain(Economy.DEFAULT_STRAIN)["grams"]), "resa piena di una pianta curata")
	_check(Grow.is_empty(plot), "dopo il raccolto il vaso torna vuoto")
	_check_eq(data.plots.size(), Economy.START_PLOTS, "il raccolto non tocca il numero di vasi")

func _test_dryness_hurts_yield() -> void:
	var data := _fresh()
	var plot := data.plot(0)
	Grow.plant(plot, Economy.DEFAULT_STRAIN, GameState.total_hours())
	# Nessuna annaffiatura per tutto il ciclo: la sete si accumula.
	_advance(float(Economy.strain(Economy.DEFAULT_STRAIN)["grow_hours"]) + 2.0)
	Grow.sync(plot, GameState.total_hours())
	_check(Grow.is_thirsty(plot, GameState.total_hours()), "senza acqua ha sete")
	_check(float(plot["dry_hours"]) > 0.0, "la sete si e' accumulata")
	var thirsty_yield := Grow.yield_grams(plot)
	_check(
		thirsty_yield < int(Economy.strain(Economy.DEFAULT_STRAIN)["grams"]),
		"una pianta trascurata rende meno")
	_check(thirsty_yield > 0, "ma rende comunque qualcosa")

func _test_selling() -> void:
	var data := _fresh()
	data.cash = 0
	data.add_item(Economy.PRODUCT, 30)
	var price := Economy.wholesale_price(data)
	var revenue := Economy.sell_wholesale(data, 10)
	_check_eq(revenue, 10 * price, "incasso all'ingrosso")
	_check_eq(data.cash, 10 * price, "i soldi arrivano in cassa")
	_check_eq(Economy.stock(data), 20, "la merce venduta esce dall'inventario")
	_check_eq(data.heat, 0.0, "vendere dal PC non alza l'attenzione")

	# Vendere più di quello che si ha vende quello che c'è, non va in negativo.
	var rest := Economy.sell_wholesale(data, 500)
	_check_eq(rest, 20 * price, "vendere troppo vende solo il disponibile")
	_check_eq(Economy.stock(data), 0, "inventario svuotato")
	_check_eq(Economy.sell_wholesale(data, 10), 0, "a mani vuote non si incassa niente")

func _test_street_customer() -> void:
	var data := _fresh()
	data.add_item(Economy.PRODUCT, 200)
	var wanted := Economy.street_demand_left(data, "tony")
	# L'intervallo di listino, allargato dal tempo che fa: col sole si compra di
	# piu' della forchetta, sotto la pioggia di meno. Vedi `_test_weather()`.
	var mod := Weather.demand_mod(Weather.of(data))
	_check(
		wanted >= int(float(Economy.STREET_DEMAND.x) * mod)
			and wanted <= int(ceil(float(Economy.STREET_DEMAND.y) * mod)),
		"domanda nell'intervallo")
	_check_eq(
		Economy.street_demand("tony", data.day), Economy.street_demand("tony", data.day),
		"la domanda del giorno e' deterministica")
	_check(
		Economy.retail_price(data) > Economy.wholesale_price(data),
		"in strada si prende piu' che all'ingrosso")

	var revenue := Economy.sell_street(data, "tony", wanted)
	_check_eq(revenue, wanted * Economy.retail_price(data), "incasso al dettaglio")
	_check(data.heat > 0.0, "vendere in strada alza l'attenzione")
	_check_eq(Economy.street_demand_left(data, "tony"), 0, "il cliente e' servito")
	_check_eq(Economy.sell_street(data, "tony", 10), 0, "non compra due volte lo stesso giorno")

func _test_plot_expansion() -> void:
	var data := _fresh()
	var cost := Economy.next_plot_cost(data)
	_check(cost > 0, "il quarto vaso ha un prezzo")
	data.cash = cost - 1
	_check(not Economy.buy_plot(data), "senza soldi non si compra")
	data.cash = cost
	_check(Economy.buy_plot(data), "con i soldi si compra")
	_check_eq(data.plot_slots, Economy.START_PLOTS + 1, "un vaso in piu'")
	_check_eq(data.plots.size(), Economy.START_PLOTS + 1, "e c'e' il posto dove piantarci")
	_check_eq(data.cash, 0, "il costo e' stato scalato")

	# Fino al limite della cantina, poi basta: i vasi dopo stanno nel garage, e
	# il garage non e' ancora nostro.
	var cellar: Dictionary = GrowSites.find("basement")
	data.cash = 999999
	while Economy.next_plot_cost(data) >= 0:
		_check(Economy.buy_plot(data), "acquisto entro il limite")
	_check_eq(data.plot_slots, int(cellar["count"]), "si riempie la cantina")
	_check(not Economy.buy_plot(data), "senza il garage non si compra altro")
	_check_eq(
		Economy.next_plot_cost(data), -1,
		"e il PC non offre nemmeno il prossimo vaso")

	# Comprato il garage, la fila riparte e arriva in fondo.
	data.properties["Garage"] = {"livello": 1, "acquisito_il": data.day}
	_check(Economy.next_plot_cost(data) > 0, "col garage si ricomincia a comprare")
	while Economy.next_plot_cost(data) >= 0:
		_check(Economy.buy_plot(data), "acquisto entro il limite")
	_check_eq(data.plot_slots, Economy.MAX_PLOTS, "si arriva al massimo")
	_check(not Economy.buy_plot(data), "oltre il massimo non si compra")

## I posti in cui Brian può dare appuntamento.
##
## Sono ricavati dal reticolo, quindi non c'è nessuno che li guardi a occhio: un
## appuntamento finito dentro a un muro o in mezzo alla carreggiata si
## scoprirebbe solo andandoci, e capita a uno su cinquanta. Qui si provano tutti.
func _test_meet_spots() -> void:
	var spots := CityMap.meet_spots()
	_check(spots.size() >= 12, "ci sono abbastanza posti dove vedersi (%d)" % spots.size())

	var home := CityMap.home_doorstep()
	var too_close: Array = []
	var too_far: Array = []
	var nameless: Array = []
	for point: Vector2 in spots:
		var distance := point.distance_to(home)
		if distance < CityMap.MEET_MIN_DISTANCE:
			too_close.append(str(point))
		if distance > CityMap.MEET_MAX_DISTANCE:
			too_far.append(str(point))
		# Il nome del posto è l'unica indicazione che il giocatore riceve: uno
		# vuoto lo lascerebbe con un appuntamento e nessun modo di sapere dove.
		if CityMap.place_name(point).strip_edges().is_empty():
			nameless.append(str(point))
	_check_empty(too_close, "nessun appuntamento sotto casa")
	_check_empty(too_far, "nessun appuntamento a mezza città di distanza")
	_check_empty(nameless, "ogni posto ha un nome da dire al giocatore")

	# Ogni posto deve cadere su una strada, e non basta che sia camminabile:
	# il nome dell'appuntamento si ricava dalla strada su cui cade il punto
	# (`street_at()`), quindi un posto fuori da ogni strada arriverebbe al
	# giocatore senza indirizzo. Terreno calpestabile lo e' lo stesso, quindi i
	# due controlli qui sotto non se ne accorgerebbero.
	var off_street: Array = []
	for point: Vector2 in spots:
		if CityMap.street_at(point).is_empty():
			off_street.append(str(point))
	_check_empty(off_street, "ogni posto sta su una strada, non sul prolungamento di una")

	# E soprattutto: ci si deve poter arrivare a piedi, e stare in piedi lì.
	var nav := CityNavigation.new()
	nav.build(CityMap.all_buildings())
	var unwalkable: Array = []
	var unreachable: Array = []
	for point: Vector2 in spots:
		if not nav.is_walkable(point):
			unwalkable.append(str(point))
			continue
		if nav.find_path(home, point).is_empty():
			unreachable.append(str(point))
	_check_empty(unwalkable, "ogni posto è calpestabile")
	_check_empty(unreachable, "da casa si arriva a ogni posto")

## Il giro completo dell'appuntamento con Brian: chiedo, aspetto, arriva la
## posizione, compro, e lui se ne va.
## I nomi dei posti d'incontro devono dire il vero.
##
## Il difetto che questo controllo blocca era vero e si vedeva solo giocando: un
## appuntamento a (736, -64) su MILL ROAD veniva annunciato "BY THE LAUNDROMAT"
## perche' la lavanderia era a 314 px in linea d'aria — ma la lavanderia sta su
## MAIN STREET, tre isolati piu' in basso. Il giocatore ci andava, si trovava
## davanti alla lavanderia, e Brian era fuori schermo su un'altra strada.
func _test_place_names() -> void:
	var liars: Array = []
	var wrong_street: Array = []
	for point: Vector2 in CityMap.meet_spots():
		var place := CityMap.place_name(point)
		var street := CityMap.street_at(point)
		if place.strip_edges().is_empty():
			liars.append("%s non ha nome" % point)
			continue
		# Il nome comincia sempre con la strada su cui si e' davvero.
		if not street.is_empty() and not place.begins_with(street):
			wrong_street.append("%s e' su %s ma si chiama '%s'" % [point, street, place])
		# Se nomina un'insegna, quell'insegna deve essere vicina E sulla stessa
		# strada, o il nome manda da un'altra parte.
		var by := place.find(" BY ")
		if by < 0:
			continue
		var sign_name := place.substr(by + 4).trim_prefix("THE ")
		var found := false
		for entry: Dictionary in CityMap.BUILDINGS:
			if str(entry.get("label", "")).trim_prefix("THE ") != sign_name:
				continue
			found = true
			var base: Vector2 = entry["base"]
			if base.distance_to(point) >= CityMap.MEET_SIGN_RANGE:
				liars.append("%s dice '%s' ma l'insegna e' a %.0f px" % [
					point, place, base.distance_to(point)])
			if CityMap.street_at(base) != street:
				liars.append("%s dice '%s' ma quell'insegna sta su %s" % [
					point, place, CityMap.street_at(base)])
			break
		if not found:
			liars.append("%s nomina '%s', che non e' un punto di riferimento" % [point, sign_name])
	_check_empty(wrong_street, "il nome del posto comincia con la strada giusta")
	_check_empty(liars, "il nome del posto non manda da un'altra parte")

	# Un'insegna che esiste in piu' copie in citta' non puo' fare da indicazione:
	# manderebbe a quella sbagliata. Vedi `CityMap._is_generic()`.
	var ambiguous: Array = []
	for point: Vector2 in CityMap.meet_spots():
		var place := CityMap.place_name(point)
		var by := place.find(" BY ")
		if by < 0:
			continue
		var sign_name := place.substr(by + 4).trim_prefix("THE ")
		for district: Dictionary in CityMap.DISTRICTS:
			if sign_name in (district.get("names", []) as Array):
				ambiguous.append("%s nomina '%s', che in citta' c'e' piu' volte" % [point, sign_name])
	_check_empty(ambiguous, "nessun posto si fa riconoscere da un'insegna generica")

func _test_seed_deal() -> void:
	var data := _fresh()
	_check(SeedDeal.can_ask(data), "all'inizio si può chiedere")
	_check(not SeedDeal.is_active(data), "e non c'è nessun appuntamento in ballo")

	_check(SeedDeal.ask(data, GameState.total_hours()), "si chiedono i semi dal PC")
	_check(SeedDeal.is_waiting(data), "si sta aspettando")
	_check(not SeedDeal.can_ask(data), "non si chiede due volte insieme")
	_check(not SeedDeal.ask(data, GameState.total_hours()), "e la seconda richiesta non attacca")

	# Subito non è ancora arrivato niente.
	_check_eq(SeedDeal.tick(data, GameState.total_hours()), "", "appena chiesto non succede niente")
	_check(SeedDeal.is_waiting(data), "si sta ancora aspettando")

	# Passata l'attesa massima, la posizione c'è per forza.
	_advance(SeedDeal.WAIT_HOURS.y)
	_check_eq(
		SeedDeal.tick(data, GameState.total_hours()), SeedDeal.STATE_READY,
		"passata l'attesa arriva la posizione")
	_check(SeedDeal.is_ready(data), "l'appuntamento è fissato")
	_check(not SeedDeal.place(data).is_empty(), "e ha un posto con un nome")
	_check(
		SeedDeal.spot(data).distance_to(CityMap.home_doorstep()) <= CityMap.MEET_MAX_DISTANCE,
		"il posto è vicino a casa")
	var brought := SeedDeal.seeds_left(data)
	_check(
		brought >= SeedDeal.SEEDS_PER_RUN.x and brought <= SeedDeal.SEEDS_PER_RUN.y,
		"ha portato una consegna dentro all'intervallo")

	# Ritick: fissato resta fissato finché non scade. Serve perché `tick()` gira
	# a ogni frame, non una volta sola.
	_check_eq(SeedDeal.tick(data, GameState.total_hours()), "", "l'appuntamento non si rifissa ogni frame")

	# Si compra. Senza soldi non si porta via niente.
	var price := Economy.seed_price(Economy.DEFAULT_STRAIN)
	var had := Economy.seeds_owned(data)
	data.cash = 0
	_check_eq(SeedDeal.buy(data, 1), 0, "senza soldi non si compra")
	_check_eq(Economy.seeds_owned(data), had, "e i semi restano quelli di prima")

	data.cash = price * 2
	_check_eq(SeedDeal.buy(data, 2), 2, "con i soldi si comprano")
	_check_eq(Economy.seeds_owned(data), had + 2, "i semi arrivano in inventario")
	_check_eq(data.cash, 0, "e i soldi se ne vanno")
	_check_eq(SeedDeal.seeds_left(data), brought - 2, "Brian ne ha due di meno")

	# Chiedendone più di quanti ne ha, ne dà quanti gliene restano e se ne va.
	data.cash = price * 99
	var rest := SeedDeal.seeds_left(data)
	_check_eq(SeedDeal.buy(data, 99), rest, "dà quello che gli è rimasto, non di più")
	_check(not SeedDeal.is_active(data), "finiti i semi l'appuntamento si chiude")
	_check(SeedDeal.can_ask(data), "e se ne può chiedere un altro")

	# Chi non si presenta lo trova andato via, non lì per sempre.
	var later := _fresh()
	SeedDeal.ask(later, GameState.total_hours())
	_advance(SeedDeal.WAIT_HOURS.y)
	SeedDeal.tick(later, GameState.total_hours())
	_check(SeedDeal.is_ready(later), "appuntamento fissato")
	_advance(SeedDeal.MEET_HOURS + 1.0)
	_check_eq(
		SeedDeal.tick(later, GameState.total_hours()), SeedDeal.EVENT_GONE,
		"Brian non aspetta per sempre")
	_check(not SeedDeal.is_active(later), "e l'appuntamento sparisce")
	_check(SeedDeal.can_ask(later), "così non si resta bloccati senza semi")

	# L'avviso prima di andarsene. È la parte che mancava quando il giocatore
	# diceva "a volte sparisce": la finestra era corta E muta, quindi non c'era
	# modo di sapere che stava per chiudersi.
	var warned := _fresh()
	SeedDeal.ask(warned, GameState.total_hours())
	_advance(SeedDeal.WAIT_HOURS.y)
	SeedDeal.tick(warned, GameState.total_hours())
	_check(SeedDeal.is_ready(warned), "appuntamento fissato")
	_check_eq(
		SeedDeal.tick(warned, GameState.total_hours()), "",
		"appena fissato non avvisa che se ne va")
	_advance(SeedDeal.MEET_HOURS - SeedDeal.LEAVING_HOURS + 0.1)
	_check_eq(
		SeedDeal.tick(warned, GameState.total_hours()), SeedDeal.EVENT_LEAVING,
		"verso la fine avvisa che sta per andarsene")
	_check(SeedDeal.is_ready(warned), "ma è ancora lì: l'avviso non è l'addio")
	_check_eq(
		SeedDeal.tick(warned, GameState.total_hours()), "",
		"e avvisa una volta sola, non a ogni frame")

	# La finestra deve restare abbastanza larga da poterci giocare dentro:
	# `MEET_HOURS` ore di gioco sono `MEET_HOURS / GAME_MINUTES_PER_SECOND * 60`
	# secondi veri. Sotto i cinque minuti si torna al problema di prima.
	var real_minutes := SeedDeal.MEET_HOURS * 60.0 / GameState.GAME_MINUTES_PER_SECOND / 60.0
	_check(real_minutes >= 5.0, "l'appuntamento dura almeno cinque minuti veri")

## Ogni riga della tabella deve avere tutte e tre le lingue, e quelle mostrate
## col font del gioco solo lettere e spazio.
##
## Serve perché una traduzione dimenticata non rompe niente: `tr()` restituisce
## la chiave, quindi il gioco continua a girare mostrando `PC_TAB_SHOP` in mezzo
## alla schermata. È il tipo di errore che si trova per caso, mesi dopo, e solo
## se qualcuno apre il gioco in quella lingua.
func _test_translations() -> void:
	_check_empty(Strings.problems(), "la tabella delle lingue e' completa")

	# Un giro vero sul TranslationServer: le chiavi che finiscono nelle scene
	# devono tradursi in tutte le lingue, altrimenti il menu mostra "MENU_BACK".
	var was := GameSettings.locale
	for locale in Strings.LOCALES:
		GameSettings.locale = locale
		var missing: Array = []
		for key in ["MENU_NEW_GAME", "MENU_BACK", "PC_TITLE", "PC_CLOSE", "ROOM_BASEMENT"]:
			if TranslationServer.translate(key) == key:
				missing.append("%s in %s" % [key, locale])
		_check_empty(missing, "le chiavi delle scene si traducono")
	GameSettings.locale = was

	# E le cose che passano dalle tabelle di gioco devono arrivare tradotte, non
	# come chiave: e' il giro che fanno davvero in partita.
	GameSettings.locale = "it"
	_check_eq(Shop.item_name("lamps"), "LAMPADE ROSSE", "il negozio parla italiano")
	_check_eq(Staff.role_name("grower"), "COLTIVATORE", "e anche il personale")
	_check_eq(Economy.heat_label(0.0), "TRANQUILLO", "e l'attenzione")
	GameSettings.locale = was

# ---------------------------------------------------------------------------

func _test_shop() -> void:
	var data := _fresh()
	data.cash = 0
	_check(not Shop.can_buy(data, "toolkit"), "senza soldi non si compra niente")
	_check(not Shop.buy(data, "toolkit"), "e il negozio dice di no")
	_check_eq(Shop.owned(data, "toolkit"), 0, "niente arriva a casa")

	data.cash = Shop.price("toolkit")
	_check(Shop.buy(data, "toolkit"), "coi soldi si compra")
	_check_eq(data.cash, 0, "e i soldi se ne vanno")
	_check_eq(Shop.owned(data, "toolkit"), 1, "il pezzo e' in inventario")

	data.cash = 100000
	_check(not Shop.can_buy(data, "toolkit"), "il toolkit e' uno solo, non se ne comprano due")
	# Una lampada per vaso, ovunque: cantina e garage. Prima il tetto erano i
	# soli sei della cantina — vedi la nota in `Shop.ITEMS`, che racconta anche
	# perche' e' cambiato.
	_check_eq(
		Shop.max_owned("lamps"), Economy.MAX_PLOTS,
		"si compra una lampada per ogni vaso del gioco")
	# La prova sotto lavora su una cantina piena, che e' il caso in cui si vede
	# se lo sconto si somma: sei lampade su sei vasi.
	var lamped: Dictionary = GrowSites.find("basement")

	# Le lampade accorciano il ciclo, il toolkit alza la resa.
	var strain := Economy.strain(Economy.DEFAULT_STRAIN)
	var base_hours := float(strain["grow_hours"])
	var base_grams := int(strain["grams"])
	var mods := Shop.grow_mods(data, base_hours, base_grams)
	_check(int(mods["grams"]) > base_grams, "il toolkit alza la resa")
	_check(is_equal_approx(float(mods["hours"]), base_hours), "ma non tocca il tempo")

	# Senza dire QUALE vaso, `grow_mods()` non regala nessuno sconto: e' il
	# ripiego sicuro, non "assume che ce l'abbia".
	_check(
		is_equal_approx(float(Shop.grow_mods(data, base_hours, base_grams, -1)["hours"]), base_hours),
		"senza un vaso indicato non c'e' nessuno sconto")

	_check(Shop.buy(data, "lamps"), "si compra la prima lampada")
	var lit := Shop.grow_mods(data, base_hours, base_grams, 0)
	_check(float(lit["hours"]) < base_hours, "il vaso con la sua lampada e' piu' veloce")
	_check(
		is_equal_approx(
			float(lit["hours"]), base_hours * (1.0 - Shop.LAMP_SPEEDUP)),
		"di esattamente l'8%, non di piu'")
	_check(
		is_equal_approx(float(Shop.grow_mods(data, base_hours, base_grams, 1)["hours"]), base_hours),
		"un vaso SENZA la sua lampada resta al tempo di listino")

	# Il punto di tutto: comprare piu' lampade non fa sommare lo sconto sullo
	# stesso vaso. Prima di questa correzione, con sei lampade comprate ogni
	# vaso — coperto o no — si vedeva tagliare il 48% (8% x 6) invece dell'8%
	# del solo vaso che ha davvero la lampada sopra.
	for i in int(lamped["count"]) - 1:
		Shop.buy(data, "lamps")
	_check_eq(Shop.owned(data, "lamps"), int(lamped["count"]), "sei lampade comprate")
	for index in int(lamped["count"]):
		var covered := Shop.grow_mods(data, base_hours, base_grams, index)
		_check(
			is_equal_approx(float(covered["hours"]), base_hours * (1.0 - Shop.LAMP_SPEEDUP)),
			"il vaso %d resta all'8%%, anche con tutte le lampade comprate" % index)
	# Un vaso oltre l'ultima lampada — se un domani il seminterrato si allarga
	# senza comprare altre lampade — non ha comunque nessuno sconto.
	_check(
		is_equal_approx(
			float(Shop.grow_mods(data, base_hours, base_grams, int(lamped["count"]))["hours"]),
			base_hours),
		"un vaso oltre l'ultima lampada non ha sconto")

	# Il filtro a carbone abbassa l'attenzione per grammo venduto in strada.
	var plain := Economy.street_heat(data)
	_check(Shop.buy(data, "filter"), "si compra il filtro")
	_check(Economy.street_heat(data) < plain, "il filtro abbassa l'attenzione per grammo")

	# La fotografia dell'attrezzatura resta attaccata alla pianta: comprare
	# altre lampade a meta' ciclo non deve accorciare una pianta gia' in terra.
	var plot := data.plot(0)
	Grow.plant(plot, Economy.DEFAULT_STRAIN, GameState.total_hours(), lit)
	var planted_hours := Grow.grow_hours(plot)
	Shop.buy(data, "lamps")
	_check(
		is_equal_approx(Grow.grow_hours(plot), planted_hours),
		"comprare lampade a meta' ciclo non cambia una pianta gia' in terra")

func _test_prologue() -> void:
	var data := _fresh()
	_check_eq(data.chapter, "prologo", "si parte dal prologo")
	_check(not bool(data.get_flag("staff_unlocked", false)), "e senza personale")
	_check(not Staff.can_hire(data, "grower"), "prima del prologo non si assume")

	data.cash = Economy.PROLOGUE_CASH
	GameState._check_prologue()
	_check_eq(data.chapter, "capitolo_uno", "ai %d $ il prologo si chiude" % Economy.PROLOGUE_CASH)
	_check(bool(data.get_flag("staff_unlocked", false)), "e si sblocca il personale")
	_check(Staff.can_hire(data, "grower") or data.cash < Staff.hire_cost("grower"), "e da li' si assume")
	# Il messaggio del cugino è un nodo vero appeso a `GameState`: senza questo
	# giro resterebbe lì per tutto il resto dei controlli, e a fine esecuzione
	# comparirebbe fra gli oggetti non liberati.
	_close_messages()

	# Scendere sotto la soglia non riapre il prologo, e il messaggio del cugino
	# non si ripresenta: e' una cosa che succede una volta sola.
	data.cash = 10
	GameState._check_prologue()
	_check_eq(data.chapter, "capitolo_uno", "il prologo resta chiuso")

func _test_staff_growing() -> void:
	var data := _fresh()
	data.cash = Staff.hire_cost("grower")
	var now := GameState.total_hours()
	_check(Staff.hire(data, "grower", now), "si assume un coltivatore")
	_check_eq(Staff.count(data, "grower"), 1, "ed e' in organico")
	_check_eq(data.cash, 0, "l'assunzione si paga")

	# Un coltivatore copre TUTTO il seminterrato, quindi finche' i vasi sono sei
	# ne basta uno. Il tetto lo dice il posto che c'e' (`Staff.max_for()`), non
	# un numero scritto a mano: quando ci sara' una seconda proprieta' salira'
	# da solo.
	data.cash = 100000
	_check_eq(Staff.max_for(data, "grower"), 1, "con sei vasi basta un coltivatore")
	_check(not Staff.can_hire(data, "grower"), "e un secondo non si puo' assumere")
	_check(Staff.max_for(data, "dealer") > 1, "i dealer invece si sommano")

	# --- L'autista: c'e' solo col furgone, ed e' uno ------------------------
	# Il ruolo non deve comparire prima del furgone: senza mezzo da guidare
	# sarebbe una riga spenta che sembra rotta invece che "non ancora".
	_check_eq(Staff.max_for(data, "driver"), 0, "senza furgone non c'e' nessun autista")
	_check(
		not Staff.roles_for(data).has("driver"),
		"e il ruolo non compare nemmeno nella lista")
	data.cash = Shop.price("van")
	Shop.buy(data, "van")
	_check_eq(Staff.max_for(data, "driver"), 1, "col furgone si puo' assumere un autista")
	_check(Staff.roles_for(data).has("driver"), "e il ruolo compare")
	data.cash = Staff.hire_cost("driver")
	_check(Staff.hire(data, "driver", now), "assunto")
	_check(Staff.has_driver(data), "e da li' i semi si ordinano dal PC")
	_check(not Staff.can_hire(data, "driver"), "ma il secondo no: il furgone e' uno")

	# --- I dealer crescono con le proprieta' --------------------------------
	# Il tetto non e' un numero fisso ma una conseguenza di quanto si e' grossi.
	# Scritto a mano resterebbe a tre il giorno che si compra la seconda
	# proprieta', e nessuno se ne accorgerebbe se non contando gli assunti.
	var senza := _fresh()
	_check_eq(Staff.max_for(senza, "dealer"), Staff.MAX_DEALERS,
		"con la sola casa i dealer sono %d" % Staff.MAX_DEALERS)
	senza.properties["Garage"] = {"livello": 1}
	_check_eq(Staff.max_for(senza, "dealer"), Staff.MAX_DEALERS + Staff.DEALERS_PER_PROPERTY,
		"con la prima proprieta' diventano %d" % (Staff.MAX_DEALERS + Staff.DEALERS_PER_PROPERTY))
	senza.properties["Chissa"] = {"livello": 1}
	_check_eq(Staff.max_for(senza, "dealer"),
		Staff.MAX_DEALERS + 2 * Staff.DEALERS_PER_PROPERTY,
		"e ogni proprieta' nuova ne porta altri %d" % Staff.DEALERS_PER_PROPERTY)
	data.cash = 0

	# Ha i semi: pianta da solo. I vasi che segue sono tutti quelli che ci sono.
	var tended := mini(Staff.POTS_PER_GROWER, data.plots.size())
	_check(tended > 0, "c'e' almeno un vaso da seguire")
	data.add_item(Economy.seed_item(Economy.DEFAULT_STRAIN), 20)
	var report := Staff.work(data, now)
	_check_eq(int(report["planted"]), tended, "pianta tutti i vasi che ci sono")
	_check(not Grow.is_empty(data.plot(0)), "il primo vaso e' pieno")
	_check(not Grow.is_empty(data.plot(tended - 1)), "e anche l'ultimo")

	# Il ciclo passa senza che il giocatore tocchi niente: annaffia e raccoglie.
	_advance(Grow.WATER_HOURS + 1.0)
	var watered := Staff.work(data, GameState.total_hours())
	_check_eq(int(watered["watered"]), tended, "annaffia quando hanno sete")

	_advance(float(Economy.strain(Economy.DEFAULT_STRAIN)["grow_hours"]))
	var reaped := Staff.work(data, GameState.total_hours())
	_check_eq(int(reaped["harvested"]), tended, "raccoglie quando sono pronte")
	_check(int(reaped["grams"]) > 0, "e la merce arriva in magazzino")
	_check_eq(Economy.stock(data), int(reaped["grams"]), "tutta quanta")
	_check_eq(int(reaped["planted"]), tended, "e ripianta subito coi semi rimasti")

	# La lampada e' un effetto per vaso anche quando a piantare e' il
	# personale: un coltivatore che ne segue sei non deve trovarsi lo stesso
	# sconto su tutti solo perche' in cantina ci sono tre lampade in totale.
	var lamped := _fresh()
	lamped.cash = Staff.hire_cost("grower")
	Staff.hire(lamped, "grower", GameState.total_hours())
	lamped.cash = Shop.price("lamps") * 3
	for i in 3:
		Shop.buy(lamped, "lamps")
	_check_eq(Shop.owned(lamped, "lamps"), 3, "tre lampade comprate, non sei")
	lamped.add_item(Economy.seed_item(Economy.DEFAULT_STRAIN), 20)
	var strain := Economy.strain(Economy.DEFAULT_STRAIN)
	var base := {"hours": strain["grow_hours"], "grams": strain["grams"]}
	Staff.work(lamped, GameState.total_hours(), base)
	for i in 3:
		_check(
			Grow.grow_hours(lamped.plot(i)) < float(strain["grow_hours"]),
			"il vaso %d ha la sua lampada ed e' piu' veloce" % i)
	for i in range(3, 6):
		_check(
			is_equal_approx(Grow.grow_hours(lamped.plot(i)), float(strain["grow_hours"])),
			"il vaso %d non ha lampada e resta al tempo di listino" % i)

## L'assegnazione dei coltivatori alle proprieta'.
##
## E' il pezzo con piu' modi di sbagliare di tutto il personale, perche' sotto
## cambia tutto: si assume, si licenzia, si compra un vaso, si compra il garage.
## Ogni volta il numero di posti e la loro capienza si muovono, e chi era
## assegnato puo' ritrovarsi in un posto che non lo regge piu'.
## I vasi delle stanze: ognuno risponde al click sul PROPRIO disegno.
##
## E' il tipo di errore che non si vede guardando la stanza e non alza nessun
## avviso. La cornice di un vaso e' alta quanto la pianta che ci cresce dentro,
## ma quello che si clicca e' il vaso, venti pixel in fondo: sui banconi del
## garage i vasi stanno su due file, e la cornice di quello davanti finisce
## esattamente sopra al vaso di quello dietro. La prima volta che sono stati
## messi cosi', **tutti e sei** i vasi della fila dietro erano inservibili.
##
## Si prova sulle scene vere e non su numeri scritti qui, perche' e' il
## piazzamento a poter sbagliare: spostare un vaso di dieci pixel nell'editor lo
## puo' rendere inservibile senza che niente lo dica.
func _test_room_plots() -> void:
	var data := _fresh()
	data.cash = 999999
	data.properties["Garage"] = {"livello": 1, "acquisito_il": 1}
	while Economy.next_plot_cost(data) >= 0:
		Economy.buy_plot(data)

	for path in ["res://scenes/rooms/Basement.tscn", "res://scenes/rooms/Garage.tscn"]:
		var scene: PackedScene = load(path)
		if scene == null:
			_check(false, "la stanza %s si carica" % path)
			continue
		var room: Node = scene.instantiate()
		add_child(room)

		var plots: Array = []
		for child in room.get_children():
			if child is Control and "index" in child and child.has_method("_has_point"):
				plots.append(child)
		var room_name: String = path.get_file().get_basename()
		_check(not plots.is_empty(), "%s ha dei vasi" % room_name)

		var seen := {}
		var deaf: Array = []
		var doubled: Array = []
		for plot in plots:
			var slot := int(plot.index)
			if seen.has(slot):
				doubled.append(str(slot))
			seen[slot] = true
			# Il centro del vaso DISEGNATO: sta in fondo alla cornice, non in
			# mezzo. Vedi `grow_plot.gd::_draw_pot()`.
			var target: Vector2 = plot.position + Vector2(plot.size.x * 0.5, plot.size.y - 9.0)
			var answers: Node = null
			for other in plots:
				# L'ultimo che contiene il punto e' quello disegnato sopra, ed e'
				# quello che il click prende davvero.
				if other._has_point(target - other.position):
					answers = other
			if answers != plot:
				deaf.append("vaso %d" % (slot + 1))
		_check_empty(deaf, "in %s ogni vaso risponde al click sul proprio disegno" % room_name)
		_check_empty(doubled, "in %s nessun indice di vaso e' ripetuto" % room_name)

		room.queue_free()

func _test_grower_sites() -> void:
	var data := _fresh()
	var cellar: Dictionary = GrowSites.find("basement")
	var garage: Dictionary = GrowSites.find("garage")
	_check(not cellar.is_empty() and not garage.is_empty(), "i due posti esistono")

	# A inizio partita c'e' solo la cantina: il garage non e' tuo.
	_check(GrowSites.is_open(data, cellar), "la cantina e' tua da subito")
	_check(not GrowSites.is_open(data, garage), "il garage no")
	_check_eq(GrowSites.open_sites(data).size(), 1, "quindi il posto e' uno solo")

	# Con tre vasi aperti basta un coltivatore, e ci va da solo appena assunto:
	# uno che si paga ogni notte non deve restare in panchina perche' nessuno si
	# e' accorto che andava assegnato.
	_check_eq(data.plot_slots, Economy.START_PLOTS, "si parte con i vasi di partenza")
	_check_eq(Staff.max_for(data, "grower"), 1, "un coltivatore basta per la cantina")
	data.cash = Staff.hire_cost("grower")
	_check(Staff.hire(data, "grower", GameState.total_hours()), "assunto")
	_check_eq(Staff.growers_on(data, "basement"), 1, "ed e' finito in cantina da solo")
	_check_eq(Staff.idle_growers(data), 0, "nessuno in panchina")

	# Senza il garage non ci si puo' mandare nessuno, e non si puo' nemmeno
	# assumere il secondo: il tetto e' la somma delle capienze dei posti APERTI.
	data.cash = 100000
	_check(not Staff.assign(data, "garage", 1), "in un posto non tuo non si manda nessuno")
	_check(not Staff.can_hire(data, "grower"), "e non serve un secondo coltivatore")

	# Comprato il garage e aperti i suoi vasi, il tetto sale da solo.
	data.properties["Garage"] = {"livello": 1, "acquisito_il": data.day}
	Staff.sync_sites(data)
	while Economy.next_plot_cost(data) >= 0:
		Economy.buy_plot(data)
	_check_eq(data.plot_slots, Economy.MAX_PLOTS, "tutti i vasi aperti")
	_check_eq(GrowSites.slots_in(data, cellar), 6, "sei in cantina")
	_check_eq(GrowSites.slots_in(data, garage), 12, "dodici in garage")
	_check_eq(GrowSites.capacity(data, garage), 2, "il garage regge due coltivatori")
	_check_eq(Staff.max_for(data, "grower"), 3, "in tutto se ne possono tenere tre")

	# Il secondo e il terzo finiscono dove c'e' spazio, cioe' in garage.
	data.cash = 100000
	_check(Staff.hire(data, "grower", GameState.total_hours()), "assunto il secondo")
	_check(Staff.hire(data, "grower", GameState.total_hours()), "assunto il terzo")
	_check_eq(Staff.growers_on(data, "garage"), 2, "tutti e due in garage")
	_check_eq(Staff.idle_growers(data), 0, "e nessuno senza posto")
	_check(not Staff.can_hire(data, "grower"), "il quarto non ci sta")

	# Spostarli e' il punto della scheda: si toglie da un posto e si mette
	# nell'altro, e non si puo' mettere piu' gente di quanta ne regga il posto.
	_check(Staff.assign(data, "garage", -1), "uno lo si toglie dal garage")
	_check_eq(Staff.idle_growers(data), 1, "e resta senza posto")
	_check(not Staff.assign(data, "basement", 1), "in cantina non ci sta il secondo")
	_check(Staff.assign(data, "garage", 1), "lo si rimanda in garage")
	_check_eq(Staff.idle_growers(data), 0, "e torna a lavorare")
	_check(not Staff.assign(data, "garage", 1), "un terzo in garage non ci sta")

	# Ognuno segue SOLO i vasi del posto in cui sta. E' la regola che prima non
	# c'era: il lavoro partiva dal primo vaso dell'elenco e andava avanti a
	# `coltivatori x 6`, quindi due in cantina coprivano anche i primi sei del
	# garage, dove non c'era nessuno.
	data.grower_sites = {"basement": 1}
	data.staff["grower"] = 1
	data.add_item(Economy.seed_item(Economy.DEFAULT_STRAIN), 50)
	data.staff_checked_at = GameState.total_hours()
	_advance(1.0)
	Staff.work(data, GameState.total_hours())
	var planted_cellar := 0
	var planted_garage := 0
	for i in Economy.MAX_PLOTS:
		if Grow.is_empty(data.plot(i)):
			continue
		if int(GrowSites.site_of(i).get("from", -1)) == 0:
			planted_cellar += 1
		else:
			planted_garage += 1
	_check_eq(planted_cellar, 6, "il coltivatore in cantina ha piantato i sei di sotto")
	_check_eq(planted_garage, 0, "e non ha toccato il garage, dove non c'e' nessuno")

	# Mandandolo in garage tocca il garage, e la cantina resta com'e'.
	data.grower_sites = {"garage": 1}
	_advance(1.0)
	Staff.work(data, GameState.total_hours())
	var garage_from := int(garage["from"])
	var now_planted := 0
	for i in range(garage_from, garage_from + 12):
		if not Grow.is_empty(data.plot(i)):
			now_planted += 1
	_check_eq(now_planted, 6, "in garage ne segue sei, quanti ne regge uno solo")

	# Licenziare deve togliere anche il posto: altrimenti resterebbe scritto che
	# in garage c'e' qualcuno che non e' piu' sul libro paga, e continuerebbe a
	# lavorare gratis.
	data.staff["grower"] = 1
	data.grower_sites = {"garage": 1}
	_check(Staff.fire(data, "grower"), "licenziato")
	_check_eq(Staff.count(data, "grower"), 0, "non c'e' piu' nessuno assunto")
	_check_eq(Staff.growers_on(data, "garage"), 0, "e nemmeno in garage")

	# Vendere (o non avere piu') una proprieta' svuota il suo posto invece di
	# lasciare gente a lavorare in casa d'altri.
	data.staff["grower"] = 2
	data.grower_sites = {"basement": 1, "garage": 1}
	data.properties.erase("Garage")
	Staff.sync_sites(data)
	_check_eq(Staff.growers_on(data, "garage"), 0, "chiuso il garage, nessuno ci lavora piu'")
	_check_eq(Staff.growers_on(data, "basement"), 1, "in cantina resta chi c'era")
	_check_eq(Staff.idle_growers(data), 1, "e l'altro e' senza posto")

func _test_staff_selling() -> void:
	var data := _fresh()
	data.cash = Staff.hire_cost("dealer")
	var now := GameState.total_hours()
	_check(Staff.hire(data, "dealer", now), "si assume un dealer")
	data.cash = 0
	data.add_item(Economy.PRODUCT, 500)

	# Finche' l'ingrosso e' chiuso non si mette da parte niente: il furgone non
	# c'e', e bloccare merce per un canale che non esiste vorrebbe dire togliere
	# lavoro ai dealer senza dare niente in cambio. Al PC la scelta non compare
	# nemmeno (vedi `management_window.gd::_build_staff()`).
	Staff.set_wholesale_share(data, 100)
	_check_eq(
		Staff.wholesale_share(data), 0,
		"a ingrosso chiuso la quota da mettere da parte e' zero")
	_check_eq(
		data.wholesale_share, 100,
		"ma il numero scelto dal giocatore resta scritto")
	_check_eq(Staff.reserved(data), 0, "e in magazzino non c'e' niente di fermo")
	_check_eq(Staff.sellable(data), 500, "i dealer possono piazzare tutto")

	# Aperto il canale, la quota torna valida e la riserva si rifa' sulla scorta
	# che c'e' gia': quel chilo non deve sparire in strada prima che la scelta
	# appena comparsa al PC voglia dire qualcosa.
	data.set_flag(Delivery.UNLOCK_FLAG, true)
	Staff.retarget_reserve(data)
	_check_eq(Staff.wholesale_share(data), 100, "aperto il canale, la quota torna quella scelta")
	_check_eq(Staff.reserved(data), 500, "e la scorta gia' in casa finisce tutta da parte")
	_check_eq(Staff.sellable(data), 0, "ai dealer non resta niente")

	# Tutto da parte: i dealer non hanno niente da vendere e non incassano.
	_advance(10.0)
	var held := Staff.work(data, GameState.total_hours())
	_check_eq(int(held["sold"]), 0, "con tutto da parte il dealer non piazza niente")
	_check_eq(Economy.stock(data), 500, "e la scorta resta intatta")
	_check_eq(data.heat, 0.0, "niente strada, niente attenzione")

	# L'esempio del gioco: cento grammi al trenta/settanta. Trenta restano
	# fermi, settanta sono dei dealer.
	data.inventory.erase(Economy.PRODUCT)
	data.wholesale_reserve = 0
	Staff.set_wholesale_share(data, 30)
	data.add_item(Economy.PRODUCT, 100)
	Staff.reserve_harvest(data, 100)
	_check_eq(Staff.reserved(data), 30, "di cento grammi raccolti trenta restano da parte")
	_check_eq(Staff.sellable(data), 70, "e settanta sono quelli che i dealer possono piazzare")

	# E non si svuota da sola: i dealer arrivano fino alla riserva e li' si
	# fermano, per quante ore gli si diano.
	for i in 10:
		_advance(10.0)
		Staff.work(data, GameState.total_hours())
	_check_eq(Economy.stock(data), 30, "piazzano i settanta e si fermano sulla riserva")
	_check_eq(Staff.reserved(data), 30, "la riserva non si consuma da sola")
	_check(data.heat > 0.0, "vendendo in strada l'attenzione sale")

	# Un raccolto nuovo aggiunge la sua quota a quella gia' ferma, invece di
	# rifare il conto sul totale: il contrario libererebbe roba gia' messa via.
	data.add_item(Economy.PRODUCT, 100)
	Staff.reserve_harvest(data, 100)
	_check_eq(Staff.reserved(data), 60, "il raccolto dopo mette da parte la sua quota")
	_check_eq(Staff.sellable(data), 70, "e ai dealer torna la stessa fetta di prima")

	# Abbassare la quota libera subito: e' il comando con cui si dice ai dealer
	# di vendere di piu', e deve valere adesso e non dal raccolto prossimo.
	Staff.set_wholesale_share(data, 0)
	_check_eq(Staff.reserved(data), 0, "a quota zero non resta fermo niente")
	_check_eq(Staff.sellable(data), Economy.stock(data), "e i dealer hanno tutto")

	# I dealer non vendono all'ingrosso: qualunque sia la quota, quello che
	# piazzano va in strada e alza l'attenzione. E' il furgone il canale
	# dell'ingrosso, ed e' del giocatore.
	data.inventory.erase(Economy.PRODUCT)
	data.wholesale_reserve = 0
	data.heat = 0.0
	data.cash = 0
	data.add_item(Economy.PRODUCT, 500)
	_advance(10.0)
	var street := Staff.work(data, GameState.total_hours())
	_check_eq(int(street["sold"]), int(10.0 * Staff.GRAMS_PER_DEALER_HOUR), "quanto riesce a piazzare in dieci ore")
	_check(data.heat > 0.0, "quello che piazza va in strada")
	_check_eq(
		int(street["gross"]), int(street["sold"]) * Economy.retail_price(data),
		"e al prezzo di strada, non a quello dell'ingrosso")

	# La quota del dealer: niente paga, si tiene una fetta di quello che piazza.
	_check(int(street["commission"]) > 0, "il dealer si e' tenuto la sua quota")
	_check_eq(
		int(street["commission"]), int(roundf(float(street["gross"]) * Staff.cut("dealer"))),
		"che e' la percentuale della tabella")
	_check_eq(
		int(street["revenue"]), int(street["gross"]) - int(street["commission"]),
		"in cassa arriva il lordo meno la quota")
	_check_eq(data.cash, int(street["revenue"]), "che e' quello che la cassa ha visto")
	# La quota non dipende da quanti sono: la merce piazzata e' la stessa,
	# divisa fra loro. Assumerne un altro aumenta quanto si riesce a piazzare,
	# non la percentuale.
	data.cash += Staff.hire_cost("dealer")
	Staff.hire(data, "dealer", GameState.total_hours())
	data.cash = 0
	_advance(10.0)
	var pair := Staff.work(data, GameState.total_hours())
	if int(pair["gross"]) > 0:
		_check_eq(
			int(pair["commission"]), int(roundf(float(pair["gross"]) * Staff.cut("dealer"))),
			"anche in due la percentuale e' la stessa")
	_check(Staff.fire(data, "dealer"), "torniamo a uno solo")

	# Senza merce non si inventa niente.
	data.inventory.erase(Economy.PRODUCT)
	_advance(10.0)
	var empty := Staff.work(data, GameState.total_hours())
	_check_eq(int(empty["revenue"]), 0, "a magazzino vuoto non si incassa niente")

	# Le ore avanzate non si perdono: il resto sotto al grammo torna al giro dopo.
	data.add_item(Economy.PRODUCT, 500)
	var before := Economy.stock(data)
	for i in 20:
		_advance(0.5)
		Staff.work(data, GameState.total_hours())
	_check_eq(
		before - Economy.stock(data), int(10.0 * Staff.GRAMS_PER_DEALER_HOUR),
		"venti mezz'ore piazzano quanto dieci ore in un colpo solo")

	# Il carico che parte scarica la riserva: e' esattamente quello per cui era
	# stata messa da parte, e se restasse ferma bloccherebbe il magazzino per
	# sempre.
	Staff.set_wholesale_share(data, 50)
	var kept := Staff.reserved(data)
	_check(kept > 0, "con meta' quota c'e' merce ferma")
	Staff.release_reserved(data, kept)
	_check_eq(Staff.reserved(data), 0, "partito il carico la riserva si libera")

func _test_staff_wages() -> void:
	var data := _fresh()
	data.cash = Staff.hire_cost("grower")
	_check(Staff.hire(data, "grower", GameState.total_hours()), "assunto")
	_check_eq(Staff.daily_wages(data), Staff.wage("grower"), "la paga del giorno")

	# I due ruoli si pagano in due modi diversi, ed e' la differenza che conta:
	# un dealer fermo non costa niente, un coltivatore senza semi costa uguale.
	data.cash = 100000
	_check(Staff.hire(data, "dealer", GameState.total_hours()), "assunto anche un dealer")
	_check_eq(Staff.wage("dealer"), 0, "il dealer non ha paga")
	_check_eq(
		Staff.daily_wages(data), Staff.wage("grower"),
		"e non entra nel conto delle paghe")
	_check(Staff.cut("dealer") > 0.0, "si tiene invece una quota sulle vendite")
	_check_eq(Staff.cut("grower"), 0.0, "il coltivatore no: lui prende la paga")

	data.cash = 1000
	var paid := Staff.pay_wages(data)
	_check_eq(int(paid["paid"]), Staff.wage("grower"), "a mezzanotte si paga")
	_check_eq(data.cash, 1000 - Staff.wage("grower"), "e la cassa cala")
	_check_eq(str(paid["quit"]), "", "nessuno se ne va")

	# Cassa vuota: se ne va uno, invece di lasciare un buco che si allarga.
	data.cash = 0
	var broke := Staff.pay_wages(data)
	_check_eq(str(broke["quit"]), "grower", "senza soldi il coltivatore se ne va")
	_check_eq(
		Staff.count(data, "dealer"), 1,
		"il dealer resta: non aveva niente da riscuotere")
	_check(data.cash >= 0, "la cassa non va sotto zero")

	# Con soli dealer in organico non c'e' nessuna paga da scalare, quindi non
	# c'e' nessuna notte in cui la cassa vuota possa mandare via qualcuno.
	var only_cut := Staff.pay_wages(data)
	_check_eq(int(only_cut["paid"]), 0, "con soli dealer non si paga niente")
	_check_eq(str(only_cut["quit"]), "", "e non se ne va nessuno")

	_check(not Staff.fire(data, "grower"), "non si puo' licenziare chi non c'e'")

func _test_save_roundtrip() -> void:
	var data := _fresh()
	# Attrezzatura e personale prima della semina: cosi' la pianta si porta
	# dietro una durata diversa da quella di listino, ed e' quella che il giro
	# del salvataggio deve restituire intatta.
	data.cash = 100000
	Shop.buy(data, "lamps")
	Staff.hire(data, "dealer", GameState.total_hours())
	Staff.set_wholesale_share(data, 40)
	# Mezz'ora di lavoro non ancora consumata: se tornasse arrotondata, il
	# personale la perderebbe a ogni caricamento.
	data.staff_checked_at = 26.5
	var strain := Economy.strain(Economy.DEFAULT_STRAIN)
	var plot := data.plot(1)
	Grow.plant(plot, Economy.DEFAULT_STRAIN, GameState.total_hours(),
		Shop.grow_mods(data, float(strain["grow_hours"]), int(strain["grams"])))
	_advance(7.5)
	Grow.sync(plot, GameState.total_hours())
	data.add_item(Economy.PRODUCT, 42)
	data.heat = 23.5
	data.market_price = 13
	data.weather = "storm"
	Economy.sell_street(data, "dee", 3)
	# Dopo la vendita, non prima: vendere in strada alza l'attenzione, quindi il
	# valore da confrontare è quello che c'è davvero al momento del salvataggio.
	var heat_before := data.heat
	# Un appuntamento aperto va ritrovato al ricaricamento, altrimenti chiudere
	# il gioco mentre Brian aspetta lo farebbe sparire coi soldi già impegnati.
	SeedDeal.ask(data, GameState.total_hours())
	_advance(SeedDeal.WAIT_HOURS.y)
	SeedDeal.tick(data, GameState.total_hours())

	var restored := SaveData.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	_check_eq(restored.plots.size(), data.plots.size(), "numero di vasi conservato")
	_check_eq(restored.plot_slots, data.plot_slots, "vasi sbloccati conservati")
	_check_eq(Shop.owned(restored, "lamps"), Shop.owned(data, "lamps"), "attrezzatura conservata")
	_check_eq(Staff.count(restored, "dealer"), Staff.count(data, "dealer"), "organico conservato")
	_check_eq(restored.wholesale_share, data.wholesale_share, "ripartizione delle vendite conservata")
	_check(
		is_equal_approx(restored.staff_checked_at, data.staff_checked_at),
		"l'orologio del personale conserva la mezz'ora")
	_check(
		is_equal_approx(Grow.grow_hours(restored.plot(0)), Grow.grow_hours(data.plot(0))),
		"la durata fotografata sulla pianta e' conservata")
	_check_eq(Economy.stock(restored), Economy.stock(data), "merce conservata")
	_check_eq(restored.market_price, 13, "prezzo del giorno conservato")
	_check_eq(restored.weather, "storm", "il tempo del giorno e' conservato")
	_check(is_equal_approx(restored.heat, heat_before), "attenzione conservata")
	_check(
		is_equal_approx(float(restored.plots[1]["planted_at"]), float(data.plots[1]["planted_at"])),
		"l'ora di semina resta un float e non viene arrotondata")
	_check_eq(
		int(restored.npc_state["dee"]["bought"]), int(data.npc_state["dee"]["bought"]),
		"quello che ha comprato un cliente e' conservato")
	_check(SeedDeal.is_ready(restored), "l'appuntamento con Brian e' conservato")
	_check(SeedDeal.spot(restored).is_equal_approx(SeedDeal.spot(data)), "e il posto e' lo stesso")
	_check_eq(SeedDeal.place(restored), SeedDeal.place(data), "col suo nome")
	_check_eq(SeedDeal.seeds_left(restored), SeedDeal.seeds_left(data), "e i semi che aveva addosso")
	_check(
		is_equal_approx(
			float(restored.seed_deal["expires_at"]), float(data.seed_deal["expires_at"])),
		"l'ora in cui se ne va resta un float e non viene arrotondata")

	# Il punto vero: la pianta salvata deve trovarsi allo stesso stadio.
	_check_eq(
		Grow.stage(restored.plots[1], GameState.total_hours()),
		Grow.stage(data.plots[1], GameState.total_hours()),
		"ricaricando, la pianta e' allo stesso stadio")

	# Un salvataggio vecchio, senza i campi della coltivazione, deve caricarsi.
	var legacy := {"version": 1, "cash": 500, "day": 4}
	var old := SaveData.from_dict(legacy)
	_check_eq(old.cash, 500, "salvataggio vecchio: soldi letti")
	_check_eq(old.weather, Weather.DEFAULT, "salvataggio vecchio: tempo di ripiego")
	_check_eq(old.plots.size(), old.plot_slots, "salvataggio vecchio: vasi creati vuoti")
	_check(Grow.is_empty(old.plot(0)), "salvataggio vecchio: vasi vuoti")

## Il giro che fa il giocatore premendo "play": si gioca, si chiude, si
## riapre e si riprende da dove si era.
##
## È il percorso che conta di più di tutti e passa da disco, non solo da
## `to_dict()`: qui si vede se il file viene scritto davvero, se "l'ultima
## partita" è quella giusta, e se torna indietro tutto quello che il giocatore
## si aspetta di ritrovare.
## Al primo assunto Brian chiede il nome; col nome compare il prestigio, che
## parte dai pivelli e sopravvive al salvataggio.
func _test_org_prestige() -> void:
	GameState.new_game()
	var data := GameState.current
	_check(not Prestige.active(data), "senza nome niente prestigio")
	GameState._check_milestones()
	_check(not bool(data.get_flag(GameState.ORG_NAME_FLAG, false)), "da soli non si chiede il nome")
	data.cash = 100000
	Staff.hire(data, "grower", GameState.total_hours())
	GameState._check_milestones()
	_check(bool(data.get_flag(GameState.ORG_NAME_FLAG, false)), "al primo assunto brian chiede il nome")
	data.org_name = "Los Cugini"
	_check(Prestige.active(data), "col nome c'e' il prestigio")
	_check_eq(Prestige.level_name(data), "PRESTIGE_ROOKIE_1", "si parte da rookie uno")
	Prestige.add(data, 25)
	_check(is_equal_approx(Prestige.progress(data), 0.25), "la barra si riempie coi punti")
	Prestige.add(data, 75)
	_check_eq(Prestige.level_name(data), "PRESTIGE_ROOKIE_2", "cento punti e si passa a rookie due")
	Prestige.add(data, -1000)
	_check_eq(data.prestige, 0, "il prestigio non va sotto zero")
	_check_eq(Prestige.level_name(data), "PRESTIGE_ROOKIE_1", "e si torna a rookie uno")
	var back := SaveData.from_dict(data.to_dict())
	_check_eq(back.org_name, "Los Cugini", "il nome si salva")

func _test_continue_last() -> void:
	_wipe_saves()

	# Una partita vecchia, che non deve essere quella ripresa.
	_fresh()
	GameState.current.cash = 11
	GameState.save_game()
	var old_slot := GameState.current_slot

	# La partita "vera": ci si mette dentro un po' di tutto.
	var data := _fresh()
	var slot := GameState.current_slot
	_check(slot != old_slot, "una partita nuova non sovrascrive la precedente")
	data.cash = 4321
	data.player_position = Vector2(1234, 567)
	data.current_room = "res://scenes/rooms/Kitchen.tscn"
	data.properties["Minimarket"] = {"livello": 2, "acquisito_il": 3}
	data.chapter = "capitolo_uno"
	data.set_flag("ha_conosciuto_milo")
	data.mark_dialogue_seen("milo_primo_incontro")
	data.add_item(Economy.PRODUCT, 55)
	data.day = 6
	data.time_of_day = 15.5
	Grow.plant(data.plot(0), Economy.DEFAULT_STRAIN, GameState.total_hours() - 8.0)
	GameState.save_game()

	# Si chiude il gioco.
	GameState.current = null
	GameState.current_slot = ""

	_check(GameState.continue_last(), "play riprende una partita")
	_check_eq(GameState.current_slot, slot, "riprende l'ULTIMA partita, non un'altra")
	var back := GameState.current
	if back == null:
		return
	_check_eq(back.cash, 4321, "soldi ripresi")
	_check(back.player_position.is_equal_approx(Vector2(1234, 567)), "posizione ripresa")
	_check_eq(back.current_room, "res://scenes/rooms/Kitchen.tscn", "stanza ripresa")
	_check_eq(int(back.properties["Minimarket"]["livello"]), 2, "proprietà riprese")
	_check_eq(back.chapter, "capitolo_uno", "punto della storia ripreso")
	_check(bool(back.get_flag("ha_conosciuto_milo")), "flag della storia ripresi")
	_check(back.has_seen_dialogue("milo_primo_incontro"), "dialoghi già visti ripresi")
	_check_eq(Economy.stock(back), 55, "merce ripresa")
	_check_eq(back.day, 6, "giorno ripreso")
	_check(is_equal_approx(back.time_of_day, 15.5), "ora ripresa")
	_check(not Grow.is_empty(back.plot(0)), "la pianta nel vaso c'è ancora")
	_check_eq(
		GameState.scene_for_current_state(), "res://scenes/rooms/Kitchen.tscn",
		"si riapre nella stanza in cui si era")

	# Salvare di nuovo deve aggiornare lo stesso slot, non crearne un altro.
	var before := GameState.list_saves().size()
	back.cash = 999
	GameState.save_game()
	_check_eq(GameState.list_saves().size(), before, "risalvare non crea un altro slot")
	GameState.current = null
	GameState.current_slot = ""
	GameState.continue_last()
	_check_eq(GameState.current.cash, 999, "il risalvataggio ha aggiornato lo slot giusto")

	# Uscendo in strada la stanza si azzera, e riprendendo si torna fuori.
	GameState.current.current_room = ""
	GameState.save_game()
	_check_eq(
		GameState.scene_for_current_state(), GameState.CITY_SCENE,
		"senza stanza si riprende in strada")

	# Un salvataggio che punta a una stanza cancellata non deve far schiantare.
	GameState.current.current_room = "res://scenes/rooms/Inesistente.tscn"
	_check_eq(
		GameState.scene_for_current_state(), GameState.CITY_SCENE,
		"una stanza sparita rimanda in strada invece di schiantare")

	# Il caso che rompeva davvero il tasto play, e che i controlli qui sopra non
	# vedevano perche' salvano tutto nello stesso secondo: la campagna
	# COMINCIATA prima ma GIOCATA per ultima.
	#
	# Il nome dello slot e' la data in cui la partita e' nata, `saved_at`
	# l'istante dell'ultimo salvataggio, e le due cose possono essere in ordine
	# opposto. Qui i due file sono scritti a mano proprio per poterli mettere in
	# ordine opposto: due ore di distanza, che e' poco in assoluto ma tantissimo
	# per un confronto sbagliato. Vedi `GameState.list_saves()`.
	_wipe_saves()
	var now := Time.get_unix_time_from_system()
	_write_fake_save("partita_20250101_120000", now, 111)
	_write_fake_save("partita_20260101_120000", now - 7200.0, 222)
	var listed := GameState.list_saves()
	_check_eq(listed.size(), 2, "i due salvataggi finti si leggono")
	if listed.size() == 2:
		_check_eq(
			str(listed[0]["slot_id"]), "partita_20250101_120000",
			"in cima c'e' la partita GIOCATA per ultima, non quella COMINCIATA per ultima")
	GameState.current = null
	GameState.current_slot = ""
	_check(GameState.continue_last(), "play riprende qualcosa")
	_check_eq(
		GameState.current_slot, "partita_20250101_120000",
		"e riprende proprio quella")
	if GameState.current != null:
		_check_eq(GameState.current.cash, 111, "con dentro la partita giusta")

func _test_day_rollover() -> void:
	var data := _fresh()
	data.heat = 40.0
	Economy.roll_new_day(data)
	_check(is_equal_approx(data.heat, 40.0 - Economy.HEAT_DECAY_PER_DAY), "di notte l'attenzione scende")
	var base := Economy.base_price(Economy.DEFAULT_STRAIN)
	_check(
		data.market_price >= int(float(base) * (1.0 - Economy.PRICE_SWING))
			and data.market_price <= int(ceil(float(base) * (1.0 + Economy.PRICE_SWING))),
		"il prezzo del giorno resta nella forchetta")
	data.heat = 3.0
	Economy.roll_new_day(data)
	_check_eq(data.heat, 0.0, "l'attenzione non va sotto zero")

# ---------------------------------------------------------------------------

## La tabella della luce.
##
## Sono funzioni pure dell'ora, quindi si provano senza scena e senza aspettare:
## e' lo stesso motivo per cui si provano cosi' la coltivazione e l'economia.
func _test_daylight() -> void:
	# Il giro si deve chiudere a mezzanotte. Un salto di colore fra le 23:59 e
	# le 00:01 sarebbe uno sfarfallio a schermo tutte le notti.
	var before := Daylight.air(23.99)
	var after := Daylight.air(0.01)
	_check(
		absf(before.r - after.r) < 0.02 and absf(before.b - after.b) < 0.02,
		"a mezzanotte il colore non salta")

	# Mai al buio pesto: vedi il commento su KEYFRAMES.
	var darkest := 1.0
	var hour := 0.0
	while hour < 24.0:
		var air := Daylight.air(hour)
		darkest = minf(darkest, (air.r + air.g + air.b) / 3.0)
		hour += 0.1
	_check(darkest > 0.25, "nemmeno di notte la citta' diventa illeggibile")

	_check(
		Daylight.air(13.0).g > Daylight.air(1.0).g,
		"a mezzogiorno c'e' piu' luce che all'una di notte")
	_check_eq(Daylight.sun_height(3.0), 0.0, "di notte il sole e' sotto l'orizzonte")
	_check(Daylight.sun_height(13.0) > 0.9, "a mezzogiorno il sole e' alto")
	_check(
		Daylight.sun_height(12.5) > Daylight.sun_height(7.5),
		"a mezzogiorno e' piu' alto che alle sette e mezza")

	var data := _fresh()
	data.weather = "clear"
	data.time_of_day = 2.0
	_check(Daylight.lamps_on(data), "di notte i lampioni sono accesi")
	data.time_of_day = 13.0
	_check(not Daylight.lamps_on(data), "a mezzogiorno sono spenti")
	# Col brutto tempo si accendono anche di giorno: e' quello che fa capire che
	# il tempo e' cambiato anche senza guardare la pioggia.
	data.weather = "storm"
	_check(Daylight.lamps_on(data), "sotto il temporale si accendono anche di giorno")

	# L'ombra gira: la mattina cade da una parte, il pomeriggio dall'altra.
	data.weather = "clear"
	data.time_of_day = 8.0
	var morning := Daylight.shadow(data)
	data.time_of_day = 18.0
	var evening := Daylight.shadow(data)
	var morning_dir: Vector2 = morning["direction"]
	var evening_dir: Vector2 = evening["direction"]
	_check(morning_dir.x * evening_dir.x < 0.0, "l'ombra gira da una parte all'altra col sole")
	_check(morning_dir.y > 0.0 and evening_dir.y > 0.0, "ma cade sempre verso chi guarda")

	# E si accorcia col sole alto: e' la cosa che fa leggere l'ora guardando
	# la strada invece dell'orologio dell'HUD.
	data.time_of_day = 13.0
	var noon := Daylight.shadow(data)
	_check(float(noon["length"]) < float(morning["length"]), "a mezzogiorno l'ombra e' piu' corta")

	# Col cielo coperto le ombre portate spariscono e resta il velo di contatto.
	var sunny := float(noon["alpha"])
	data.weather = "overcast"
	var dull := float(Daylight.shadow(data)["alpha"])
	_check(dull < sunny, "col coperto l'ombra sbiadisce")
	_check(dull > 0.0, "ma resta il contatto con il terreno")

	# Il giro che fa ogni cosa accesa: divisa per la luce, poi moltiplicata dal
	# `CanvasModulate`, deve tornare il colore di partenza.
	var ambient := Color(0.3, 0.33, 0.55)
	var lit := Color(1.0, 0.84, 0.5, 0.7)
	var compensated := Daylight.emissive(lit, ambient)
	_check(
		is_equal_approx(compensated.r * ambient.r, lit.r)
			and is_equal_approx(compensated.g * ambient.g, lit.g),
		"il colore compensato torna dov'era una volta moltiplicato")
	_check_eq(compensated.a, lit.a, "e l'opacita' non viene toccata")
	# Col buio pesto il tetto deve reggere, o un lampione diventa una macchia.
	var extreme := Daylight.emissive(Color.WHITE, Color(0.001, 0.001, 0.001))
	_check(extreme.r <= Daylight.EMISSIVE_CEILING, "il tetto regge anche col buio pesto")

# ---------------------------------------------------------------------------

## Il meteo: la tabella, il tiro del giorno nuovo, e quanto pesa in partita.
## La giornata dell'aeroporto e' una funzione dell'ora (`AirportPlan.pose()`):
## si controlla che il copione torni da tutte e due le parti — com'e' la
## mattina, com'e' la sera — e che in mezzo nessun mezzo salti da un punto
## all'altro, che e' quello che succede quando due tratti non si attaccano.
func _test_airport() -> void:
	var before := AirportPlan.START_HOUR - 1.0
	var after := AirportPlan.hour_at(AirportPlan.duration() + 1.0)
	_check(not bool(AirportPlan.pose("jet", before)["visible"]), "la mattina l'aereo di linea non c'e' ancora")
	_check(bool(AirportPlan.pose("twin", before)["visible"]), "la mattina il bimotore e' al suo posto")
	var jet := AirportPlan.pose("jet", after)
	_check(bool(jet["visible"]) and (jet["pos"] as Vector2).distance_to(AirportPlan.JET_STAND) < 1.0,
		"la sera l'aereo di linea e' fermo davanti all'hangar")
	_check(not bool(AirportPlan.pose("twin", after)["visible"]), "la sera il bimotore e' partito")
	var stairs := AirportPlan.pose("stairs", after)
	_check_eq(int(stairs["frame"]), AirportPlan.STAIRS_FRAMES - 1, "la sera la scala e' alzata")
	# Il bimotore esce davvero dalla mappa, e non svanisce in vista.
	var last := AirportPlan.pose("twin", AirportPlan.hour_at(AirportPlan.duration() - 0.05))
	_check(not CityMap.view_bounds().has_point(last["pos"]), "il bimotore finisce fuori dalla vista")
	# Nessun salto: un quarto di secondo alla volta, di quanto si muove ognuno.
	var jumps: Array = []
	for actor in AirportPlan.ACTORS:
		var prev: Vector2 = AirportPlan.pose(actor, AirportPlan.hour_at(0.0))["pos"]
		var t := 0.25
		while t <= AirportPlan.duration():
			var pos: Vector2 = AirportPlan.pose(actor, AirportPlan.hour_at(t))["pos"]
			if pos.distance_to(prev) > 120.0:
				jumps.append("%s a %.2f s: %.0f px" % [actor, t, pos.distance_to(prev)])
				break
			prev = pos
			t += 0.25
	_check_empty(jumps, "nessun mezzo dell'aeroporto salta da un punto all'altro")
	# La notte si torna alla mattina: dopo il cambio, tutto e' come prima.
	for actor in AirportPlan.ACTORS:
		var morning := AirportPlan.pose(actor, before)
		var dawn := AirportPlan.pose(actor, AirportPlan.RESET_TO + 0.01)
		_check(bool(morning["visible"]) == bool(dawn["visible"])
			and (morning["pos"] as Vector2).distance_to(dawn["pos"]) < 1.0,
			"dopo la notte %s e' di nuovo al posto della mattina" % actor)
	# Gli aerei fermi stanno dentro all'aeroporto.
	var outside: Array = []
	for entry in AirportPlan.PARKED:
		if not CityMap.AIRPORT.has_point(entry[1]):
			outside.append(entry[0])
	_check_empty(outside, "gli aerei parcheggiati stanno dentro all'aeroporto")

func _test_weather() -> void:
	_check_empty(Weather.problems(), "la tabella del meteo e' completa")

	# Il tiro non deve mai restituire un tempo che non esiste: una chiave
	# sbagliata non schianta, ricade sul sereno, ed e' l'errore che non si vede.
	var bad: Array = []
	for start in Weather.TYPES:
		for i in 60:
			var next := Weather.roll(str(start))
			if not Weather.TYPES.has(next):
				bad.append("da %s si finisce su %s" % [start, next])
				break
	_check_empty(bad, "il tiro resta dentro alla tabella")
	# Anche partendo da una chiave che non esiste — un salvataggio scritto con
	# una tabella diversa — deve venire fuori qualcosa di valido.
	_check(
		Weather.TYPES.has(Weather.roll("un_tempo_che_non_esiste")),
		"un tempo sconosciuto non blocca il tiro")

	# I passaggi devono avere una direzione: dal temporale non si torna al sole
	# piu' facilmente di quanto ci si torni dal nuvoloso.
	_check(
		int(Weather.TRANSITIONS["storm"].get("clear", 0))
			< int(Weather.TRANSITIONS["clouds"].get("clear", 0)),
		"il tempo si schiarisce per gradi, non di colpo")

	var data := _fresh()
	data.add_item(Economy.PRODUCT, 400)

	# Il punto di tutto: sotto la pioggia si vende meno, ma ci si fa notare meno.
	data.weather = "clear"
	var sunny_demand := Economy.street_demand("tony", data.day, "clear")
	var sunny_heat := Economy.street_heat(data)
	data.weather = "rain"
	var wet_demand := Economy.street_demand("tony", data.day, "rain")
	var wet_heat := Economy.street_heat(data)
	_check(wet_demand < sunny_demand, "sotto la pioggia i clienti comprano meno")
	_check(wet_heat < sunny_heat, "ma ci si fa notare meno")
	_check(wet_demand >= 1, "nemmeno col tempo peggiore la domanda si azzera")

	# E quello che conta davvero: la differenza si vede nell'incasso.
	data.weather = "clear"
	data.npc_state.clear()
	var sunny_take := Economy.sell_street(data, "tony", 999)
	data.weather = "rain"
	data.npc_state.clear()
	var wet_take := Economy.sell_street(data, "tony", 999)
	_check(wet_take < sunny_take, "una giornata di pioggia incassa meno di una di sole")

	# Mezzanotte tira il tempo nuovo insieme al prezzo.
	var seen := {}
	var invalid: Array = []
	for i in 40:
		Economy.roll_new_day(data)
		seen[data.weather] = true
		if not Weather.TYPES.has(data.weather):
			invalid.append(data.weather)
	_check_empty(invalid, "a mezzanotte esce sempre un tempo valido")
	_check(seen.size() > 1, "in quaranta giorni il tempo cambia almeno una volta")

	# `Weather.of()` deve reggere il caso in cui non c'e' nessuna partita: e' il
	# menu principale, ed e' il primo posto in cui gira questo codice.
	_check_eq(Weather.of(null), Weather.DEFAULT, "senza partita vale il tempo di ripiego")
	data.weather = "questo_non_esiste"
	_check_eq(Weather.of(data), Weather.DEFAULT, "e anche con un tempo sconosciuto nel salvataggio")

# ---------------------------------------------------------------------------

## Il recupero del tempo passato a gioco chiuso.
##
## Gira senza aspettare niente: `Offline.catch_up()` prende i secondi veri come
## parametro invece di leggere l'orologio del sistema, apposta perche' si possa
## provare una notte intera in un millisecondo. E' lo stesso motivo per cui il
## ritmo dell'orologio glielo passa chi chiama.
func _test_offline() -> void:
	const RATE := 4.0  # minuti di gioco per secondo vero, come in GameState
	const HOUR := 3600.0

	# --- Sotto al minuto non succede niente --------------------------------
	var data := _fresh()
	var before_day := data.day
	var quick := Offline.catch_up(data, 30.0, RATE)
	_check(not Offline.happened(quick), "riaprire subito non fa scattare il recupero")
	_check_eq(data.day, before_day, "e non sposta l'orologio")

	# Un salvataggio nel futuro (orologio di sistema spostato indietro) deve
	# dare zero, non un numero negativo che farebbe camminare l'ora all'indietro.
	data.saved_at = Time.get_unix_time_from_system() + 10000.0
	_check_eq(
		Offline.away_seconds(data, Time.get_unix_time_from_system()), 0.0,
		"un salvataggio nel futuro non regala tempo")

	# --- L'orologio avanza per intero, senza nessuno sconto ----------------
	#
	# A 4 minuti di gioco al secondo, due minuti veri sono 480 minuti di gioco,
	# cioe' otto ore. A gioco spento il mondo e' lo stesso di quello a gioco
	# aperto: quelle otto ore si contano tutte.
	data = _fresh()
	data.time_of_day = 8.0
	data.day = 1
	var report := Offline.catch_up(data, 120.0, RATE)
	_check(Offline.happened(report), "due minuti veri fanno scattare il recupero")
	_check(
		is_equal_approx(float(report["game_hours"]), 8.0),
		"e valgono per intero le otto ore di gioco che valgono")
	_check(
		data.day == 1 and is_equal_approx(data.time_of_day, 16.0),
		"quindi l'orologio della partita arriva alle sedici, non a mezzogiorno")
	_check(
		not bool(report["capped"]),
		"e un'assenza che sta sotto al tetto non lo dice nemmeno")

	# --- Il tetto: sette giorni di gioco, e non uno di piu' ----------------
	#
	# Sotto al tetto ogni ora vera vale le ore di gioco che vale, senza tagli:
	# mezz'ora vera fa 120 ore di gioco, che stanno dentro ai sette giorni.
	data = _fresh()
	data.time_of_day = 8.0
	var long_away := Offline.catch_up(data, 0.5 * HOUR, RATE)
	_check(
		is_equal_approx(float(long_away["game_hours"]), 0.5 * HOUR * RATE / 60.0),
		"sotto al tetto l'assenza vale per intero")
	_check(not bool(long_away["capped"]), "e non e' tagliata")
	# Sopra, invece, si ferma li' per sempre: una settimana vera e un mese vero
	# devono dare la stessa identica settimana di gioco.
	var week := _fresh()
	week.time_of_day = 8.0
	var week_report := Offline.catch_up(week, 24.0 * 7.0 * HOUR, RATE)
	_check(
		is_equal_approx(float(week_report["game_hours"]), Offline.MAX_GAME_HOURS),
		"una settimana vera vale il tetto, sette giorni di gioco")
	_check(bool(week_report["capped"]), "e il resoconto dice che e' stata tagliata")
	var month := _fresh()
	month.time_of_day = 8.0
	var month_report := Offline.catch_up(month, 24.0 * 30.0 * HOUR, RATE)
	_check(
		is_equal_approx(
			float(month_report["game_hours"]), float(week_report["game_hours"])),
		"e un mese vero non vale niente di piu': oltre al tetto non si conta")
	_check(
		week.day == month.day and is_equal_approx(week.time_of_day, month.time_of_day),
		"quindi le due partite riaprono alla stessa ora dello stesso giorno")

	# --- Il personale lavora davvero ---------------------------------------
	data = _fresh()
	data.cash = 100000
	data.time_of_day = 8.0
	Staff.hire(data, "grower", GameState.total_hours())
	Staff.hire(data, "dealer", GameState.total_hours())
	data.staff_checked_at = 0.0
	data.time_of_day = 8.0
	data.day = 1
	data.staff_checked_at = 8.0
	# Semi in mano: senza, i coltivatori non hanno niente da piantare.
	data.add_item(Economy.seed_item(Economy.DEFAULT_STRAIN), 6)
	var cash_before := data.cash
	# Dodici minuti veri: le quarantotto ore di gioco che servono a vedere un
	# ciclo intero piu' mezzo.
	var worked := Offline.catch_up(data, 12.0 * 60.0, RATE)
	_check(int(worked["planted"]) > 0, "i coltivatori piantano mentre il gioco e' chiuso")
	_check(int(worked["grams"]) > 0, "e raccolgono")
	_check(int(worked["sold"]) > 0, "i dealer piazzano la merce")
	_check(int(worked["revenue"]) > 0, "e portano a casa dei soldi")
	_check(int(worked["wages"]) > 0, "le paghe delle mezzanotti attraversate sono state scalate")
	_check(data.cash != cash_before, "e il conto in banca se n'e' accorto")

	# --- Un passo solo non basta: il punto di tutto il file ----------------
	#
	# Un vaso completa un ciclo in 29 ore di gioco. In 40 ore ne fa uno e mezzo,
	# quindi un coltivatore deve raccogliere E ripiantare. Saltando l'orologio
	# in un colpo e chiamando `Staff.work()` una volta sola se ne raccoglierebbe
	# uno e basta, e chi lascia il gioco aperto guadagnerebbe piu' di chi lo
	# chiude per lo stesso tempo.
	var stepped := _fresh()
	stepped.cash = 100000
	stepped.time_of_day = 0.0
	stepped.day = 1
	Staff.hire(stepped, "grower", 0.0)
	stepped.staff_checked_at = 0.0
	stepped.add_item(Economy.seed_item(Economy.DEFAULT_STRAIN), 8)
	# Un quarto d'ora vero: sessanta ore di gioco, sopra a un ciclo e mezzo di
	# 29 ore.
	var tended_pots := mini(Staff.POTS_PER_GROWER, stepped.plots.size())
	var many := Offline.catch_up(stepped, 15.0 * 60.0, RATE)
	_check(
		int(many["planted"]) > tended_pots,
		"in due giornate di gioco i vasi vengono ripiantati, non seminati una volta sola")

	# --- Finiti i semi, la produzione si ferma da sola ----------------------
	var seedless := _fresh()
	seedless.cash = 100000
	seedless.time_of_day = 8.0
	Staff.hire(seedless, "grower", GameState.total_hours())
	seedless.staff_checked_at = 8.0
	seedless.day = 1
	seedless.time_of_day = 8.0
	seedless.inventory.erase(Economy.seed_item(Economy.DEFAULT_STRAIN))
	var dry_run := Offline.catch_up(seedless, 12.0 * 60.0, RATE)
	_check_eq(int(dry_run["planted"]), 0, "senza semi non si pianta niente")
	_check(int(dry_run["idle"]) > 0, "e il resoconto dice perche' i vasi sono fermi")
	_check_eq(
		Economy.seeds_owned(seedless), 0,
		"a gioco chiuso i semi non si comprano da soli")

	# --- Senza personale scorre solo l'orologio ----------------------------
	var alone := _fresh()
	alone.time_of_day = 8.0
	alone.day = 1
	var stock_before := Economy.stock(alone)
	var idle := Offline.catch_up(alone, 12.0 * 60.0, RATE)
	_check_eq(int(idle["revenue"]), 0, "senza personale non entra un soldo")
	_check_eq(Economy.stock(alone), stock_before, "e la merce resta dov'era")
	_check(is_equal_approx(alone.time_of_day, 0.0) or alone.day > 1, "ma l'orologio e' andato avanti")
	# Il segnaposto del personale deve seguire l'orologio anche senza nessuno
	# assunto, o il primo assunto si troverebbe addosso tutte quelle ore.
	_check(
		is_equal_approx(alone.staff_checked_at, float(alone.day - 1) * 24.0 + alone.time_of_day),
		"il segnaposto del personale segue l'orologio")

	# --- L'appuntamento con Brian scorre anche a gioco chiuso --------------
	var meeting := _fresh()
	meeting.day = 1
	meeting.time_of_day = 8.0
	SeedDeal.ask(meeting, 8.0)
	# Piu' della finestra dell'incontro: Brian non aspetta in pausa.
	var missed := Offline.catch_up(meeting, 24.0 * 60.0, RATE)
	_check_eq(str(missed["deal"]), "gone", "un appuntamento lasciato in sospeso scade")
	_check(not SeedDeal.is_active(meeting), "e l'appuntamento viene chiuso")

	# --- Le piante hanno sete ----------------------------------------------
	var thirsty := _fresh()
	thirsty.day = 1
	thirsty.time_of_day = 8.0
	Grow.plant(thirsty.plot(0), Economy.DEFAULT_STRAIN, GameState.total_hours())
	var quality_before := Grow.quality(thirsty.plot(0))
	var neglected := Offline.catch_up(thirsty, 12.0 * 60.0, RATE)
	Grow.sync(thirsty.plot(0), float(thirsty.day - 1) * 24.0 + thirsty.time_of_day)
	_check(int(neglected["thirsty"]) > 0, "i vasi che nessuno segue restano a secco")
	_check(
		Grow.quality(thirsty.plot(0)) < quality_before,
		"e la sete si porta via un pezzo di resa, come a gioco aperto")
	_check(
		Grow.quality(thirsty.plot(0)) >= Grow.MIN_QUALITY,
		"ma non sotto al minimo: una notte via non azzera un raccolto")

	# --- Chi spegne il mondo offline riapre dove aveva lasciato ------------
	#
	# Qui si passa da `GameState`, e non da `Offline`, perche' la scelta e' un
	# collegamento e non un pezzo del conto: `catch_up()` non sa nemmeno che
	# esiste. Si prova quello che il giocatore vede — riaprire la partita.
	var was_offline := GameSettings.offline_progress
	_wipe_saves()
	_fresh()
	GameState.current.day = 3
	GameState.current.time_of_day = 21.0
	GameState.save_game()
	var slot := GameState.current_slot
	# Un salvataggio di ieri. `save_game()` riscrive sempre `saved_at` con
	# adesso, quindi la data si mette a mano nel file: e' l'unico modo di
	# fingere un'assenza senza aspettarla davvero.
	var path := GameState.save_dir.path_join(slot + GameState.EXTENSION)
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Dictionary = JSON.parse_string(raw)
	parsed["saved_at"] = Time.get_unix_time_from_system() - 24.0 * HOUR
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()

	GameSettings.offline_progress = false
	GameState.current = null
	GameState.current_slot = ""
	_check(GameState.load_slot(slot), "la partita si ricarica")
	_check(
		GameState.current.day == 3 and is_equal_approx(GameState.current.time_of_day, 21.0),
		"col mondo offline spento si riapre all'ora in cui si era chiuso")

	# E riaccendendolo NON si recupera anche il tempo saltato: il salvataggio
	# appena fatto ha riscritto `saved_at`, quindi l'assenza riparte da adesso.
	GameSettings.offline_progress = true
	GameState.save_game()
	GameState.current = null
	GameState.current_slot = ""
	_check(GameState.load_slot(slot), "e si ricarica di nuovo")
	_check(
		GameState.current.day == 3 and is_equal_approx(GameState.current.time_of_day, 21.0),
		"riaccendendolo il tempo saltato non torna indietro a presentare il conto")
	GameSettings.offline_progress = was_offline
	_wipe_saves()

# ---------------------------------------------------------------------------

## In collina la stessa roba si paga di piu'.
func _test_district_price() -> void:
	# Le due tabelle devono essere d'accordo: un nome di quartiere scritto male
	# passerebbe in silenzio come "nessun aumento", ed e' il tipo di errore che
	# non si nota mai perche' non rompe niente.
	var unknown: Array = []
	for key in Economy.DISTRICT_PRICE:
		var found := false
		for district: Dictionary in CityMap.DISTRICTS:
			if str(district["name"]) == str(key):
				found = true
				break
		if not found:
			unknown.append(str(key))
	_check_empty(unknown, "i quartieri col prezzo maggiorato esistono sulla mappa")

	var data := _fresh()
	# Un prezzo tondo e alto: cosi' l'arrotondamento agli interi non sporca il
	# confronto fra le due cifre.
	data.market_price = 100
	var base := Economy.retail_price(data)
	var uptown := Economy.retail_price(data, "HILLSIDE")
	_check(uptown > base, "in collina il prezzo e' piu' alto")
	_check(
		absf(float(uptown) / float(base) - Economy.district_price("HILLSIDE")) < 0.01,
		"ed e' la maggiorazione della tabella")
	_check_eq(
		Economy.retail_price(data, "THE FLATS"), base,
		"in un quartiere qualunque si paga il prezzo di strada")
	_check_eq(
		Economy.retail_price(data, "un quartiere che non esiste"), base,
		"e un quartiere sconosciuto non regala niente")

	# Il punto: la stessa vendita in collina incassa di piu'.
	data.add_item(Economy.PRODUCT, 400)
	var here := Economy.sell_street(data, "tony", 10)
	data.npc_state.clear()
	var there := Economy.sell_street(data, "tony", 10, "HILLSIDE")
	_check(there > here, "dieci grammi in collina rendono piu' che sotto casa")

	# Il personale non ha una posizione sulla mappa, quindi prende il prezzo
	# base: andarci di persona e' l'unica cosa che quel dieci per cento lo porta
	# a casa. E' una differenza voluta, non una dimenticanza.
	data.npc_state.clear()
	_check_eq(
		Economy.sell_street(data, "tony", 10), here,
		"senza quartiere si torna al prezzo base")

# ---------------------------------------------------------------------------

## La bolletta della luce: una spesa che arriva al mese, non ogni notte.
func _test_power_bill() -> void:
	var data := _fresh()
	data.cash = 100000

	_check_eq(Economy.power_bill(data), Economy.POWER_BASE, "a cantina spenta si paga la quota fissa")
	Shop.buy(data, "lamps")
	Shop.buy(data, "lamps")
	_check_eq(
		Economy.power_bill(data), Economy.POWER_BASE + 2 * Economy.POWER_PER_LAMP,
		"ogni lampada accesa aggiunge la sua quota")

	# Prima della scadenza non si paga niente.
	data.cash = 5000
	var early := Economy.charge_power(data)
	_check_eq(int(early["due"]), 0, "il primo giorno non c'e' niente da pagare")
	_check_eq(data.cash, 5000, "e la cassa non si tocca")
	_check_eq(Economy.days_to_bill(data), Economy.BILL_DAYS, "mancano trenta giorni")

	# A scadenza si paga.
	data.day += Economy.BILL_DAYS
	var due := Economy.power_bill(data)
	var bill := Economy.charge_power(data)
	_check_eq(int(bill["due"]), due, "dopo un mese arriva la bolletta")
	_check_eq(int(bill["paid"]), due, "e si paga tutta")
	_check_eq(data.cash, 5000 - due, "la cassa cala di quello che era dovuto")
	# Due volte lo stesso giorno non si paga: il conto riparte da quando e'
	# scaduta, non da oggi.
	_check_eq(int(Economy.charge_power(data)["due"]), 0, "non arriva due volte lo stesso mese")

	# Cassa a secco: si paga quello che c'e', e non si va sotto zero.
	data.day += Economy.BILL_DAYS
	data.cash = 30
	var short_bill := Economy.charge_power(data)
	_check(int(short_bill["due"]) > int(short_bill["paid"]), "a cassa vuota la bolletta resta scoperta")
	_check_eq(int(short_bill["paid"]), 30, "si paga quello che c'era")
	_check_eq(data.cash, 0, "e la cassa non va sotto zero")

	# Attraversando piu' mesi in un colpo solo — il recupero del tempo a gioco
	# chiuso — non se ne deve saltare nessuno.
	var away := _fresh()
	away.cash = 100000
	away.day = 1
	away.time_of_day = 8.0
	var before := away.cash
	for i in Economy.BILL_DAYS * 2:
		away.day += 1
		Economy.charge_power(away)
	_check_eq(
		before - away.cash, Economy.POWER_BASE * 2,
		"in sessanta giorni arrivano due bollette, non una e non tre")

	# Comprare un posto lo si paga anche dopo, ogni mese, a vasi vuoti.
	var owner := _fresh()
	owner.cash = 100000
	var empty := Economy.power_bill(owner)
	owner.properties["Garage"] = {"livello": 1, "acquisito_il": owner.day, "tassato_il": owner.day}
	_check_eq(
		Economy.power_bill(owner), empty + RealEstate.power_draw("Garage"),
		"una proprieta' in piu' alza la bolletta anche senza lampade")

# ---------------------------------------------------------------------------

## La tassa sulla proprieta': una volta l'anno, l'1% di quello che e' costata.
func _test_property_tax() -> void:
	var data := _fresh()
	data.cash = 100000

	_check_eq(int(Economy.charge_property_tax(data)["due"]), 0, "senza proprieta' non si paga niente")
	_check_eq(Economy.days_to_tax(data), -1, "e non c'e' nessuna scadenza in vista")

	data.properties["Garage"] = {"livello": 1, "acquisito_il": data.day, "tassato_il": data.day}
	var due := int(roundf(float(RealEstate.price("Garage")) * Economy.TAX_RATE))
	_check_eq(Economy.property_tax("Garage"), due, "la tassa e' l'uno per cento del prezzo")
	_check_eq(Economy.yearly_tax(data), due, "e all'anno si paga quella")
	_check_eq(Economy.days_to_tax(data), Economy.TAX_DAYS, "la prima scade fra un anno")

	# Prima dell'anniversario non si tocca niente.
	data.day += Economy.TAX_DAYS - 1
	_check_eq(int(Economy.charge_property_tax(data)["due"]), 0, "un giorno prima non scade")
	_check_eq(data.cash, 100000, "e la cassa resta intatta")

	# All'anniversario si paga.
	data.day += 1
	var charged := Economy.charge_property_tax(data)
	_check_eq(int(charged["due"]), due, "dopo un anno arriva la tassa")
	_check_eq(int(charged["paid"]), due, "e si paga tutta")
	_check_eq(data.cash, 100000 - due, "la cassa cala di quello che era dovuto")
	_check_eq(int(Economy.charge_property_tax(data)["due"]), 0, "non arriva due volte lo stesso anno")

	# Cassa a secco: si paga quello che c'e' e non si va sotto zero.
	data.day += Economy.TAX_DAYS
	data.cash = 12
	var short_tax := Economy.charge_property_tax(data)
	_check(int(short_tax["due"]) > int(short_tax["paid"]), "a cassa vuota la tassa resta scoperta")
	_check_eq(data.cash, 0, "e la cassa non va sotto zero")

	# Piu' anni in un colpo solo — il tempo a gioco chiuso — sono piu' tasse.
	var away := _fresh()
	away.cash = 100000
	away.properties["Garage"] = {"livello": 1, "acquisito_il": away.day, "tassato_il": away.day}
	away.day += Economy.TAX_DAYS * 3
	_check_eq(
		int(Economy.charge_property_tax(away)["due"]), due * 3,
		"tre anni di assenza sono tre tasse, non una")

	# Un salvataggio vecchio non ha `tassato_il`: l'anno si conta dal rogito, e
	# non si trova ne' un arretrato inventato ne' un anno regalato.
	var old_save := _fresh()
	old_save.cash = 100000
	old_save.properties["Garage"] = {"livello": 1, "acquisito_il": old_save.day}
	old_save.day += Economy.TAX_DAYS
	_check_eq(
		int(Economy.charge_property_tax(old_save)["due"]), due,
		"una partita di prima delle tasse paga un anno solo")

# ---------------------------------------------------------------------------

## I messaggi che arrivano sul telefono.
##
## La parte che puo' sbagliare in silenzio e' QUANDO parte l'avviso: un avviso
## che si ripete a ogni frame riempirebbe lo schermo, uno che non riparte mai
## lascerebbe il giocatore senza semi e senza nessuno che glielo dice.
func _test_phone_alerts() -> void:
	var data := _fresh()

	# Con i semi in mano non c'e' niente da dire, nemmeno con dei vasi fermi.
	_check_eq(
		Staff.seedless_alert(data, 3), false,
		"finche' ci sono semi il personale non avvisa")

	# Semi finiti ma nessun vaso fermo: il lavoro sta andando avanti lo stesso,
	# non c'e' niente da segnalare.
	data.inventory.erase(Economy.seed_item(Economy.DEFAULT_STRAIN))
	_check_eq(
		Staff.seedless_alert(data, 0), false,
		"senza vasi fermi non si avvisa, anche a semi zero")

	# Semi finiti E vasi fermi: si avvisa, UNA volta sola.
	_check_eq(Staff.seedless_alert(data, 2), true, "semi finiti e vasi fermi: si avvisa")
	_check_eq(Staff.seedless_alert(data, 2), false, "ma una volta sola, non a ogni giro")
	for i in 20:
		_check_eq(Staff.seedless_alert(data, 2), false, "e nemmeno insistendo")

	# Il flag sta nel salvataggio: riaprire la partita non fa ripartire
	# l'avviso da capo.
	var reloaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	_check_eq(
		Staff.seedless_alert(reloaded, 2), false,
		"ricaricando la partita l'avviso non si ripete")

	# Arrivano altri semi: il permesso torna, e alla prossima secca si riavvisa.
	data.add_item(Economy.seed_item(Economy.DEFAULT_STRAIN), 4)
	_check_eq(Staff.seedless_alert(data, 2), false, "coi semi in mano si sta zitti")
	data.inventory.erase(Economy.seed_item(Economy.DEFAULT_STRAIN))
	_check_eq(
		Staff.seedless_alert(data, 2), true,
		"finiti di nuovo, si avvisa di nuovo")

	# Il recupero del tempo a gioco chiuso lo dice nel suo resoconto
	# (`AWAY_IDLE`), quindi segna il flag: il telefono non deve ripetere un
	# attimo dopo una notizia che il giocatore ha appena letto.
	var away := _fresh()
	away.cash = 100000
	away.day = 1
	away.time_of_day = 8.0
	Staff.hire(away, "grower", 0.0)
	away.staff_checked_at = 8.0
	away.inventory.erase(Economy.seed_item(Economy.DEFAULT_STRAIN))
	var report := Offline.catch_up(away, 12.0 * 60.0, 4.0)
	if int(report["idle"]) > 0:
		_check_eq(
			Staff.seedless_alert(away, int(report["idle"])), false,
			"quello che ha gia' detto il resoconto non lo ripete il telefono")

	# `GameState.text_message()` tiene l'ultimo messaggio, cosi' il telefono lo
	# ritrova cambiando stanza.
	GameState.text_message("BRIAN", "MAIN STREET AT MILL ROAD")
	_check_eq(str(GameState.last_text.get("sender", "")), "BRIAN", "il mittente resta")
	_check_eq(
		str(GameState.last_text.get("body", "")), "MAIN STREET AT MILL ROAD",
		"e anche il testo")

# ---------------------------------------------------------------------------

## La chat del telefono.
##
## La cosa che puo' sbagliare in silenzio e' **quali messaggi restano**: i
## traguardi devono ritrovarsi anche dopo giorni, mentre il giro della richiesta
## di semi deve sparire da solo appena l'appuntamento si chiude. Nessuna delle
## due si vede finche' non si apre il telefono, e la seconda si scoprirebbe solo
## trovandosi la chat piena di richieste vecchie tutte uguali.
func _test_chat() -> void:
	var data := _fresh()
	var now := GameState.total_hours()

	_check(Chat.thread(data, Chat.BRIAN, now).is_empty(), "si parte senza messaggi")

	# --- Quelli che restano -------------------------------------------------
	Chat.keep(data, Chat.BRIAN, "MSG_INTRO_BODY", "", 1.0)
	Chat.keep(data, Chat.BRIAN, "MSG_COUSIN_BODY", "", 20.0)
	_check_eq(Chat.thread(data, Chat.BRIAN, now).size(), 2, "i traguardi restano")
	# Dentro ci sono chiavi, non frasi: e' quello che fa cambiare lingua anche
	# ai messaggi vecchi.
	_check_eq(
		str(data.chat_log[0]["key"]), "MSG_INTRO_BODY",
		"in cronologia c'e' la chiave, non la frase gia' scritta")

	var reloaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	_check_eq(
		Chat.thread(reloaded, Chat.BRIAN, now).size(), 2,
		"e si ritrovano ricaricando la partita")
	_check_eq(
		float(reloaded.chat_log[1]["at"]), 20.0,
		"con l'ora di gioco intatta, che serve a metterli in fila")

	# --- Quelli che non restano ---------------------------------------------
	_check(SeedDeal.ask(data, 30.0), "si chiedono i semi")
	# Appena chiesto si vede partire la richiesta e nient'altro: la risposta
	# arriva dopo `REPLY_GAP`, altrimenti comparirebbero insieme.
	var asking := Chat.thread(data, Chat.BRIAN, 30.0)
	_check_eq(asking.size(), 3, "la richiesta compare subito")
	_check(Chat.is_mine(asking[-1]), "ed e' l'unica riga scritta dal giocatore")
	_check_eq(
		Chat.thread(data, Chat.BRIAN, 30.0 + Chat.REPLY_GAP).size(), 4,
		"e un attimo dopo risponde")

	# Arrivata la posizione, il posto e' dentro al messaggio.
	SeedDeal.tick(data, 30.0 + SeedDeal.WAIT_HOURS.y)
	_check(SeedDeal.is_ready(data), "la posizione arriva")
	var ready_thread := Chat.thread(data, Chat.BRIAN, 40.0)
	_check_eq(ready_thread.size(), 5, "e si aggiunge al filo")
	_check(
		Chat.body(ready_thread[-1]).contains(SeedDeal.place(data)),
		"col posto scritto dentro")

	# --- E qui quelli che non restano se ne vanno da soli --------------------
	SeedDeal.clear(data)
	_check_eq(
		Chat.thread(data, Chat.BRIAN, 40.0).size(), 2,
		"chiuso l'appuntamento resta solo la cronologia")

	# --- L'autista in rubrica ------------------------------------------------
	# Il contatto non c'e' finche' non lo si assume: una chat con uno che non
	# lavora per te e' un contatto che non risponde mai.
	var rubrica := Chat.contacts(data)
	_check_eq(rubrica.size(), 1, "in rubrica c'e' il solo Brian")
	data.upgrades["van"] = 1
	data.cash = Staff.hire_cost("driver")
	_check(Staff.hire(data, "driver", 50.0), "si assume l'autista")
	_check_eq(Chat.contacts(data).size(), 2, "e entra in rubrica")
	_check_eq(
		Chat.name_key(Chat.DRIVER), "MSG_DRIVER_SPEAKER",
		"col suo nome, che e' una chiave come tutti gli altri")
	# Si presenta lui, una volta sola: e' quel messaggio a far trovare la chat.
	_check(Staff.check_driver_hello(data), "assunto, scrive per primo")
	_check(not Staff.check_driver_hello(data), "ma una volta sola")

	# --- Il giro dei semi, che sparisce da solo ------------------------------
	_check(
		Chat.thread(data, Chat.DRIVER, 50.0).is_empty(),
		"fermo, la sua chat non ha niente da dire")
	data.cash = SeedRun.pack_price(SeedRun.PACKS[0])
	# Il grossista lo apre Brian col furgone, e qui il furgone e' arrivato di
	# soppiatto: senza il flag `order()` rifiuterebbe e il resto non proverebbe
	# niente.
	data.set_flag(SeedRun.UNLOCK_FLAG, true)
	_check(SeedRun.order(data, SeedRun.PACKS[0], 50.0) > 0, "lo si manda a prendere i semi")
	_check_eq(
		Chat.thread(data, Chat.DRIVER, 50.0).size(), 1,
		"l'ordine compare subito")
	var risposta := Chat.thread(data, Chat.DRIVER, 50.0 + Chat.REPLY_GAP)
	_check_eq(risposta.size(), 2, "e un attimo dopo risponde")
	_check(
		Chat.body(risposta[0]).contains(str(int(SeedRun.PACKS[0]["seeds"]))),
		"e nell'ordine c'e' scritto quanti semi")
	SeedRun.tick(data, 50.0 + SeedRun.TRIP_HOURS)
	_check(
		Chat.thread(data, Chat.DRIVER, 60.0).is_empty(),
		"rientrato, le due righe se ne vanno da sole")
	_check_eq(
		data.chat_log.size(), 2,
		"e nessuno ha dovuto cancellare niente: non erano salvate")

	# Dieci chiamate di fila non lasciano dietro dieci richieste identiche: e'
	# il motivo per cui il giro dei semi si ricava invece di scriverselo.
	for i in 10:
		SeedDeal.ask(data, 50.0 + float(i))
		SeedDeal.clear(data)
	_check_eq(
		Chat.thread(data, Chat.BRIAN, 70.0).size(), 2,
		"nemmeno dopo dieci chiamate")

	# --- L'ordine ------------------------------------------------------------
	# Un traguardo che scatta con un appuntamento gia' aperto va al suo posto,
	# non in fondo: le due liste si mescolano sull'ora, non si appiccicano.
	SeedDeal.ask(data, 80.0)
	Chat.keep(data, Chat.BRIAN, "MSG_KILO_BODY", "", 200.0)
	var mixed := Chat.thread(data, Chat.BRIAN, 300.0)
	_check_eq(
		str(mixed[-1]["key"]), "MSG_KILO_BODY",
		"i messaggi si mettono in fila per ora di gioco")

	# La rubrica risponde anche per chi non c'e': un contatto sconosciuto non
	# deve far scoppiare la schermata.
	_check(Chat.thread(data, "nessuno", 300.0).is_empty(), "un contatto che non c'e' non ha filo")
	_check_eq(Chat.name_key(Chat.BRIAN), "MSG_COUSIN_SPEAKER", "il nome del contatto e' una chiave")

	# --- La guida ------------------------------------------------------------
	# Una chiave che non c'e' non rompe niente e non avvisa: `tr()` restituisce
	# la chiave, e nella guida comparirebbe "GUIDE_HEAT_BODY" al posto di un
	# paragrafo. E' il motivo per cui l'elenco delle sezioni e' una tabella e
	# non del testo scritto dentro alla schermata.
	_check(not Guide.SECTIONS.is_empty(), "la guida ha delle sezioni")
	for key: String in Guide.keys():
		_check(Strings.TEXT.has(key), "la guida usa %s, che deve esistere" % key)

	# Il messaggio d'apertura manda alla guida: se qualcuno riscrive il
	# messaggio e si dimentica quella riga, il giocatore non la trova piu'.
	for i in Strings.LOCALES.size():
		var intro := str(Strings.TEXT["MSG_INTRO_BODY"][i]).to_lower()
		var name := str(Strings.TEXT["GUIDE_TITLE"][i]).to_lower()
		_check(
			intro.contains(name),
			"il messaggio d'apertura nomina la guida in %s" % Strings.LOCALES[i])

# ---------------------------------------------------------------------------

## L'ingrosso: lo sblocco, il furgone, il carburante e il viaggio.
func _test_delivery() -> void:
	var data := _fresh()

	# --- Dove sta in sosta --------------------------------------------------
	# Il posto va controllato qui e non a occhio: e' scritto come un numero
	# sommato allo zerbino, quindi spostare la casa o allargare MAIN STREET lo
	# manderebbe sul marciapiede o dentro a un muro senza che nessuno se ne
	# accorga fino a quando non si compra un furgone.
	#
	# Il controllo chiedeva che stesse "fra la casa e la carreggiata", entro 48
	# px dall'asfalto, ed era rimasto indietro: il furgone e' stato spostato dal
	# bordo della strada al vialetto — al bordo dell'asfalto sembrava un'auto
	# del traffico ferma li' (vedi `CityMap.van_parking()`) — e il controllo e'
	# rimasto quello di prima, rosso da allora. Un controllo rosso che tutti
	# sanno che e' rosso non controlla piu' niente. Adesso chiede quello che la
	# sosta deve davvero rispettare: fuori dalla strada, fuori dal marciapiede,
	# e nella striscia fra il muro del palazzo e il muro di casa.
	var parking := CityMap.van_parking()
	var main_street: Rect2 = CityMap.ROADS_H[0]
	_check(
		not main_street.has_point(parking),
		"in sosta il furgone non sta in mezzo alla strada")
	_check(
		parking.y < CityMap.SIDEWALK_N[0],
		"e nemmeno sul marciapiede dove cammina la gente")
	# La striscia e' ricavata dai due edifici e non scritta a mano: accostando
	# di nuovo casa e palazzo, o cambiando la larghezza di uno dei due disegni,
	# il vialetto si sposta e il furgone deve seguirlo.
	var muro_palazzo := 0.0
	var muro_casa := 0.0
	for entry in CityMap.BUILDINGS:
		var click: Rect2 = entry.get("click", Rect2())
		if str(entry["id"]) == "Condo":
			muro_palazzo = (entry["base"] as Vector2).x + click.end.x
		elif str(entry["id"]) == "FirstHouse":
			muro_casa = (entry["base"] as Vector2).x + click.position.x
	_check(
		parking.x > muro_palazzo and parking.x < muro_casa,
		"ma nel vialetto, fra il muro del palazzo e quello di casa")
	_check(
		parking.distance_to(CityMap.home_doorstep()) > 48.0,
		"non davanti alla porta, dove si esce e dove a volte aspetta Brian")
	_check(
		parking.distance_to(CityMap.home_doorstep()) < 200.0,
		"ed e' comunque a fianco di casa, non in fondo alla strada")
	_check(
		not is_equal_approx(CityMap.VAN_PARK_ANGLE, 0.0),
		"e in sosta e' girato verso la strada, non nel verso di marcia")

	# --- Chiuso in partenza -------------------------------------------------
	_check(not Delivery.is_unlocked(data), "a inizio partita l'ingrosso e' chiuso")
	_check(not Delivery.has_van(data), "e non c'e' nessun furgone")
	_check(not Delivery.can_dispatch(data), "quindi non si spedisce niente")
	_check_eq(
		Delivery.dispatch(data, 1000, 0.0), 0,
		"spedire a canale chiuso non fa niente")

	# --- Il chilo apre il canale, una volta sola ----------------------------
	data.add_item(Economy.PRODUCT, Delivery.UNLOCK_GRAMS - 1)
	_check(not Delivery.check_unlock(data), "sotto al chilo non si sblocca niente")
	data.add_item(Economy.PRODUCT, 1)
	_check(Delivery.check_unlock(data), "col chilo in mano si sblocca")
	_check(Delivery.is_unlocked(data), "e resta sbloccato")
	_check(not Delivery.check_unlock(data), "ma il messaggio scatta una volta sola")
	# Lo sblocco non si perde svuotando il magazzino: era un traguardo, non uno
	# stato del momento.
	data.inventory.erase(Economy.PRODUCT)
	_check(Delivery.is_unlocked(data), "svuotare il magazzino non richiude il canale")

	# --- Serve il furgone ---------------------------------------------------
	_check(not Delivery.can_dispatch(data), "sbloccato ma senza mezzo non si parte")
	data.cash = Shop.price(Delivery.VAN_ITEM)
	_check(Shop.buy(data, Delivery.VAN_ITEM), "si compra il furgone")
	_check_eq(
		Delivery.fuel(data), Delivery.TANK_RUNS,
		"e arriva col pieno fatto")

	# --- Il viaggio ---------------------------------------------------------
	data.add_item(Economy.PRODUCT, 3000)
	data.cash = 0
	var before_stock := Economy.stock(data)
	var price := Economy.wholesale_price(data)
	var sent := Delivery.dispatch(data, 2000, 10.0)
	_check_eq(sent, 2000, "parte il carico chiesto")
	_check_eq(Economy.stock(data), before_stock - 2000, "la merce parte subito")
	_check_eq(data.cash, 0, "ma i soldi non arrivano alla partenza")
	_check_eq(Delivery.load_value(data), 2000 * price, "il prezzo si fissa alla partenza")
	_check(Delivery.is_running(data), "il furgone e' fuori")
	_check(not Delivery.can_dispatch(data), "e non se ne manda un secondo")
	_check_eq(Delivery.fuel(data), Delivery.TANK_RUNS - 1, "il viaggio consuma una consegna")

	# Prima dell'ora non torna.
	_check_eq(Delivery.tick(data, 10.0), 0, "appena partito non e' gia' tornato")
	_check(Delivery.hours_left(data, 10.0) > 0.0, "e manca ancora del tempo")

	# All'ora torna, e paga.
	var back := 10.0 + Delivery.trip_hours(2000) + 0.01
	var revenue := Delivery.tick(data, back)
	_check_eq(revenue, 2000 * price, "al ritorno incassa il prezzo fissato")
	_check_eq(data.cash, revenue, "e i soldi arrivano in cassa")
	_check(not Delivery.is_running(data), "il furgone e' rientrato")
	_check_eq(Delivery.tick(data, back + 100.0), 0, "e non paga due volte")

	# Un prezzo che cambia mentre il furgone e' in viaggio non tocca l'accordo.
	data.add_item(Economy.PRODUCT, 2000)
	Delivery.dispatch(data, 1000, 100.0)
	var agreed := Delivery.load_value(data)
	data.market_price = Economy.wholesale_price(data) * 3
	_check_eq(
		Delivery.tick(data, 100.0 + Delivery.trip_hours(1000) + 0.01), agreed,
		"il prezzo del giorno che cambia non tocca un carico gia' partito")

	# --- Il carburante ------------------------------------------------------
	data.van_fuel = 0
	data.add_item(Economy.PRODUCT, 5000)
	_check(Delivery.needs_fuel(data), "a secco serve il pieno")
	_check(not Delivery.can_dispatch(data), "e non si parte")
	data.cash = Delivery.TANK_PRICE - 1
	_check(not Delivery.refuel(data), "senza i soldi non si fa il pieno")
	data.cash = Delivery.TANK_PRICE
	_check(Delivery.refuel(data), "coi soldi si")
	_check_eq(data.cash, 0, "e il pieno si paga")
	_check_eq(Delivery.fuel(data), Delivery.TANK_RUNS, "il serbatoio e' pieno")
	_check(not Delivery.refuel(data), "e un pieno sul pieno non si fa")

	# Dieci consegne con un pieno, non nove e non undici. Il magazzino si
	# ricarica a ogni giro: qui l'unica cosa che deve fermare il furgone e' la
	# benzina, non la merce.
	var runs := 0
	var clock := 200.0
	while Delivery.fuel(data) > 0 and runs < 50:
		data.add_item(Economy.PRODUCT, 1000)
		if Delivery.dispatch(data, 1000, clock) <= 0:
			break
		clock += Delivery.trip_hours(1000) + 0.01
		Delivery.tick(data, clock)
		runs += 1
	_check_eq(runs, Delivery.TANK_RUNS, "un pieno vale dieci consegne")

	# --- I tagli ------------------------------------------------------------
	var poor := _fresh()
	poor.set_flag(Delivery.UNLOCK_FLAG, true)
	poor.add_item(Economy.PRODUCT, 2500)
	_check_eq(Delivery.loads_for(poor), [1000, 2000], "si offrono solo i carichi che ci stanno")
	poor.inventory.erase(Economy.PRODUCT)
	_check(Delivery.loads_for(poor).is_empty(), "e a magazzino vuoto nessuno")

	# --- Il giro del salvataggio -------------------------------------------
	var saved := _fresh()
	saved.set_flag(Delivery.UNLOCK_FLAG, true)
	saved.cash = 100000
	Shop.buy(saved, Delivery.VAN_ITEM)
	saved.add_item(Economy.PRODUCT, 2000)
	Delivery.dispatch(saved, 1000, 12.5)
	var reloaded := SaveData.from_dict(JSON.parse_string(JSON.stringify(saved.to_dict())))
	_check(Delivery.is_running(reloaded), "il viaggio in corso si conserva")
	_check_eq(
		Delivery.load_value(reloaded), Delivery.load_value(saved),
		"con l'incasso pattuito")
	_check(
		is_equal_approx(
			float(reloaded.van_run["back_at"]), float(saved.van_run["back_at"])),
		"e l'ora del ritorno resta un float, non arrotondata")
	_check_eq(Delivery.fuel(reloaded), Delivery.fuel(saved), "il serbatoio si conserva")

## L'agenzia: gli annunci devono corrispondere a edifici che in citta' esistono
## davvero, e comprare deve togliere i soldi una volta sola.
##
## Il primo controllo e' il piu' importante e non e' ovvio: `RealEstate.LISTINGS`
## e `CityMap.BUILDINGS` sono due tabelle separate legate solo dall'id scritto a
## mano in tutte e due. Un refuso qui non da' nessun errore — si comprerebbe una
## proprieta' che in citta' non si vede, e ci si accorgerebbe andando a cercarla.
func _test_real_estate() -> void:
	var ids: Array = []
	for entry in CityMap.BUILDINGS:
		ids.append(str(entry["id"]))
	var orfani: Array = []
	for listing in RealEstate.all():
		if not RealEstate.building_of(listing) in ids:
			orfani.append(str(listing["id"]))
	_check_empty(orfani, "ogni annuncio ha il suo edificio sulla pianta")

	var data := SaveData.new()
	GameState.current = data
	data.cash = 40000
	_check(not data.owns("Garage"), "il garage non e' gia' tuo")
	_check(RealEstate.buy("Garage"), "si compra col contante che basta")
	_check(data.owns("Garage"), "dopo l'acquisto risulta tuo")
	_check_eq(data.cash, 5000, "il prezzo e' stato scalato una volta sola")
	_check(not RealEstate.buy("Garage"), "non si ricompra quello che si ha gia'")
	_check_eq(data.cash, 5000, "il secondo tentativo non tocca il contante")

	data.properties.erase("Garage")
	data.cash = 100
	_check(not RealEstate.buy("Garage"), "senza soldi non si compra")
	_check_eq(data.cash, 100, "un acquisto fallito non scala niente")
	_check(not data.owns("Garage"), "un acquisto fallito non segna la proprieta'")

	# Comprare una proprieta' vuol dire poterci entrare, e il collegamento fra
	# le due cose e' solo l'id: una porta che resta chiusa dopo l'acquisto non
	# darebbe nessun errore, si limiterebbe a non aprirsi. Si prova su ogni
	# annuncio e non solo sul garage, cosi' la proprieta' che verra' dopo e'
	# davvero una riga di dati e basta.
	var senza_porta: Array = []
	var chiuse: Array = []
	var aperte_a_sbafo: Array = []
	for listing in RealEstate.all():
		var id := str(listing["id"])
		# Gli appartamenti dentro a un edificio (la torre) non hanno ancora una
		# porta loro: si comprano e basta. Il controllo vale per le proprieta'
		# che SONO un edificio.
		if listing.has("edificio"):
			continue
		var entry := {}
		for candidate in CityMap.BUILDINGS:
			if str(candidate["id"]) == id:
				entry = candidate
		if entry.is_empty():
			continue
		var interior := str(entry.get("interior", ""))
		if interior.is_empty() or not ResourceLoader.exists(interior):
			senza_porta.append(id)
			continue
		var porta := EnterableBuilding.new()
		porta.interior_scene = interior
		porta.building_id = id
		porta.needs_ownership = bool(entry.get("owned", false))
		data.properties.erase(id)
		if porta.can_open():
			aperte_a_sbafo.append(id)
		data.properties[id] = {"livello": 1, "acquisito_il": data.day}
		if not porta.can_open():
			chiuse.append(id)
		data.properties.erase(id)
		porta.free()
	_check_empty(senza_porta, "ogni proprieta' in vendita ha un interno che esiste")
	_check_empty(aperte_a_sbafo, "non si entra in quello che non si e' comprato")
	_check_empty(chiuse, "comprata, ci si entra")

	# La finestra dell'agenzia, appesa dove la appende il gioco: sotto a un
	# Node2D, come e' `City`.
	#
	# **La radice dev'essere un CanvasLayer.** Un Control appeso a un Node2D
	# finisce nello spazio del MONDO: segue la camera, si sposta con lei e si
	# ingrandisce con lo zoom. La prima versione era cosi' e la finestra si
	# apriva davvero, ma fuori inquadratura — cliccare sull'agenzia sembrava non
	# fare niente, e non c'era nessun errore da nessuna parte.
	data.cash = 40000
	data.properties.erase("Garage")
	var citta := Node2D.new()
	citta.position = Vector2(1234, -567)
	add_child(citta)
	var scena: PackedScene = load("res://scenes/ui/RealEstateWindow.tscn")
	_check(scena != null, "la scena della finestra si carica")
	var finestra: Node = scena.instantiate()
	_check(finestra is CanvasLayer,
		"la radice e' un CanvasLayer, non segue la camera")
	citta.add_child(finestra)
	var righe: Node = finestra.get_node_or_null("Root/Window/Scroll/Content")
	_check(righe != null, "la finestra trova le sue righe")
	if righe != null:
		_check_eq(righe.get_child_count(), RealEstate.for_agency("flats").size(),
			"c'e' una riga per ogni annuncio")
	# L'agenzia di DOWNTOWN mostra i suoi, e solo i suoi: i due appartamenti.
	var scena_dt: PackedScene = load("res://scenes/ui/RealEstateDowntownWindow.tscn")
	_check(scena_dt != null, "la finestra di downtown si carica")
	var finestra_dt: Node = scena_dt.instantiate()
	citta.add_child(finestra_dt)
	var righe_dt: Node = finestra_dt.get_node_or_null("Root/Window/Scroll/Content")
	if righe_dt != null:
		_check_eq(righe_dt.get_child_count(), 2, "a downtown ci sono i due appartamenti")
	data.cash = 350000
	_check(RealEstate.buy("MeridianApt5"), "l'appartamento al quinto piano si compra")
	_check_eq(data.cash, 50000, "costa trecentomila")
	_check(not RealEstate.buy("MeridianApt21"), "quello al ventunesimo costa di piu'")
	citta.queue_free()

## Scrive un salvataggio finto con un istante deciso da noi. Serve a provare
## l'ordinamento: `save_game()` mette sempre "adesso", quindi da li' non si
## possono ottenere due partite salvate a ore di distanza.
func _write_fake_save(slot_id: String, saved_at: float, cash: int) -> void:
	var data := SaveData.create_new(slot_id)
	data.cash = cash
	data.saved_at = saved_at
	var file := FileAccess.open(
		GameState.save_dir.path_join(slot_id + GameState.EXTENSION), FileAccess.WRITE)
	if file == null:
		_check(false, "il salvataggio finto %s si scrive" % slot_id)
		return
	file.store_string(JSON.stringify(data.to_dict(), "	"))
	file.close()


# ---------------------------------------------------------------------------

## Il grossista dei semi: lo sblocco col furgone, l'ordine e le due ore d'attesa.
func _test_seed_run() -> void:
	var data := _fresh()

	# --- Lo sblocco ---------------------------------------------------------
	_check(not SeedRun.is_unlocked(data), "senza furgone il grossista non esiste")
	_check(not SeedRun.check_unlock(data), "e non si sblocca da solo")
	data.cash = Shop.price("van")
	Shop.buy(data, "van")
	_check(SeedRun.check_unlock(data), "comprato il furgone, il grossista si apre")
	_check(
		not SeedRun.check_unlock(data),
		"ma una volta sola: il messaggio di Brian non si ripete")

	# --- L'ordine -----------------------------------------------------------
	var pack: Dictionary = SeedRun.PACKS[0]
	var seeds := int(pack["seeds"])
	var price := SeedRun.pack_price(pack)
	_check(
		price < Economy.seed_price(Economy.DEFAULT_STRAIN) * seeds,
		"a cassette il seme costa meno che da Brian")

	data.cash = price - 1
	_check(not SeedRun.can_order(data, pack), "con i soldi corti non si ordina")
	data.cash = price
	# Una partita nuova parte gia' con qualche seme in mano: il confronto e'
	# con quelli, non con lo zero.
	var before := Economy.seeds_owned(data)
	var now := 10.0
	_check_eq(SeedRun.order(data, pack, now), seeds, "ordine partito")
	_check_eq(data.cash, 0, "e pagato subito, non al ritorno")
	_check(SeedRun.is_running(data), "il furgone e' in viaggio")
	_check_eq(
		Economy.seeds_owned(data), before,
		"i semi NON sono ancora in mano: il viaggio dura")

	# --- L'attesa -----------------------------------------------------------
	_check_eq(
		SeedRun.tick(data, now + SeedRun.TRIP_HOURS - 0.1), 0,
		"prima dell'ora il furgone non rientra")
	_check_eq(
		SeedRun.tick(data, now + SeedRun.TRIP_HOURS), seeds,
		"scadute le due ore rientra coi semi")
	_check_eq(
		Economy.seeds_owned(data), before + seeds,
		"e i semi entrano in inventario")
	_check(not SeedRun.is_running(data), "il viaggio e' chiuso")
	_check_eq(SeedRun.tick(data, now + 99.0), 0, "e non si scarica due volte")

	# --- Il consiglio dell'autista ------------------------------------------
	# Arriva al primo ordine e una volta sola. Un consiglio che si ripete a ogni
	# cassa di semi non e' un consiglio, e' un promemoria che non si spegne.
	_check(
		bool(data.get_flag(SeedRun.BOUGHT_FLAG, false)),
		"il primo ordine resta segnato")
	_check(
		not SeedRun.check_driver_hint(_fresh()),
		"senza mai aver comprato semi Brian non consiglia niente")
	var hinted := SaveData.from_dict(data.to_dict())
	_check(SeedRun.check_driver_hint(hinted), "comprati i semi, Brian consiglia l'autista")
	_check(not SeedRun.check_driver_hint(hinted), "ma una volta sola")

	# --- Un furgone solo, un viaggio alla volta -----------------------------
	# E' la regola che tiene insieme le due cose: lo stesso mezzo porta la merce
	# all'ingrosso e va a ritirare i semi, quindi non puo' fare tutti e due.
	data.cash = SeedRun.pack_price(pack)
	# L'ingrosso della merce ha un suo sblocco, separato dal furgone: senza
	# quello `dispatch()` non parte e la prova non proverebbe niente.
	data.set_flag(Delivery.UNLOCK_FLAG, true)
	data.add_item(Economy.PRODUCT, Delivery.LOADS[0])
	_check_eq(
		Delivery.dispatch(data, Delivery.LOADS[0], now), Delivery.LOADS[0],
		"il carico per l'ingrosso e' partito")
	_check(
		not SeedRun.can_order(data, pack),
		"col furgone gia' in giro per l'ingrosso non si ordina")

	# --- Il viaggio sopravvive al salvataggio -------------------------------
	# Le ore sono float: un `back_at` di 12.5 che torna 12 farebbe arrivare i
	# semi mezz'ora prima. E' lo stesso motivo per cui `van_run` ha il suo cast.
	var fresh := _fresh()
	fresh.set_flag(SeedRun.UNLOCK_FLAG, true)
	fresh.cash = SeedRun.pack_price(pack)
	SeedRun.order(fresh, pack, 12.25)
	var reloaded := SaveData.from_dict(fresh.to_dict())
	_check(SeedRun.is_running(reloaded), "il viaggio si ritrova ricaricando")
	_check(
		is_equal_approx(float(reloaded.seed_run["back_at"]), 12.25 + SeedRun.TRIP_HOURS),
		"con l'ora di rientro intatta, mezz'ora compresa")

# ---------------------------------------------------------------------------

## Il contatto fuori stato di Kevin: lo sblocco ai centomila dollari, l'ordine
## fino a duecentocinquanta semi, e le sei ore d'attesa. Stessa forma di
## `_test_seed_run()`.
func _test_bus_import() -> void:
	var data := _fresh()

	# --- Lo sblocco -----------------------------------------------------
	_check(not BusImport.is_unlocked(data), "senza centomila dollari il contatto non esiste")
	_check(not BusImport.check_unlock(data), "e non si sblocca da solo")
	data.cash = BusImport.UNLOCK_CASH - 1
	_check(not BusImport.check_unlock(data), "manca un dollaro e ancora niente")
	data.cash = BusImport.UNLOCK_CASH
	_check(BusImport.check_unlock(data), "arrivati ai centomila, kevin manda il messaggio")
	_check(
		not BusImport.check_unlock(data),
		"ma una volta sola: il messaggio non si ripete")
	_check(
		Chat.KEVIN in Chat.contacts(data).map(func(c: Dictionary) -> String: return str(c["id"])),
		"e kevin compare in rubrica")

	# --- L'ordine ---------------------------------------------------------
	var pack: Dictionary = BusImport.PACKS[-1]
	var seeds := int(pack["seeds"])
	_check_eq(seeds, 250, "il taglio piu' grande arriva a duecentocinquanta semi")
	var price := BusImport.pack_price(pack)
	_check(
		price < Economy.seed_price(Economy.DEFAULT_STRAIN) * seeds,
		"anche qui il seme costa meno che da Brian")
	var seed_run_price := SeedRun.pack_price(SeedRun.PACKS[-1])
	_check(
		float(price) / float(seeds) < float(seed_run_price) / float(SeedRun.PACKS[-1]["seeds"]),
		"e lo sconto e' il piu' alto del gioco, sopra a quello del grossista in centro")

	data.cash = price - 1
	_check(not BusImport.can_order(data, pack), "con i soldi corti non si ordina")
	data.cash = price
	var before := Economy.seeds_owned(data)
	var now := 10.0
	_check_eq(BusImport.order(data, pack, now), seeds, "ordine partito")
	_check_eq(data.cash, 0, "e pagato subito, non al ritorno")
	_check(BusImport.is_running(data), "il furgone e' in viaggio")
	_check_eq(
		Economy.seeds_owned(data), before,
		"i semi NON sono ancora in mano: il viaggio dura")

	# --- L'attesa -----------------------------------------------------------
	_check_eq(
		BusImport.tick(data, now + BusImport.TRIP_HOURS - 0.1), 0,
		"prima dell'ora il furgone non rientra")
	_check_eq(
		BusImport.tick(data, now + BusImport.TRIP_HOURS), seeds,
		"scadute le sei ore rientra coi semi")
	_check_eq(
		Economy.seeds_owned(data), before + seeds,
		"e i semi entrano in inventario")
	_check(not BusImport.is_running(data), "il viaggio e' chiuso")
	_check_eq(BusImport.tick(data, now + 99.0), 0, "e non si scarica due volte")

	# --- Un furgone solo, un viaggio alla volta -----------------------------
	# E' la stessa regola di `SeedRun`, estesa a tre viaggi: la merce
	# all'ingrosso, i semi dal grossista in centro, i semi dal contatto fuori
	# stato. Uno alla volta, in tutte e tre le direzioni.
	data.cash = BusImport.pack_price(pack)
	data.set_flag(Delivery.UNLOCK_FLAG, true)
	data.add_item(Economy.PRODUCT, Delivery.LOADS[0])
	_check_eq(
		Delivery.dispatch(data, Delivery.LOADS[0], now), Delivery.LOADS[0],
		"il carico per l'ingrosso e' partito")
	_check(
		not BusImport.can_order(data, pack),
		"col furgone gia' in giro per l'ingrosso non si ordina da kevin")

	var busy := _fresh()
	busy.set_flag(BusImport.UNLOCK_FLAG, true)
	busy.set_flag(SeedRun.UNLOCK_FLAG, true)
	busy.cash = BusImport.pack_price(BusImport.PACKS[0])
	BusImport.order(busy, BusImport.PACKS[0], now)
	busy.cash = SeedRun.pack_price(SeedRun.PACKS[0])
	_check(
		not SeedRun.can_order(busy, SeedRun.PACKS[0]),
		"e col furgone in giro dal contatto fuori stato non si ordina dal grossista in centro")

	# --- Il viaggio sopravvive al salvataggio -------------------------------
	var fresh := _fresh()
	fresh.set_flag(BusImport.UNLOCK_FLAG, true)
	fresh.cash = BusImport.pack_price(pack)
	BusImport.order(fresh, pack, 12.25)
	var reloaded := SaveData.from_dict(fresh.to_dict())
	_check(BusImport.is_running(reloaded), "il viaggio si ritrova ricaricando")
	_check(
		is_equal_approx(float(reloaded.bus_run["back_at"]), 12.25 + BusImport.TRIP_HOURS),
		"con l'ora di rientro intatta, mezz'ora compresa")
