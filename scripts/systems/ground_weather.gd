extends Node2D

## Il tempo che fa, ma per terra: le ombre delle nuvole che scorrono sui
## quartieri, l'asfalto bagnato, le pozze, le cartacce che il vento porta in
## giro.
##
## Sta **nel mondo** e non a schermo, al contrario di `weather_view.gd`, perché
## queste sono cose che hanno un posto nella città: un'ombra di nuvola ancorata
## allo schermo scivolerebbe sui tetti mentre ci si guarda intorno con il tasto
## destro, ed è il genere di errore che si nota subito anche senza saperlo
## spiegare.
##
## Nell'albero sta subito dopo `Ground` e senza Y-sort, quindi si posa sul
## terreno e tutto il resto — edifici, persone, auto — ci passa sopra. La tinta
## dell'aria lo raggiunge come raggiunge il terreno, ed è giusto così: un'ombra
## di nuvola di notte non si vede, e infatti di notte le nuvole qui non ci sono.
##
## ## Niente stato sparso per la mappa
##
## Le ombre delle nuvole non sono una lista di oggetti che vivono da qualche
## parte nella città: sono ricavate da una griglia infinita agganciata alla
## camera (`_draw_clouds()`). Cinquemila per quattromila pixel di mappa
## riempiti di nuvole vorrebbero dire tenerne in vita centinaia per vederne
## cinque, e salvarle per non farle saltare da una parte all'altra ricaricando.
## Così invece non esistono finché non le si guarda, e sono sempre le stesse.

## Lato della cella della griglia delle nuvole. Una nuvola per cella, con
## posizione e taglia decise dalla cella stessa: celle più piccole diventano una
## retinatura, più grandi lasciano interi quartieri senza mai un'ombra.
const CLOUD_CELL := 320.0
const CLOUD_COLOR := Color(0.05, 0.06, 0.12)
## Quanto scorre un'ombra di nuvola, in pixel al secondo a vento pieno.
const CLOUD_DRIFT := 46.0

## Velo d'acqua sull'asfalto, e riflesso dei lampioni dentro alle pozze.
const WET_COLOR := Color(0.36, 0.45, 0.62)
const PUDDLE_COLOR := Color(0.52, 0.62, 0.78)
## Una pozza ogni tanti pixel di strada: abbastanza rade da essere una pozza e
## non un allagamento.
const PUDDLE_CELL := 224.0

## Cartacce e foglie portate dal vento. Poche e sempre le stesse: si rimettono
## in gioco dal bordo opposto quando escono dall'inquadratura.
const LITTER_COUNT := 18
const LITTER_COLORS := [
	Color(0.72, 0.70, 0.62), Color(0.55, 0.50, 0.40),
	Color(0.45, 0.52, 0.36), Color(0.66, 0.62, 0.58),
]

## In quanti secondi il velo d'acqua a schermo raggiunge quello della partita,
## come in `weather_view.gd`: la pioggia che comincia bagna l'asfalto in qualche
## secondo, non nell'istante in cui scocca la mezzanotte.
const EASE_SPEED := 0.6

var _time := 0.0
var _wet := 0.0
var _clouds := 0.0
## Il vento di adesso, calcolato in `_process()` e riletto da `_draw_clouds()`:
## stesso `Weather.entry()`, una lettura sola invece di due per fotogramma.
var _wind := 0.0
## Ogni cartaccia: posizione, angolo, velocità propria.
var _litter: Array[Dictionary] = []

func _ready() -> void:
	# Dietro al terreno non ci va niente, ma davanti nemmeno: questo nodo deve
	# stare esattamente dove lo mette l'ordine dell'albero. Y-sort spento.
	y_sort_enabled = false

func _process(delta: float) -> void:
	_time += delta
	var entry := Weather.entry(Weather.of(GameState.current))
	_wet = lerpf(_wet, float(entry["rain"]), 1.0 - exp(-delta / EASE_SPEED))
	# Le ombre delle nuvole hanno bisogno del sole: col buio non esistono, e
	# disegnarle lo stesso vorrebbe dire macchie scure su una strada già scura.
	var sun := Daylight.sun_height(Daylight.hour_of(GameState.current))
	_clouds = lerpf(_clouds, float(entry["clouds"]) * sun, 1.0 - exp(-delta / EASE_SPEED))
	_wind = float(entry["wind"])
	_move_litter(delta, _wind)
	queue_redraw()

func _draw() -> void:
	var view := _camera_rect()
	if _clouds > 0.01:
		_draw_clouds(view)
	if _wet > 0.01:
		_draw_wet(view)
	_draw_litter()

# --- Ombre delle nuvole -----------------------------------------------------

