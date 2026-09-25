extends Node
class_name BusDepot

## Il via vai della stazione degli autobus: autobus fermi alle banchine, e ogni
## tanto uno che arriva da LOCK STREET e accosta, o uno che riparte e se ne va
## per SEVENTH STREET.
##
## E' solo scena, come il parcheggio della steak house (`ParkingLot`), di cui
## usa le stesse auto (`ParkingCar`) e le stesse curve (`ParkingLot.path_leg()`):
## nessun dato di gioco dipende da quanti autobus ci sono, quindi niente va
## salvato, e a ogni ingresso in strada il piazzale si ripopola da capo.
##
## ## Le corsie si attraversano, non si fa manovra
##
## Ogni corsia di fermata va da ovest a est: si entra dalla testa ovest, si
## accosta, e ripartendo si tira dritto fino a SEVENTH STREET. Niente
## retromarce — un autobus in retromarcia in una stazione e' una cosa che non
## si vede mai. Ma le fermate di una corsia sono due, una dietro l'altra, e un
## autobus non passa attraverso a un altro. Quindi:
##
## - si arriva solo se la fermata ovest (la prima che si incontra) e' libera, e
##   ci si ferma alla est se c'e' posto, alla ovest se no;
## - si riparte dalla est quando si vuole, dalla ovest solo a est libera;
## - in una corsia si muove un autobus alla volta.
##
## Fra corsie diverse invece si puo' arrivare e ripartire insieme: si arriva da
## LOCK STREET e si esce su SEVENTH, e le due strade non si incrociano.

## Lo sprite dell'autobus. **Segnaposto**: e' il bus del traffico cittadino
## (`Car.VEHICLES`), in attesa dei disegni veri degli autobus della stazione.
## Quando arriveranno, basta cambiare questa riga — o farne una lista e
## pescarci a caso, come `ParkingLot` fa con le auto.
const BUS_MODEL := "res://assets/sprites/props/cars/bus01.png"

## Quanto e' lungo il tratto di strada fatto prima di entrare e dopo essere
## usciti: gli autobus compaiono e spariscono lontano dal piazzale.
const RUN := 700.0
## Raggio delle curve, in px: un autobus gira largo.
const TURN := 26.0
## Piu' piano delle auto del parcheggio: e' lungo il doppio.
const SPEED := 46.0
## Quanto sta fermo alla banchina, in secondi, e quanto si aspetta fra una
## partenza (o un arrivo) e la prossima.
const STAY := Vector2(25.0, 80.0)
const GAP := Vector2(3.0, 9.0)

## Le fermate: `lane`, `side` (0 ovest, 1 est), `pos`, `bus`, `leave_at`.
var _stops: Array = []
var _lanes := 0
## Corsie in cui qualcuno si sta muovendo adesso: li' non parte ne' arriva
## nessun altro.
var _busy_lanes := {}
var _arriving := false
var _departing := false
var _west := Rect2()
var _east := Rect2()
var _parent: Node = null
var _watch: Node2D = null
var _cooldown := 2.0
var _time := 0.0

## `plan` e' `CityMap.bus_depot()`. Gli autobus finiscono in `parent`, il nodo
## Y-sortato del traffico: cosi' passano davanti e dietro alle pensiline come
## le auto in strada davanti e dietro agli edifici.
func setup(plan: Dictionary, parent: Node, watch: Node2D) -> void:
	_parent = parent
	_watch = watch
	_west = plan["west"]
	_east = plan["east"]
	var lanes: Array = plan["lanes"]
	var stops_x: Array = plan["stops_x"]
	_lanes = lanes.size()
	for lane in _lanes:
		for side in stops_x.size():
			_stops.append({
				"lane": lane, "side": side,
				"pos": Vector2(float(stops_x[side]), float(lanes[lane])),
				"bus": null, "leave_at": 0.0,
			})
	# Si entra in strada col piazzale gia' mezzo pieno, e le partenze sparse
	# nel tempo. Fermi, qualunque combinazione va bene: le regole servono solo
	# a chi si muove.
	var free := _stops.duplicate()
	free.shuffle()
	for i in mini(_target(), free.size()):
		var stop: Dictionary = free[i]
		stop["bus"] = _new_bus(stop["pos"])
		stop["leave_at"] = randf_range(5.0, STAY.y)

