extends Node2D

## Il tempo che fa, disegnato davanti a tutto: pioggia, schizzi, foschia,
## lampi e il buio agli angoli dello schermo.
##
## Sta su una tela sua (`WeatherLayer`), sopra al mondo e sotto all'HUD. Due
## conseguenze, ed è per quelle che sta lì:
##
## 1. La pioggia cade **davanti** a edifici e personaggi, come si guarda da
##    dietro un vetro, invece di finire sotto al primo palazzo Y-sortato.
## 2. La tinta dell'aria (`atmosphere.gd`) non la tocca: una tela diversa non
##    viene moltiplicata dal `CanvasModulate`. La pioggia resta chiara anche di
##    notte, che è come si vede davvero — sono le gocce a prendere la luce.
##
## ## Perché in coordinate schermo e non nel mondo
##
## La pioggia non ha una posizione nella città: è fra l'occhio e la scena.
## Disegnata nel mondo bisognerebbe coprire tutto quello che la camera può
## inquadrare a ogni livello di zoom, cioè riempire di gocce mezza mappa per
## vederne trenta. Qui lo schermo è 640x360 e le gocce sono trecento, sempre.
##
## Quello che invece **sta per terra** — le ombre delle nuvole, le pozze, le
## cartacce che rotolano — sta nel mondo e lo disegna `ground_weather.gd`.
##
## Tutto è disegnato a mano e non con le particelle: a 640x360 una goccia è una
## riga di due pixel, e un `GPUParticles2D` per disegnare delle righe costa un
## materiale, una texture e un nodo in più per ogni tipo di precipitazione.

## Quante gocce con la pioggia al massimo. Sopra le trecento non si distinguono
## più: diventa una retinatura grigia, che è il momento in cui la pioggia smette
## di sembrare pioggia.
const MAX_DROPS := 300
## Quanto è lunga la scia di una goccia, in pixel di schermo.
const DROP_LENGTH := Vector2(7.0, 16.0)
const DROP_SPEED := Vector2(300.0, 520.0)
const DROP_COLOR := Color(0.76, 0.84, 0.95, 0.42)
## Spinta laterale a vento pieno, in pixel al secondo.
const WIND_PUSH := 260.0

## Schizzi per secondo con la pioggia al massimo, e quanto durano.
const SPLASH_RATE := 90.0
const SPLASH_LIFE := 0.22
const SPLASH_COLOR := Color(0.80, 0.87, 0.96, 0.55)

## Banchi di foschia: pochi e molto larghi, perché la nebbia si legge dal fatto
## che le cose lontane sbiadiscono, non dal fatto che passano delle nuvolette.
const HAZE_BANKS := 9
const HAZE_COLOR := Color(0.78, 0.81, 0.86)

## Il velo bianco del lampo, sopra a quello che ha già fatto `atmosphere.gd`
## sul mondo: quello schiarisce le cose illuminate, questo è il cielo che si
## accende. Servono tutti e due — solo il primo sembra un cambio di contrasto.
const FLASH_COLOR := Color(0.92, 0.94, 1.0)
const FLASH_FADE := 4.5
const FLASH_PEAK := 0.26

## Il buio agli angoli. Non è meteo, è la cornice: di notte e col brutto tempo
## chiude lo sguardo verso il centro, di giorno sereno sparisce.
const VIGNETTE_RINGS := 14
const VIGNETTE_STEP := 9.0
const VIGNETTE_COLOR := Color(0.02, 0.03, 0.07)

## Ogni goccia: posizione, e quanto è "vicina" (0 lontana e lenta, 1 vicina e
## veloce). La profondità finta è quello che toglie alla pioggia l'aria di una
## texture che scorre: le gocce davanti corrono, quelle dietro scendono piano.
var _drops: Array[Vector3] = []
## Schizzi vivi: posizione e quanto gli resta da vivere.
var _splashes: Array[Vector3] = []
var _splash_debt := 0.0

## Fase dei banchi di foschia, che scorrono col vento.
var _haze_phase := 0.0
var _flash := 0.0
var _time := 0.0

