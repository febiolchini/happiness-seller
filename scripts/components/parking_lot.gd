extends Node
class_name ParkingLot

## Il via vai del parcheggio fra la steak house e il grossista: auto ferme
## negli stalli, e ogni tanto una che arriva dalla strada e parcheggia o una che
## esce in retromarcia e se ne va.
##
## E' solo scena, come il furgone: nessun dato di gioco dipende da quante auto
## ci sono, quindi niente va salvato e a ogni ingresso in strada il parcheggio
## si ripopola da capo.
##
## ## Gli stalli sono quelli disegnati
##
## La geometria non e' scritta qui: le file e la corsia si ricavano dal lotto
## con le stesse misure con cui `city_ground.gd` disegna le righe (`BAY`,
## `BAY_AISLE`). Un'auto parcheggiata a cavallo di una riga si vede subito, e
## con due tabelle da tenere d'accordo prima o poi succede.
##
## Della prima coppia di file si vede tutto, del resto quasi niente — dietro
## c'e' il tetto del grossista. Quindi:
##
## - la **prima fila**, contro la facciata del ristorante, ha solo auto ferme:
##   non da' sulla corsia, e un'auto che ci entrasse passerebbe sopra a quelle
##   della seconda;
## - la **seconda** e la **terza**, ai due lati della corsia, sono quelle in cui
##   si entra e da cui si esce.
##
## Davanti alla porta del ristorante gli stalli restano vuoti: e' il passaggio
## per chi arriva a piedi. Nella terza fila restano vuoti quelli sotto ai
## lampioni, che hanno il palo sulla riga, e non ci sono quelli dove stanno le
## aiuole con gli alberi.
##
## ## Una manovra alla volta
##
## La corsia e' una sola e le auto non si vedono fra loro: due manovre insieme
## finirebbero prima o poi una dentro all'altra. Una alla volta, con una pausa
## in mezzo, basta a far sembrare il posto frequentato senza farlo sembrare un
## autoscontro.

## Quanto e' lungo il tratto di strada percorso prima di entrare e dopo essere
## uscite: le auto arrivano da MAIN STREET e ci tornano, e devono comparire e
## sparire lontano dal parcheggio, non sul cordolo.
const RUN := 700.0
## Quanto spazio laterale serve per uscire in retromarcia e raddrizzarsi.
const BACK_OUT := 34.0
## Raggio delle curve, in px: stretto nel parcheggio, largo in strada.
const TURN_LOT := 18.0
const TURN_ROAD := 22.0
## Quanto stanno ferme, in secondi, e quanto si aspetta fra una manovra e
## l'altra.
const STAY := Vector2(35.0, 110.0)
const GAP := Vector2(2.0, 6.0)
## Quanti posti del passaggio lasciare liberi davanti alla porta, in px dal
## suo centro, e intorno al palo di un lampione.
const DOOR_CLEAR := 30.0
const LAMP_CLEAR := 16.0
## Quante auto ferme nella prima fila, sui posti che ha.
const FRONT_FILL := 0.55

const GROUND := preload("res://scripts/levels/city_ground.gd")

var _lot := Rect2()
var _west := Rect2()
var _east := Rect2()
var _aisle_y := 0.0
## Gli stalli in cui si entra e si esce: `pos`, `angle`, `car`, `leave_at`.
var _stalls: Array = []
var _parent: Node = null
var _watch: Node2D = null
var _busy := false
var _cooldown := 2.0
var _time := 0.0
var _models: Array = []

## `plan` e' `CityMap.steakhouse_parking()`. Le auto finiscono in `parent`,
## che deve essere il nodo Y-sortato del traffico: cosi' passano davanti e
## dietro agli edifici e ai lampioni come quelle in strada.
func setup(plan: Dictionary, parent: Node, watch: Node2D) -> void:
	_lot = plan["lot"]
	_west = plan["west"]
	_east = plan["east"]
	_parent = parent
	_watch = watch
	# Il bus non entra in uno stallo, e una volante parcheggiata davanti a una
	# steak house racconta una storia che il gioco non sta raccontando.
	for path: String in Car.VEHICLES:
		if not ("bus" in path or "Police" in path):
			_models.append(path)
	var door_x := float(plan["door_x"])
	var top := _lot.position.y + 6.0
	var bay: Vector2 = GROUND.BAY
	var front_y := top + bay.y * 0.5
	var north_y := top + bay.y * 1.5
	_aisle_y = top + bay.y * 2.0 + GROUND.BAY_AISLE * 0.5
	var south_y := top + bay.y * 2.0 + GROUND.BAY_AISLE + bay.y * 0.5
	var lamps: Array = []
	for lamp in CityMap.lot_lamps():
		if _lot.has_point(lamp["pos"]):
			lamps.append(float((lamp["pos"] as Vector2).x))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4712
	var count := int(_lot.size.x / bay.x)
	for k in count:
		var x := _lot.position.x + bay.x * (float(k) + 0.5)
		if absf(x - door_x) < DOOR_CLEAR:
			continue
		# La prima fila: ferme e basta, col muso verso il ristorante.
		if rng.randf() < FRONT_FILL:
			_park_new(Vector2(x, front_y), -PI / 2.0)
		_stalls.append({"pos": Vector2(x, north_y), "angle": -PI / 2.0, "car": null, "leave_at": 0.0})
		var under_lamp := false
		for lamp_x: float in lamps:
			if absf(x - lamp_x) < LAMP_CLEAR:
				under_lamp = true
		var on_island := false
		for island: Rect2 in plan.get("islands", []):
			if island.has_point(Vector2(x, south_y)):
				on_island = true
		if not under_lamp and not on_island:
			_stalls.append({"pos": Vector2(x, south_y), "angle": PI / 2.0, "car": null, "leave_at": 0.0})
	# Si entra in strada col parcheggio gia' mezzo pieno, non vuoto: chi arriva
	# lo trova com'e' a quell'ora, e le partenze sono sparse nel tempo.
	var free := _stalls.duplicate()
	free.shuffle()
	for i in mini(_target(), free.size()):
		var stall: Dictionary = free[i]
		stall["car"] = _park_new(stall["pos"], float(stall["angle"]))
		stall["leave_at"] = randf_range(5.0, STAY.y)

