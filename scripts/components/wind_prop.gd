extends Sprite2D

## Una cosa appesa a un edificio che si muove col vento: la girandola nel
## giardinetto, la bandiera sul portico.
##
## I fotogrammi li renderizza `render_buildings.py` con la stessa camera
## dell'edificio (vedi `casa_gialla_animati()`), e `import_flats_art.py` li mette
## in fila in una striscia gia' allineata al disegno: qui si sceglie solo quale
## mostrare. Sono un CICLO chiuso — un quarto di giro della girandola, un'onda
## della bandiera — quindi si possono scorrere all'infinito.
##
## ## Il vento e' quello del meteo
##
## La velocita' non e' fissa: viene da `wind` della tabella del meteo, lo
## stesso numero che spinge di lato pioggia e cartacce in strada. Col sereno la
## girandola gira piano, col temporale frulla — e c'e' una raffica lenta
## sopra, perche' il vento vero non soffia mai uguale per due secondi di fila.
## Senza, anche a velocita' giusta, si legge come un'animazione in loop.
##
## ## Gli altri modi (`mode` nella voce)
##
## - `wind` (quello di default): quanto detto sopra.
## - `loop`: fotogrammi in fila a `fps` fissi, sempre. La parete di schermi
##   del negozio di videogiochi.
## - `event`: fermo sul primo fotogramma, e ogni tanto — una pausa a caso fra
##   `pause[0]` e `pause[1]` secondi — scorre tutta la striscia una volta. Le
##   lampadine del cinema che fanno la corsa.
##
## `emissive: true` dice che la striscia e' luce (lampadine, schermi): di
## notte non si spegne con il resto della citta', per lo stesso giro di
## `building_lights.gd` — la si moltiplica per l'inverso della luce dell'ora.

## Fotogrammi al secondo con l'aria ferma e col vento pieno.
@export var calm_fps := 2.0
@export var storm_fps := 18.0

var _frames := 1
var _mode := "wind"
var _fps := 6.0
var _pause := Vector2(6.0, 14.0)
var _emissive := false
## Per `event`: secondi alla prossima corsa, o negativo mentre corre.
var _wait := 0.0
var _phase := 0.0
var _time := 0.0
## Ogni quanto si rilegge il meteo: cambia a mezzanotte, non a ogni frame.
var _wind := 0.2
var _refresh := 0.0

func setup(entry: Dictionary) -> void:
	texture = load(str(entry["texture"]))
	centered = false
	position = entry["at"]
	_frames = int(entry["frames"])
	hframes = _frames
	var fps: Array = entry.get("fps", [])
	if fps.size() == 2:
		calm_fps = float(fps[0])
		storm_fps = float(fps[1])
	elif fps.size() == 1:
		_fps = float(fps[0])
	_mode = str(entry.get("mode", "wind"))
	var pause: Array = entry.get("pause", [])
	if pause.size() == 2:
		_pause = Vector2(pause[0], pause[1])
	_emissive = bool(entry.get("emissive", false))
	_wait = randf_range(1.0, _pause.y)
	# Fase a caso: due girandole della stessa casa non girano in sincrono. Un
	# evento invece parte sempre dall'inizio, dopo la sua attesa.
	_phase = 0.0 if _mode == "event" else randf() * _frames
	_time = randf() * 100.0

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		if GameState.current != null:
			_wind = float(Weather.entry(Weather.of(GameState.current))["wind"])
			if _emissive:
				modulate = Daylight.emissive(Color.WHITE, Daylight.light(GameState.current))
	if _mode == "loop":
		_phase = fmod(_phase + _fps * delta, float(_frames))
		frame = int(_phase)
		return
	if _mode == "event":
		_tick_event(delta)
		return
	_time += delta
	# La raffica: un'onda lenta fra meta' e una volta e mezzo il vento medio.
	var gust := 1.0 + 0.5 * sin(_time * 0.7) * sin(_time * 0.23 + 1.3)
	var fps := lerpf(calm_fps, storm_fps, clampf(_wind * gust, 0.0, 1.0))
	_phase = fmod(_phase + fps * delta, float(_frames))
	frame = int(_phase)

func _tick_event(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		frame = 0
		return
	_phase += _fps * delta
	if _phase >= float(_frames):
		_phase = 0.0
		frame = 0
		_wait = randf_range(_pause.x, _pause.y)
		return
	frame = int(_phase)
