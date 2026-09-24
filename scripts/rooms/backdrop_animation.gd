extends Sprite2D

## Un pezzo di fondale che si muove: il lampadario che dondola, la fiamma della
## caldaia, la goccia del rubinetto.
##
## Il fondale della stanza è un PNG fermo; questo è un ritaglio della stessa
## stanza appoggiato sopra, che cambia fotogramma. I fotogrammi li
## renderizza `scripts_tools/blender_stanze.py` e li ritaglia
## `import_room_art.py` al solo rettangolo in cui qualcosa cambia — fuori dal
## movimento sono trasparenti, e sotto si vede il fondale identico. La voce
## della tabella (`RoomArt.ROOMS`) dice dove appoggiarlo e come muoverlo.
##
## ## Tre modi di muoversi
##
## - `loop`: i fotogrammi in fila, sempre. La fiamma, il vapore, il pendolo.
## - `event`: i fotogrammi in fila una volta, poi fermo sul primo per una pausa
##   a caso. La goccia, il ragno, la tenda nello spiffero.
## - `swing`: i fotogrammi sono POSE, dalla più a sinistra alla più a destra, e
##   quella di mezzo è a riposo. Non si scorrono in fila: ogni tanto l'oggetto
##   riceve una spinta, e l'angolo segue un'oscillazione smorzata da cui si
##   prende la posa più vicina. È quello che fa sembrare vero un lampadario:
##   ogni dondolio parte con una forza diversa e si spegne da solo, invece di
##   ripetere sempre la stessa animazione di due secondi.
##
## Le pause sono in secondi veri, non in ore di gioco: sono cose che si guardano
## mentre succedono, come i lampi del temporale.

var _kind := "loop"
var _frames := 1
var _fps := 8.0
var _pause := Vector2(8.0, 20.0)
var _period := 1.5
var _decay := 2.5
var _kick := Vector2(0.5, 1.0)

## Secondi da aspettare prima del prossimo movimento (event e swing).
var _wait := 0.0
## Da quanto dura il movimento in corso; negativo = fermo.
var _t := -1.0
var _amplitude := 0.0

## Monta il pezzo leggendo la voce di `RoomArt.ROOMS[stanza]["animations"]`.
func setup(entry: Dictionary) -> void:
	name = str(entry["name"]).to_pascal_case()
	texture = load(entry["texture"])
	centered = false
	var rect: Array = entry["rect"]
	position = Vector2(rect[0], rect[1])
	hframes = int(entry["columns"])
	vframes = int(entry["rows"])
	_frames = int(entry["frames"])
	_kind = entry["kind"]
	_fps = float(entry.get("fps", 8.0))
	var pause: Array = entry.get("pause", [8.0, 20.0])
	_pause = Vector2(pause[0], pause[1])
	_period = float(entry.get("period", 1.5))
	_decay = float(entry.get("decay", 2.5))
	var kick: Array = entry.get("kick", [0.5, 1.0])
	_kick = Vector2(kick[0], kick[1])

	frame = _rest_frame()
	# La prima volta si aspetta meno: entrando in una stanza si deve vedere
	# presto che qualcosa si muove, altrimenti il primo minuto è una foto. E a
	# caso, perché tutte le cose della stanza non partano insieme.
	_wait = randf_range(1.0, _pause.x * 0.6)
	if _kind == "loop":
		# I cicli partono da un punto a caso: due fiamme in fase si notano.
		_t = randf() * float(_frames) / _fps

func _process(delta: float) -> void:
	match _kind:
		"loop":
			_t += delta
			frame = int(_t * _fps) % _frames
		"event":
			_tick_event(delta)
		"swing":
			_tick_swing(delta)

func _tick_event(delta: float) -> void:
	if _t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
		return
	_t += delta
	var index := int(_t * _fps)
	if index >= _frames:
		frame = 0
		_t = -1.0
		_wait = randf_range(_pause.x, _pause.y)
		return
	frame = index

func _tick_swing(delta: float) -> void:
	if _t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
			_amplitude = randf_range(_kick.x, _kick.y)
			# Metà delle volte parte verso l'altro lato.
			if randf() < 0.5:
				_amplitude = -_amplitude
		return
	_t += delta
	var envelope := _amplitude * exp(-_t / _decay)
	# Sotto mezza posa di ampiezza il dondolio non si vede più: si ferma lì e
	# non a zero, altrimenti continuerebbe a scattare avanti e indietro fra la
	# posa di riposo e quella accanto per un altro mezzo minuto.
	var half_pose := 1.0 / float(_frames - 1)
	if absf(envelope) < half_pose:
		frame = _rest_frame()
		_t = -1.0
		_wait = randf_range(_pause.x, _pause.y)
		return
	var angle := envelope * sin(TAU * _t / _period)
	frame = clampi(roundi((angle + 1.0) * 0.5 * float(_frames - 1)), 0, _frames - 1)

## A riposo: la posa di mezzo per un dondolo, il primo fotogramma per il resto.
func _rest_frame() -> int:
	return int((_frames - 1) / 2.0) if _kind == "swing" else 0