## Una griglia infinita che scorre col vento: per ogni cella visibile si ricava
## dalla cella stessa dove sta la nuvola e quanto è grande, sempre con gli
## stessi numeri. Vedi il commento in cima al file.
func _draw_clouds(view: Rect2) -> void:
	var drift := Vector2(_wind, 0.28) * CLOUD_DRIFT * _time
	var field := Rect2(view.position - drift, view.size)
	var from := Vector2i(floori(field.position.x / CLOUD_CELL), floori(field.position.y / CLOUD_CELL))
	var to := Vector2i(ceili(field.end.x / CLOUD_CELL), ceili(field.end.y / CLOUD_CELL))
	for cy in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			var noise := absi(hash("%d,%d" % [cx, cy]))
			# Non tutte le celle hanno una nuvola: con il cielo sereno ne passa
			# una ogni tanto, col coperto quasi tutte.
			if float(noise % 100) / 100.0 > _clouds:
				continue
			var jitter := Vector2(
				float((noise / 100) % 100) / 100.0, float((noise / 10000) % 100) / 100.0)
			var size := 90.0 + float((noise / 1000000) % 70)
			var center := Vector2(cx, cy) * CLOUD_CELL + jitter * CLOUD_CELL + drift
			var color := CLOUD_COLOR
			color.a = 0.13 * _clouds
			draw_colored_polygon(Shapes.ellipse(center, Vector2(size, size * 0.52)), color)

# --- Asfalto bagnato --------------------------------------------------------

## L'acqua si vede solo dove c'è asfalto: sul prato o sulla terra battuta un
## velo azzurrino si leggerebbe come un errore di disegno.
func _draw_wet(view: Rect2) -> void:
	var sheen := WET_COLOR
	sheen.a = 0.16 * _wet
	for road: Rect2 in CityMap.ROADS_H + CityMap.ROADS_V:
		var visible_part := road.intersection(view)
		if visible_part.size.x <= 0.0 or visible_part.size.y <= 0.0:
			continue
		draw_rect(visible_part, sheen, true)
		_draw_puddles(visible_part)

## Pozze sulla parte di strada inquadrata, una per cella della griglia. Come per
## le nuvole, la posizione la decide la cella: le pozze restano dove sono fra un
## frame e l'altro senza che nessuno le tenga in vita.
func _draw_puddles(part: Rect2) -> void:
	var from := Vector2i(floori(part.position.x / PUDDLE_CELL), floori(part.position.y / PUDDLE_CELL))
	var to := Vector2i(ceili(part.end.x / PUDDLE_CELL), ceili(part.end.y / PUDDLE_CELL))
	var color := PUDDLE_COLOR
	color.a = 0.22 * _wet
	for cy in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			var noise := absi(hash("pool%d,%d" % [cx, cy]))
			if noise % 100 > 55:
				continue
			var jitter := Vector2(
				float((noise / 100) % 100), float((noise / 10000) % 100)) / 100.0
			var center := Vector2(cx, cy) * PUDDLE_CELL + jitter * PUDDLE_CELL
			if not part.has_point(center):
				continue
			var width := 14.0 + float((noise / 1000000) % 26)
			# Il tremolio è lentissimo e minimo: una pozza che pulsa si nota,
			# una pozza ferma in un temporale sembra vernice.
			var wobble := 1.0 + 0.05 * sin(_time * 1.3 + float(cx + cy))
			draw_colored_polygon(Shapes.ellipse(center, Vector2(width, width * 0.34) * wobble), color)

# --- Cartacce ---------------------------------------------------------------

## Le cartacce nascono la prima volta che servono e poi girano: uscite
## dall'inquadratura rientrano dal lato opposto. Sono diciotto in tutto,
## qualunque sia la grandezza della città.
func _move_litter(delta: float, wind: float) -> void:
	var view := _camera_rect()
	if _litter.is_empty():
		for i in LITTER_COUNT:
			_litter.append({
				"pos": view.position + Vector2(randf() * view.size.x, randf() * view.size.y),
				"spin": randf() * TAU,
				"speed": 0.5 + randf(),
				"color": LITTER_COLORS[i % LITTER_COLORS.size()],
			})
	# Senza vento restano ferme dove sono: è il vento a portarle in giro, e in
	# una giornata di bonaccia una cartaccia che scivola da sola è un fantasma.
	var push := Vector2(wind, sin(_time * 0.7) * 0.12) * 70.0
	for piece in _litter:
		var speed: float = piece["speed"]
		piece["pos"] += push * speed * delta
		piece["spin"] += delta * (0.6 + absf(wind) * 5.0) * speed
		var pos: Vector2 = piece["pos"]
		if not view.grow(40.0).has_point(pos):
			# Rientra dal bordo da cui soffia il vento, a un'altezza a caso.
			var entry_x: float = view.position.x - 24.0 if push.x >= 0.0 else view.end.x + 24.0
			piece["pos"] = Vector2(entry_x, view.position.y + randf() * view.size.y)

func _draw_litter() -> void:
	for piece in _litter:
		var pos: Vector2 = piece["pos"]
		var spin: float = piece["spin"]
		# Un quadratino che ruota e si schiaccia: a tre pixel di lato è tutto
		# quello che serve perché l'occhio ci legga una carta che rotola.
		var wide := 1.5 + absf(cos(spin)) * 2.0
		var tall := 1.0 + absf(sin(spin)) * 1.6
		var color: Color = piece["color"]
		color.a = 0.75
		draw_rect(Rect2(pos.x - wide, pos.y - tall, wide * 2.0, tall * 2.0), color, true)

# --- Utilità ----------------------------------------------------------------

## Il rettangolo di mondo inquadrato adesso, un po' più largo dello schermo.
##
## È quello che tiene il costo di questo nodo legato allo schermo e non alla
## mappa: nuvole e pozze si disegnano solo dove si guarda, e la città può
## crescere quanto vuole senza che questo disegno rallenti.
func _camera_rect() -> Rect2:
	return Shapes.camera_world_rect(self, 96.0)