func _process(delta: float) -> void:
	_time += delta
	if _busy:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var parked := 0
	var leaving: Array = []
	for stall: Dictionary in _stalls:
		if stall["car"] != null:
			parked += 1
			if float(stall["leave_at"]) <= _time:
				leaving.append(stall)
	var target := _target()
	if not leaving.is_empty() and (parked > target / 2 or randf() < 0.5):
		_depart(leaving.pick_random())
	elif parked < target:
		_arrive()
	else:
		_cooldown = randf_range(GAP.x, GAP.y)

## Quante auto nelle due file che si muovono, a seconda dell'ora: vuoto la
## notte fonda, pieno all'ora di cena.
func _target() -> int:
	var hour := 13.0
	if GameState.current != null:
		hour = float(GameState.current.time_of_day)
	if hour < 6.0:
		return 3
	if hour < 11.0:
		return 6
	if hour < 15.0:
		return 14
	if hour < 18.0:
		return 10
	if hour < 23.0:
		return 20
	return 8

## Arriva da MAIN STREET, risale la strada laterale piu' vicina allo stallo,
## entra nella corsia e si infila col muso avanti.
func _arrive() -> void:
	var free: Array = []
	for stall: Dictionary in _stalls:
		if stall["car"] == null:
			free.append(stall)
	if free.is_empty():
		return
	var stall: Dictionary = free.pick_random()
	var pos: Vector2 = stall["pos"]
	var road := _west if pos.x < _lot.get_center().x else _east
	# La corsia che sale verso nord: guida a destra, quella a est.
	var lane_x := road.end.x - 24.0
	var start := Vector2(lane_x, _aisle_y + RUN)
	var car := _park_new(start, -PI / 2.0)
	stall["car"] = car
	_busy = true
	var leg := path_leg([start, Vector2(lane_x, _aisle_y), Vector2(pos.x, _aisle_y), pos],
		[TURN_ROAD, TURN_LOT], ParkingCar.SPEED_LOT, false, road)
	leg["fade_in"] = true
	leg["stop"] = true
	car.drive([leg], func() -> void:
		stall["leave_at"] = _time + randf_range(STAY.x, STAY.y)
		_done())

## Esce in retromarcia girando la coda dalla parte opposta a dove andra', si
## raddrizza nella corsia, e scende verso MAIN STREET dalla strada piu' vicina.
func _depart(stall: Dictionary) -> void:
	var car: ParkingCar = stall["car"]
	var pos: Vector2 = stall["pos"]
	var toward := -1.0 if pos.x < _lot.get_center().x else 1.0
	var road := _west if toward < 0.0 else _east
	# La corsia che scende verso sud: guida a destra, quella a ovest.
	var lane_x := road.position.x + 24.0
	var turned := Vector2(pos.x - toward * BACK_OUT, _aisle_y)
	var back := path_leg([pos, Vector2(pos.x, _aisle_y), turned], [TURN_LOT],
		ParkingCar.SPEED_REVERSE, true, Rect2())
	var away := path_leg([turned, Vector2(lane_x, _aisle_y), Vector2(lane_x, _aisle_y + RUN)],
		[TURN_ROAD], ParkingCar.SPEED_LOT, false, road)
	away["fade_out"] = true
	_busy = true
	car.drive([back, away], func() -> void:
		stall["car"] = null
		car.queue_free()
		_done())

func _done() -> void:
	_busy = false
	_cooldown = randf_range(GAP.x, GAP.y)

func _park_new(at: Vector2, angle: float) -> ParkingCar:
	var car := ParkingCar.new()
	var body := Sprite2D.new()
	body.name = "Body"
	car.add_child(body)
	car.watch = _watch
	_parent.add_child(car)
	car.set_vehicle(str(_models.pick_random()))
	car.park(at, angle)
	return car

## Una tratta: la spezzata `points` con gli angoli arrotondati (un raggio per
## angolo, in ordine), percorsa a `speed` — e a velocita' di strada dentro a
## `fast`, la carreggiata da cui si arriva o su cui si esce. Statica: la usano
## anche gli autobus della stazione (`BusDepot`).
static func path_leg(points: Array, radii: Array, speed: float, reverse: bool, fast: Rect2) -> Dictionary:
	var curve := Curve2D.new()
	curve.bake_interval = 2.0
	curve.add_point(points[0])
	for i in range(1, points.size() - 1):
		var a: Vector2 = points[i - 1]
		var p: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var r: float = minf(float(radii[mini(i - 1, radii.size() - 1)]),
			minf(p.distance_to(a), p.distance_to(b)) * 0.5)
		var into := p + (a - p).normalized() * r
		var out := p + (b - p).normalized() * r
		# Un quarto di cerchio fatto di Bezier: le maniglie a 0,55 del raggio
		# sono la costante che ci si avvicina di piu'.
		curve.add_point(into, Vector2.ZERO, (p - into) * 0.55)
		curve.add_point(out, (p - out) * 0.55, Vector2.ZERO)
	curve.add_point(points[points.size() - 1])
	return {"curve": curve, "speed": speed, "reverse": reverse,
		"fast": fast.grow(8.0) if fast.has_area() else Rect2()}
