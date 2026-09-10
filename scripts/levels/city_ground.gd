@tool
extends Node2D

## Disegna il "pavimento" di tutta la cittadina: terreno dei quartieri, strade,
## marciapiedi, prato del parco, piazza, campo da football, alberi.
##
## È tutta roba piatta calpestabile, quindi sta in un unico nodo con origine a
## y = 0: nell'Y-sort della City finisce sempre dietro a edifici e personaggi.
## Ogni superficie qui è un segnaposto per i futuri `TileMapLayer` in pixel art,
## e la pianta la legge da `CityMap` — questo file sa solo *come* si disegna,
## non *dove* stanno le cose.
##
## L'ordine di disegno è la parte che conta: prima tutti i marciapiedi, poi
## tutto l'asfalto. Così agli incroci i marciapiedi restano sotto e le due
## strade si fondono in una piazzola, senza dover calcolare le intersezioni.

const SIDEWALK := Color(0.72, 0.73, 0.75)
const SIDEWALK_EDGE := Color(0.60, 0.61, 0.64)
const CURB := Color(0.83, 0.84, 0.86)
const ASPHALT := Color(0.26, 0.26, 0.29)
const ASPHALT_PATCH := Color(0.30, 0.30, 0.33)
const ROAD_LINE := Color(0.85, 0.82, 0.55, 0.75)
const CROSSWALK := Color(0.88, 0.89, 0.90, 0.55)
const DISTRICT_LABEL := Color(0.93, 0.95, 0.92, 0.30)
const LOT_LABEL := Color(0.88, 0.90, 0.86, 0.45)

## Stile di ogni tipo di superficie particolare (i `kind` di `CityMap.LOTS`).
## `line` è il colore della segnaletica/recinzione disegnata sopra.
const LOT_STYLES := {
	"field": {"fill": Color(0.29, 0.38, 0.22), "line": Color(0.80, 0.82, 0.78, 0.35)},
	"lawn": {"fill": Color(0.33, 0.45, 0.27), "line": Color(0.80, 0.85, 0.75, 0.16)},
	"plaza": {"fill": Color(0.63, 0.62, 0.60), "line": Color(0.45, 0.44, 0.43, 0.55)},
	"dirt": {"fill": Color(0.40, 0.35, 0.24), "line": Color(0.55, 0.50, 0.38, 0.35)},
	"gravel": {"fill": Color(0.35, 0.34, 0.32), "line": Color(0.50, 0.48, 0.45, 0.35)},
	"concrete": {"fill": Color(0.46, 0.46, 0.45), "line": Color(0.35, 0.35, 0.35, 0.45)},
	"asphalt": {"fill": Color(0.28, 0.28, 0.30), "line": Color(0.85, 0.85, 0.70, 0.35)},
	"court": {"fill": Color(0.42, 0.30, 0.24), "line": Color(0.90, 0.92, 0.88, 0.45)},
	"pool": {"fill": Color(0.24, 0.48, 0.58), "line": Color(0.85, 0.92, 0.95, 0.45)},
}

const TREE_TRUNK := Color(0.30, 0.23, 0.17)
const TREE_LEAVES := Color(0.22, 0.34, 0.20)
const TREE_LEAVES_LIT := Color(0.28, 0.42, 0.24)

const LABEL_SIZE := 8
const DISTRICT_LABEL_SIZE := 16

func _draw() -> void:
	_draw_districts()
	_draw_lots()
	# Marciapiedi di TUTTE le strade prima di qualsiasi asfalto: è quello che
	# fa venire bene gli incroci senza calcolarli.
	for road in CityMap.ROADS_H + CityMap.ROADS_V:
		_draw_sidewalk_band(road)
	for road in CityMap.ROADS_H + CityMap.ROADS_V:
		draw_rect(road, ASPHALT, true)
	for road in CityMap.ROADS_H:
		_draw_road_markings(road, true)
	for road in CityMap.ROADS_V:
		_draw_road_markings(road, false)
	_draw_crosswalks()
	_draw_trees()
	_draw_labels()

# --- Quartieri -------------------------------------------------------------

func _draw_districts() -> void:
	for district in CityMap.DISTRICTS:
		draw_rect(district["rect"], district["color"], true)

# --- Superfici particolari -------------------------------------------------

func _draw_lots() -> void:
	for lot in CityMap.LOTS:
		var rect: Rect2 = lot["rect"]
		var style: Dictionary = LOT_STYLES.get(str(lot["kind"]), LOT_STYLES["dirt"])
		var fill: Color = style["fill"]
		var line: Color = style["line"]
		draw_rect(rect, fill, true)
		match str(lot["kind"]):
			"field":
				_draw_football_field(rect, fill, line)
			"lawn":
				_draw_lawn(rect, fill)
			"plaza":
				_draw_paving(rect, line)
			"court":
				draw_rect(rect.grow(-6.0), line, false, 1.0)
				draw_line(
					Vector2(rect.position.x + 6.0, rect.get_center().y),
					Vector2(rect.end.x - 6.0, rect.get_center().y), line, 1.0)
			"pool":
				draw_rect(rect.grow(-4.0), line, false, 2.0)
			"asphalt":
				_draw_parking_bays(rect, line)
			"gravel", "concrete", "dirt":
				draw_rect(rect, line, false, 1.0)
				_draw_scatter(rect, line)

