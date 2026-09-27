class_name WindowView
extends Node2D

## Quello che si vede dalla vetrata di una stanza in alto in un grattacielo:
## la città VERA, dal punto della mappa in cui sta la stanza.
##
## Il fondale della stanza ha i vetri trasparenti (holdout in
## `blender_stanze.py`, alfa conservata da `import_room_art.py`), e questo
## nodo sta sotto al fondale: si vede solo attraverso i vetri, e montanti,
## piante e mobili gli passano davanti da soli.
##
## ## Come si ricostruisce la città
##
## Dentro a una `SubViewport` 3D, dagli stessi dati che costruiscono la mappa,
## quindi quello che si vede fuori è quello che c'è davvero:
##
## - **il terreno** è `city_ground.gd` stesso, renderizzato UNA volta dall'alto
##   in una texture e steso su un piano. Strade, marciapiedi, prati, piazzali:
##   tutto quello che si vede camminando.
## - **gli edifici** sono i loro PNG, in piedi sulla loro riga di terra come
##   cartonati. Il disegno è già una vista da sud, ed è da sud che si guarda:
##   da quassù una città di sagome in fila è esattamente uno skyline.
## - **le montagne** sono lo shader del bordo (`landscape.gdshader`), che
##   disegna già un rilievo visto da sud: se ne renderizza la fascia nord e la
##   si mette in piedi sul bordo della città, all'orizzonte.
## - **le auto** girano sulle corsie di `CityMap.lanes()` alle loro velocità,
##   sdraiate sull'asfalto (gli sprite sono visti dall'alto).
## - **il cielo** e la **foschia** vengono dall'ora e dal meteo; di notte si
##   accendono le finestre (`lit` delle voci della pianta) e i lampioni.
##
## Tutto in unità di mondo: un pixel di mappa è un'unità, e l'altezza di uno
## sprite in pixel è la sua altezza in unità. È la stessa proporzione con cui
## la città si guarda in strada, ed è quella che rende la vista "vera".
##
## La luce dell'ora la mette questo nodo sulle cose di fuori; quella della
## stanza (`RoomLight`, il `CanvasModulate`) non deve sommarcisi sopra, quindi
## `room.gd` lo mette fra i nodi da compensare, come le scritte.

const CITY_GROUND := preload("res://scripts/levels/city_ground.gd")
const SKY_SHADER := preload("res://assets/shaders/window_sky.gdshader")
const MOUNTAIN_SHADER := preload("res://assets/shaders/window_mountains.gdshader")

## Pixel di mondo per metro: la scala degli edifici (`render_buildings.py`).
const PX_PER_METRE := 22.3
## Un piano, in metri, e l'altezza degli occhi sul pavimento.
const FLOOR_METRES := 3.6
const EYE_METRES := 1.6
## La vista si renderizza al doppio e si riduce: le sagome lontane sono
## centinaia di pixel di disegno stretti in pochi, e a uno a uno sfarfallano.
const SUPERSAMPLE := 2
## A che scala si fotografa il terreno: un quarto basta, lo si guarda da
## chilometri. La texture viene sui tremila pixel di lato.
const GROUND_SCALE := 0.25
## Quanto la camera guarda in giù, e quanto è larga. La vetrata è una striscia
## quattro volte più larga che alta: più in giù si vedrebbero le strade sotto
## la torre ma non l'orizzonte, più in su solo cielo.
const PITCH_DEGREES := 7.0
const FOV_DEGREES := 84.0
## I lampioni di notte: quanto sta in alto il punto luce e quanto è grande.
const LAMP_HEAD := 70.0
const LAMP_GLOW := 26.0
## Quanto sono alte le creste piu' alte, in unita' di mondo: abbastanza da
## salire un poco sopra all'orizzonte visto dal 21 piano.
const MOUNTAIN_HEIGHT := 2050.0
## La campagna oltre il bordo del mondo: il verde delle colline del bordo.
const FIELDS := Color(0.30, 0.42, 0.25)

