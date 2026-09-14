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
		["pianta della citta'", _test_city_layout],
		["percorsi", _test_navigation],
		["partita nuova", _test_new_game],
		["ciclo di coltivazione", _test_grow_cycle],
		["la sete rovina la resa", _test_dryness_hurts_yield],
		["vendite", _test_selling],
		["clienti di strada", _test_street_customer],
		["ampliamento del seminterrato", _test_plot_expansion],
		["negozio online", _test_shop],
		["fine del prologo", _test_prologue],
		["il personale coltiva", _test_staff_growing],
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
		["il telefono", _test_phone_alerts],
		["il tempo a gioco chiuso", _test_offline],
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
			if sign_name in (district["names"] as Array):
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
	# Una lampada per vaso, e i vasi in cantina sono sei.
	_check_eq(
		Shop.max_owned("lamps"), Economy.MAX_PLOTS,
		"si compra una lampada per ogni vaso del seminterrato")

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
	for i in Economy.MAX_PLOTS - 1:
		Shop.buy(data, "lamps")
	_check_eq(Shop.owned(data, "lamps"), Economy.MAX_PLOTS, "tutte e sei le lampade comprate")
	for index in Economy.MAX_PLOTS:
		var covered := Shop.grow_mods(data, base_hours, base_grams, index)
		_check(
			is_equal_approx(float(covered["hours"]), base_hours * (1.0 - Shop.LAMP_SPEEDUP)),
			"il vaso %d resta all'8%%, anche con tutte le lampade comprate" % index)
	# Un vaso oltre l'ultima lampada — se un domani il seminterrato si allarga
	# senza comprare altre lampade — non ha comunque nessuno sconto.
	_check(
		is_equal_approx(
			float(Shop.grow_mods(data, base_hours, base_grams, Economy.MAX_PLOTS)["hours"]), base_hours),
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

	# La quota del dealer: niente paga, si tiene una fetta di quello che piazza.
	_check(int(bulk["gross"]) > 0, "la merce ha fatto un lordo")
	_check(int(bulk["commission"]) > 0, "e il dealer si e' tenuto la sua quota")
	_check_eq(
		int(bulk["commission"]), int(roundf(float(bulk["gross"]) * Staff.cut("dealer"))),
		"che e' la percentuale della tabella")
	_check_eq(
		int(bulk["revenue"]), int(bulk["gross"]) - int(bulk["commission"]),
		"in cassa arriva il lordo meno la quota")
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

	# Le finestre: di giorno quasi tutte spente, dopo cena quasi tutte accese.
	_check(
		Daylight.window_lit_ratio(21.0) > Daylight.window_lit_ratio(12.0) * 3.0,
		"dopo cena le finestre accese sono molte piu' che a mezzogiorno")
	var probe := 0.0
	var outside: Array = []
	while probe < 24.0:
		var value := Daylight.window_lit_ratio(probe)
		if value < 0.0 or value > 1.0:
			outside.append("alle %.1f vale %.2f" % [probe, value])
		probe += 0.25
	_check_empty(outside, "la quota di finestre accese resta fra 0 e 1")

# ---------------------------------------------------------------------------

## Il meteo: la tabella, il tiro del giorno nuovo, e quanto pesa in partita.
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

	# --- L'orologio avanza di quanto deve ----------------------------------
	#
	# A 4 minuti di gioco al secondo, due minuti veri sono 480 minuti di gioco,
	# cioe' otto ore. E' il rapporto che rende necessario il tetto: vedi sotto.
	data = _fresh()
	data.time_of_day = 8.0
	data.day = 1
	var report := Offline.catch_up(data, 120.0, RATE)
	_check(Offline.happened(report), "due minuti veri fanno scattare il recupero")
	_check(is_equal_approx(float(report["game_hours"]), 8.0), "due minuti veri sono otto ore di gioco")
	_check(
		data.day == 1 and is_equal_approx(data.time_of_day, 16.0),
		"e l'orologio della partita arriva alle sedici")
	_check(not bool(report["capped"]), "otto ore stanno sotto al tetto")

	# --- Il tetto -----------------------------------------------------------
	data = _fresh()
	data.time_of_day = 8.0
	var long_away := Offline.catch_up(data, 2.0 * HOUR, RATE)
	_check(bool(long_away["capped"]), "due ore vere sbattono contro il tetto")
	_check(
		is_equal_approx(float(long_away["game_hours"]), Offline.MAX_GAME_HOURS),
		"e vengono recuperate solo le ore del tetto")
	# Il tetto e' quello che tiene il gioco un gestionale invece di un idle:
	# tornare dopo una settimana deve dare quanto tornare dopo un quarto d'ora.
	var week := _fresh()
	week.time_of_day = 8.0
	var week_report := Offline.catch_up(week, 24.0 * 7.0 * HOUR, RATE)
	_check(
		is_equal_approx(float(week_report["game_hours"]), float(long_away["game_hours"])),
		"una settimana vale quanto il tetto, non di piu'")

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
	# Dodici minuti veri: il tetto pieno, due giornate di gioco.
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
	# Il tetto pieno: 48 ore di gioco, sopra a un ciclo e mezzo di 29 ore.
	var tended_pots := mini(Staff.POTS_PER_GROWER, stepped.plots.size())
	var many := Offline.catch_up(stepped, 30.0 * 60.0, RATE)
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
	var missed := Offline.catch_up(meeting, 12.0 * 60.0, RATE)
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
