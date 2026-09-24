extends Node2D
class_name LayeredGrass

## I prati a strati di un quartiere: dei rettangoli con sopra
## `layered_grass.gdshader`, e le tre cose che lo shader da solo non sa — chi ci
## cammina sopra, quali lampioni sono accesi, quanto tira il vento.
##
## **Un nodo per quartiere, non uno per isolato.** HILLSIDE sono una
## cinquantina di isolati: cinquanta nodi vorrebbero dire cinquanta volte a
## ogni frame la stessa lista di passanti e di lampioni. Qui il materiale e'
## uno, i rettangoli sono tanti, e ognuno si porta il suo bordo alto nella UV
## dei vertici (vedi lo shader).
##
## **Sta a (0,0) e disegna in coordinate mondo**, come `grass_field.gd` e per
## lo stesso motivo: e' pavimento, e con `z_index` -2 sta sotto a chiunque ci
## cammini sopra qualunque sia la sua y.
##
## ## Le impronte
##
## Sotto ai piedi l'erba si schiaccia, e quando si passa oltre non torna su di
## colpo: ogni pochi passi resta un'impronta che si rialza in tre secondi. E' la
## scia che fa capire che l'erba ha reagito al passaggio, e non che il
## personaggio ha una macchia che lo segue.

const SHADER := preload("res://assets/shaders/layered_grass.gdshader")

## Le tinte dei prati, per quartiere.
##
## `curato` e' il prato dei benestanti: verde pieno, chiaro, toni vicini fra
## loro come un tappeto tagliato da poco. `incolto` e' quello di THE FLATS: lo
## stesso prato fitto, ma lasciato andare — tirato verso il giallo e il
## marroncino della paglia, perche' nessuno lo innaffia. `brullo` e' quello della
## zona industriale, ancora un filo piu' verso la terra.
const STYLES := {
	"curato": {
		"fondo": Color(0.200, 0.270, 0.120), "scuro": Color(0.280, 0.370, 0.150),
		"medio": Color(0.310, 0.410, 0.165), "chiaro": Color(0.340, 0.450, 0.180),
		"punta": Color(0.420, 0.540, 0.220), "stelo": Color(0.190, 0.260, 0.100),
		"illuminata": Color(0.500, 0.660, 0.220),
	},
	# La zona industriale: lo stesso prato fitto, ma tirato verso il marroncino
	# della terra battuta fra un capannone e l'altro.
	"brullo": {
		"fondo": Color(0.250, 0.235, 0.130), "scuro": Color(0.345, 0.330, 0.170),
		"medio": Color(0.380, 0.365, 0.185), "chiaro": Color(0.420, 0.400, 0.200),
		"punta": Color(0.515, 0.490, 0.255), "stelo": Color(0.235, 0.215, 0.110),
		"illuminata": Color(0.580, 0.560, 0.270),
	},
	"incolto": {
		"fondo": Color(0.235, 0.260, 0.125), "scuro": Color(0.320, 0.360, 0.160),
		"medio": Color(0.355, 0.395, 0.175), "chiaro": Color(0.395, 0.435, 0.190),
		"punta": Color(0.490, 0.520, 0.245), "stelo": Color(0.220, 0.235, 0.105),
		"illuminata": Color(0.580, 0.590, 0.260),
	},
}

## Quante impronte e quanti lampioni sa leggere lo shader: le dimensioni dei
## due array uniform in `layered_grass.gdshader`.
const MAX_PRINTS := 32
const MAX_LIGHTS := 8

## Ogni quanti pixel di cammino resta un'impronta.
const PRINT_STEP := 5.0
## In quanti secondi un'impronta si rialza del tutto.
const RECOVER := 3.0
## Il braccio del lampione, che sposta la luce dal palo alla lampada: stesso
## numero di `street_lamp.gd`.
const LAMP_ARM := 18.0

## I prati, in coordinate mondo.
var rects: Array[Rect2] = []
## Una chiave di `STYLES`.
var style := "curato"

var _material: ShaderMaterial
## Impronte lasciate: x, y, forza.
var _prints: Array[Vector3] = []
## instance_id di chi cammina -> dove ha lasciato l'ultima impronta.
var _last_print := {}
## Centri delle luci dei lampioni che toccano i prati.
var _lamps: Array[Vector2] = []

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var colors: Dictionary = STYLES[style]
	for key in colors:
		_material.set_shader_parameter(key, colors[key])
	material = _material
	for entry in CityMap.street_lamps() + CityMap.lot_lamps():
		var center: Vector2 = entry["pos"] + (entry["reach"] as Vector2).normalized() * LAMP_ARM
		if _touches(center, 130.0):
			_lamps.append(center)

