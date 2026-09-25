extends Node2D

## La cittadina: cinque quartieri intorno a un reticolo di strade, con il
## traffico che passa e la gente che cammina sui marciapiedi.
##
## ## La scena si costruisce dai dati
##
## `City.tscn` contiene solo i contenitori vuoti. Strade, quartieri, edifici,
## auto e passanti li istanzia `_build_city()` leggendo `CityMap` e
## `NpcRoster`. È la stessa regola già valida per i salvataggi — la mappa si
## ricostruisce dallo stato, non si salva l'albero della scena — estesa alla
## pianta della città: così spostare un quartiere è cambiare due numeri in una
## tabella, non trascinare trenta nodi in un file di scena.
##
## ## Un click, tre significati
##
## Cliccare vuol dire "vai lì", "vai a parlargli" o "vai a entrarci", e la
## differenza la fa cosa c'è sotto il puntatore. In tutti e tre i casi prima si
## cammina: quello che succede all'arrivo se lo ricorda `_talking_to` /
## `_entering` e lo esegue `_on_player_arrived()`.
##
## ## Il nome sotto al puntatore
##
## Passando sopra a un edificio compare la sua insegna, appesa al puntatore.
## Serve perché la città è fatta di disegni e non di cartelli: una palazzina
## come un'altra non dice se è l'agenzia, il garage in vendita o casa, e senza
## un nome l'unico modo di saperlo era cliccarci sopra e vedere dove si finiva.
##
## ## L'ora e il tempo che fa
##
## La luce non è un effetto appiccicato sopra alla mappa: `Atmosphere` tinge
## tutta la tela del mondo col colore dell'ora (`daylight.gd`), i lampioni e le
## finestre si accendono da soli quando quel colore scende, le ombre girano col
## sole. Le nuvole e le pozze stanno per terra (`GroundWeather`), la pioggia
## davanti a tutto su una tela sua (`WeatherLayer`). Nessuno di questi nodi sa
## niente degli altri: guardano tutti l'orologio della partita.
##
## Esc = menu principale, tasto destro trascinando = pan, rotellina = zoom.

const TILE_SIZE := 32
const MAIN_MENU := "res://scenes/main/Main.tscn"
const RIPPLE := preload("res://scenes/components/ClickRipple.tscn")
const ENTERABLE := preload("res://scripts/components/enterable_building.gd")
const BUILDING_LIGHTS := preload("res://scripts/components/building_lights.gd")
const SHOP_SHUTTER := preload("res://scripts/components/shop_shutter.gd")
const SUN_GLASS := preload("res://scripts/components/sun_glass.gd")
const WIND_PROP := preload("res://scripts/components/wind_prop.gd")
const GLASS_SHEEN := preload("res://assets/shaders/glass_sheen.gdshader")
const NPC := preload("res://scenes/characters/Npc.tscn")
const CAR := preload("res://scenes/components/Car.tscn")
const FOUNTAIN := preload("res://scenes/components/Fountain.tscn")
const STREET_LAMP := preload("res://scenes/components/StreetLamp.tscn")
const DELIVERY_VAN := preload("res://scenes/components/DeliveryVan.tscn")

## Quanto lontano dalla facciata si ferma il protagonista.
const APPROACH := 26.0

## L'etichetta col nome dell'edificio sotto al puntatore.
##
## Otto, come il nome che gli NPC si portano sopra la testa (`npc.gd`): sono la
## stessa cosa — come si chiama quello che c'è sotto al puntatore — e a corpi
## diversi si leggerebbero come due informazioni diverse. È anche la misura
## giusta per una scritta che compare e sparisce muovendo il mouse: più grande
## si mette a gridare sopra a una città in cui tutto il resto è disegnato.
const HOVER_SIZE := 8
const HOVER_COLOR := Color(0.94, 0.93, 0.87)
## Dove sta rispetto alla punta del puntatore. A destra e sopra, come un
## suggerimento di sistema: sotto finirebbe coperta dalla mano del cursore.
const HOVER_NUDGE := Vector2(12, -15)
## Quanto resta lontana dal bordo dello schermo prima di ribaltarsi dall'altra
## parte del puntatore.
const HOVER_MARGIN := 6.0
## Disattivata quando la mappa è usata solo come sfondo decorativo (menu).
@export var interactive := true

@onready var _player: CharacterBody2D = $Player
@onready var _effects: Node2D = $Effects
@onready var _buildings: Node2D = $Buildings
@onready var _props: Node2D = $Props
@onready var _npcs: Node2D = $Npcs
@onready var _traffic: Node2D = $Traffic
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: CanvasLayer = $HUD
@onready var _phone: Control = $Phone/Screen
@onready var _dialogue: CanvasLayer = $DialogueBox

