extends Node
class_name Airport

## Gli aerei e i mezzi dell'aeroporto: quelli parcheggiati, e i quattro della
## giornata (l'aereo di linea, il bimotore, la scala, il trattorino) che si
## mettono ogni fotogramma dove dice `AirportPlan.pose()`.
##
## Gli sprite sono visti dall'alto e ruotati, come le auto: vedi
## `scripts_tools/render_aeroporto_mezzi.py`. Stanno nei `Props` della City,
## quindi a terra si ordinano per y con edifici e persone.
##
## ## In volo
##
## L'ombra resta a terra e l'aereo sale: si sposta in su sullo schermo di
## quanto e' alto (e' la stessa convenzione degli edifici, in cui un punto alto
## H si disegna H pixel piu' su), si ingrandisce un poco, e passa sopra a tutto
## con uno `z_index` alto — un aereo in volo non puo' finire dietro a un tetto.
## L'ombra si stacca dall'aereo verso sud-est e sbiadisce salendo.

const DIR := "res://assets/sprites/props/airport/"
const SHADOW := Color(0, 0, 0, 0.30)
## Da quanto in su un aereo conta "in volo" e si disegna sopra a tutto.
const AIRBORNE := 2.0
const FLYING_Z := 6

var _props: Node2D = null
## attore -> [sprite, ombra]
var _actors := {}
var _stairs_frames: Array[Texture2D] = []

## `props` e' il nodo Y-sortato della City in cui mettere gli sprite.
func setup(props: Node2D) -> void:
	_props = props
	for entry in AirportPlan.PARKED:
		var pair := _pair(load(DIR + str(entry[0]) + ".png"))
		_place(pair, entry[1], deg_to_rad(float(entry[2])), 0.0, 1.0)
	for i in AirportPlan.STAIRS_FRAMES:
		_stairs_frames.append(load(DIR + "scala_%02d.png" % i))
	_actors["jet"] = _pair(load(DIR + "jet.png"))
	_actors["twin"] = _pair(load(DIR + "bimotore.png"))
	_actors["stairs"] = _pair(_stairs_frames[0])
	_actors["tug"] = _pair(load(DIR + "trattorino.png"))
	_process(0.0)

func _process(_delta: float) -> void:
	if _props == null:
		return
	var hour := Daylight.hour_of(GameState.current)
	for actor: String in _actors:
		var pose := AirportPlan.pose(actor, hour)
		var pair: Array = _actors[actor]
		var visible := bool(pose["visible"]) and float(pose["alpha"]) > 0.01
		(pair[0] as Sprite2D).visible = visible
		(pair[1] as Sprite2D).visible = visible
		if not visible:
			continue
		if actor == "stairs":
			var tex := _stairs_frames[clampi(int(pose["frame"]), 0, _stairs_frames.size() - 1)]
			(pair[0] as Sprite2D).texture = tex
			(pair[1] as Sprite2D).texture = tex
		_place(pair, pose["pos"], float(pose["heading"]), float(pose["alt"]), float(pose["alpha"]))

## Uno sprite e la sua ombra, gia' dentro ai `Props`.
func _pair(texture: Texture2D) -> Array:
	var shadow := Sprite2D.new()
	shadow.texture = texture
	shadow.modulate = SHADOW
	# Sotto a tutto quello che sta in piedi, sopra al pavimento: come le pozze
	# e le ombre delle nuvole di `GroundWeather`.
	shadow.z_index = -1
	var sprite := Sprite2D.new()
	sprite.texture = texture
	_props.add_child(shadow)
	_props.add_child(sprite)
	return [sprite, shadow]

func _place(pair: Array, pos: Vector2, heading: float, alt: float, alpha: float) -> void:
	var sprite: Sprite2D = pair[0]
	var shadow: Sprite2D = pair[1]
	var grow := 1.0 + alt / 1400.0
	sprite.position = pos - Vector2(0.0, alt)
	sprite.rotation = heading
	sprite.scale = Vector2(grow, grow)
	sprite.z_index = FLYING_Z if alt > AIRBORNE else 0
	sprite.modulate.a = alpha
	shadow.position = pos + Vector2(4.0, 5.0) + Vector2(0.30, 0.12) * alt
	shadow.rotation = heading
	var fade := clampf(1.0 - alt / 700.0, 0.0, 1.0)
	shadow.modulate = Color(SHADOW.r, SHADOW.g, SHADOW.b, SHADOW.a * fade * alpha)
