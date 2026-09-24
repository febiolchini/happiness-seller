extends Node2D
class_name AirportGround

## Il pavimento dell'aeroporto: piazzale, raccordi, piste con la segnaletica,
## eliporto, la recinzione tutto intorno e di notte le luci di bordo pista.
##
## E' pavimento come le strade, quindi lo disegna il gioco e non Blender (vedi
## la nota su strutture e superfici in `blender_aeroporto.py`). Sta sopra
## all'erba dell'aeroporto e sotto a tutto il resto: stesso `z_index` del
## terreno, e subito dopo i prati nell'albero (lo mette li' `city.gd`).
##
## Si ridisegna solo quando cambia la luce, come i lampioni: e' tutto fermo,
## tranne le luci della pista che la sera si accendono.

const ASPHALT := Color(0.235, 0.235, 0.255)
const TAXI := Color(0.30, 0.30, 0.32)
const CONCRETE := Color(0.60, 0.60, 0.575)
const JOINT := Color(0.52, 0.52, 0.50)
const WHITE := Color(0.90, 0.90, 0.88)
const YELLOW := Color(0.86, 0.72, 0.22)
const FENCE := Color(0.46, 0.47, 0.48)
const EDGE_LIGHT := Color(1.0, 0.92, 0.66)
const END_LIGHT := Color(0.45, 1.0, 0.55)

func _ready() -> void:
	add_to_group(Daylight.LIGHT_GROUP)

func on_light_changed() -> void:
	queue_redraw()

func _draw() -> void:
	_draw_apron()
	for path in AirportPlan.TAXIWAYS:
		_draw_taxiway(path)
	_draw_runway(AirportPlan.RUNWAY_MAIN, "09", "27")
	_draw_runway(AirportPlan.RUNWAY_CROSS, "24", "06")
	_draw_helipad(AirportPlan.HELIPAD)
	_draw_fence(CityMap.AIRPORT)
	var strength := Daylight.lamp_strength(GameState.current)
	if strength > 0.01:
		var ambient := Daylight.light(GameState.current)
		_draw_lights(AirportPlan.RUNWAY_MAIN, ambient, strength)
		_draw_lights(AirportPlan.RUNWAY_CROSS, ambient, strength)

func _draw_apron() -> void:
	var r := AirportPlan.APRON
	draw_rect(r, CONCRETE)
	# I giunti delle lastre: e' quello che fa leggere il piazzale come cemento
	# e non come un rettangolo grigio.
	var x := r.position.x + 48.0
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), JOINT, 1.0)
		x += 48.0
	var y := r.position.y + 46.0
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), JOINT, 1.0)
		y += 46.0
	# La linea gialla dei posti davanti agli hangar.
	draw_line(Vector2(r.position.x + 20, r.end.y - 18), Vector2(r.end.x - 20, r.end.y - 18), YELLOW, 2.0)

func _draw_taxiway(path: Array) -> void:
	var pts := PackedVector2Array(path)
	draw_polyline(pts, TAXI, AirportPlan.TAXI_WIDTH)
	for p in pts:
		draw_circle(p, AirportPlan.TAXI_WIDTH * 0.5, TAXI)
	draw_polyline(pts, YELLOW, 2.0)

## Una pista: asfalto, bordi bianchi, mezzeria tratteggiata, le soglie a
## tasti di pianoforte ai due capi e il numero (la direzione in decine di
## gradi, come quelle vere) appena dopo la soglia.
func _draw_runway(runway: Array, name_a: String, name_b: String) -> void:
	var a: Vector2 = runway[0]
	var b: Vector2 = runway[1]
	var width: float = runway[2]
	var along := (b - a).normalized()
	var side := Vector2(-along.y, along.x) * width * 0.5
	draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), ASPHALT)
	var edge := side * 0.88
	draw_line(a + edge, b + edge, WHITE, 2.0)
	draw_line(a - edge, b - edge, WHITE, 2.0)
	var length := a.distance_to(b)
	# La mezzeria, fra le due scritte.
	var s := 110.0
	while s < length - 110.0:
		draw_line(a + along * s, a + along * minf(s + 26.0, length - 110.0), WHITE, 3.0)
		s += 46.0
	for end in [[a, along, name_a], [b, -along, name_b]]:
		var at: Vector2 = end[0]
		var dir: Vector2 = end[1]
		var across := Vector2(-dir.y, dir.x)
		for k in range(-3, 4):
			var off := across * (float(k) * width * 0.12)
			draw_line(at + dir * 10.0 + off, at + dir * 40.0 + off, WHITE, 4.0)
		_draw_number(at + dir * 72.0, dir, str(end[2]))

## Il numero della pista, scritto di traverso in modo che lo si legga
## arrivando da quel capo.
func _draw_number(center: Vector2, dir: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var size := 20
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_set_transform(center, dir.angle() + PI * 0.5, Vector2.ONE)
	draw_string(font, Vector2(-width * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_helipad(center: Vector2) -> void:
	draw_circle(center, 46.0, CONCRETE)
	draw_arc(center, 40.0, 0.0, TAU, 32, YELLOW, 2.0)
	draw_line(center + Vector2(-12, -16), center + Vector2(-12, 16), WHITE, 4.0)
	draw_line(center + Vector2(12, -16), center + Vector2(12, 16), WHITE, 4.0)
	draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), WHITE, 4.0)

## La recinzione: una rete bassa coi paletti. E' anche il motivo, a vederla,
## per cui dentro non si entra a piedi (vedi `CityNavigation`).
func _draw_fence(r: Rect2) -> void:
	var inner := r.grow(-4.0)
	var corners := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y),
		inner.end, Vector2(inner.position.x, inner.end.y), inner.position])
	draw_polyline(corners, FENCE, 2.0)
	for i in range(corners.size() - 1):
		var from := corners[i]
		var to := corners[i + 1]
		var steps := int(from.distance_to(to) / 32.0)
		for k in steps + 1:
			var p := from.lerp(to, float(k) / float(maxi(steps, 1)))
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), FENCE.darkened(0.3))

## Le luci di bordo pista, la sera: puntini caldi ogni tanto lungo i due
## bordi, verdi alle testate. Accese con `Daylight.emissive()`, come i
## lampioni, cosi' restano accese dentro alla tinta della notte.
func _draw_lights(runway: Array, ambient: Color, strength: float) -> void:
	var a: Vector2 = runway[0]
	var b: Vector2 = runway[1]
	var width: float = runway[2]
	var along := (b - a).normalized()
	var side := Vector2(-along.y, along.x) * (width * 0.5 + 3.0)
	var length := a.distance_to(b)
	var lit := EDGE_LIGHT
	lit.a = strength
	var green := END_LIGHT
	green.a = strength
	var s := 0.0
	while s <= length:
		var p := a + along * s
		for q in [p + side, p - side]:
			draw_circle(q, 2.0, Daylight.emissive(lit, ambient))
		s += 64.0
	for end in [a, b]:
		for k in range(-3, 4):
			draw_circle(end + Vector2(-along.y, along.x) * (float(k) * width * 0.14), 2.0,
				Daylight.emissive(green, ambient))
