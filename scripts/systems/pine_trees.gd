@tool
extends Node2D
class_name PineTrees

## Gli abeti sparsi sulle colline intorno alla città.
##
## Ogni albero e' un quadrilatero con sopra `pine_tree.gdshader`: un materiale
## solo per tutti, un `_draw()` solo e poi basta. Il vento lo anima lo shader
## col suo `TIME`, quindi da qui a ogni frame si scrive un numero e nient'altro.
##
## ## Dove stanno
##
## Si decide una volta sola, costruendo il paesaggio, ed e' sempre uguale:
## stesso seme, stesse posizioni. Un albero va bene se:
##
## - sta sulle **colline**, la fascia bassa appena fuori citta': sulle montagne
##   c'e' roccia e neve, e piu' in la' la foschia li renderebbe macchie;
## - sta **lontano dalle strade** che escono dalla citta', che passano in valle;
## - non finisce **sopra alla citta'**: un albero a sud del bordo si alza verso
##   nord, e la sua cima non deve coprire l'ultimo isolato;
## - **si vede**: in questa vista le colline davanti coprono quello che hanno
##   dietro, e un albero piantato dietro a una gobba spunterebbe fuori dal
##   terreno come un adesivo. Si controlla come fa lo shader del paesaggio:
##   partendo dal piede dell'albero si guarda verso sud se c'e' terreno
##   abbastanza alto da arrivarci davanti.
##
## Per sapere a che quota sta un punto serve la stessa quota dello shader del
## paesaggio: `quota()` e' la sua copia, e legge le stesse immagini di rumore
## che `city_ground.gd` passa allo shader. Se si ritocca una delle due va
## ritoccata l'altra, o gli alberi si staccano da terra.

const SHADER := preload("res://assets/shaders/pine_tree.gdshader")

## Lato della cella della griglia su cui si provano gli alberi: al massimo uno
## per cella, spostato a caso dentro. Le macchie del rumore decidono quali celle
## ne hanno uno, quindi gli alberi vengono a gruppi e non a scacchiera.
const CELL := 96.0
const SEED := 11
## Altezza di un albero, in pixel di mondo. Un personaggio e' alto una
## quarantina: un abete vero e' cinque o sei volte tanto.
const HEIGHT := Vector2(150.0, 250.0)
## La fascia delle colline, in distanza dal bordo della citta'.
const BAND := Vector2(70.0, 430.0)
## Sopra questa quota (in frazione della cima piu' alta) comincia la roccia.
const MAX_QUOTA := 0.20
## Distanza minima dalle strade che escono dalla citta'.
const ROAD_GAP := 110.0

## Stessi numeri di `landscape.gdshader`.
const SPORGENZA := 0.55
const NOISE_SIZE := 512

var _hills := PackedByteArray()
var _ridges := PackedByteArray()
var _city := Rect2()
var _roads: Array[Rect2] = []
var _depth := 1024.0
var _alt_max := 560.0
## Gli alberi, dal piu' lontano al piu' vicino: piede a schermo, altezza, seme.
var _trees: Array[Dictionary] = []
var _material: ShaderMaterial

## Pianta gli alberi. Le immagini sono i due rumori del paesaggio in L8.
func build(hills: Image, ridges: Image, city: Rect2, roads: Array[Rect2],
		depth: float, alt_max: float, view: Rect2) -> void:
	_hills = _bytes(hills)
	_ridges = _bytes(ridges)
	_city = city
	_roads = roads
	_depth = depth
	_alt_max = alt_max
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	_plant(view)
	queue_redraw()

func _process(_delta: float) -> void:
	if _material == null or Engine.is_editor_hint():
		return
	var entry := Weather.entry(Weather.of(GameState.current))
	_material.set_shader_parameter("vento", 0.2 + absf(float(entry["wind"])))

func _draw() -> void:
	for tree in _trees:
		var foot: Vector2 = tree["foot"]
		var width: float = tree["height"] * 0.62
		# L'ombra per terra, verso sud-est: la luce viene da nord-ovest.
		var shadow := PackedVector2Array()
		for i in range(17):
			var a := TAU * float(i) / 16.0
			shadow.append(foot + Vector2(width * 0.16, 3.0)
				+ Vector2(cos(a) * width * 0.42, sin(a) * width * 0.13))
		# Blu a 1: per lo shader vuol dire "sei un'ombra", vedi `pine_tree.gdshader`.
		draw_polygon(shadow, PackedColorArray([Color(0, 0, 1, 1)]))
	for tree in _trees:
		var foot: Vector2 = tree["foot"]
		var height: float = tree["height"]
		# Largo abbastanza per la chioma e per quanto la piega il vento.
		var half := height * 0.31 + 12.0
		var data := Color(float(tree["seed"]), height / 512.0, 0.0, 1.0)
		draw_polygon(
			PackedVector2Array([
				foot + Vector2(-half, 6.0), foot + Vector2(half, 6.0),
				foot + Vector2(half, -height - 4.0), foot + Vector2(-half, -height - 4.0)]),
			PackedColorArray([data]),
			PackedVector2Array([
				Vector2(-half, -6.0), Vector2(half, -6.0),
				Vector2(half, height + 4.0), Vector2(-half, height + 4.0)]))