## Il cielo in otto momenti della giornata: zenit e orizzonte. Stessa idea di
## `Daylight.KEYFRAMES`, ma quello è il colore dell'aria sulle cose e questo è
## il cielo dietro: un cielo di mezzogiorno non è bianco come la luce.
const SKY_KEYS := [
	{"hour": 0.0, "top": Color(0.03, 0.04, 0.10), "horizon": Color(0.10, 0.12, 0.24)},
	{"hour": 5.2, "top": Color(0.04, 0.05, 0.12), "horizon": Color(0.12, 0.13, 0.26)},
	{"hour": 6.6, "top": Color(0.30, 0.35, 0.58), "horizon": Color(0.95, 0.66, 0.55)},
	{"hour": 8.5, "top": Color(0.38, 0.58, 0.84), "horizon": Color(0.80, 0.86, 0.92)},
	{"hour": 17.0, "top": Color(0.36, 0.58, 0.86), "horizon": Color(0.78, 0.86, 0.93)},
	{"hour": 19.2, "top": Color(0.34, 0.40, 0.68), "horizon": Color(0.98, 0.64, 0.42)},
	{"hour": 20.6, "top": Color(0.10, 0.11, 0.26), "horizon": Color(0.42, 0.28, 0.40)},
	{"hour": 22.0, "top": Color(0.03, 0.04, 0.10), "horizon": Color(0.10, 0.12, 0.24)},
	{"hour": 24.0, "top": Color(0.03, 0.04, 0.10), "horizon": Color(0.10, 0.12, 0.24)},
]

var _rect := Rect2()
var _building_id := ""
var _floor := 1

var _viewport: SubViewport
var _camera: Camera3D
var _env: Environment
var _sky: ShaderMaterial
var _ground: StandardMaterial3D
var _fields: StandardMaterial3D
var _mountains: ShaderMaterial
var _noise: NoiseTexture2D
var _sprites: Array[Sprite3D] = []
var _lit: Array[Sprite3D] = []
var _lamps: MultiMeshInstance3D
var _lamp_material: StandardMaterial3D
## Ogni auto: [nodo, corsia, posizione lungo la corsia].
var _cars: Array = []
var _textures := {}
var _drift := 0.0
var _light_timer := 0.0

## `rect` è il rettangolo della vetrata in pixel di stanza; `building_id` è la
## voce di `CityMap.BUILDINGS` in cui sta la stanza, `floor_number` il piano.
func setup(rect: Rect2, building_id: String, floor_number: int) -> void:
	_rect = rect
	_building_id = building_id
	_floor = floor_number

func _ready() -> void:
	name = "WindowView"
	var entry := _building_entry()
	if entry.is_empty():
		push_warning("WindowView: edificio %s non trovato nella pianta" % _building_id)
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(_rect.size) * SUPERSAMPLE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

	var world := Node3D.new()
	world.name = "Citta"
	_viewport.add_child(world)
	_build_environment(world)
	_build_camera(world, entry)
	_build_ground(world)
	_build_mountains(world)
	_build_buildings(world, entry)
	_build_lamps(world)
	_build_cars(world)

	var picture := Sprite2D.new()
	picture.name = "Picture"
	picture.texture = _viewport.get_texture()
	picture.centered = false
	picture.position = _rect.position
	picture.scale = Vector2.ONE / float(SUPERSAMPLE)
	# Lineare: e' la riduzione del supersampling, non uno sprite da ingrandire.
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(picture)
	var glass := Node2D.new()
	glass.name = "Glass"
	glass.draw.connect(_draw_glass.bind(glass))
	add_child(glass)
	_update_light()

func _process(delta: float) -> void:
	if _viewport == null:
		return
	_move_cars(delta)
	var weather := Weather.entry(Weather.of(GameState.current))
	# Le nuvole scorrono col vento del giorno, da ovest a est; anche senza vento
	# si muovono appena, o il cielo sembra dipinto.
	_drift += delta * (0.0015 + absf(float(weather["wind"])) * 0.004)
	_sky.set_shader_parameter("drift", _drift)
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 1.0
		_update_light()