func _process(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var parked := 0
	for stop: Dictionary in _stops:
		if stop["bus"] != null:
			parked += 1
	var target := _target()
	if not _departing and (parked > target or randf() < 0.6):
		var leaving := _ready_to_leave()
		if not leaving.is_empty():
			_depart(leaving.pick_random())
			_cooldown = randf_range(GAP.x, GAP.y)
			return
	if not _arriving and parked < target:
		_arrive()
	_cooldown = randf_range(GAP.x, GAP.y)

## Quanti autobus fermi, a seconda dell'ora: pochi di notte, pieno all'ora di
## punta del mattino e della sera.
func _target() -> int:
	var hour := 13.0
	if GameState.current != null:
		hour = float(GameState.current.time_of_day)
	if hour < 5.0:
		return 1
	if hour < 7.0:
		return 3
	if hour < 10.0:
		return 6
	if hour < 16.0:
		return 4
	if hour < 20.0:
		return 6
	return 2

func _stop(lane: int, side: int) -> Dictionary:
	for stop: Dictionary in _stops:
		if int(stop["lane"]) == lane and int(stop["side"]) == side:
			return stop
	return {}

## Gli autobus che possono ripartire adesso: il loro tempo e' scaduto, la loro
## corsia e' ferma, e davanti — a est — non c'e' nessuno.
func _ready_to_leave() -> Array:
	var list: Array = []
	for stop: Dictionary in _stops:
		if stop["bus"] == null or float(stop["leave_at"]) > _time:
			continue
		var lane := int(stop["lane"])
		if _busy_lanes.has(lane):
			continue
		if int(stop["side"]) == 0 and _stop(lane, 1)["bus"] != null:
			continue
		list.append(stop)
	return list

## Arriva da sud su LOCK STREET, gira nella corsia e accosta alla fermata.
func _arrive() -> void:
	var choices: Array = []
	for lane in _lanes:
		if _busy_lanes.has(lane) or _stop(lane, 0)["bus"] != null:
			continue
		var east := _stop(lane, 1)
		choices.append(east if east["bus"] == null else _stop(lane, 0))
	if choices.is_empty():
		return
	var stop: Dictionary = choices.pick_random()
	var lane := int(stop["lane"])
	var pos: Vector2 = stop["pos"]
	# La corsia di LOCK STREET che sale verso nord: guida a destra, quella a est.
	var road_x := _west.end.x - 24.0
	var start := Vector2(road_x, pos.y + RUN)
	var bus := _new_bus(start, -PI / 2.0)
	stop["bus"] = bus
	_busy_lanes[lane] = true
	_arriving = true
	var leg := ParkingLot.path_leg([start, Vector2(road_x, pos.y), pos], [TURN],
		SPEED, false, _west)
	leg["fade_in"] = true
	leg["stop"] = true
	bus.drive([leg], func() -> void:
		stop["leave_at"] = _time + randf_range(STAY.x, STAY.y)
		_busy_lanes.erase(lane)
		_arriving = false)

## Riparte verso est, gira a sud su SEVENTH STREET e se ne va.
func _depart(stop: Dictionary) -> void:
	var bus: ParkingCar = stop["bus"]
	var lane := int(stop["lane"])
	var pos: Vector2 = stop["pos"]
	# La corsia di SEVENTH STREET che scende verso sud: guida a destra, quella
	# a ovest.
	var road_x := _east.position.x + 24.0
	var leg := ParkingLot.path_leg(
		[pos, Vector2(road_x, pos.y), Vector2(road_x, pos.y + RUN)], [TURN],
		SPEED, false, _east)
	leg["fade_out"] = true
	_busy_lanes[lane] = true
	_departing = true
	# La fermata si libera appena l'autobus parte, non quando sparisce: chi
	# arriva dopo trova il posto, e la corsia resta occupata finche' questo non
	# ne e' uscito (`_busy_lanes`).
	stop["bus"] = null
	bus.drive([leg], func() -> void:
		bus.queue_free()
		_busy_lanes.erase(lane)
		_departing = false)

func _new_bus(at: Vector2, angle := 0.0) -> ParkingCar:
	var bus := ParkingCar.new()
	var body := Sprite2D.new()
	body.name = "Body"
	bus.add_child(body)
	bus.watch = _watch
	_parent.add_child(bus)
	bus.set_vehicle(BUS_MODEL)
	bus.park(at, angle)
	return bus
