extends Node2D

## Auto segnaposto che percorre una corsia in tondo.
##
## L'origine del nodo è a terra, al centro dell'auto, come per gli edifici e i
## personaggi: così l'Y-sort della City la mette davanti o dietro alle cose in
## base a dove sta sulla strada, e un'auto che passa nasconde il marciapiede
## dietro ma non il protagonista che le sta davanti.
##
## Non c'è nessuna fisica: la corsia è una retta, l'auto la scorre e quando
## esce da un capo rientra dall'altro. Le corsie stanno in `CityMap.LANES`.

## Chi tenere d'occhio per frenare. Lo passa `city.gd`: un'auto che investe il
## protagonista senza rallentare si legge come un bug, e questo costa due righe.
var watch: Node2D = null

const BODY_LENGTH := 44.0
const BODY_WIDTH := 20.0
const WHEEL := Color(0.10, 0.10, 0.12)
const GLASS := Color(0.52, 0.66, 0.72, 0.85)
const HEADLIGHT := Color(1.0, 0.95, 0.72, 0.30)

## Quanto davanti guarda per frenare, e quanto stretto è il "davanti".
const BRAKE_DISTANCE := 58.0
const BRAKE_WIDTH := 26.0

var _horizontal := true
var _from := 0.0
var _to := 0.0
var _fixed := 0.0
var _dir := 1
var _speed := 60.0
var _current_speed := 0.0
var _along := 0.0
var _color := Color(0.6, 0.3, 0.3)
var _was_night := false

## `offset` è la posizione di partenza lungo la corsia, 0-1: serve a distribuire
## le auto della stessa corsia invece di farle partire tutte appiccicate.
func setup(lane: Dictionary, offset: float, color: Color) -> void:
	_horizontal = str(lane["axis"]) == "h"
	_from = float(lane["from"])
	_to = float(lane["to"])
	_fixed = float(lane["pos"])
	_dir = int(lane["dir"])
	_speed = float(lane["speed"])
	_current_speed = _speed
	_color = color
	_along = lerpf(_from, _to, offset)
	_place()

func _process(delta: float) -> void:
	# Frenata morbida: cambiare velocità di scatto fa sobbalzare l'auto.
	var target := 0.0 if _player_ahead() else _speed
	_current_speed = move_toward(_current_speed, target, 140.0 * delta)
	_along += float(_dir) * _current_speed * delta

	var length := _to - _from
	# Riavvolge invece di teletrasportare a un capo fisso: se la corsia è più
	# corta di quanto l'auto percorre in un frame, non si perde niente.
	if _along > _to:
		_along -= length
	elif _along < _from:
		_along += length
	_place()

	# L'auto si muove cambiando `position`, che non richiede di ridisegnare: il
	# disegno va rifatto solo quando cambia, e l'unica cosa che cambia sono i
	# fari che si accendono al tramonto.
	var night := _is_night()
	if night != _was_night:
		_was_night = night
		queue_redraw()

func _place() -> void:
	position = Vector2(_along, _fixed) if _horizontal else Vector2(_fixed, _along)

## Il protagonista è davanti al muso, dentro alla larghezza dell'auto?
func _player_ahead() -> bool:
	if watch == null:
		return false
	var to_player := watch.global_position - global_position
	var forward := _forward()
	var ahead := to_player.dot(forward)
	var lateral := absf(to_player.dot(Vector2(-forward.y, forward.x)))
	return ahead > 0.0 and ahead < BRAKE_DISTANCE and lateral < BRAKE_WIDTH

func _forward() -> Vector2:
	if _horizontal:
		return Vector2(float(_dir), 0.0)
	return Vector2(0.0, float(_dir))

func _draw() -> void:
	var length := BODY_LENGTH
	var width := BODY_WIDTH
	var size := Vector2(length, width) if _horizontal else Vector2(width, length)
	var body := Rect2(-size * 0.5, size)
	# L'ombra sotto: è quello che fa sembrare l'auto appoggiata all'asfalto
	# invece di un rettangolo incollato sopra.
	draw_colored_polygon(_ellipse(Vector2(0, 3), size * Vector2(0.52, 0.30)), Color(0, 0, 0, 0.25))
	draw_rect(body, _color, true)
	draw_rect(body, _color.darkened(0.45), false, 1.0)
	# Tetto e vetri, schiacciati verso il centro.
	draw_rect(Rect2(body.position + size * 0.22, size * 0.56), _color.lightened(0.12), true)
	draw_rect(Rect2(body.position + size * 0.28, size * 0.44), GLASS, true)
	_draw_wheels(size)
	if _is_night():
		_draw_headlights(size)

func _draw_wheels(size: Vector2) -> void:
	var offsets: Array[Vector2] = []
	if _horizontal:
		var dx := size.x * 0.30
		var dy := size.y * 0.5
		offsets = [Vector2(-dx, -dy), Vector2(dx, -dy), Vector2(-dx, dy), Vector2(dx, dy)]
	else:
		var dx := size.x * 0.5
		var dy := size.y * 0.30
		offsets = [Vector2(-dx, -dy), Vector2(-dx, dy), Vector2(dx, -dy), Vector2(dx, dy)]
	for offset in offsets:
		draw_rect(Rect2(offset - Vector2(3, 2), Vector2(6, 4)), WHEEL, true)

## Fari accesi di notte: è un dettaglio, ma è il modo più economico di far
## vedere che l'orologio di gioco esiste anche fuori dall'HUD.
func _draw_headlights(size: Vector2) -> void:
	var forward := _forward()
	var nose := forward * (size.length() * 0.5 * 0.62)
	var side := Vector2(-forward.y, forward.x) * (size.x if _horizontal else size.y) * 0.22
	for lamp in [nose + side, nose - side]:
		draw_colored_polygon(_ellipse(lamp + forward * 12.0, Vector2(16, 10)), HEADLIGHT)

func _is_night() -> bool:
	if GameState.current == null:
		return false
	var hour := GameState.current.time_of_day
	return hour < 6.5 or hour > 19.5

func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points
