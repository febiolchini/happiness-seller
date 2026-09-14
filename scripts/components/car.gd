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

## Fari e stop. I fari sono il cono di luce davanti, gli stop la coda rossa
## dietro: senza i secondi un'auto vista da dietro di notte è una sagoma nera,
## e la strada sembra percorsa da buchi invece che da macchine.
const HEADLIGHT := Color(1.0, 0.82, 0.46)
const TAILLIGHT := Color(1.0, 0.20, 0.16)
## Quanto arriva lontano il cono dei fari, e quanto si apre alla fine.
const BEAM_LENGTH := 42.0
const BEAM_SPREAD := 15.0

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

## Il mezzo che tocca a questa: `city.gd` ne pesca uno a caso, e per strada
## capita di tutto. Vedi `VEHICLES`.
static func random_vehicle() -> String:
	return str(VEHICLES[randi() % VEHICLES.size()])

func _ready() -> void:
	add_to_group(Daylight.LIGHT_GROUP)

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
	# disegno va rifatto solo quando cambia. A cambiare sono i fari che si
	# accendono al tramonto e l'ombra che gira col sole, e di tutti e due
	# l'avviso arriva da `atmosphere.gd` (vedi `on_light_changed()`).

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

## Chiamata da `atmosphere.gd` quando la luce è cambiata abbastanza da vedersi.
func on_light_changed() -> void:
	queue_redraw()

## Sotto allo sprite ci restano l'ombra, i fari e gli stop: l'ombra è quello che
## fa sembrare il mezzo appoggiato all'asfalto invece che incollato sopra.
func _draw() -> void:
	var footprint := Vector2(_size.x, _size.y) if _horizontal else Vector2(_size.y, _size.x)
	_draw_shadow(footprint)
	if Daylight.lamps_on(GameState.current):
		_draw_lights(footprint)

## L'ombra segue il sole come quella degli edifici, ma con un limite: un'auto è
## bassa, e la sua ombra all'alba non è lunga come quella di un palazzo. Qui la
## lunghezza è quella dell'ombra di un oggetto alto un metro e mezzo, non del
## fattore pieno.
func _draw_shadow(footprint: Vector2) -> void:
	var info := Daylight.shadow(GameState.current)
	var slide: Vector2 = (info["direction"] as Vector2) * minf(float(info["length"]) * 7.0, 16.0)
	# Ben dentro alla sagoma. Il PNG ha un margine trasparente intorno e il
	# corpo dipinto è più stretto del suo formato: un'ombra presa sulle misure
	# del file sbuca ai lati e sembrano due macchie scure attaccate alle
	# fiancate, non un'ombra.
	draw_colored_polygon(
		_ellipse(Vector2(0, 3) + slide, footprint * Vector2(0.34, 0.20)),
		Color(0, 0, 0, 0.16 + float(info["alpha"]) * 0.35))

## Fari e stop accesi di notte. È un dettaglio, ma di notte è il traffico a
## tenere viva la città: le auto sono l'unica cosa che si muove su tutta la
## mappa, e due luci accese le rendono visibili da un isolato di distanza.
func _draw_lights(footprint: Vector2) -> void:
	var ambient := Daylight.light(GameState.current)
	var strength := Daylight.lamp_strength(GameState.current)
	var forward := _forward()
	var across := Vector2(-forward.y, forward.x)
	var half_width := (footprint.x if _horizontal else footprint.y) * 0.22
	var nose := forward * (footprint.length() * 0.5 * 0.62)

	# Il cono sull'asfalto davanti. Un pezzo solo e non due — due coni separati
	# per i due fari si incrociano e fanno una farfalla, che non è come si vede
	# — ma in tre strati di lunghezza diversa: il più corto è coperto da tutti e
	# tre, il più lungo da uno solo, e il cono si spegne piano verso la punta.
	# Con un trapezio pieno la luce finisce di colpo, e si legge come un
	# cartoncino appoggiato sull'asfalto.
	var tip := nose + forward * 8.0
	for i in 3:
		var reach: float = BEAM_LENGTH * (0.42 + 0.29 * float(i))
		var spread: float = BEAM_SPREAD * (0.42 + 0.29 * float(i))
		var beam := HEADLIGHT
		beam.a = 0.048 * strength
		# Il cono parte stretto come i fari e non largo come l'auto: partendo
		# dalla fiancata sembrerebbe una luce che esce da tutto il muso.
		var root: float = half_width * 0.7
		draw_colored_polygon(PackedVector2Array([
			tip + across * root, tip - across * root,
			tip + forward * reach - across * spread,
			tip + forward * reach + across * spread,
		]), Daylight.emissive(beam, ambient))

	# I due fari veri, piccoli e pieni.
	var bulb := HEADLIGHT
	bulb.a = 0.9 * strength
	for lamp in [nose + across * half_width, nose - across * half_width]:
		draw_colored_polygon(
			_ellipse(lamp + forward * 3.0, Vector2(4, 3)), Daylight.emissive(bulb, ambient))

	# Gli stop dietro, rossi e più piccoli.
	var tail := TAILLIGHT
	tail.a = 0.75 * strength
	var back := -forward * (footprint.length() * 0.5 * 0.58)
	for lamp in [back + across * half_width, back - across * half_width]:
		draw_colored_polygon(_ellipse(lamp, Vector2(3, 2)), Daylight.emissive(tail, ambient))

func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points
