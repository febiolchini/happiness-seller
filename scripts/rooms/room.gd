extends Control

## Stanza interna a un edificio.
##
## Per ora è volutamente vuota: c'è solo il protagonista in grande e fermo, il
## nome della stanza in alto e i collegamenti alle altre stanze in basso. Quando
## arriveranno i fondali pixel art basterà aggiungerli sotto a `Background`.
##
## Tutte le stanze condividono questo script: `Entrance`, `Kitchen` e `Basement`
## sono scene ereditate che cambiano solo nome, colore e uscite.

const EXIT_BUTTON := preload("res://scenes/ui/MenuTextButton.tscn")
const HAND_CURSOR := preload("res://assets/sprites/ui/cursors/hand_open.png")
const HAND_HOTSPOT := Vector2(22, 22)

## Nome mostrato in alto. In inglese, come tutte le scritte delle stanze.
@export var room_name := "ROOM"
## Uscite, nell'ordine in cui compaiono: etichetta -> scena di destinazione.
@export var exits: Dictionary = {}
@export var background_color := Color(0.13, 0.12, 0.15)

@onready var _background: ColorRect = $Background
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