func _process(delta: float) -> void:
	var data := GameState.current
	var entry := Weather.entry(Weather.of(data))
	var hour := Daylight.hour_of(data)
	_material.set_shader_parameter("vento", 0.25 + absf(float(entry["wind"])))
	_material.set_shader_parameter("sole", Daylight.sun_height(hour) * float(entry["shadows"]))
	var ambient := Daylight.light(data)
	_material.set_shader_parameter("ambiente", Vector3(ambient.r, ambient.g, ambient.b))
	var view := _camera_rect()
	_update_lights(Daylight.lamp_strength(data), view)
	_update_prints(delta, view)

func _draw() -> void:
	# Bianco pieno: il colore lo decide lo shader. La UV porta il bordo alto del
	# rettangolo, che lo shader usa per far cominciare lì il prato.
	for rect in rects:
		var top := Vector2(rect.position.y, 0.0)
		draw_polygon(
			PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
				rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([Color.WHITE]),
			PackedVector2Array([top, top, top, top]))

func _update_lights(strength: float, view: Rect2) -> void:
	var lights := PackedVector3Array()
	if strength > 0.01:
		var eye := view.get_center()
		var near := _lamps.filter(func(center: Vector2) -> bool:
			return view.grow(130.0).has_point(center))
		near.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.distance_squared_to(eye) < b.distance_squared_to(eye))
		for center: Vector2 in near.slice(0, MAX_LIGHTS):
			lights.append(Vector3(center.x, center.y, strength))
	_material.set_shader_parameter("n_luci", lights.size())
	lights.resize(MAX_LIGHTS)
	_material.set_shader_parameter("luci", lights)

func _update_prints(delta: float, view: Rect2) -> void:
	var alive: Array[Vector3] = []
	for print_ in _prints:
		print_.z -= delta / RECOVER
		if print_.z > 0.0:
			alive.append(print_)
	_prints = alive

	# Solo chi e' inquadrato: gli slot sono trentadue, e un quartiere intero di
	# passanti se li mangerebbe tutti lontano da dove si guarda.
	var feet := PackedVector3Array()
	for walker in _walkers():
		var pos := walker.global_position
		var id := walker.get_instance_id()
		if not view.has_point(pos) or not _touches(pos, 16.0):
			_last_print.erase(id)
			continue
		feet.append(Vector3(pos.x, pos.y, 1.0))
		if not _last_print.has(id) or (_last_print[id] as Vector2).distance_to(pos) >= PRINT_STEP:
			_last_print[id] = pos
			_prints.append(Vector3(pos.x, pos.y, 1.0))

	# I piedi prima, poi le impronte dalla piu' fresca: se non ci stanno tutte
	# si perdono quelle gia' quasi rialzate, che sono quelle che non si vedono.
	var list := feet
	for i in range(_prints.size() - 1, -1, -1):
		if list.size() >= MAX_PRINTS:
			break
		list.append(_prints[i])
	if _prints.size() > MAX_PRINTS * 2:
		_prints = _prints.slice(_prints.size() - MAX_PRINTS * 2)
	_material.set_shader_parameter("n_impronte", mini(list.size(), MAX_PRINTS))
	list.resize(MAX_PRINTS)
	_material.set_shader_parameter("impronte", list)

func _walkers() -> Array[Node2D]:
	var list: Array[Node2D] = []
	var player := get_parent().get_node_or_null("Player") as Node2D
	if player != null:
		list.append(player)
	for npc in get_tree().get_nodes_in_group(Npc.GROUP):
		if npc is Node2D and (npc as Node2D).visible:
			list.append(npc)
	return list

## Se un punto sta su uno dei prati, o a meno di `margin` pixel.
func _touches(point: Vector2, margin: float) -> bool:
	for rect in rects:
		if rect.grow(margin).has_point(point):
			return true
	return false

## Il rettangolo di mondo inquadrato adesso, un po' più largo dello schermo.
## Stesso conto di `ground_weather.gd`.
func _camera_rect() -> Rect2:
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := to_world * Vector2.ZERO
	var bottom_right := to_world * get_viewport_rect().size
	return Rect2(top_left, bottom_right - top_left).grow(64.0)