# --- Dove sta la finestra ---------------------------------------------------

func _building_entry() -> Dictionary:
	for entry in CityMap.BUILDINGS:
		if str(entry["id"]) == _building_id:
			return entry
	return {}

## Gli occhi di chi sta alla vetrata: sulla facciata nord della torre, al piano
## giusto. La facciata nord è il bordo alto del `click`, che per una torre è il
## suo piede (vedi la voce MERIDIAN TOWER in `city_map.gd`).
func _eye(entry: Dictionary) -> Vector3:
	var base: Vector2 = entry["base"]
	var foot: Rect2 = entry.get("click", Rect2(-50, -100, 100, 100))
	var height := (float(_floor) * FLOOR_METRES + EYE_METRES) * PX_PER_METRE
	return Vector3(base.x + foot.get_center().x, height, base.y + foot.position.y - 4.0)

func _build_camera(world: Node3D, entry: Dictionary) -> void:
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = FOV_DEGREES
	_camera.near = 20.0
	_camera.far = 40000.0
	_camera.position = _eye(entry)
	# Nord è -Z (la y della mappa cresce verso sud): la camera di Godot guarda
	# già verso -Z, basta abbassarla.
	_camera.rotation_degrees = Vector3(-PITCH_DEGREES, 0.0, 0.0)
	world.add_child(_camera)

# --- Cielo e foschia ----------------------------------------------------------

func _build_environment(world: Node3D) -> void:
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 256
	noise.height = 256
	_noise = noise
	var fast := FastNoiseLite.new()
	fast.seed = 11
	fast.frequency = 0.012
	fast.fractal_octaves = 4
	noise.noise = fast
	_sky.set_shader_parameter("noise", noise)
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = 3500.0
	_env.fog_depth_end = 14000.0
	_env.fog_depth_curve = 1.6
	_env.fog_density = 0.6
	_env.fog_sky_affect = 0.0
	var env_node := WorldEnvironment.new()
	env_node.environment = _env
	world.add_child(env_node)

# --- Il terreno ---------------------------------------------------------------

## Fotografa `city_ground.gd` dall'alto in una texture, una volta sola.
##
## Il terreno non cambia con l'ora — la luce la mette il materiale — quindi
## basta un fotogramma. Senza le scritte: i nomi delle strade da quassù
## sarebbero graffi.
func _ground_texture() -> ViewportTexture:
	var view := CityMap.view_bounds()
	var shot := SubViewport.new()
	shot.name = "GroundShot"
	shot.size = Vector2i(view.size * GROUND_SCALE)
	shot.render_target_update_mode = SubViewport.UPDATE_ONCE
	shot.disable_3d = true
	add_child(shot)
	var ground := Node2D.new()
	ground.set_script(CITY_GROUND)
	shot.add_child(ground)
	var labels := ground.get_node_or_null("Scritte")
	if labels != null:
		labels.visible = false
	var cam := Camera2D.new()
	cam.position = view.get_center()
	cam.zoom = Vector2.ONE * GROUND_SCALE
	shot.add_child(cam)
	return shot.get_texture()

func _build_ground(world: Node3D) -> void:
	var view := CityMap.view_bounds()
	var mesh := PlaneMesh.new()
	mesh.size = view.size
	_ground = _unshaded(null)
	_ground.albedo_texture = _ground_texture()
	_ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	# Sotto, una campagna senza fine: il terreno fotografato finisce col mondo,
	# e ai lati della vista, lontano, si vedrebbe il vuoto sotto l'orizzonte.
	var fields := PlaneMesh.new()
	fields.size = view.size * 6.0
	_fields = _unshaded(null)
	var under := MeshInstance3D.new()
	under.name = "Campagna"
	under.mesh = fields
	under.material_override = _fields
	under.position = Vector3(view.get_center().x, -2.0, view.get_center().y)
	world.add_child(under)
	var plane := MeshInstance3D.new()
	plane.name = "Terreno"
	plane.mesh = mesh
	plane.material_override = _ground
	var center := view.get_center()
	plane.position = Vector3(center.x, 0.0, center.y)
	world.add_child(plane)