## Il reticolo su cui si cammina. Costruito una volta dalla stessa pianta che
## costruisce gli edifici, così non possono divergere.
var _navigation := CityNavigation.new()

## Edificio in cui si sta entrando: il protagonista ci sta camminando verso.
var _entering: EnterableBuilding = null
## Personaggio con cui si sta andando a parlare.
var _talking_to: Npc = null

## L'etichetta col nome dell'edificio sotto al puntatore, e quello che ci sta
## scritto adesso: senza il secondo la Label si riscriverebbe ogni fotogramma.
var _hover_label: Label = null
var _hover_shown := ""

## Tutti gli edifici cliccabili, nello stesso ordine in cui `_build_city()` li
## pianta nell'albero. Riempita una volta sola: la pianta della città non
## cambia mentre si gioca, quindi `_building_at()` — chiamata a ogni
## fotogramma per l'etichetta sotto al puntatore — scorre questa invece di
## chiedere il gruppo alla `SceneTree` ogni volta.
var _enterable_buildings: Array[EnterableBuilding] = []

func _ready() -> void:
	# La città si costruisce sempre, anche da sfondo del menu: dietro ai
	# bottoni si vede il quartiere vero, con le auto che passano.
	_build_city()

	# Da sfondo di un menu la mappa non deve toccare la partita in corso,
	# e nemmeno mostrare l'HUD dietro ai bottoni.
	_hud.enabled = interactive
	# Dietro ai bottoni del menu principale non ci va nemmeno la linguetta del
	# telefono: lì la mappa è carta da parati, non una partita.
	_phone.enabled = interactive
	if not interactive:
		return

	# Aprendo City.tscn direttamente dall'editor non si passa dal menu: senza
	# questo non ci sarebbe nessuna partita e tutto quello che legge lo stato
	# schianterebbe.
	if GameState.current == null:
		GameState.new_game()
	_apply_state(GameState.current)
	# La mappa È il "fuori": arrivarci vuol dire non essere più in nessuna stanza.
	GameState.current.current_room = ""
	GameState.clock_running = true
	_player.arrived.connect(_on_player_arrived)
	_camera.follow = _player
	# La camera arriva fino alle montagne, non al bordo della citta': e' tutta
	# la ragione per cui la cornice esiste. Vedi `CityMap.view_bounds()`.
	_camera.set_bounds(CityMap.view_bounds())

	# Dove sta il protagonista lo sa solo la scena, non `SaveData`: prima di
	# ogni scrittura su disco lo riversiamo noi. Vale anche per i salvataggi
	# automatici, che partono da `GameState` e non passano di qui.
	GameState.saving.connect(_collect_state)
	# Brian non è nel roster: compare solo quando c'è un appuntamento. Il
	# segnale copre il caso in cui la posizione arriva mentre si è già in
	# strada; `_apply_state()` quello in cui c'era già entrando qui.
	GameState.seed_spot_ready.connect(_on_seed_spot_ready)
	GameState.seed_deal_closed.connect(_on_seed_deal_closed)
	# Il furgone dell'ingrosso: si vede partire e rientrare solo se in quel
	# momento si è in strada. Chi manda un carico e poi scende in cantina
	# ritrova comunque i soldi — l'animazione è la ciliegina, non il
	# meccanismo. Il filmato della partenza invece si vede ovunque, perché è
	# appeso a `GameState`. Vedi `delivery_van.gd` e `van_cutscene.gd`.
	GameState.van_left.connect(_on_van_left)
	GameState.van_back.connect(_on_van_back)
	# Il viaggio dal grossista dei semi muove lo stesso mezzo, quindi riusa le
	# stesse due animazioni: esce da casa e rientra. Vedi `SeedRun`.
	GameState.seed_run_left.connect(_on_van_left)
	GameState.seed_run_back.connect(_on_van_back)
	# Il contatto fuori stato di Kevin muove lo stesso furgone: stessa ragione
	# del grossista in centro. Vedi `BusImport`.
	GameState.bus_order_left.connect(_on_van_left)
	GameState.bus_order_back.connect(_on_van_back)
	_build_hover_label()
	# Arrivare in strada è un punto di controllo: da qui in poi la partita
	# ricomincerebbe fuori, non nella stanza da cui si è appena usciti.
	GameState.save_game()

func _exit_tree() -> void:
	if interactive:
		GameState.clock_running = false

# --- Costruzione della mappa ----------------------------------------------

