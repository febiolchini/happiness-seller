extends Car
class_name ParkingCar

## Un'auto del parcheggio: sta ferma in uno stallo, oppure percorre una
## manovra — arrivare dalla strada e infilarsi nel posto, o uscire in
## retromarcia e andarsene. A decidere quando e dove e' `ParkingLot`; qui c'e'
## solo come ci si muove.
##
## Estende `Car` per lo sprite, l'ombra e i fari, che devono essere gli stessi
## del traffico: un'auto che esce dal parcheggio e si immette in strada non
## deve cambiare faccia a meta' manovra. Non ne prende la corsia: le sue sono
## curve (`Curve2D`) e non rette.
##
## **Non sta nel gruppo del traffico** (`Traffic.GROUP`). Chi attraversa la
## strada interroga quel gruppo chiedendo corsia, verso e velocita', e da
## un'auto che gira in un parcheggio avrebbe avuto risposte senza senso.

## Velocita' di manovra: piano nel parcheggio, piu' svelta in strada, a passo
## d'uomo in retromarcia.
const SPEED_LOT := 58.0
const SPEED_ROAD := 104.0
const SPEED_REVERSE := 30.0
## Quanto in fretta cambia velocita', in px/s al secondo: una ripartenza da
## ferma o un cambio di tratta non devono essere uno scatto.
const ACCEL := 90.0
## Su quanti pixel compare in fondo alla strada e sparisce all'uscita.
const FADE := 80.0

## Le tratte della manovra in corso: `curve`, `speed`, `reverse`, `fade_in`,
## `fade_out`, `stop` (rallenta per fermarsi alla fine), `fast` (il pezzo di
## carreggiata in cui si va a `SPEED_ROAD`).
var _legs: Array = []
var _leg := 0
var _offset := 0.0
var _now := 0.0
var _moving := false
var _done := Callable()

## Il `_ready()` di `Car` mette l'auto anche nel gruppo del traffico: qui no
## (vedi sopra), solo in quello della luce, per fari e ombra.
func _ready() -> void:
	add_to_group(Daylight.LIGHT_GROUP)

func set_vehicle(vehicle: String) -> void:
	var texture: Texture2D = load(vehicle)
	_body.texture = texture
	_size = texture.get_size()

## Ferma in `at`, col muso verso `angle` (0 = est, come lo sprite).
func park(at: Vector2, angle: float) -> void:
	_moving = false
	position = at
	modulate.a = 1.0
	_face(angle)
	queue_redraw()

## Percorre `legs` una dopo l'altra e alla fine chiama `done`.
func drive(legs: Array, done: Callable) -> void:
	_legs = legs
	_leg = 0
	_offset = 0.0
	_now = 0.0
	_done = done
	_moving = true
	_place()

func is_moving() -> bool:
	return _moving

func _process(delta: float) -> void:
	if not _moving:
		return
	var leg: Dictionary = _legs[_leg]
	var curve: Curve2D = leg["curve"]
	var length := curve.get_baked_length()
	var target := float(leg["speed"])
	# In carreggiata si va a velocita' di strada: a passo di parcheggio
	# un'auto che arriva da MAIN STREET ci metterebbe dieci secondi.
	var fast: Rect2 = leg.get("fast", Rect2())
	if fast.has_area() and fast.has_point(position):
		target = SPEED_ROAD
	if bool(leg.get("stop", false)):
		# Si ferma dolce nello stallo invece di inchiodare sulla riga.
		target = minf(target, maxf(12.0, (length - _offset) * 1.6))
	if _blocked():
		target = 0.0
	_now = move_toward(_now, target, ACCEL * delta)
	_offset += _now * delta
	if _offset >= length:
		_leg += 1
		_offset = 0.0
		if _leg >= _legs.size():
			_moving = false
			_legs = []
			if _done.is_valid():
				_done.call()
			return
	_place()

func _place() -> void:
	var leg: Dictionary = _legs[_leg]
	var curve: Curve2D = leg["curve"]
	var length := curve.get_baked_length()
	var at := clampf(_offset, 0.0, length)
	var xf := curve.sample_baked_with_rotation(at)
	position = xf.origin
	# In retromarcia il muso guarda al contrario del verso in cui si va.
	_face(xf.get_rotation() + (PI if bool(leg["reverse"]) else 0.0))
	var alpha := 1.0
	if bool(leg.get("fade_in", false)):
		alpha = minf(alpha, clampf(at / FADE, 0.0, 1.0))
	if bool(leg.get("fade_out", false)):
		alpha = minf(alpha, clampf((length - at) / FADE, 0.0, 1.0))
	modulate.a = alpha
	queue_redraw()

func _face(angle: float) -> void:
	_body.rotation = angle
	# `Car` disegna ombra e fari su un'impronta orizzontale o verticale: in
	# curva si prende quella del verso che prevale.
	_horizontal = absf(cos(angle)) >= absf(sin(angle))

## Il muso, dove guarda lo sprite. `Car` lo ricava dalla corsia.
func _forward() -> Vector2:
	return Vector2.from_angle(_body.rotation)

## Il protagonista davanti, nel verso in cui ci si muove — dietro, in
## retromarcia. Il controllo di `Car` vale solo in carreggiata, e in un
## parcheggio si cammina fra le auto.
func _blocked() -> bool:
	if watch == null or _legs.is_empty():
		return false
	var going := _forward() * (-1.0 if bool(_legs[_leg]["reverse"]) else 1.0)
	var to_player := watch.global_position - global_position
	var ahead := to_player.dot(going)
	var lateral := absf(to_player.dot(Vector2(-going.y, going.x)))
	return ahead > 0.0 and ahead < 44.0 and lateral < 16.0

## Da ferma niente fari: un parcheggio pieno di auto coi fari accesi di notte
## sembrerebbe una coda a un semaforo.
func _draw() -> void:
	var footprint := Vector2(_size.x, _size.y) if _horizontal else Vector2(_size.y, _size.x)
	_draw_shadow(footprint)
	if _moving and Daylight.lamps_on(GameState.current):
		_draw_lights(footprint)