# --- Dove piantarli ---------------------------------------------------------

func _plant(view: Rect2) -> void:
	_trees.clear()
	var rng := RandomNumberGenerator.new()
	var from := Vector2i(floori(view.position.x / CELL), floori(view.position.y / CELL))
	var to := Vector2i(ceili(view.end.x / CELL), ceili(view.end.y / CELL))
	for cy in range(from.y, to.y):
		for cx in range(from.x, to.x):
			var corner := Vector2(cx, cy) * CELL
			# Scarto veloce: la cella intera e' in citta' o troppo lontana.
			var near := _outside(corner + Vector2(CELL, CELL) * 0.5)
			if near < BAND.x - CELL or near > BAND.y + CELL:
				continue
			rng.seed = hash(Vector3i(cx, cy, SEED))
			var point := corner + Vector2(rng.randf(), rng.randf()) * CELL
			var tree := _try(point, rng)
			if not tree.is_empty():
				_trees.append(tree)
	_trees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["ground"] as Vector2).y < (b["ground"] as Vector2).y)

func _try(point: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var d := _outside(point)
	if d < BAND.x or d > BAND.y:
		return {}
	# A gruppi: dove il rumore delle macchie e' alto (lo stesso che nello shader
	# fa i boschi) gli alberi sono fitti, altrove se ne trova uno ogni tanto.
	var patch := _sample(_hills, point / 1800.0 + Vector2(0.21, 0.63))
	if rng.randf() > 0.05 + 0.50 * smoothstep(0.42, 0.62, patch):
		return {}
	var height := rng.randf_range(HEIGHT.x, HEIGHT.y)
	var half := height * 0.31
	if _from_roads(point) < ROAD_GAP + half:
		return {}
	var q := quota(point)
	if q / _alt_max > MAX_QUOTA:
		return {}
	var foot := point - Vector2(0.0, q)
	var top := foot - Vector2(0.0, height)
	for corner in [foot + Vector2(-half, 0), foot + Vector2(half, 0),
			top + Vector2(-half, 0), top + Vector2(half, 0)]:
		if _outside(corner) < 8.0:
			return {}
	# Qualcosa piu' a sud arriva abbastanza in alto da coprire il piede?
	var t := q + 6.0
	while t < q + 280.0:
		if quota(foot + Vector2(0.0, t)) >= t:
			return {}
		t += 10.0
	return {"foot": foot.round(), "ground": point, "height": roundf(height), "seed": rng.randf()}

# --- La copia della quota dello shader --------------------------------------

## La quota di un punto, in pixel di mondo. E' `quota()` di
## `landscape.gdshader`, riga per riga.
func quota(p: Vector2) -> float:
	var d := _outside(p)
	if d <= 0.0:
		return 0.0
	var t := d / _depth
	var c := _sample(_hills, p / 4096.0)
	var r := _sample(_ridges, p / 5120.0 + Vector2(0.37, 0.11))
	var h := smoothstep(0.0, 0.32, t) * (0.05 + 0.20 * c)
	h += smoothstep(0.22, 0.90, t) * (0.20 + 0.80 * r) * (0.65 + 0.45 * c)
	h *= smoothstep(40.0, 520.0, _from_roads(p))
	return minf(h * _alt_max, d * SPORGENZA)

func _outside(p: Vector2) -> float:
	var a := _city.position - p
	var b := p - _city.end
	return Vector2(maxf(maxf(a.x, b.x), 0.0), maxf(maxf(a.y, b.y), 0.0)).length()

func _from_roads(p: Vector2) -> float:
	var best := INF
	for road in _roads:
		var d := (p - road.get_center()).abs() - road.size * 0.5
		var v := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)
		best = minf(best, v)
	return best

## Lettura bilineare con ripetizione, come `texture()` con `filter_linear` e
## `repeat_enable`.
func _sample(data: PackedByteArray, uv: Vector2) -> float:
	var x := uv.x * NOISE_SIZE - 0.5
	var y := uv.y * NOISE_SIZE - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var ax := posmod(x0, NOISE_SIZE)
	var bx := posmod(x0 + 1, NOISE_SIZE)
	var ay := posmod(y0, NOISE_SIZE) * NOISE_SIZE
	var by := posmod(y0 + 1, NOISE_SIZE) * NOISE_SIZE
	var top := lerpf(data[ay + ax], data[ay + bx], fx)
	var bottom := lerpf(data[by + ax], data[by + bx], fx)
	return lerpf(top, bottom, fy) / 255.0

func _bytes(image: Image) -> PackedByteArray:
	var copy := image.duplicate() as Image
	if copy.get_format() != Image.FORMAT_L8:
		copy.convert(Image.FORMAT_L8)
	return copy.get_data()