func _build_city() -> void:
	# `all_buildings()` e non `BUILDINGS`: la seconda ha solo i punti di
	# riferimento scritti a mano, la prima ci aggiunge le file di edifici
	# generate lungo i fronti stradali.
	var buildings := CityMap.all_buildings()
	# Prima i vicini, poi chi deve stare davanti. L'Y-sort mette avanti chi ha la
	# base più in basso, ma questi tre poggiano sulla STESSA riga di terra: a
	# parità di y decide l'ordine in cui stanno nell'albero, cioè questo.
	#
	# Serve perché i disegni si accavallano: per non lasciare terreno scoperto
	# fra una facciata e l'altra, il cortile di un edificio finisce dentro a
	# quello del vicino (vedi "Il rettangolo cliccabile è il muro"). Senza dire
	# chi vince, la casa iniziale finiva **dietro** all'agenzia, che le copriva
	# la veranda e la staccionata.
	for entry in buildings:
		if not bool(entry.get("in_front", false)):
			_add_building(_make_building(entry))
	for entry in buildings:
		if bool(entry.get("in_front", false)):
			_add_building(_make_building(entry))
	# Da sfondo di un menu non si cammina, e costruire la griglia costerebbe
	# un caricamento in più per niente.
	if interactive:
		_navigation.build(buildings)
	# Il campo da football (erba a shader + gradinata/torre faro/porte) è stato
	# tolto dalla mappa il 2026-09-16 insieme a tutti gli altri segnaposto di
	# `CityMap.LOTS` — vedi il commento lì. `GRASS_FIELD`, `grass_field.gdshader`
	# e i tre PNG restano sul disco: `CityMap.field_props()` torna a costruire
	# le posizioni non appena un lotto "football" ricompare in `LOTS`, e questo
	# ciclo va rimesso qui davanti a `FOUNTAINS`.
	# Subito dopo `Ground` nell'albero: stesso `z_index`, quindi a decidere
	# chi sta sopra e' l'ordine, e l'erba va sopra al terreno del quartiere.
	var ground := get_node("Ground")
	for entry in CityMap.LAYERED_GRASS:
		var grass := LayeredGrass.new()
		grass.rects = CityMap.grass_rects(entry)
		grass.style = str(entry["style"])
		grass.z_index = ground.z_index
		add_child(grass)
		move_child(grass, ground.get_index() + 1)
	# Il pavimento dell'aeroporto sopra ai prati (lo stesso `z_index`, quindi
	# decide l'ordine: dopo l'ultimo prato), e gli aerei nei `Props`.
	var airport_ground := AirportGround.new()
	airport_ground.z_index = ground.z_index
	add_child(airport_ground)
	move_child(airport_ground, ground.get_index() + CityMap.LAYERED_GRASS.size() + 1)
	var airport := Airport.new()
	add_child(airport)
	airport.setup(_props)
	# L'ingombro di ogni pianta, per non seminare fiori sotto alle foglie: lo
	# si raccoglie mentre si piazzano, prima di disegnare i fiori qui sotto.
	var plant_footprints: Array[Rect2] = []
	for entry: Dictionary in CityMap.WIND_TREES:
		var tree := WindTree.new()
		tree.position = entry["at"]
		# La scala si applica al NODO, non solo allo sprite: cosi' cresce dal
		# piede (il pivot) e si porta dietro anche l'ombra disegnata in
		# `WindTree._draw()` e l'oscillazione dello shader, senza bisogno di
		# ricalcolare niente a mano.
		var plant_scale := float(entry.get("scale", 1.0))
		tree.scale = Vector2.ONE * plant_scale
		_props.add_child(tree)
		plant_footprints.append(WindTree.footprint(entry["at"], "tree", plant_scale))
	for entry: Dictionary in CityMap.BUSHES:
		var bush := WindTree.new()
		bush.kind = "bush"
		bush.position = entry["at"]
		var plant_scale := float(entry.get("scale", 1.0))
		bush.scale = Vector2.ONE * plant_scale
		_props.add_child(bush)
		plant_footprints.append(WindTree.footprint(entry["at"], "bush", plant_scale))
	# I fiori delle aiuole: stesso z_index dell'erba, aggiunti per ultimi fra
	# i piani di terra così stanno sopra invece che schiacciati sotto, e mai
	# dove li coprirebbe un cespuglio o un albero (`plant_footprints`).
	var flowers := FlowerBed.new()
	flowers.rects = CityMap.flower_beds()
	flowers.avoid = plant_footprints
	flowers.z_index = ground.z_index
	add_child(flowers)
	move_child(flowers, ground.get_index() + CityMap.LAYERED_GRASS.size() + 2)
	for point in CityMap.FOUNTAINS:
		var fountain := FOUNTAIN.instantiate()
		fountain.position = point
		_props.add_child(fountain)
	# I lampioni stanno fra i `Props` e non fra il terreno: hanno un'altezza,
	# quindi vanno Y-sortati come gli edifici, o il protagonista passerebbe
	# davanti al palo anche camminandoci dietro.
	# I lampioni delle strade e quelli dei piazzali sono lo stesso nodo: un palo
	# in un parcheggio e un palo sul marciapiede si accendono alla stessa ora e
	# fanno la stessa pozza di luce, e averne due versioni vorrebbe dire due
	# posti in cui aggiustare la sera.
	for entry in CityMap.street_lamps() + CityMap.lot_lamps():
		var lamp := STREET_LAMP.instantiate()
		lamp.position = entry["pos"]
		lamp.reach = entry["reach"]
		_props.add_child(lamp)
	for entry in NpcRoster.NPCS:
		var npc := NPC.instantiate()
		_npcs.add_child(npc)
		# `setup()` dopo `add_child()`: sceglie una tappa a caso e ci si
		# posiziona, e per farlo deve essere già nell'albero.
		npc.setup(entry)
	_build_traffic()
	# Il via vai del parcheggio della steak house: le auto stanno nel traffico,
	# che e' Y-sortato, e a muoverle e' un nodo a parte (vedi `ParkingLot`).
	var parking := ParkingLot.new()
	parking.name = "SteakhouseParking"
	add_child(parking)
	parking.setup(CityMap.steakhouse_parking(), _traffic, _player)
	# Gli autobus della stazione, stesso principio. Ci sono dall'inizio, come
	# la stazione: lo sblocco di Kevin apre solo lo sportello (vedi `BusDepot`).
	var depot := BusDepot.new()
	depot.name = "BusDepot"
	add_child(depot)
	depot.setup(CityMap.bus_depot(), _traffic, _player)

