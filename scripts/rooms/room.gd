extends Control

## Stanza interna a un edificio.
##
## C'è il nome della stanza in alto, l'uscita in basso, e sopra a tutto
## l'atmosfera: la luce che cambia con l'ora, il taglio di sole dalla finestra,
## la pioggia sui vetri. Il protagonista non c'è più: il gioco è un gestionale,
## e una stanza è il posto in cui stanno i vasi, non uno in cui si cammina.
##
## Tutte le stanze condividono questo script: `Basement`, `Garage` e `Office`
## sono scene ereditate che cambiano solo nome, colore, uscite e finestra. Le
## stanze di casa sono una sola, il seminterrato: cucina e ingresso sono state
## tolte insieme alla camminata, e cliccando casa si apre direttamente lì.
##
## ## L'atmosfera si costruisce, non si mette nella scena
##
## `Room.tscn` è la scena base delle altre tre, che si riferiscono ai propri
## nodi per indice: aggiungere un nodo lì dentro sposterebbe quegli indici e
## andrebbero risistemate tutte e tre a mano. Costruiti qui, il
## `CanvasModulate` e il velo dell'atmosfera arrivano in ogni stanza senza che
## nessuna scena venga toccata — la stessa regola della città, dove strade ed
## edifici li costruisce `city.gd` e il `.tscn` contiene solo i contenitori.

const EXIT_BUTTON := preload("res://scenes/ui/MenuTextButton.tscn")
const ROOM_AMBIENCE := preload("res://scripts/systems/room_ambience.gd")
const HAND_CURSOR := preload("res://assets/sprites/ui/cursors/hand_open.png")
const HAND_HOTSPOT := Vector2(22, 22)
const BACKDROP_ANIMATION := preload("res://scripts/rooms/backdrop_animation.gd")

## Nome mostrato in alto. In inglese, come tutte le scritte delle stanze.
@export var room_name := "ROOM"
## Uscite, nell'ordine in cui compaiono: etichetta -> scena di destinazione.
@export var exits: Dictionary = {}
@export var background_color := Color(0.13, 0.12, 0.15)

## La stanza vede la luce di fuori?
##
## Falso per la cantina, che sottoterra non ha né ora né tempo: è anche il
## motivo per cui si perde la cognizione del tempo a coltivare di sotto, e
## l'orologio dell'HUD diventa l'unico modo di sapere che ore sono.
@export var daylight := true

## Dove sta la finestra nel fondale, in coordinate della stanza (640x360).
## Un rettangolo vuoto vuol dire nessuna finestra: niente taglio di luce sul
## pavimento, niente pioggia sul vetro, niente lampo che entra.
##
## Va misurato sul fondale COME SI VEDE a schermo, non sul PNG: il `Backdrop`
## usa "keep aspect covered", quindi l'immagine viene ritagliata.
@export var window_rect := Rect2()
## La stessa finestra per angoli, quando è vista di sbieco: in alto a
## sinistra, in alto a destra, in basso a destra, in basso a sinistra. Vuoto per
## le finestre viste di fronte, che bastano col rettangolo. Se c'è, vince su
## `window_rect` — vedi `room_ambience.gd::_quad`.
@export var window_quad := PackedVector2Array()

## Quale stanza di `RoomArt.ROOMS` è questa: da lì vengono le animazioni del
## fondale (il lampadario che dondola, la fiamma della caldaia). Vuoto = un
## fondale fermo, o nessun fondale.
@export var art := ""

## Per una stanza in alto in un grattacielo: da quale edificio della pianta
## (`CityMap.BUILDINGS`) e da che piano si guarda fuori. Con questi due, dietro
## ai vetri trasparenti del fondale si vede la città vera (`WindowView`) invece
## del cielo dipinto. Vuoto = una finestra normale.
@export var view_building := ""
@export var view_floor := 0

var _window_view: WindowView = null

@onready var _background: ColorRect = $Background
@onready var _backdrop: TextureRect = $Backdrop
@onready var _title: Label = $Title
@onready var _exits_box: HBoxContainer = $Exits

