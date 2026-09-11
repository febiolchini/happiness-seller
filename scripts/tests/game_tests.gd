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
		["pianta della citta'", _test_city_layout],
		["percorsi", _test_navigation],
		["partita nuova", _test_new_game],
		["ciclo di coltivazione", _test_grow_cycle],
		["la sete rovina la resa", _test_dryness_hurts_yield],
		["vendite", _test_selling],
		["clienti di strada", _test_street_customer],
		["ampliamento del seminterrato", _test_plot_expansion],
		["negozio online", _test_shop],
		["vasi autoinnaffianti", _test_auto_water],
		["fine del prologo", _test_prologue],
		["il personale coltiva", _test_staff_growing],
		["il personale vende", _test_staff_selling],
		["le paghe", _test_staff_wages],
		["posti dove vedersi", _test_meet_spots],
		["appuntamento con brian", _test_seed_deal],
		["salvataggio e ricaricamento", _test_save_roundtrip],
		["riprendi l'ultima partita", _test_continue_last],
		["mezzanotte", _test_day_rollover],
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

## La pianta della città: due edifici a mano più duecento generati.
##
## Sono controlli che a occhio non si fanno. Un capannone che spunta in mezzo
## alla carreggiata o due case sovrapposte in fondo alla mappa si notano solo
## passando di lì per caso, e con cinque quartieri quel caso non capita mai.
func _test_city_layout() -> void:
	var buildings := CityMap.all_buildings()
	_check(buildings.size() > 150, "la città è piena (%d edifici)" % buildings.size())

	var road_bands: Array[Rect2] = []
	for road: Rect2 in CityMap.ROADS_H + CityMap.ROADS_V:
		road_bands.append(road.grow(CityMap.SIDEWALK_DEPTH))

	var placed: Array[Rect2] = []
	var on_road: Array = []
	var overlapping: Array = []
	var outside: Array = []
	for entry in buildings:
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
	_check_empty(overlapping, "nessun edificio sovrapposto a un altro")
	_check_empty(outside, "nessun edificio fuori dai confini del mondo")

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
	var unreachable: Array = []
	var through_walls: Array = []
	for entry in buildings:
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
	var factory := Rect2()
	for entry in CityMap.BUILDINGS:
		if str(entry["id"]) == "Factory":
			factory = CityMap.footprint(entry)
	var north := Vector2(factory.get_center().x, factory.position.y - 40.0)
	var south := Vector2(factory.get_center().x, factory.end.y + 40.0)
	var around := nav.find_path(north, south)
	_check(not around.is_empty(), "si passa da un lato all'altro della fabbrica")
	var walked := 0.0
	for i in range(around.size() - 1):
		walked += around[i].distance_to(around[i + 1])
	_check(
		walked > north.distance_to(south) * 1.5,
		"la fabbrica si aggira invece di attraversarla (%d px contro %d in linea d'aria)"
			% [int(walked), int(north.distance_to(south))])

	# Attraversare mezza città deve funzionare e restare un percorso sensato.
	var far := nav.find_path(home, Vector2(4600, 3600))
	_check(not far.is_empty(), "si attraversa tutta la città")
	_check(far.size() < 200, "il percorso lungo resta semplificato (%d tappe)" % far.size())

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
	_check(wanted >= Economy.STREET_DEMAND.x and wanted <= Economy.STREET_DEMAND.y, "domanda nell'intervallo")
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

	# Fino al limite del seminterrato, poi basta.
	data.cash = 999999
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
	_check_eq(SeedDeal.seeds_left(data), SeedDeal.SEEDS_PER_RUN, "ha portato i semi")

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
	_check_eq(SeedDeal.seeds_left(data), SeedDeal.SEEDS_PER_RUN - 2, "Brian ne ha due di meno")

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
	_check_eq(SeedDeal.tick(later, GameState.total_hours()), "gone", "Brian non aspetta per sempre")
	_check(not SeedDeal.is_active(later), "e l'appuntamento sparisce")
	_check(SeedDeal.can_ask(later), "così non si resta bloccati senza semi")

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

	# Le lampade accorciano il ciclo, il toolkit alza la resa.
	var strain := Economy.strain(Economy.DEFAULT_STRAIN)
	var base_hours := float(strain["grow_hours"])
	var base_grams := int(strain["grams"])
	var mods := Shop.grow_mods(data, base_hours, base_grams)
	_check(int(mods["grams"]) > base_grams, "il toolkit alza la resa")
	_check(is_equal_approx(float(mods["hours"]), base_hours), "ma non tocca il tempo")

	_check(Shop.buy(data, "lamps"), "si comprano le lampade")
	var lit := Shop.grow_mods(data, base_hours, base_grams)
	_check(float(lit["hours"]) < base_hours, "le lampade accorciano il ciclo")

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