## Pianta un edificio nell'albero e, se è cliccabile, lo tiene anche in
## `_enterable_buildings`: vedi il commento lì.
func _add_building(node: Node2D) -> void:
	_buildings.add_child(node)
	if node is EnterableBuilding:
		_enterable_buildings.append(node)

## Un edificio: il suo PNG, con lo script che lo rende cliccabile.
##
## Un ramo solo, adesso: ogni voce della pianta ha la sua `texture`. Prima ce
## n'era un secondo per i segnaposto — rettangolo colorato, insegna scritta
## sopra, finestre che si accendevano la sera — e serviva a riempire i quartieri
## di cui non c'è il disegno. Quei quartieri adesso restano vuoti apposta: vedi
## `BUILT_DISTRICTS` in `city_map.gd`.
func _make_building(entry: Dictionary) -> Node2D:
	var node := Sprite2D.new()
	node.texture = load(str(entry["texture"]))
	node.centered = false
	node.offset = entry.get("offset", Vector2.ZERO)
	node.name = str(entry["id"])
	node.position = entry["base"]
	# `frames` dice che la texture non e' un disegno solo ma una striscia di
	# fotogrammi affiancati: l'officina, che la sera tira giu' la serranda. Lo
	# sprite ne disegna uno per volta e a sceglierlo e' `shop_shutter.gd`, che
	# sta in un figlio perche' qui lo script e' gia' occupato da
	# `enterable_building.gd`. Vedi `blender_officina.py`.
	var frames := int(entry.get("frames", 1))
	if frames > 1:
		node.hframes = frames
	# Le finestre accese: un secondo PNG appoggiato sopra, con lo stesso
	# scostamento del disegno. Figlio dell'edificio e non nodo a sé — come
	# l'insegna — così segue il muro dovunque vada. Vedi `building_lights.gd`.
	if entry.has("lit"):
		var lights := Sprite2D.new()
		lights.name = "Lights"
		lights.texture = load(str(entry["lit"]))
		lights.centered = false
		lights.offset = node.offset
		lights.set_script(BUILDING_LIGHTS)
		node.add_child(lights)
	# Le cose che si muovono col vento — la girandola, la bandiera — sono
	# strisce di fotogrammi a parte, gia' allineate al disegno. Dopo le luci e
	# non prima: una bandiera davanti a una finestra accesa la copre, com'e'
	# giusto. Vedi `wind_prop.gd`.
	for anim: Dictionary in entry.get("anims", []):
		var prop := Sprite2D.new()
		prop.set_script(WIND_PROP)
		prop.name = str(anim["texture"]).get_file().get_basename()
		node.add_child(prop)
		prop.setup(anim)
	# `glass` e' la maschera del vetro dei grattacieli: dice allo shader quali
	# pixel riflettono il sole e in che direzione guardano. Il riflesso non sta
	# nel disegno — cambia con l'ora, e nel disegno sarebbe fermo. Vedi
	# `sun_glass.gd` e `scripts_tools/blender_grattacieli.py`. Sta prima
	# dell'uscita dei fondali: anche il terminal dell'aeroporto, che non si
	# clicca, ha il vetro.
	if entry.has("glass"):
		var vetro := ShaderMaterial.new()
		vetro.shader = GLASS_SHEEN
		vetro.set_shader_parameter("maschera", load(str(entry["glass"])))
		node.material = vetro
		var sole := Node.new()
		sole.name = "SunGlass"
		sole.set_script(SUN_GLASS)
		node.add_child(sole)
	# I fondali dentro agli isolati restano uno sprite e basta: murati dietro
	# alla fila che dà sulla strada, non hanno una porta a cui andare, e un
	# click che manda il protagonista a sbattere contro il muro davanti sarebbe
	# peggio di un click che non fa niente.
	if bool(entry.get("backdrop", false)):
		return node

	node.set_script(ENTERABLE)
	if entry.has("click"):
		node.click_rect = entry["click"]
	node.interior_scene = str(entry.get("interior", ""))
	node.window_scene = str(entry.get("window", ""))
	node.window_flag = str(entry.get("window_flag", ""))
	node.display_name = str(entry.get("label", ""))
	node.building_id = str(entry["id"])
	node.needs_ownership = bool(entry.get("owned", false))
	node.entry_offset = _entry_offset(entry)
	# L'insegna è figlia dell'edificio e non un nodo a sé: così segue la
	# schiacciata del click e la luce dell'ora come fosse dipinta sul muro, che
	# è quello che deve sembrare.
	if frames > 1:
		var shutter := Node.new()
		shutter.name = "Shutter"
		shutter.set_script(SHOP_SHUTTER)
		node.add_child(shutter)
	if entry.has("sign"):
		var sign := Sprite2D.new()
		sign.name = "Sign"
		sign.texture = load(str(entry["sign"]))
		sign.centered = false
		sign.position = entry.get("sign_at", Vector2.ZERO)
		node.add_child(sign)
	return node