## Erba con qualche chiazza più chiara: senza, un prato grande resta una
## macchia piatta e si legge come un buco nella mappa.
func _draw_lawn(rect: Rect2, fill: Color) -> void:
	var lighter := fill.lightened(0.10)
	var step := 96.0
	var y := rect.position.y + 24.0
	var row := 0
	while y < rect.end.y - 16.0:
		var x := rect.position.x + 24.0 + (48.0 if row % 2 == 1 else 0.0)
		while x < rect.end.x - 32.0:
			draw_rect(Rect2(x, y, 40.0, 14.0), lighter, true)
			x += step
		y += 56.0
		row += 1

func _draw_paving(rect: Rect2, line: Color) -> void:
	var x := ceilf(rect.position.x / 32.0) * 32.0
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line, 1.0)
		x += 32.0
	var y := ceilf(rect.position.y / 32.0) * 32.0
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line, 1.0)
		y += 32.0

func _draw_parking_bays(rect: Rect2, line: Color) -> void:
	draw_rect(rect, line * Color(1, 1, 1, 0.5), false, 1.0)
	var x := rect.position.x + 24.0
	while x < rect.end.x - 8.0:
		draw_line(Vector2(x, rect.position.y + 6.0), Vector2(x, rect.position.y + 46.0), line, 1.0)
		draw_line(Vector2(x, rect.end.y - 46.0), Vector2(x, rect.end.y - 6.0), line, 1.0)
		x += 24.0

## Rottami, cassoni, macchie d'olio: dà l'idea di un piazzale usato.
func _draw_scatter(rect: Rect2, line: Color) -> void:
	var blot := line * Color(1, 1, 1, 0.6)
	var seed := int(absf(rect.position.x) + absf(rect.position.y))
	for i in 7:
		var fx := float((seed + i * 37) % 100) / 100.0
		var fy := float((seed + i * 61) % 100) / 100.0
		var w := 14.0 + float((seed + i * 13) % 26)
		var h := 8.0 + float((seed + i * 7) % 18)
		var pos := rect.position + Vector2(fx * (rect.size.x - w), fy * (rect.size.y - h))
		draw_rect(Rect2(pos, Vector2(w, h)), blot, true)

func _draw_football_field(rect: Rect2, fill: Color, line: Color) -> void:
	var dirt := Color(0.40, 0.35, 0.24)
	# Zone spelacchiate: il campo è abbandonato.
	draw_rect(Rect2(rect.position.x + 24.0, rect.position.y + 40.0, 64.0, 34.0), dirt, true)
	draw_rect(Rect2(rect.position.x + 168.0, rect.position.y + 118.0, 82.0, 40.0), dirt, true)
	draw_rect(rect.grow(-8.0), line, false, 1.0)
	var mid := rect.get_center().y
	draw_line(Vector2(rect.position.x + 8.0, mid), Vector2(rect.end.x - 8.0, mid), line, 1.0)
	# Cerchio di centrocampo schiacciato: la vista è obliqua, non dall'alto.
	var points := PackedVector2Array()
	var center := rect.get_center()
	for i in range(33):
		var a := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(a) * 42.0, sin(a) * 22.0))
	draw_polyline(points, line, 1.0)
	# Le due porte sfondate.
	var bright := line * Color(1, 1, 1, 1.6)
	for y in [rect.position.y + 10.0, rect.end.y - 10.0]:
		draw_line(Vector2(center.x - 34.0, y), Vector2(center.x + 34.0, y), bright, 2.0)
		draw_line(Vector2(center.x - 34.0, y), Vector2(center.x - 34.0, y - 12.0), bright, 1.0)
		draw_line(Vector2(center.x + 34.0, y), Vector2(center.x + 34.0, y - 12.0), bright, 1.0)

# --- Strade ----------------------------------------------------------------

func _draw_sidewalk_band(road: Rect2) -> void:
	var band := road.grow(CityMap.SIDEWALK_DEPTH)
	draw_rect(band, SIDEWALK, true)
	# Fughe fra le lastre, una per tile.
	var x := ceilf(band.position.x / 32.0) * 32.0
	while x < band.end.x:
		draw_line(Vector2(x, band.position.y), Vector2(x, band.end.y), SIDEWALK_EDGE, 1.0)
		x += 32.0

