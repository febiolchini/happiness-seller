@tool
extends Node2D

## Disegna il "pavimento" di tutta la cittadina: terreno dei quartieri, strade,
## marciapiedi, prato del parco, piazza, campo da football, alberi.
##
## È tutta roba piatta calpestabile e sta in un unico nodo. Ogni superficie qui
## è un segnaposto per i futuri `TileMapLayer` in pixel art, e la pianta la
## legge da `CityMap` — questo file sa solo *come* si disegna, non *dove* stanno
## le cose.
##
## ## Il nodo ha `z_index = -2`, e non è un dettaglio
##
## Qui c'era scritto che il nodo, avendo origine a y = 0, nell'Y-sort della City
## finisce sempre dietro a edifici e personaggi. È falso, ed è metà vero nel
## modo peggiore: l'Y-sort ordina per la y del NODO, e questo disegna tutta la
## città da un nodo solo piantato a y = 0. Quindi finisce dietro a tutto quello
## che sta a y positiva — cioè quasi tutto, per questo non se n'era accorto
## nessuno — e **davanti** a tutto quello che sta più a nord: i lampioni del
## bordo alto della mappa e quelli del parcheggio del grossista sparivano sotto
## al terreno, senza nessun errore, restando nell'albero e "visibili".
##
## Col `z_index` negativo l'ordine non dipende più da dove il nodo ha l'origine:
## lo z_index viene prima dell'Y-sort, e il pavimento sta sotto per definizione.
## `GroundWeather` ha -1 per lo stesso motivo — pozzanghere sopra all'asfalto,
## sotto a tutto il resto.
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
	# Il campo da football e' terra e non erba: l'erba ci arriva sopra dallo
	# shader (`grass_field.gdshader`), a chiazze e con dei buchi. Quello che si
	# disegna qui e' il fondo che si vede DA quei buchi, righe sbiadite comprese.
	# Le righe sono molto piu' marcate di quanto sembri giusto guardando solo
	# questo strato: l'erba ne copre quattro quinti, e quel che resta a vista e'
	# qualche spezzone dentro alle chiazze pelate. A 0.30 non si vedeva niente.
	"football": {"fill": Color(0.353, 0.318, 0.220), "line": Color(0.82, 0.81, 0.72, 0.70)},
	"lawn": {"fill": Color(0.33, 0.45, 0.27), "line": Color(0.80, 0.85, 0.75, 0.16)},
	"plaza": {"fill": Color(0.63, 0.62, 0.60), "line": Color(0.45, 0.44, 0.43, 0.55)},
	"dirt": {"fill": Color(0.40, 0.35, 0.24), "line": Color(0.55, 0.50, 0.38, 0.35)},
	"gravel": {"fill": Color(0.35, 0.34, 0.32), "line": Color(0.50, 0.48, 0.45, 0.35)},
	"concrete": {"fill": Color(0.46, 0.46, 0.45), "line": Color(0.35, 0.35, 0.35, 0.45)},
	# Piu' scuro del terreno di DOWNTOWN, che e' un grigio-azzurro quasi dello
	# stesso tono: col vecchio 0,28 il parcheggio del grossista si leggeva come
	# un rettangolo appena piu' chiaro del prato, e le righe dei posti come dei
	# graffi. L'asfalto di un piazzale e' la cosa piu' scura dell'isolato.
	"asphalt": {"fill": Color(0.205, 0.205, 0.215), "line": Color(0.86, 0.86, 0.72, 0.50)},
	"court": {"fill": Color(0.42, 0.30, 0.24), "line": Color(0.90, 0.92, 0.88, 0.45)},
	"pool": {"fill": Color(0.24, 0.48, 0.58), "line": Color(0.85, 0.92, 0.95, 0.45)},
}

const TREE_TRUNK := Color(0.30, 0.23, 0.17)
const TREE_LEAVES := Color(0.22, 0.34, 0.20)
const TREE_LEAVES_LIT := Color(0.28, 0.42, 0.24)

const LABEL_SIZE := 8
const DISTRICT_LABEL_SIZE := 16

