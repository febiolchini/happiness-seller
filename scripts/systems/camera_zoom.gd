extends Camera2D

## Zoom della mappa con la rotellina, pensato per restare sempre pixel-perfect.
##
## Il progetto usa stretch mode "canvas_items": la finestra reale (es. 1280x720)
## viene divisa per la risoluzione di design (640x360), quindi ogni cosa è già
## moltiplicata per un fattore di stretch (2 a 720p). La nitidezza dipende dalla
## SCALA NETTA = zoom * stretch: se è intera, un pixel dello sprite copre un
## numero esatto di pixel a schermo e resta netto; se è frazionaria (es. 2.81)
## alcuni pixel ne occupano 2 e altri 3, e l'immagine "balla".
##
## Per questo lo zoom non è continuo ma scatta tra scale nette intere.

## Scale nette selezionabili: 1 = un pixel sprite per pixel schermo (vista più
## larga sulla città), 8 = massimo avvicinamento.
##
## Devono essere INTERI >= 1, non ci sono vie di mezzo: a 1.5 un pixel dello
## sprite ne coprirebbe a volte 1 e a volte 2, e sotto a 1 lo sprite verrebbe
## rimpicciolito buttando via dettaglio. Per questo i passi intermedi possibili
## sono solo quelli interi, e sono tutti già elencati qui.
@export var net_scales: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
## Livello iniziale (indice in net_scales): 2x è la vista di default.
@export var default_level := 1
## Disattiva zoom, pan e cursore custom: usata quando la mappa è solo sfondo
## decorativo (es. dietro al menu principale) e non deve reagire al mouse.
@export var interactive := true

const HAND_OPEN := preload("res://assets/sprites/ui/cursors/hand_open.png")
const HAND_CLOSED := preload("res://assets/sprites/ui/cursors/hand_closed.png")
const HAND_CLICK := preload("res://assets/sprites/ui/cursors/hand_click.png")
const HAND_HOTSPOT := Vector2(22, 22)

## Nodo da seguire, di solito il protagonista. Lo assegna `city.gd`.
##
## La città è larga qualche migliaio di pixel: con una camera ferma il
## giocatore uscirebbe dallo schermo dopo tre passi e la mappa sarebbe
## inservibile. Il pan col tasto destro resta, ma diventa un'occhiata in giro.
var follow: Node2D = null

## Quanto velocemente la camera recupera il bersaglio. Non è una velocità in
## pixel: è la rapidità con cui si chiude la distanza, quindi il movimento
## parte deciso e arriva morbido senza dipendere dal frame rate.
const FOLLOW_SPEED := 6.0
## La camera guarda un po' sopra ai piedi del personaggio, altrimenti metà
## schermo è il pavimento davanti a lui.
const FOLLOW_OFFSET := Vector2(0, -24)

var _level := 0
var _panning := false
var _clicking := false
## Falso mentre il giocatore si sta guardando intorno col tasto destro: la
## camera resta dove l'ha lasciata finché non riprende a muoversi.
var _following := true
## Posizione continua della camera: `position` è la sua versione arrotondata.
## Serve per non perdere i movimenti di mouse più piccoli di un pixel mondo.
var _pan_position := Vector2.ZERO

func _ready() -> void:
	_validate_net_scales()
	_level = clampi(default_level, 0, net_scales.size() - 1)
	_pan_position = position
	_apply()
	get_window().size_changed.connect(_apply)
	if interactive:
		Input.set_custom_mouse_cursor(HAND_OPEN, Input.CURSOR_ARROW, HAND_HOTSPOT)

func _process(delta: float) -> void:
	if not _following or follow == null:
		return
	var target := follow.global_position + FOLLOW_OFFSET
	_pan_position = _pan_position.lerp(target, 1.0 - exp(-delta * FOLLOW_SPEED))
	_snap()

## Riattacca la camera al personaggio. La mappa la chiama quando il giocatore
## dà un ordine di movimento: chi ha appena cliccato dove andare vuole vedere
## dove sta andando, anche se un momento prima stava guardando altrove.
func recenter() -> void:
	_following = true

## Limita l'inquadratura ai confini del mondo, così non si finisce a guardare
## il vuoto oltre il bordo della città.
func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)

func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_step(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_step(-1)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
			if _panning:
				# Guardarsi intorno stacca la camera dal personaggio: se
				# continuasse a inseguirlo, il pan tornerebbe indietro da solo.
				_following = false
			_update_cursor()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Il comando di movimento lo gestisce la mappa (city.gd): qui cambia
			# solo il cursore, così il click resta "non gestito" e arriva a entrambi.
			_clicking = event.pressed
			_update_cursor()
	elif event is InputEventMouseMotion and _panning:
		_pan_position -= event.relative / zoom
		_snap()

func _update_cursor() -> void:
	var cursor := HAND_OPEN
	if _panning:
		cursor = HAND_CLOSED
	elif _clicking:
		cursor = HAND_CLICK
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, HAND_HOTSPOT)

func _step(direction: int) -> void:
	var next := clampi(_level + direction, 0, net_scales.size() - 1)
	if next != _level:
		_level = next
		_apply()

## Traduce la scala netta desiderata nello zoom della camera, tenendo conto
## di quanto la finestra corrente sta già ingrandendo il canvas.
func _apply() -> void:
	var design_height: float = ProjectSettings.get_setting("display/window/size/viewport_height")
	var stretch: float = float(get_window().size.y) / design_height
	if stretch <= 0.0:
		stretch = 1.0
	var level: float = float(net_scales[_level]) / stretch
	zoom = Vector2(level, level)
	_snap()

## Tiene la camera su coordinate mondo intere. Con la scala netta intera questo
## garantisce che ogni pixel degli sprite cada esattamente su pixel dello schermo:
## senza, una camera ferma a 320.37 sfalsa il campionamento e l'immagine "sbava".
func _snap() -> void:
	position = _pan_position.round()

## La nitidezza dipende da questa lista: se qualcuno ci infila un valore sbagliato
## è meglio accorgersene subito invece di inseguire uno sfarfallio a video.
func _validate_net_scales() -> void:
	if net_scales.is_empty():
		push_error("net_scales è vuoto: la camera non ha nessun livello di zoom.")
		net_scales = [1]
		return
	for scale in net_scales:
		if scale < 1:
			push_warning("Scala netta %d < 1: gli sprite verrebbero rimpiccioliti e perderebbero dettaglio." % scale)