func _draw_road_markings(road: Rect2, horizontal: bool) -> void:
	# Cordoli chiari sui due lati.
	if horizontal:
		draw_line(road.position, Vector2(road.end.x, road.position.y), CURB, 2.0)
		draw_line(Vector2(road.position.x, road.end.y), road.end, CURB, 2.0)
	else:
		draw_line(road.position, Vector2(road.position.x, road.end.y), CURB, 2.0)
		draw_line(Vector2(road.end.x, road.position.y), road.end, CURB, 2.0)

	# Rappezzi d'asfalto: le strade di questa città sono malmesse.
	draw_rect(Rect2(road.position.x + 96.0, road.position.y + 18.0, 72.0, 26.0), ASPHALT_PATCH, true)
	draw_rect(Rect2(road.position.x + 512.0, road.position.y + 52.0, 96.0, 22.0), ASPHALT_PATCH, true)

	# Mezzeria tratteggiata, interrotta dentro agli incroci: una linea continua
	# che attraversa un incrocio si legge subito come un errore di disegno.
	var crossing := CityMap.ROADS_V if horizontal else CityMap.ROADS_H
	if horizontal:
		var y := road.get_center().y
		var x := road.position.x
		while x < road.end.x:
			var to := minf(x + 20.0, road.end.x)
			if not _inside_any(crossing, Vector2((x + to) * 0.5, y)):
				draw_line(Vector2(x, y), Vector2(to, y), ROAD_LINE, 2.0)
			x += 36.0
	else:
		var x := road.get_center().x
		var y := road.position.y
		while y < road.end.y:
			var to := minf(y + 20.0, road.end.y)
			if not _inside_any(crossing, Vector2(x, (y + to) * 0.5)):
				draw_line(Vector2(x, y), Vector2(x, to), ROAD_LINE, 2.0)
			y += 36.0

## Strisce pedonali sui quattro lati di ogni incrocio: sono il segnale visivo
## di dove si può attraversare, e i percorsi degli NPC passano da lì.
func _draw_crosswalks() -> void:
	for road_h: Rect2 in CityMap.ROADS_H:
		for road_v: Rect2 in CityMap.ROADS_V:
			var cross: Rect2 = road_h.intersection(road_v)
			if cross.size.x <= 0.0 or cross.size.y <= 0.0:
				continue
			_draw_stripes(Rect2(cross.position.x, road_h.position.y - 14.0, cross.size.x, 12.0), true)
			_draw_stripes(Rect2(cross.position.x, road_h.end.y + 2.0, cross.size.x, 12.0), true)
			_draw_stripes(Rect2(road_v.position.x - 14.0, cross.position.y, 12.0, cross.size.y), false)
			_draw_stripes(Rect2(road_v.end.x + 2.0, cross.position.y, 12.0, cross.size.y), false)

func _draw_stripes(rect: Rect2, horizontal: bool) -> void:
	if horizontal:
		var x := rect.position.x + 4.0
		while x < rect.end.x - 6.0:
			draw_rect(Rect2(x, rect.position.y, 8.0, rect.size.y), CROSSWALK, true)
			x += 16.0
	else:
		var y := rect.position.y + 4.0
		while y < rect.end.y - 6.0:
			draw_rect(Rect2(rect.position.x, y, rect.size.x, 8.0), CROSSWALK, true)
			y += 16.0

func _inside_any(rects: Array, point: Vector2) -> bool:
	for rect in rects:
		if (rect as Rect2).has_point(point):
			return true
	return false

# --- Alberi ----------------------------------------------------------------

## Alberi segnaposto, disegnati sul piano del terreno come il campo da football:
## il giocatore ci passa sopra. Diventeranno sprite Y-sortati insieme al resto
## della pixel art.
func _draw_trees() -> void:
	for point in CityMap.trees():
		draw_colored_polygon(_ellipse(point + Vector2(2, 4), Vector2(15, 6)), Color(0, 0, 0, 0.20))
		draw_rect(Rect2(point.x - 2.0, point.y - 14.0, 4.0, 14.0), TREE_TRUNK, true)
		draw_colored_polygon(_ellipse(point + Vector2(0, -22), Vector2(16, 13)), TREE_LEAVES)
		draw_colored_polygon(_ellipse(point + Vector2(-4, -27), Vector2(9, 7)), TREE_LEAVES_LIT)

func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points

# --- Etichette -------------------------------------------------------------

## Nomi dei quartieri e dei terreni. Sparirà tutto con la pixel art: servono
## adesso, per capire a occhio dove si è mentre si prova il gioco.
func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	for district in CityMap.DISTRICTS:
		draw_string(
			font, district["label_at"], str(district["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, DISTRICT_LABEL_SIZE, DISTRICT_LABEL)
	for lot in CityMap.LOTS:
		var text := str(lot["label"])
		if text.is_empty():
			continue
		var rect: Rect2 = lot["rect"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		draw_string(
			font, Vector2(rect.get_center().x - width * 0.5, rect.position.y + 14.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LOT_LABEL)