## Dove si ferma il protagonista davanti a un edificio.
##
## `front` dice su quale lato della strada sta l'edificio, quindi da che parte
## è il marciapiede. Gli edifici a sud di una strada hanno la base *sotto* la
## carreggiata, col corpo che sale fino al marciapiede: per loro "davanti" è
## sopra, non sotto, altrimenti il protagonista andrebbe a parcheggiarsi dietro
## al muro. Stessa cosa, ruotata, per quelli sulle strade verticali.
func _entry_offset(entry: Dictionary) -> Vector2:
	if entry.has("entry"):
		return entry["entry"]
	var size: Vector2 = entry["size"]
	match str(entry.get("front", "north")):
		"south":
			return Vector2(0, -size.y - APPROACH)
		"west":
			return Vector2(size.x * 0.5 + APPROACH, 0)
		"east":
			return Vector2(-size.x * 0.5 - APPROACH, 0)
		_:
			return Vector2(0, APPROACH)

func _build_traffic() -> void:
	for lane in CityMap.lanes():
		var count := int(lane["cars"])
		for i in count:
			var car := CAR.instantiate()
			_traffic.add_child(car)
			# Il mezzo è pescato a caso, non a giro fisso su un elenco: per
			# strada capita di tutto, e un ciclo regolare si legge come una
			# fila ordinata di modelli che si ripete.
			car.setup(lane, float(i) / float(count), Car.random_vehicle())
			car.watch = _player

# --- Stato della partita ---------------------------------------------------

## Ricostruisce la mappa a partire dai dati della partita. È qui che andranno
## anche gli edifici posseduti e lo stato della storia man mano che esistono:
## la scena si costruisce dai dati, mai il contrario.
func _apply_state(data: SaveData) -> void:
	_player.global_position = data.player_position
	# Un appuntamento fissato mentre si era in cantina, o lasciato aperto
	# chiudendo il gioco: tornando in strada Brian deve essere lì ad aspettare.
	if SeedDeal.is_ready(data):
		_spawn_brian()
	# Il furgone comprato e fermo: deve essere già lì entrando in strada, non
	# comparire solo quando parte.
	_refresh_parked_van()

# --- L'appuntamento con Brian ---------------------------------------------