## Quanto si sta bagnando lo schermo adesso, 0-1. Sale e scende piano invece di
## scattare: la pioggia che parte a bomba a mezzanotte esatta si legge come un
## interruttore. Vedi `_ease()`.
var _wetness := 0.0
var _haze := 0.0
var _dark := 0.0

## In quanti secondi il meteo a schermo raggiunge quello della partita.
const EASE_SPEED := 0.35

func _ready() -> void:
	_seed_drops()
	var atmosphere := get_node_or_null("../../Atmosphere")
	if atmosphere != null:
		atmosphere.lightning.connect(_on_lightning)

func _process(delta: float) -> void:
	_time += delta
	var entry := Weather.entry(Weather.of(GameState.current))
	var wind := float(entry["wind"])

	_wetness = _ease(_wetness, float(entry["rain"]), delta)
	_haze = _ease(_haze, float(entry["fog"]), delta)
	# Il buio agli angoli è la somma di due cose che lo vogliono: l'ora e il
	# tempo. Una notte serena e un temporale di giorno chiudono lo stesso.
	var night := 1.0 - Daylight.brightness(GameState.current)
	_dark = _ease(_dark, clampf(night * 0.75 + float(entry["fog"]) * 0.3 + float(entry["rain"]) * 0.35, 0.0, 1.0), delta)

	_flash = maxf(0.0, _flash - delta * FLASH_FADE)
	_haze_phase += delta * (6.0 + wind * 26.0)
	_move_drops(delta, wind)
	_tick_splashes(delta)
	queue_redraw()

## Avvicinamento morbido e indipendente dal frame rate, lo stesso schema che usa
## la camera per inseguire il protagonista.
func _ease(current: float, target: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-delta / EASE_SPEED))

func _on_lightning(strength: float) -> void:
	_flash = maxf(_flash, strength)

# --- Gocce ------------------------------------------------------------------

## Le gocce si creano una volta sola e poi girano in tondo: nascono già sparse
## su tutto lo schermo, così quando la pioggia comincia non si vede una riga di
## gocce che entra dall'alto tutta insieme.
func _seed_drops() -> void:
	var view := _view()
	_drops.resize(MAX_DROPS)
	for i in MAX_DROPS:
		_drops[i] = Vector3(randf() * view.x, randf() * view.y, randf())

func _move_drops(delta: float, wind: float) -> void:
	if _wetness <= 0.01:
		return
	var view := _view()
	var count := int(MAX_DROPS * _wetness)
	for i in count:
		var drop := _drops[i]
		var speed: float = lerpf(DROP_SPEED.x, DROP_SPEED.y, drop.z)
		drop.x += wind * WIND_PUSH * (0.4 + drop.z * 0.6) * delta
		drop.y += speed * delta
		# Fuori da un bordo si rientra dall'altro, a un'altezza a caso: le gocce
		# sono sempre le stesse trecento e nessuno se ne accorge.
		if drop.y > view.y:
			drop = Vector3(randf() * view.x, -DROP_LENGTH.y, randf())
		elif drop.x < -16.0:
			drop = Vector3(view.x + 8.0, randf() * view.y, randf())
		elif drop.x > view.x + 16.0:
			drop = Vector3(-8.0, randf() * view.y, randf())
		_drops[i] = drop

# --- Schizzi ----------------------------------------------------------------

## Gli schizzi non nascono dove atterra una goccia: nascono a caso sullo
## schermo, con una frequenza proporzionale alla pioggia.
##
## Seguire le gocce sarebbe più giusto e si vedrebbe peggio — quelle che "toccano
## terra" sarebbero solo quelle uscite dal bordo inferiore, cioè una riga di
## schizzi in fondo allo schermo invece di pioggia che batte dappertutto. Il
## terreno, in una vista obliqua, è tutto lo schermo.
func _tick_splashes(delta: float) -> void:
	var view := _view()
	_splash_debt += SPLASH_RATE * _wetness * delta
	while _splash_debt >= 1.0:
		_splash_debt -= 1.0
		_splashes.append(Vector3(randf() * view.x, randf() * view.y, SPLASH_LIFE))
	var alive: Array[Vector3] = []
	for splash in _splashes:
		splash.z -= delta
		if splash.z > 0.0:
			alive.append(splash)
	_splashes = alive

# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	if _haze > 0.01:
		_draw_haze()
	if _wetness > 0.01:
		_draw_rain()
		_draw_splashes()
	if _dark > 0.01:
		_draw_vignette()
	if _flash > 0.01:
		draw_rect(Rect2(Vector2.ZERO, _view()), Color(
			FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, _flash * FLASH_PEAK), true)

func _draw_rain() -> void:
	var entry := Weather.entry(Weather.of(GameState.current))
	var wind := float(entry["wind"])
	var count := int(MAX_DROPS * _wetness)
	for i in count:
		var drop := _drops[i]
		var length: float = lerpf(DROP_LENGTH.x, DROP_LENGTH.y, drop.z)
		# La scia segue la traiettoria vera della goccia, vento compreso:
		# gocce verticali sotto un vento che spinge di lato si leggono subito
		# come sbagliate anche senza sapere perché.
		var fall := Vector2(wind * WIND_PUSH * (0.4 + drop.z * 0.6), lerpf(DROP_SPEED.x, DROP_SPEED.y, drop.z))
		var tail := fall.normalized() * length
		var color := DROP_COLOR
		color.a *= 0.45 + drop.z * 0.55
		draw_line(Vector2(drop.x, drop.y), Vector2(drop.x, drop.y) + tail, color, 1.0)

func _draw_splashes() -> void:
	for splash in _splashes:
		var t := splash.z / SPLASH_LIFE
		var half := 1.0 + (1.0 - t) * 2.5
		var color := SPLASH_COLOR
		color.a *= t
		# Un trattino che si allarga e sbiadisce: a questa scala è tutto quello
		# che serve per leggere "una goccia ha appena toccato terra".
		draw_line(Vector2(splash.x - half, splash.y), Vector2(splash.x + half, splash.y), color, 1.0)

## Foschia: un velo piatto su tutto, più qualche banco più denso che scorre.
## Il velo da solo è un filtro grigio; i banchi da soli sono delle macchie. È
## la somma che si legge come aria spessa.
func _draw_haze() -> void:
	var view := _view()
	var flat := HAZE_COLOR
	flat.a = _haze * 0.30
	draw_rect(Rect2(Vector2.ZERO, view), flat, true)
	for i in HAZE_BANKS:
		var phase := float(i) * 1.37
		var y := fposmod(view.y * (0.12 + 0.13 * float(i)) + sin(_time * 0.11 + phase) * 18.0, view.y)
		var x := fposmod(_haze_phase * (0.4 + 0.2 * float(i % 3)) + phase * 210.0, view.x + 420.0) - 210.0
		var band := HAZE_COLOR
		# Larghi e tenui: a banchi stretti e densi la nebbia si legge come una
		# fila di macchie che passa, non come aria spessa.
		band.a = _haze * 0.10
		draw_colored_polygon(_ellipse(Vector2(x, y), Vector2(250.0 + 60.0 * float(i % 3), 42.0)), band)

## Il buio agli angoli, fatto di cornici sempre più strette e sempre più
## trasparenti verso il centro. Senza shader e senza texture: quattordici
## rettangoli vuoti costano meno di un materiale, e a 640x360 la sfumatura di
## uno shader non si vedrebbe comunque.
func _draw_vignette() -> void:
	var view := _view()
	for i in VIGNETTE_RINGS:
		var inset := float(i) * VIGNETTE_STEP
		var color := VIGNETTE_COLOR
		color.a = _dark * 0.055 * (1.0 - float(i) / float(VIGNETTE_RINGS))
		draw_rect(Rect2(inset, inset, view.x - inset * 2.0, view.y - inset * 2.0), color, false, VIGNETTE_STEP)

# --- Utilità ----------------------------------------------------------------

## Lo schermo in cui disegnare. Con lo stretch "canvas_items" è la risoluzione
## di progetto (640x360) qualunque sia la finestra, quindi la pioggia ha la
## stessa grana a 720p e a schermo intero.
func _view() -> Vector2:
	return get_viewport_rect().size

func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points