func _ready() -> void:
	Input.set_custom_mouse_cursor(HAND_CURSOR, Input.CURSOR_ARROW, HAND_HOTSPOT)
	_background.color = background_color
	_title.text = room_name
	# Pennello (il nome di una stanza è sempre di sole parole) con l'ombra
	# dura già scritta nella scena, Nunito altrimenti — come ovunque il testo
	# sta sopra a un fondale e non su carta.
	UiTheme.dress_world_text(_title, room_name, 24, 18, UiTheme.W_REGULAR,
		Color(0, 0, 0, 0.7))

	# Aprendo una stanza direttamente dall'editor non si passa dal menu.
	if GameState.current == null:
		GameState.new_game()
	# Chi entra qui è "dentro": così chiudendo il gioco e riprendendo la partita
	# si torna in questa stanza invece che in mezzo alla strada.
	GameState.current.current_room = scene_file_path
	GameState.clock_running = true
	# Entrare in una stanza è un punto di controllo: riprendendo la partita si
	# torna qui dentro. Senza questa scrittura il salvataggio continuerebbe a
	# dire "in strada" fino al primo salvataggio automatico.
	GameState.save_game()

	for label in exits:
		var exit := _build_exit(str(label), str(exits[label]))
		_exits_box.add_child(exit)
		# Due pixel di respiro oltre alla misura del testo. Il contenitore
		# stringe ogni bottone esattamente a quella, e col pennello —
		# rimpicciolito da 56 px a 18, con le frazioni che si arrotondano —
		# l'ultima lettera sforava di un niente e spariva: "ENTRANC". Dopo
		# `add_child()`: fuori dall'albero la chiave non e' ancora tradotta, e
		# si misurerebbe "ROOM_BASEMENT".
		exit.custom_minimum_size.x = exit.get_minimum_size().x + 2.0

	_build_window_view()
	_build_backdrop_animations()
	_build_ambience()

## Tira su la luce della stanza: un `CanvasModulate` che tinge tutto quello che
## sta sulla tela della stanza — fondale, vasi, lampade — e sopra
## il velo che disegna il taglio di sole, la pioggia sul vetro e il pulviscolo.
##
## L'HUD non viene toccato: sta su una tela sua (`CanvasLayer`), e un
## `CanvasModulate` non attraversa le tele. Vale qui come in City.
func _build_ambience() -> void:
	var tint := CanvasModulate.new()
	tint.name = "RoomLight"
	add_child(tint)
	var ambience: Control = ROOM_AMBIENCE.new()
	ambience.name = "RoomAmbience"
	# Nome della stanza e uscite sono interfaccia: la luce della sera non deve
	# spegnerli. Vedi `room_ambience.gd::_keep_readable()`.
	# La vista ha gia' la luce di fuori: la tinta della stanza non ci si deve
	# sommare sopra, quindi si compensa come le scritte.
	var readable: Array = [_title, _exits_box]
	if _window_view != null:
		readable.append(_window_view)
	ambience.setup(tint, daylight, window_rect, readable, window_quad, _window_view != null)
	add_child(ambience)

## La città vista dalla vetrata. Figlia del `Background` e non della stanza:
## si disegna dopo il fondo e PRIMA del fondale, che la copre tutta tranne dove
## ha i vetri trasparenti — ed e' li' che si vede. Non sposta gli indici dei
## nodi, per la stessa ragione delle animazioni qui sotto.
func _build_window_view() -> void:
	if view_building.is_empty():
		return
	var rect := window_rect
	if window_quad.size() == 4:
		rect = Rect2(window_quad[0], Vector2.ZERO)
		for corner in window_quad:
			rect = rect.expand(corner)
	rect = Rect2(rect.position.floor(), rect.size.ceil() + Vector2.ONE)
	_window_view = WindowView.new()
	_window_view.setup(rect, view_building, view_floor)
	_background.add_child(_window_view)

## Appoggia sopra al fondale i pezzi che si muovono.
##
## Sono figli del `Backdrop` e non della stanza per due ragioni: si disegnano
## subito dopo il fondale e prima di tutto il resto (vasi, lampade), com'è giusto per un pezzo di fondale; e non spostano gli indici
## dei nodi, che le scene ereditate usano per riferirsi ai propri — vedi il
## commento in testa. Le coordinate della tabella sono pixel di schermo, e il
## `Backdrop` copre lo schermo a scala uno con un fondale da 640x360.
func _build_backdrop_animations() -> void:
	if art.is_empty():
		return
	var room: Dictionary = RoomArt.ROOMS.get(art, {})
	for entry in room.get("animations", []):
		var piece: Sprite2D = BACKDROP_ANIMATION.new()
		piece.setup(entry)
		_backdrop.add_child(piece)

func _exit_tree() -> void:
	GameState.clock_running = false

func _build_exit(label: String, target_scene: String) -> Button:
	var button := EXIT_BUTTON.instantiate()
	button.text = label
	button.target_scene = target_scene
	return button

## Uscendo dal gioco da qui la partita si salva comunque, stanza compresa.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and GameState.current != null:
		GameState.save_game()
