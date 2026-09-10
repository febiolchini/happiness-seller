extends Node2D
class_name Car

## Auto che percorre una corsia in tondo.
##
## L'origine del nodo è a terra, al centro dell'auto, come per gli edifici e i
## personaggi: così l'Y-sort della City la mette davanti o dietro alle cose in
## base a dove sta sulla strada, e un'auto che passa nasconde il marciapiede
## dietro ma non il protagonista che le sta davanti.
##
## Non c'è nessuna fisica: la corsia è una retta, l'auto la scorre e quando
## esce da un capo rientra dall'altro. Le corsie stanno in `CityMap.lanes()`.
##
## ## Il veicolo è uno sprite, non un disegno
##
## I mezzi sono i modelli low-poly di `assets/sprites/props/Low_Poly_Cars...`
## renderizzati **dall'alto** a sprite (lo script sta in `scripts_tools/`).
## Dall'alto un render solo basta per tutte e quattro le direzioni: girare lo
## sprite di novanta gradi è esatto, e non serve una versione per verso.
##
## Per questo lo sprite è renderizzato **col muso verso destra**, che è la
## direzione "est" di `_forward()`. Un veicolo nuovo si aggiunge mettendo il PNG
## in `assets/sprites/props/cars/` e una riga in `VEHICLES`.

## Chi tenere d'occhio per frenare. Lo passa `city.gd`: un'auto che investe il
## protagonista senza rallentare si legge come un bug, e questo costa due righe.
var watch: Node2D = null

## I mezzi che girano per la città. Sono in scala fra loro come nei modelli —
## il bus è davvero lungo il doppio di una berlina — perché sono stati
## renderizzati tutti con lo stesso rapporto fra unità e pixel.
const VEHICLES := [
	"res://assets/sprites/props/cars/car01.png",
	"res://assets/sprites/props/cars/car02.png",
	"res://assets/sprites/props/cars/car03.png",
	"res://assets/sprites/props/cars/pickupTruck01.png",
	"res://assets/sprites/props/cars/pickupTruck02.png",
	"res://assets/sprites/props/cars/carPolice.png",
	"res://assets/sprites/props/cars/bus01.png",
]

const HEADLIGHT := Color(1.0, 0.95, 0.72, 0.30)

## Quanto davanti guarda per frenare, e quanto stretto è il "davanti".
const BRAKE_DISTANCE := 58.0
const BRAKE_WIDTH := 26.0

@onready var _body: Sprite2D = $Body

var _horizontal := true
var _from := 0.0
var _to := 0.0
var _fixed := 0.0
var _dir := 1
var _speed := 60.0
var _current_speed := 0.0
var _along := 0.0
var _size := Vector2(44, 20)
var _was_night := false

## Il mezzo che tocca a questa: `city.gd` ne pesca uno a caso, e per strada
## capita di tutto. Vedi `VEHICLES`.
static func random_vehicle() -> String:
	return str(VEHICLES[randi() % VEHICLES.size()])

## `offset` è la posizione di partenza lungo la corsia, 0-1: serve a distribuire
## le auto della stessa corsia invece di farle partire tutte appiccicate.
func setup(lane: Dictionary, offset: float, vehicle: String) -> void:
	_horizontal = str(lane["axis"]) == "h"
	_from = float(lane["from"])
	_to = float(lane["to"])
	_fixed = float(lane["pos"])
	_dir = int(lane["dir"])
	_speed = float(lane["speed"])
	_current_speed = _speed
	_along = lerpf(_from, _to, offset)

	var texture: Texture2D = load(vehicle)
	_body.texture = texture
	_size = texture.get_size()
	# Lo sprite è renderizzato col muso a destra: basta girarlo verso dove va.
	_body.rotation = _forward().angle()
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

## Sotto allo sprite ci restano solo l'ombra e i fari: l'ombra è quello che fa
## sembrare il mezzo appoggiato all'asfalto invece di incollato sopra.
func _draw() -> void:
	var footprint := Vector2(_size.x, _size.y) if _horizontal else Vector2(_size.y, _size.x)
	# Ben dentro alla sagoma. Il PNG ha un margine trasparente intorno e il
	# corpo dipinto è più stretto del suo formato: un'ombra presa sulle misure
	# del file sbuca ai lati e sembrano due macchie scure attaccate alle
	# fiancate, non un'ombra.
	draw_colored_polygon(
		_ellipse(Vector2(0, 3), footprint * Vector2(0.34, 0.20)), Color(0, 0, 0, 0.22))
	if _is_night():
		_draw_headlights(footprint)

## Fari accesi di notte: è un dettaglio, ma è il modo più economico di far
## vedere che l'orologio di gioco esiste anche fuori dall'HUD.
func _draw_headlights(footprint: Vector2) -> void:
	var forward := _forward()
	var nose := forward * (footprint.length() * 0.5 * 0.62)
	var side := Vector2(-forward.y, forward.x) * (footprint.x if _horizontal else footprint.y) * 0.22
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