## Tira su Brian dove aspetta. Passa da `SeedDeal.npc_entry()`, che ha la stessa
## forma di una riga del roster: l'NPC non deve sapere se viene da lì o da un
## appuntamento.
func _spawn_brian() -> void:
	if _npcs.has_node(SeedDeal.NPC_ID):
		return
	var npc := NPC.instantiate()
	_npcs.add_child(npc)
	npc.setup(SeedDeal.npc_entry(GameState.current))

func _on_seed_spot_ready(spot: Vector2, _place: String) -> void:
	_spawn_brian()
	# Un'onda sul posto, più larga e più lenta di quella del click: se il punto
	# è già in vista lega il messaggio appena arrivato a un punto della mappa.
	# Se è fuori schermo non si perde niente — a dire dove andare è il testo
	# della notifica, e sul posto c'è il rombo verde sopra la testa di Brian.
	var ripple := RIPPLE.instantiate()
	ripple.position = spot
	ripple.duration = 1.2
	ripple.max_radius = 44.0
	ripple.rings = 3
	ripple.color = Npc.MARKER_SELLER
	_effects.add_child(ripple)

# --- Il furgone dell'ingrosso ----------------------------------------------

## Il furgone fermo a fianco di casa. È un nodo solo, tenuto in vita finché il
## mezzo è in sosta: `null` quando non lo si è ancora comprato e mentre è via.
var _parked_van: Node2D = null

## Rimette d'accordo quello che si vede con quello che dice `Delivery`:
## parcheggiato se è comprato e fermo, niente in tutti gli altri casi.
##
## Si chiama entrando in strada e a ogni partenza o rientro, invece di
## controllare ogni fotogramma: lo stato del furgone cambia solo in quei tre
## momenti, ed è la stessa regola di tutto il resto — si guarda il dato quando
## serve, non si tiene in vita un contatore.
func _refresh_parked_van() -> void:
	var data := GameState.current
	# **Tutti e tre i viaggi, non solo la consegna.** Il furgone è uno: quello
	# che porta la merce all'ingrosso è lo stesso che va a ritirare i semi dal
	# grossista (`SeedRun`) o dal contatto fuori stato di Kevin (`BusImport`),
	# e `can_order` lo sa già — non si può ordinare mentre è fuori. Qui invece
	# si guardava solo `Delivery`, e il risultato era che ordinati i semi il
	# furgone restava parcheggiato nel vialetto per tutte le ore del viaggio.
	# Peggio: al rientro `_on_van_back` trova un furgone già in sosta e non fa
	# niente, quindi non si vedeva nemmeno arrivare. Il giro dei semi è proprio
	# quello in cui si torna a casa a piedi, cioè quello in cui lo si guarda.
	var should_park := (
		data != null and Delivery.has_van(data)
		and not Delivery.is_running(data) and not SeedRun.is_running(data)
		and not BusImport.holds_van(data))
	if not should_park:
		if _parked_van != null and is_instance_valid(_parked_van):
			_parked_van.queue_free()
		_parked_van = null
		return
	if _parked_van != null and is_instance_valid(_parked_van):
		return
	_parked_van = DELIVERY_VAN.instantiate()
	_traffic.add_child(_parked_van)
	_parked_van.park(CityMap.van_parking())

## Parte: se c'è il furgone in sosta è **quello** a muoversi, non una copia.
## Vederne uno uscire mentre l'altro resta parcheggiato butterebbe a terra tutta
## la finzione.
## Parte. Il parametro è quello che sta andando a muovere — grammi da vendere o
## semi da ritirare — e qui non serve: quello che si vede è il furgone che esce.
func _on_van_left(_carico: int) -> void:
	var van := _parked_van
	if van == null or not is_instance_valid(van):
		van = DELIVERY_VAN.instantiate()
		_traffic.add_child(van)
	_parked_van = null
	van.drive_out(CityMap.van_parking(), _lane_y(), func() -> void: pass)

## Rientra e parcheggia: nessun filmato, solo il mezzo che si rimette al suo
## posto. Tornare a casa non ha bisogno di essere raccontato.
##
## Vale sia per il carico venduto sia per i semi ritirati dal grossista: il
## furgone è lo stesso, e l'unica differenza — cosa c'è dentro — l'ha già detta
## il messaggino.
func _on_van_back(_carico: int) -> void:
	if _parked_van != null and is_instance_valid(_parked_van):
		return
	var van := DELIVERY_VAN.instantiate()
	_traffic.add_child(van)
	_parked_van = van
	van.drive_in(CityMap.van_parking(), _lane_y(), func() -> void: pass)