## Il nome della strada, stampato **sul marciapiede**.
##
## Non su un cartello a un angolo: a 640x360 un cartello leggibile sarebbe
## grosso quanto mezzo isolato. E non sull'asfalto, che è la prima cosa che ho
## provato — lì la scritta cade sulla mezzeria tratteggiata, ci passano sopra le
## auto, e su un grigio scuro un giallo tenue non si legge comunque.
##
## Sul marciapiede invece il fondo è chiaro (`SIDEWALK`), quindi basta uno
## scuro poco carico per leggersi bene restando discreto: si vede quando lo si
## cerca e non dà fastidio quando non lo si cerca. Ed è anche il posto giusto —
## il nome serve **dove si cammina**, e gli appuntamenti con Brian si danno per
## strada ("MILL ROAD NORTH OF MAIN STREET").
##
## Sta su un lato solo (nord per le orizzontali, ovest per le verticali): su
## tutti e due sarebbe il doppio delle scritte per la stessa informazione.
const STREET_LABEL := Color(0.19, 0.20, 0.24, 0.55)
const STREET_LABEL_SIZE := 13
## Ogni quanto si ripete lungo la stessa strada. A 900 px se ne incontra uno
## ogni schermata e mezza alla vista di default: abbastanza da trovarlo
## camminando, non tanto da diventare una decorazione a righe.
const STREET_LABEL_STEP := 900.0

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
	_draw_street_names()
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
			"football":
				_draw_football_field(rect, fill, line)
			"field", "lawn":
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

## Larghezza di un posto auto e profondità di una fila, in pixel.
const BAY := Vector2(24.0, 40.0)
## La corsia di manovra fra due file accoppiate.
const BAY_AISLE := 46.0

## Le righe dei posti auto.
##
## Prima ne disegnava due, una attaccata al bordo alto e una al bordo basso, e
## per un piazzale piccolo bastava. Su un parcheggio profondo — quello del
## grossista lo è 337 px — restava in mezzo una lastra di asfalto vuota grande
## quanto il parcheggio stesso: righe ai bordi e niente dentro non si legge
## come un parcheggio, si legge come un piazzale con qualcosa disegnato sugli
## orli. Adesso le file si ripetono per tutta la profondità, accoppiate a due a
## due con la corsia di manovra in mezzo, che è come sono fatti davvero.
func _draw_parking_bays(rect: Rect2, line: Color) -> void:
	draw_rect(rect, line * Color(1, 1, 1, 0.5), false, 1.0)
	var y := rect.position.y + 6.0
	while y + BAY.y <= rect.end.y - 6.0:
		_draw_bay_row(rect, line, y)
		if y + BAY.y * 2.0 <= rect.end.y - 6.0:
			_draw_bay_row(rect, line, y + BAY.y)
			y += BAY.y * 2.0 + BAY_AISLE
		else:
			y += BAY.y + BAY_AISLE

## Una fila di posti: i divisori fra un posto e l'altro, e la riga di testa a
## cui si accostano.
func _draw_bay_row(rect: Rect2, line: Color, top: float) -> void:
	var x := rect.position.x + BAY.x
	while x < rect.end.x - 8.0:
		draw_line(Vector2(x, top), Vector2(x, top + BAY.y), line, 1.0)
		x += BAY.x
	draw_line(Vector2(rect.position.x + 8.0, top),
		Vector2(rect.end.x - 8.0, top), line * Color(1, 1, 1, 0.7), 1.0)

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

## Il fondo del campo abbandonato: terra, chiazze piu' scure, e quel che resta
## delle righe.
##
## Sopra ci va l'erba dello shader, che ne copre quattro quinti. Quindi qui non
## si disegna un campo "bello" da coprire: si disegna quello che deve spuntare
## dai buchi. Le righe sono piu' marcate di quanto sembri giusto guardando solo
## questo strato, perche' a vederle finite ne resta a vista un pezzo su cinque.
func _draw_football_field(rect: Rect2, fill: Color, line: Color) -> void:
	var scuro := fill.darkened(0.16)
	var seme := int(absf(rect.position.x) + absf(rect.position.y))
	for i in 11:
		var fx := float((seme + i * 37) % 1000) / 1000.0
		var fy := float((seme + i * 61) % 1000) / 1000.0
		var w := 30.0 + float((seme + i * 13) % 70)
		var h := 14.0 + float((seme + i * 7) % 34)
		draw_rect(Rect2(
			rect.position + Vector2(fx * (rect.size.x - w), fy * (rect.size.y - h)),
			Vector2(w, h)), scuro, true)

	var bordo := rect.grow(-10.0)
	draw_rect(bordo, line, false, 2.0)
	var mid := rect.get_center().y
	draw_line(Vector2(bordo.position.x, mid), Vector2(bordo.end.x, mid), line, 2.0)
	# Cerchio di centrocampo schiacciato: la vista e' obliqua, non dall'alto,
	# quindi un cerchio vero in pianta a schermo e' un'ellisse.
	var punti := PackedVector2Array()
	var centro := rect.get_center()
	var raggio := minf(rect.size.x * 0.13, rect.size.y * 0.30)
	for i in range(33):
		var a := TAU * float(i) / 32.0
		punti.append(centro + Vector2(cos(a) * raggio, sin(a) * raggio * 0.52))
	draw_polyline(punti, line, 2.0)
	# Le due aree, davanti alle porte.
	var area := Vector2(rect.size.x * 0.28, rect.size.y * 0.17)
	for y in [bordo.position.y, bordo.end.y - area.y]:
		draw_rect(Rect2(centro.x - area.x * 0.5, y, area.x, area.y), line, false, 2.0)


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

