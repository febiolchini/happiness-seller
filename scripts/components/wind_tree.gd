extends Node2D
class_name WindTree

## Una pianta vera, con l'altezza — un albero o un cespuglio: sta fra i nodi
## Y-sortati, quindi chi ci passa dietro sparisce sotto le foglie e chi passa
## davanti le copre.
##
## Gli alberi dei prati (`CityMap.trees()`) sono un'altra cosa: disegnati piatti
## sul terreno. Queste sono i disegni di `tree.png` e `bush.png`, piazzati a mano
## in `CityMap.WIND_TREES` e `CityMap.BUSHES`. Chi le crea sceglie il tipo con
## `kind` prima di aggiungerle all'albero dei nodi.
##
## ## Due modi di muoversi
##
## - **L'albero, a raffiche.** Fermo per qualche secondo, poi una raffica: la
##   chioma si piega di due o tre pixel, le foglie fremono, e torna ferma. Un
##   albero che ondeggia sempre allo stesso modo si legge come un'animazione in
##   loop; uno che ogni tanto si muove si legge come vento.
## - **Il cespuglio, sempre un poco.** E' basso e piccolo, e fermo sembra un
##   sasso verde: ondeggia di continuo di un pixel, con le foglie che fremono
##   piano, e quando passa una raffica si muove di piu'.
##
## In tutti e due la forza viene dal `wind` del meteo, lo stesso che fa girare
## le girandole: col temporale si piegano di piu' e piu' spesso.
##
## La piega la fa `tree_sway.gdshader`; qui si decide solo quanto e quando.
## Ogni pianta ha il suo materiale e i suoi tempi: due vicine che si piegano
## insieme sembrano una cosa sola.

## Il disegno, quanto del basso resta fermo (il tronco: il cespuglio non ce
## l'ha), e la larghezza dell'ombra rispetto al disegno. Caricati e non
## precaricati: con `preload` lo script non si compila finche' Godot non ha
## importato il PNG, e l'importazione si ferma sullo script che non si compila.
const KINDS := {
	"tree": {"texture": "res://assets/sprites/buildings/tree.png", "trunk": 0.3,
		"shadow": Vector2(0.37, 0.11), "always": false},
	"bush": {"texture": "res://assets/sprites/buildings/bush.png", "trunk": 0.0,
		"shadow": Vector2(0.5, 0.2), "always": true},
}
const SWAY := preload("res://shaders/tree_sway.gdshader")

## Di quanti pixel si piega la cima durante una raffica, col vento fermo e con
## quello pieno.
const BEND := Vector2(1.5, 4.0)
## Quanto dura una raffica, e la pausa fra una e l'altra col vento fermo.
const GUST := Vector2(1.4, 3.0)
const CALM := Vector2(4.0, 11.0)
## Il cespuglio fra una raffica e l'altra: di quanti pixel ondeggia, e quanto
## fremono le foglie.
const IDLE_SWAY := 1.2
const IDLE_FLUTTER := 0.35

## "tree" o "bush", una chiave di `KINDS`. Va scelto prima di `add_child()`.
var kind := "tree"

var _material := ShaderMaterial.new()
var _always := false
var _shadow := Vector2(44, 13)
var _wind := 0.2
var _refresh := 0.0
var _wait := 0.0
var _time := 0.0
## Secondi dall'inizio della raffica in corso, negativo se non ce n'e'.
var _gust := -1.0
var _length := 2.0
var _strength := 2.0
var _side := 1.0

func _ready() -> void:
	add_to_group(Daylight.LIGHT_GROUP)
	var spec: Dictionary = KINDS[kind]
	_always = bool(spec["always"])
	var sprite := Sprite2D.new()
	var texture: Texture2D = load(str(spec["texture"]))
	sprite.texture = texture
	sprite.centered = false
	# L'origine e' a terra, al piede, come per gli edifici.
	var size := texture.get_size()
	sprite.offset = Vector2(-size.x * 0.5, -size.y)
	_shadow = size.x * (spec["shadow"] as Vector2)
	_material.shader = SWAY
	_material.set_shader_parameter("trunk", float(spec["trunk"]))
	sprite.material = _material
	add_child(sprite)
	_wait = randf_range(0.5, CALM.y)
	_time = randf() * 100.0

func _process(delta: float) -> void:
	_time += delta
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		if GameState.current != null:
			_wind = float(Weather.entry(Weather.of(GameState.current))["wind"])
	var sway := 0.0
	var flutter := 0.0
	if _always:
		# L'ondeggiare di fondo: due onde lente sovrapposte, cosi' non torna
		# mai uguale a se stesso a ogni giro.
		var calm := sin(_time * 1.3) * 0.7 + sin(_time * 0.47 + 1.1) * 0.3
		sway = calm * IDLE_SWAY * lerpf(0.8, 1.6, clampf(_wind, 0.0, 1.0))
		flutter = IDLE_FLUTTER
	if _gust < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_gust = 0.0
			_length = randf_range(GUST.x, GUST.y)
			_strength = lerpf(BEND.x, BEND.y, clampf(_wind, 0.0, 1.0)) * randf_range(0.75, 1.0)
			_side = 1.0 if randf() < 0.7 else -1.0
	else:
		_gust += delta
		if _gust >= _length:
			_gust = -1.0
			_wait = randf_range(CALM.x, CALM.y) * lerpf(1.0, 0.35, clampf(_wind, 0.0, 1.0))
		else:
			# Sale e scende in una campana, con un'onda sopra: la raffica non
			# spinge con forza costante, arriva a colpi.
			var envelope := sin(PI * _gust / _length)
			var pulse := 0.7 + 0.3 * sin(_gust * 7.0)
			sway += _side * _strength * envelope * pulse
			flutter = maxf(flutter, envelope * 0.8)
	_material.set_shader_parameter("sway", sway)
	_material.set_shader_parameter("flutter", flutter)

## L'ingombro (in orizzontale e in verticale) del disegno di una pianta, dato
## il piede, il tipo e la scala: da dove parte a dove arriva la chioma o il
## cespuglio. Serve a chi semina altra roba intorno (`FlowerBed`) per sapere
## dove non seminare, perché lì sopra non si vedrebbe.
static func footprint(at: Vector2, kind: String, scale: float) -> Rect2:
	var texture: Texture2D = load(str((KINDS[kind] as Dictionary)["texture"]))
	var size: Vector2 = texture.get_size() * scale
	return Rect2(at - Vector2(size.x * 0.5, size.y), size)

## Chiamata da `atmosphere.gd` quando la luce cambia: l'ombra gira col sole.
func on_light_changed() -> void:
	queue_redraw()

## L'ombra a terra, spostata dal sole come quelle degli edifici. E' quello che
## fa sembrare la pianta piantata e non incollata sopra al prato.
func _draw() -> void:
	var info := Daylight.shadow(GameState.current)
	var reach := 34.0 if kind == "tree" else 8.0
	var slide: Vector2 = (info["direction"] as Vector2) * minf(float(info["length"]) * 14.0, reach)
	var points := PackedVector2Array()
	for i in range(21):
		var a := TAU * float(i) / 20.0
		points.append(Vector2(0, -3) + slide + Vector2(cos(a) * _shadow.x, sin(a) * _shadow.y))
	draw_colored_polygon(points, Color(0, 0, 0, 0.12 + float(info["alpha"]) * 0.3))