## La corsia verso est di MAIN STREET: quella in cui il furgone si immette
## uscendo e da cui esce rientrando. È la stessa in cui va il traffico
## (`CityMap.lanes()`, 24 px dal bordo sud dell'asfalto): un furgone che
## scivola in mezzo alla carreggiata si legge come un errore.
func _lane_y() -> float:
	return (CityMap.ROADS_H[0] as Rect2).end.y - 24.0

func _on_seed_deal_closed() -> void:
	if _npcs.has_node(SeedDeal.NPC_ID):
		_npcs.get_node(SeedDeal.NPC_ID).queue_free()
	# Un appuntamento chiuso è un punto di controllo: i semi comprati e i soldi
	# spesi non devono dipendere dal prossimo salvataggio automatico.
	GameState.save_game()

## Riversa nella partita quello che la mappa sa (per ora solo dove sta il
## giocatore). Agganciata al segnale `GameState.saving`, quindi vale per ogni
## scrittura: quella volontaria, quella automatica e quella alla chiusura.
func _collect_state() -> void:
	if GameState.current == null:
		return
	GameState.current.player_position = _player.global_position

func save() -> void:
	if not interactive or GameState.current == null:
		return
	GameState.save_game()

## Chiudendo la finestra si salva comunque, così non si perde la sessione.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()

# --- Il nome sotto al puntatore --------------------------------------------

## Costruita da codice e non messa in `City.tscn` per la stessa ragione di tutto
## il resto della mappa: la scena contiene i contenitori, il contenuto lo mette
## chi lo sa usare. Sta su una tela sua perché segue il puntatore in coordinate
## di schermo, e con la camera che si muove e zooma un nodo del mondo dovrebbe
## rifare quel conto al contrario a ogni fotogramma.
##
## Sotto all'HUD (layer 5) e sotto alle finestre: è la scritta meno importante
## che ci sia, e non deve mai coprire un numero o un bottone.
func _build_hover_label() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HoverLayer"
	layer.layer = 4
	add_child(layer)

	_hover_label = Label.new()
	_hover_label.name = "BuildingName"
	_hover_label.visible = false
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# È un'insegna, cioè un nome proprio: tradurla la sposterebbe in un'altra
	# città. Vedi la nota in cima a `strings.gd`.
	_hover_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hover_label.add_theme_color_override("font_color", HOVER_COLOR)
	# Pennello (un'insegna è sempre di sole lettere) con l'ombra dura al posto
	# del riquadro, come nell'HUD: sotto la scritta può passarci un muro
	# chiaro, l'asfalto o il cielo.
	UiTheme.dress_world_text(_hover_label, "", UiTheme.brush_size(HOVER_SIZE), HOVER_SIZE,
		UiTheme.W_REGULAR, Color(0, 0, 0, 0.85))
	layer.add_child(_hover_label)

func _process(_delta: float) -> void:
	if _hover_label == null:
		return
	_hover_label.visible = false
	if UiTheme.modal_open():
		return
	var building := _building_at(get_global_mouse_position())
	if building == null or building.display_name.is_empty():
		return
	if _hover_shown != building.display_name:
		_hover_shown = building.display_name
		_hover_label.text = building.display_name
		UiTheme.dress_world_text(_hover_label, building.display_name,
			UiTheme.brush_size(HOVER_SIZE), HOVER_SIZE, UiTheme.W_REGULAR,
			Color(0, 0, 0, 0.85))
	_hover_label.visible = true
	_place_hover()

## Mette l'etichetta accanto al puntatore, dalla parte in cui ci sta. Vicino al
## bordo destro o in cima allo schermo si ribalta invece di essere tagliata: un
## nome mezzo fuori non si legge, ed è proprio agli edifici sul bordo che si
## guarda per capire dove si sta andando.
func _place_hover() -> void:
	var mouse := _hover_label.get_viewport().get_mouse_position()
	var screen := Vector2(_hover_label.get_viewport_rect().size)
	var size := _hover_label.get_minimum_size()
	var at := mouse + HOVER_NUDGE
	if at.x + size.x > screen.x - HOVER_MARGIN:
		at.x = mouse.x - HOVER_NUDGE.x - size.x
	if at.y < HOVER_MARGIN:
		at.y = mouse.y - HOVER_NUDGE.y
	_hover_label.position = at.round()

