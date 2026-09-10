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

	_test_everything_loads()
	_test_city_layout()
	_test_navigation()
	_test_new_game()
	_test_grow_cycle()
	_test_dryness_hurts_yield()
	_test_selling()
	_test_street_customer()
	_test_plot_expansion()
	_test_save_roundtrip()
	_test_continue_last()
	_test_day_rollover()

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
	_check(int(roles.get(NpcRoster.ROLE_SEEDS, 0)) >= 1, "c'e' chi vende i semi")
	_check(int(roles.get(NpcRoster.ROLE_BUYER, 0)) >= 4, "ci sono abbastanza clienti")
	_check(int(roles.get(NpcRoster.ROLE_COP, 0)) >= 1, "c'e' almeno una pattuglia")

	# Milo deve stare davanti alla clinica, non da qualche altra parte: se la
	# clinica si sposta e lui no, i semi diventano introvabili.
	var clinic := Rect2()
	for entry in CityMap.BUILDINGS:
		if str(entry["id"]) == "Clinic":
			clinic = CityMap.footprint(entry)
	_check(clinic.size.x > 0.0, "la clinica esiste")
	var milo := NpcRoster.by_id("milo")
	_check(not milo.is_empty(), "milo esiste")
	var milo_at: Vector2 = milo["route"][0]
	_check(
		absf(milo_at.x - clinic.get_center().x) < clinic.size.x
			and absf(milo_at.y - clinic.end.y) < 120.0,
		"milo sta davanti alla clinica")

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

func _test_save_roundtrip() -> void:
	var data := _fresh()
	var plot := data.plot(1)
	Grow.plant(plot, Economy.DEFAULT_STRAIN, GameState.total_hours())
	_advance(7.5)
	Grow.sync(plot, GameState.total_hours())
	data.add_item(Economy.PRODUCT, 42)
	data.heat = 23.5
	data.market_price = 13
	Economy.sell_street(data, "dee", 3)
	# Dopo la vendita, non prima: vendere in strada alza l'attenzione, quindi il
	# valore da confrontare è quello che c'è davvero al momento del salvataggio.
	var heat_before := data.heat

	var restored := SaveData.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	_check_eq(restored.plots.size(), data.plots.size(), "numero di vasi conservato")
	_check_eq(restored.plot_slots, data.plot_slots, "vasi sbloccati conservati")
	_check_eq(Economy.stock(restored), Economy.stock(data), "merce conservata")
	_check_eq(restored.market_price, 13, "prezzo del giorno conservato")
	_check(is_equal_approx(restored.heat, heat_before), "attenzione conservata")
	_check(
		is_equal_approx(float(restored.plots[1]["planted_at"]), float(data.plots[1]["planted_at"])),
		"l'ora di semina resta un float e non viene arrotondata")
	_check_eq(
		int(restored.npc_state["dee"]["bought"]), int(data.npc_state["dee"]["bought"]),
		"quello che ha comprato un cliente e' conservato")
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