# --- Le montagne --------------------------------------------------------------

## L'orizzonte: tre file di creste in piedi sul bordo nord del mondo, dietro
## alla fascia di colline che il terreno ha gia' disegnato piatta.
##
## Non e' `landscape.gdshader` fotografato e messo in piedi: e' stato provato,
## e quello e' un rilievo visto dall'ALTO con le cime spostate di poco, quindi
## in piedi faceva un muro di prato con due macchie di roccia. Questo invece
## e' disegnato per essere guardato di fronte. La valle si apre dove esce
## PORT STREET, la strada che lascia la citta' a nord.
func _build_mountains(world: Node3D) -> void:
	var view := CityMap.view_bounds()
	var width := view.size.x * 1.6
	var left := view.get_center().x - width * 0.5
	_mountains = ShaderMaterial.new()
	_mountains.shader = MOUNTAIN_SHADER
	_mountains.set_shader_parameter("noise", _noise)
	var valley := 0.5
	for exit_road in CityMap.exit_roads():
		var r: Rect2 = exit_road["rect"]
		if not bool(exit_road["horizontal"]) and r.position.y < CityMap.WORLD_BOUNDS.position.y:
			valley = (r.get_center().x - left) / width
	_mountains.set_shader_parameter("valley", valley)
	var quad := QuadMesh.new()
	quad.size = Vector2(width, MOUNTAIN_HEIGHT)
	var wall := MeshInstance3D.new()
	wall.name = "Montagne"
	wall.mesh = quad
	wall.material_override = _mountains
	wall.position = Vector3(view.get_center().x, MOUNTAIN_HEIGHT * 0.5, view.position.y)
	world.add_child(wall)

# --- Gli edifici --------------------------------------------------------------

## Ogni edificio a nord della finestra, in piedi sulla sua riga di terra.
##
## L'origine di una voce è il punto a terra al centro della facciata, e
## `offset` è dove comincia il disegno rispetto a lei (in su, quindi negativo):
## lo stesso conto di `city.gd::_make_building()`, con la y che diventa quota.
func _build_buildings(world: Node3D, own: Dictionary) -> void:
	var eye := _eye(own)
	var reach := tan(deg_to_rad(FOV_DEGREES * 0.5)) * 1.15
	for entry in CityMap.all_buildings():
		if str(entry["id"]) == _building_id or not entry.has("texture"):
			continue
		var base: Vector2 = entry["base"]
		var ahead := eye.z - base.y
		if ahead < 1.0:
			continue
		var texture := _texture(str(entry["texture"]))
		if texture == null:
			continue
		var frames := int(entry.get("frames", 1))
		var size := Vector2(texture.get_width() / float(frames), texture.get_height())
		var offset: Vector2 = entry.get("offset", Vector2(-size.x * 0.5, -size.y))
		var center_x := base.x + offset.x + size.x * 0.5
		if absf(center_x - eye.x) - size.x * 0.5 > ahead * reach:
			continue
		var height := -(offset.y + size.y * 0.5)
		var sprite := _sprite(texture, frames)
		sprite.position = Vector3(center_x, height, base.y)
		world.add_child(sprite)
		_sprites.append(sprite)
		if entry.has("lit"):
			var lit_texture := _texture(str(entry["lit"]))
			if lit_texture != null:
				var lit := _sprite(lit_texture, frames)
				lit.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
				# Un'unità davanti al muro: sta sopra al disegno senza
				# litigarci la profondità.
				lit.position = sprite.position + Vector3(0.0, 0.0, 1.0)
				world.add_child(lit)
				_lit.append(lit)

