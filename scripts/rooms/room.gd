extends Control

## Stanza interna a un edificio.
##
## C'è il protagonista in grande e fermo, il nome della stanza in alto, i
## collegamenti alle altre stanze in basso, e sopra a tutto l'atmosfera: la luce
## che cambia con l'ora, il taglio di sole dalla finestra, la pioggia sui vetri.
##
## Tutte le stanze condividono questo script: `Entrance`, `Kitchen` e `Basement`
## sono scene ereditate che cambiano solo nome, colore, uscite e finestra.
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
const PHONE := preload("res://scenes/ui/Phone.tscn")
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

@onready var _background: ColorRect = $Background
@onready var _backdrop: TextureRect = $Backdrop
@onready var _title: Label = $Title
@onready var _exits_box: HBoxContainer = $Exits

func _ready() -> void:
	Input.set_custom_mouse_cursor(HAND_CURSOR, Input.CURSOR_ARROW, HAND_HOTSPOT)
	_background.color = background_color
	_title.text = room_name

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
		_exits_box.add_child(_build_exit(str(label), str(exits[label])))

	_build_backdrop_animations()
	_build_ambience()
	# Il telefono c'è anche in casa: i semi finiscono mentre si annaffia in
	# cantina, ed è lì che serve poter chiamare Brian. Costruito da codice per
	# la stessa ragione dell'atmosfera — vedi `_build_ambience()`.
	add_child(PHONE.instantiate())

## Tira su la luce della stanza: un `CanvasModulate` che tinge tutto quello che
## sta sulla tela della stanza — fondale, protagonista, vasi, lampade — e sopra
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
	ambience.setup(tint, daylight, window_rect, [_title, _exits_box], window_quad)
	add_child(ambience)

## Appoggia sopra al fondale i pezzi che si muovono.
##
## Sono figli del `Backdrop` e non della stanza per due ragioni: si disegnano
## subito dopo il fondale e prima di tutto il resto (protagonista, vasi,
## lampade), com'è giusto per un pezzo di fondale; e non spostano gli indici
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
