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
## Esc = menu principale, tasto destro trascinando = pan, rotellina = zoom.

const TILE_SIZE := 32
const MAIN_MENU := "res://scenes/main/Main.tscn"
const RIPPLE := preload("res://scenes/components/ClickRipple.tscn")
const PLACEHOLDER := preload("res://scenes/components/BuildingPlaceholder.tscn")
const ENTERABLE := preload("res://scripts/components/enterable_building.gd")
const NPC := preload("res://scenes/characters/Npc.tscn")
const CAR := preload("res://scenes/components/Car.tscn")
const FOUNTAIN := preload("res://scenes/components/Fountain.tscn")

## Quanto lontano dalla facciata si ferma il protagonista.
const APPROACH := 26.0

## Carrozzerie delle auto segnaposto: colori smorti da utilitaria vissuta.
const CAR_COLORS := [
	Color(0.541, 0.271, 0.243), Color(0.278, 0.353, 0.451),
	Color(0.588, 0.561, 0.478), Color(0.294, 0.400, 0.310),
	Color(0.647, 0.596, 0.267), Color(0.400, 0.365, 0.400),
	Color(0.741, 0.729, 0.706), Color(0.310, 0.322, 0.341),
]

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
@onready var _dialogue: CanvasLayer = $DialogueBox

## Il reticolo su cui si cammina. Costruito una volta dalla stessa pianta che
## costruisce gli edifici, così non possono divergere.
var _navigation := CityNavigation.new()

## Edificio in cui si sta entrando: il protagonista ci sta camminando verso.
var _entering: EnterableBuilding = null
## Personaggio con cui si sta andando a parlare.
var _talking_to: Npc = null

func _ready() -> void:
	# La città si costruisce sempre, anche da sfondo del menu: dietro ai
	# bottoni si vede il quartiere vero, con le auto che passano.
	_build_city()

	# Da sfondo di un menu la mappa non deve toccare la partita in corso,
	# e nemmeno mostrare l'HUD dietro ai bottoni.
	_hud.enabled = interactive
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
	_camera.set_bounds(CityMap.WORLD_BOUNDS)

	# Dove sta il protagonista lo sa solo la scena, non `SaveData`: prima di
	# ogni scrittura su disco lo riversiamo noi. Vale anche per i salvataggi
	# automatici, che partono da `GameState` e non passano di qui.
	GameState.saving.connect(_collect_state)
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
	for entry in buildings:
		_buildings.add_child(_make_building(entry))
	# Da sfondo di un menu non si cammina, e costruire la griglia costerebbe
	# un caricamento in più per niente.
	if interactive:
		_navigation.build(buildings)
	for point in CityMap.FOUNTAINS:
		var fountain := FOUNTAIN.instantiate()
		fountain.position = point
		_props.add_child(fountain)
	for entry in NpcRoster.NPCS:
		var npc := NPC.instantiate()
		_npcs.add_child(npc)
		# `setup()` dopo `add_child()`: sceglie una tappa a caso e ci si
		# posiziona, e per farlo deve essere già nell'albero.
		npc.setup(entry)
	_build_traffic()

## Un edificio: `Sprite2D` se ha già il PNG, segnaposto disegnato se no. In
## entrambi i casi finisce con lo stesso script addosso e lo stesso
## comportamento al click — è quello che rende la sostituzione indolore.
func _make_building(entry: Dictionary) -> Node2D:
	var node: Node2D
	if entry.has("texture"):
		var sprite := Sprite2D.new()
		sprite.texture = load(str(entry["texture"]))
		sprite.centered = false
		sprite.offset = entry.get("offset", Vector2.ZERO)
		sprite.set_script(ENTERABLE)
		if entry.has("click"):
			sprite.click_rect = entry["click"]
		node = sprite
	else:
		var placeholder := PLACEHOLDER.instantiate()
		placeholder.size = entry["size"]
		placeholder.label = str(entry["label"])
		placeholder.fill_color = entry["color"]
		placeholder.floors = int(entry.get("floors", 1))
		node = placeholder

	node.name = str(entry["id"])
	node.position = entry["base"]
	node.interior_scene = str(entry.get("interior", ""))
	node.entry_offset = _entry_offset(entry)
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
	var index := 0
	for lane in CityMap.lanes():
		var count := int(lane["cars"])
		for i in count:
			var car := CAR.instantiate()
			_traffic.add_child(car)
			car.setup(lane, float(i) / float(count), CAR_COLORS[index % CAR_COLORS.size()])
			car.watch = _player
			index += 1

# --- Stato della partita ---------------------------------------------------

## Ricostruisce la mappa a partire dai dati della partita. È qui che andranno
## anche gli edifici posseduti e lo stato della storia man mano che esistono:
## la scena si costruisce dai dati, mai il contrario.
func _apply_state(data: SaveData) -> void:
	_player.global_position = data.player_position

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
func _building_at(point: Vector2) -> EnterableBuilding:
	var found: EnterableBuilding = null
	for building in get_tree().get_nodes_in_group(EnterableBuilding.GROUP):
		if not building.contains_point(point):
			continue
		if found == null or building.global_position.y > found.global_position.y:
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
	if building.interior_scene.is_empty():
		# Edificio cliccabile ma non ancora visitabile: ci si avvicina e basta.
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
	await _player.vanish().finished
	# La posizione salvata è quella davanti alla porta: uscendo di casa il
	# protagonista ricompare lì, non dove era prima di incamminarsi.
	GameState.current.player_position = building.entry_point()
	# Si salva PRIMA di cambiare scena: dopo, questo nodo non esiste più e
	# nessuno saprebbe più dire dov'era il protagonista.
	GameState.save_game()
	get_tree().change_scene_to_file(building.interior_scene)