# --- Comandi ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event.is_action_pressed("ui_cancel"):
		save()
		get_tree().change_scene_to_file(MAIN_MENU)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		# Le persone hanno la precedenza sugli edifici: stanno davanti, e chi
		# clicca su un passante fermo davanti a un negozio vuole il passante.
		var npc := _npc_at(point)
		if npc != null:
			_go_talk(npc)
			return
		var building := _building_at(point)
		if building != null:
			_go_enter(building)
			return
		# Nelle montagne non si va. La griglia dei percorsi copre la citta' e
		# basta (`CityMap.WORLD_BOUNDS`), e un click fuori le veniva accostato
		# alla cella di bordo piu' vicina mentre la destinazione restava quella
		# cliccata: il protagonista usciva dalla mappa e si incamminava dentro
		# a un monte. Un click li' non e' un ordine, e' un click a vuoto.
		if not CityMap.WORLD_BOUNDS.has_point(point):
			return
		_order_move(point)

func _order_move(target: Vector2) -> void:
	# Un click altrove annulla quello che si stava andando a fare.
	_entering = null
	_talking_to = null
	_walk_to(target)
	var ripple := RIPPLE.instantiate()
	ripple.position = target
	_effects.add_child(ripple)

## Manda il protagonista a un punto seguendo le strade.
##
## Se un percorso non si trova — un bersaglio murato, o una pianta della città
## che cambia sotto ai piedi — si va comunque in linea retta: meglio un tragitto
## brutto che un personaggio che ignora il click e sembra rotto.
func _walk_to(target: Vector2) -> void:
	var path := _navigation.find_path(_player.global_position, target)
	if path.is_empty():
		_player.move_to(target)
	else:
		_player.follow_path(path)
	_camera.recenter()

## Edificio visitabile sotto al punto indicato. Se due si sovrappongono vince
## quello più in basso, cioè quello che l'Y-sort disegna davanti: è quello che
## il giocatore vede e crede di aver cliccato.
##
## `>=` e non `>`: a parità di y l'Y-sort disegna davanti l'ULTIMO dell'albero,
## e il gruppo li elenca nello stesso ordine. Con `>` vinceva il primo, cioè
## quello disegnato dietro — e su tre edifici che poggiano sulla stessa riga di
## terra il nome che compariva era quello dell'edificio nascosto.
func _building_at(point: Vector2) -> EnterableBuilding:
	var found: EnterableBuilding = null
	for building in _enterable_buildings:
		if not building.contains_point(point):
			continue
		if found == null or building.global_position.y >= found.global_position.y:
			found = building
	return found

## Stessa regola per le persone, per lo stesso motivo.
func _npc_at(point: Vector2) -> Npc:
	var found: Npc = null
	for npc in get_tree().get_nodes_in_group(Npc.GROUP):
		if not npc.contains_point(point):
			continue
		if found == null or npc.global_position.y > found.global_position.y:
			found = npc
	return found

func _go_enter(building: EnterableBuilding) -> void:
	building.press()
	_talking_to = null
	if not building.can_open():
		# Edificio cliccabile ma non visitabile: ci si avvicina e basta. Una
		# proprietà in vendita lo dice, perché lì la porta chiusa è una regola
		# del gioco e non un muro — sapere che si apre comprandola è metà del
		# motivo per andare in agenzia.
		if not building.is_unlocked():
			# Chiusa per un flag (la stazione prima del contatto di Kevin) o
			# perche' non e' roba propria: due porte chiuse diverse.
			GameState.notify(tr("NOTE_NO_CONTACT" if not building.window_flag.is_empty()
				else "NOTE_NOT_YOURS"))
		_order_move(building.entry_point())
		return
	_entering = building
	_walk_to(building.entry_point())

func _go_talk(npc: Npc) -> void:
	npc.acknowledge()
	_entering = null
	_talking_to = npc
	_walk_to(npc.approach_point())

func _on_player_arrived() -> void:
	if _talking_to != null:
		var npc := _talking_to
		_talking_to = null
		npc.talk(_dialogue)
		return
	if _entering == null:
		return
	var building := _entering
	_entering = null
	# Sportello e non porta: il protagonista resta sul marciapiede e la finestra
	# si apre sopra la citta'. Niente `vanish()`, niente cambio scena, niente
	# salvataggio — non si e' mosso da dove si vede che e' fermo.
	if not building.window_scene.is_empty():
		var finestra: PackedScene = load(building.window_scene)
		if finestra != null:
			add_child(finestra.instantiate())
		return
	await _player.vanish().finished
	# La posizione salvata è quella davanti alla porta: uscendo di casa il
	# protagonista ricompare lì, non dove era prima di incamminarsi.
	GameState.current.player_position = building.entry_point()
	# Si salva PRIMA di cambiare scena: dopo, questo nodo non esiste più e
	# nessuno saprebbe più dire dov'era il protagonista.
	GameState.save_game()
	get_tree().change_scene_to_file(building.interior_scene)