func _sprite(texture: Texture2D, frames: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.hframes = frames
	sprite.pixel_size = 1.0
	sprite.shaded = false
	sprite.double_sided = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite

## I PNG del gioco sono importati senza mipmap, che per la pixel art in strada
## e' giusto. Da quassu' pero' un palazzo di trecento pixel ne occupa dieci, e
## senza mipmap sarebbe una manciata di pixel a caso del disegno: le mipmap si
## fanno qui, una volta per texture.
func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var source := load(path) as Texture2D
	var result: Texture2D = null
	if source != null:
		var image := source.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			image.generate_mipmaps()
			result = ImageTexture.create_from_image(image)
	_textures[path] = result
	return result

# --- I lampioni ---------------------------------------------------------------

func _build_lamps(world: Node3D) -> void:
	var points: Array = []
	for entry in CityMap.street_lamps() + CityMap.lot_lamps():
		var pos: Vector2 = entry["pos"]
		if pos.y < _camera.position.z:
			points.append(pos)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * LAMP_GLOW
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = points.size()
	for i in points.size():
		var pos: Vector2 = points[i]
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(pos.x, LAMP_HEAD, pos.y)))
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.7, 1.0))
	gradient.set_color(1, Color(1.0, 0.7, 0.35, 0.0))
	glow.gradient = gradient
	_lamp_material = _unshaded(glow)
	_lamp_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lamp_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lamp_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_lamp_material.no_depth_test = false
	_lamps = MultiMeshInstance3D.new()
	_lamps.name = "Lampioni"
	_lamps.multimesh = multimesh
	_lamps.material_override = _lamp_material
	world.add_child(_lamps)

# --- Il traffico --------------------------------------------------------------