# --- Nomi delle strade -----------------------------------------------------

## Il nome di ogni strada, ripetuto lungo la carreggiata e orientato con essa.
##
## Sulle verticali il testo è ruotato di novanta gradi e si legge dall'alto
## verso il basso: è l'unico verso che non costringe a piegare la testa
## dall'altra parte rispetto a come si guarda la mappa.
##
## Niente nomi dentro agli incroci: lì sotto ci sono già le strisce pedonali, e
## una scritta che ci passa sopra si legge come un errore di disegno. È la
## stessa regola della mezzeria tratteggiata, che pure si interrompe.
func _draw_street_names() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	# Mezza fascia sopra all'asfalto: il marciapiede è profondo 32 px, quindi la
	# scritta gli finisce in mezzo.
	var band := CityMap.SIDEWALK_DEPTH * 0.5

	for i in CityMap.ROADS_H.size():
		var road: Rect2 = CityMap.ROADS_H[i]
		var name := str(CityMap.ROAD_NAMES_H[i])
		var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, STREET_LABEL_SIZE).x
		var y := road.position.y - band
		var x := road.position.x + STREET_LABEL_STEP * 0.5
		while x < road.end.x:
			# Agli incroci il marciapiede non c'è: lì passa l'altra strada, e una
			# scritta sull'asfalto si legge come un errore di disegno. Si
			# controllano tutti e due i capi, non solo il centro, o una scritta
			# lunga ci entra per metà.
			if not _crosses_road(CityMap.ROADS_V, x - width * 0.5, x + width * 0.5, y):
				draw_string(
					font, Vector2(x - width * 0.5, y + STREET_LABEL_SIZE * 0.36), name,
					HORIZONTAL_ALIGNMENT_LEFT, -1, STREET_LABEL_SIZE, STREET_LABEL)
			x += STREET_LABEL_STEP

	for i in CityMap.ROADS_V.size():
		var road: Rect2 = CityMap.ROADS_V[i]
		var name := str(CityMap.ROAD_NAMES_V[i])
		var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, STREET_LABEL_SIZE).x
		var x := road.position.x - band
		var y := road.position.y + STREET_LABEL_STEP * 0.5
		while y < road.end.y:
			if not _crosses_road_v(CityMap.ROADS_H, y - width * 0.5, y + width * 0.5, x):
				# Ruotare la tela e disegnare nell'origine: `draw_string` non sa
				# girare il testo da solo, e comporre la rotazione lettera per
				# lettera costerebbe un giro in più per niente. Novanta gradi in
				# senso orario, così si legge dall'alto verso il basso: è l'unico
				# verso che non costringe a piegare la testa dalla parte opposta
				# a come si guarda la mappa.
				draw_set_transform(Vector2(x, y), PI * 0.5, Vector2.ONE)
				draw_string(
					font, Vector2(-width * 0.5, STREET_LABEL_SIZE * 0.36), name,
					HORIZONTAL_ALIGNMENT_LEFT, -1, STREET_LABEL_SIZE, STREET_LABEL)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			y += STREET_LABEL_STEP

## Se il tratto orizzontale da `from` a `to` alla quota `y` incrocia una di
## queste strade (asfalto più marciapiedi).
func _crosses_road(roads: Array, from: float, to: float, y: float) -> bool:
	for road: Rect2 in roads:
		var band := road.grow(CityMap.SIDEWALK_DEPTH)
		if to >= band.position.x and from <= band.end.x and y >= band.position.y and y <= band.end.y:
			return true
	return false

## Lo stesso per un tratto verticale: `from`-`to` sono quote, `x` l'ascissa.
func _crosses_road_v(roads: Array, from: float, to: float, x: float) -> bool:
	for road: Rect2 in roads:
		var band := road.grow(CityMap.SIDEWALK_DEPTH)
		if to >= band.position.y and from <= band.end.y and x >= band.position.x and x <= band.end.x:
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
		# `get` e non `[]`: il nome è facoltativo. Un campo da football sulla
		# mappa ha senso che lo porti, il parcheggio dietro a un negozio no, e
		# leggendo la chiave per forza il primo lotto senza nome faceva alzare
		# un errore a ogni ridisegno del terreno.
		var text := str(lot.get("label", ""))
		if text.is_empty():
			continue
		var rect: Rect2 = lot["rect"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		draw_string(
			font, Vector2(rect.get_center().x - width * 0.5, rect.position.y + 14.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LOT_LABEL)