func _test_auto_water() -> void:
	var data := _fresh()
	data.cash = 100000
	_check(Shop.buy(data, "auto_water"), "si compra un vaso autoinnaffiante")
	_check(Shop.is_auto_pot(data, 0), "equipaggia il primo vaso")
	_check(not Shop.is_auto_pot(data, 1), "e solo quello")
	_check_eq(Shop.max_owned(data, "auto_water"), data.plot_slots, "se ne possono avere quanti sono i vasi")

	var auto_plot := data.plot(0)
	var plain_plot := data.plot(1)
	var now := GameState.total_hours()
	Grow.plant(auto_plot, Economy.DEFAULT_STRAIN, now)
	Grow.plant(plain_plot, Economy.DEFAULT_STRAIN, now)

	# Un ciclo intero senza toccare niente.
	_advance(float(Economy.strain(Economy.DEFAULT_STRAIN)["grow_hours"]) + 2.0)
	now = GameState.total_hours()
	Grow.sync(auto_plot, now, true)
	Grow.sync(plain_plot, now)
	_check(not Grow.is_thirsty(auto_plot, now, true), "il vaso col serbatoio non ha mai sete")
	_check(Grow.is_thirsty(plain_plot, now), "quello normale si', lasciato li'")
	_check(is_equal_approx(Grow.quality(auto_plot), 1.0), "e rende pieno senza che nessuno lo annaffi")
	_check(Grow.yield_grams(auto_plot) > Grow.yield_grams(plain_plot), "piu' di quello trascurato")

	_check_eq(
		Grow.count_thirsty(data.plots, now, Shop.auto_pots(data)), 1,
		"nel conto dei vasi con sete ci finisce solo quello normale")

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

	# Ha i semi: pianta da solo.
	data.add_item(Economy.seed_item(Economy.DEFAULT_STRAIN), 4)
	var report := Staff.work(data, now)
	_check_eq(int(report["planted"]), Staff.POTS_PER_GROWER, "pianta i vasi che segue")
	_check(not Grow.is_empty(data.plot(0)), "il primo vaso e' pieno")
	_check(Grow.is_empty(data.plot(2)), "il terzo no: un coltivatore segue due vasi")

	# Il ciclo passa senza che il giocatore tocchi niente: annaffia e raccoglie.
	_advance(Grow.WATER_HOURS + 1.0)
	var watered := Staff.work(data, GameState.total_hours())
	_check_eq(int(watered["watered"]), Staff.POTS_PER_GROWER, "annaffia quando hanno sete")

	_advance(float(Economy.strain(Economy.DEFAULT_STRAIN)["grow_hours"]))
	var cut := Staff.work(data, GameState.total_hours())
	_check_eq(int(cut["harvested"]), Staff.POTS_PER_GROWER, "raccoglie quando sono pronte")
	_check(int(cut["grams"]) > 0, "e la merce arriva in magazzino")
	_check_eq(Economy.stock(data), int(cut["grams"]), "tutta quanta")
	_check_eq(int(cut["planted"]), Staff.POTS_PER_GROWER, "e ripianta subito coi semi rimasti")

func _test_staff_selling() -> void:
	var data := _fresh()
	data.cash = Staff.hire_cost("dealer")
	var now := GameState.total_hours()
	_check(Staff.hire(data, "dealer", now), "si assume un dealer")
	data.cash = 0
	data.add_item(Economy.PRODUCT, 500)

	# Tutto all'ingrosso: non si alza l'attenzione.
	Staff.set_wholesale_share(data, 100)
	_advance(10.0)
	var bulk := Staff.work(data, GameState.total_hours())
	_check(int(bulk["sold"]) > 0, "in dieci ore qualcosa lo piazza")
	_check_eq(int(bulk["sold"]), int(10.0 * Staff.GRAMS_PER_DEALER_HOUR), "quanto riesce a piazzare in dieci ore")
	_check(int(bulk["revenue"]) > 0, "e porta a casa i soldi")
	_check_eq(data.cash, int(bulk["revenue"]), "che finiscono in cassa")
	_check_eq(data.heat, 0.0, "vendendo all'ingrosso non si alza l'attenzione")

	# Tutto in strada: rende di piu' e scalda le acque.
	Staff.set_wholesale_share(data, 0)
	_advance(10.0)
	var street := Staff.work(data, GameState.total_hours())
	_check(data.heat > 0.0, "vendendo in strada l'attenzione sale")
	_check(int(street["revenue"]) > int(bulk["revenue"]), "e la strada paga meglio dell'ingrosso")

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

func _test_staff_wages() -> void:
	var data := _fresh()
	data.cash = Staff.hire_cost("grower")
	_check(Staff.hire(data, "grower", GameState.total_hours()), "assunto")
	_check_eq(Staff.daily_wages(data), Staff.wage("grower"), "la paga del giorno")

	data.cash = 1000
	var paid := Staff.pay_wages(data)
	_check_eq(int(paid["paid"]), Staff.wage("grower"), "a mezzanotte si paga")
	_check_eq(data.cash, 1000 - Staff.wage("grower"), "e la cassa cala")
	_check_eq(str(paid["quit"]), "", "nessuno se ne va")

	# Cassa vuota: se ne va uno, invece di lasciare un buco che si allarga.
	data.cash = 0
	var broke := Staff.pay_wages(data)
	_check_eq(str(broke["quit"]), "grower", "senza soldi il coltivatore se ne va")
	_check_eq(Staff.total(data), 0, "e l'organico si svuota")
	_check(data.cash >= 0, "la cassa non va sotto zero")

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
	_check_eq(old.plots.size(), old.plot_slots, "salvataggio vecchio: vasi creati vuoti")
	_check(Grow.is_empty(old.plot(0)), "salvataggio vecchio: vasi vuoti")

## Il giro che fa il giocatore premendo "play": si gioca, si chiude, si
## riapre e si riprende da dove si era.
##
## È il percorso che conta di più di tutti e passa da disco, non solo da
## `to_dict()`: qui si vede se il file viene scritto davvero, se "l'ultima
## partita" è quella giusta, e se torna indietro tutto quello che il giocatore
## si aspetta di ritrovare.
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