## Le auto sulle corsie vere, ferme sull'asfalto e sdraiate: gli sprite dei
## mezzi sono resi dall'alto col muso a est (`render_cars.py`), quindi basta
## girarli sul verso della corsia. Non frenano per nessuno e non si guardano
## fra loro: da quassu' non si vede, e sono duecento.
func _build_cars(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2107
	for lane in CityMap.lanes():
		var from := float(lane["from"])
		var to := float(lane["to"])
		var count := int(lane["cars"])
		for i in count:
			var texture := _texture(Car.VEHICLES[rng.randi() % Car.VEHICLES.size()])
			if texture == null:
				continue
			var car := Sprite3D.new()
			car.texture = texture
			car.pixel_size = 1.0
			car.shaded = false
			car.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			car.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var yaw := 0.0
			var dir := int(lane["dir"])
			if str(lane["axis"]) == "h":
				yaw = 0.0 if dir > 0 else 180.0
			else:
				yaw = -90.0 if dir > 0 else 90.0
			car.rotation_degrees = Vector3(-90.0, yaw, 0.0)
			world.add_child(car)
			_sprites.append(car)
			var along := lerpf(from, to, (float(i) + rng.randf() * 0.6) / float(count))
			_cars.append([car, lane, along])
	_move_cars(0.0)

func _move_cars(delta: float) -> void:
	for item in _cars:
		var car: Sprite3D = item[0]
		var lane: Dictionary = item[1]
		var from := float(lane["from"])
		var to := float(lane["to"])
		var along: float = item[2] + float(lane["speed"]) * float(lane["dir"]) * delta
		if along > to:
			along = from + (along - to)
		elif along < from:
			along = to - (from - along)
		item[2] = along
		var pos := float(lane["pos"])
		if str(lane["axis"]) == "h":
			car.position = Vector3(along, 1.0, pos)
		else:
			car.position = Vector3(pos, 1.0, along)

# --- La luce ------------------------------------------------------------------

func _update_light() -> void:
	var data := GameState.current
	var hour := Daylight.hour_of(data)
	var weather_id := Weather.of(data)
	var weather := Weather.entry(weather_id)
	var tint := Weather.tint(weather_id)
	var light := Daylight.light(data)

	var top := _sky_color(hour, "top")
	var horizon := _sky_color(hour, "horizon")
	# Col coperto il cielo sbianca verso il grigio, oltre a scurirsi.
	var grey := clampf(float(weather["clouds"]) * 0.6 + float(weather["fog"]), 0.0, 0.8)
	var dull := Color(0.62, 0.64, 0.68) * Daylight.brightness(data)
	top = (top * tint).lerp(dull, grey)
	horizon = (horizon * tint).lerp(dull, grey * 0.8)
	_sky.set_shader_parameter("top", top)
	_sky.set_shader_parameter("horizon", horizon)
	_sky.set_shader_parameter("cloud_lit", Color(1, 1, 1).lerp(horizon, 0.25) * light)
	_sky.set_shader_parameter("cloud_shade", horizon.lerp(Color(0.55, 0.58, 0.66), 0.5) * light)
	_sky.set_shader_parameter("cover", clampf(float(weather["clouds"]) * 0.75 + 0.08, 0.0, 0.9))
	_sky.set_shader_parameter("stars", clampf(1.0 - Daylight.brightness(data) * 1.8, 0.0, 1.0)
		* (1.0 - float(weather["clouds"])))

	_env.fog_light_color = horizon
	_env.fog_depth_begin = lerpf(3500.0, 300.0, float(weather["fog"]))
	_env.fog_depth_end = lerpf(14000.0, 4500.0, float(weather["fog"]))
	_env.fog_density = lerpf(0.6, 0.95, float(weather["fog"]))

	_ground.albedo_color = light
	_fields.albedo_color = FIELDS * light
	_mountains.set_shader_parameter("tint", light)
	for sprite in _sprites:
		sprite.modulate = light
	var lamps := Daylight.lamp_strength(data)
	for lit in _lit:
		lit.visible = lamps > 0.01
		lit.modulate = Color(1, 1, 1, lamps)
	_lamps.visible = lamps > 0.01
	_lamp_material.albedo_color = Color(1, 1, 1, lamps)

static func _sky_color(hour: float, field: String) -> Color:
	var wrapped := fposmod(hour, 24.0)
	for i in range(SKY_KEYS.size() - 1):
		var from: Dictionary = SKY_KEYS[i]
		var to: Dictionary = SKY_KEYS[i + 1]
		if wrapped >= float(from["hour"]) and wrapped <= float(to["hour"]):
			var span := float(to["hour"]) - float(from["hour"])
			var t := 0.0 if span <= 0.0 else (wrapped - float(from["hour"])) / span
			return (from[field] as Color).lerp(to[field] as Color, smoothstep(0.0, 1.0, t))
	return SKY_KEYS[0][field]

# --- Il vetro -----------------------------------------------------------------

## Due riflessi in diagonale sul vetro, come nel disegno di riferimento. Stanno
## sotto al fondale, quindi si vedono solo dentro ai vetri: i montanti li
## tagliano da soli.
func _draw_glass(canvas: Node2D) -> void:
	var data := GameState.current
	var strength := 0.05 + 0.07 * Daylight.brightness(data)
	var sheen := Color(0.85, 0.92, 1.0, strength)
	var h := _rect.size.y
	for band in [[0.18, 26.0], [0.26, 10.0], [0.62, 40.0], [0.72, 14.0]]:
		var x: float = _rect.position.x + _rect.size.x * float(band[0])
		var w: float = band[1]
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x, _rect.position.y), Vector2(x + w, _rect.position.y),
			Vector2(x + w - h * 0.7, _rect.end.y), Vector2(x - h * 0.7, _rect.end.y),
		]), sheen)

## Una unshaded senza ombre: tutto quello che c'è là fuori ha la luce già
## decisa da `_update_light()`.
static func _unshaded(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if texture != null:
		material.albedo_texture = texture
	return material
