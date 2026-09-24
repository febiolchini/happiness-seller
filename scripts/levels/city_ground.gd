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
## ## Le strade sono piastrelle, non rettangoli colorati
##
## L'asfalto non si disegna più a mano: sono le piastrelle del kit stradale di
## Kenney, renderizzate dall'alto da `scripts_tools/render_road_tiles.py` e
## stese qui. Mezzeria, strisce pedonali e cordolo stanno **dentro al disegno**,
## quindi da questo file sono spariti insieme al codice che li tracciava.
##
## Una piastrella è 120 px: 96 di asfalto — esattamente `CityMap.ROAD_WIDTH` —
## e 12 di cordolo rialzato per lato, che cadono sul bordo interno della fascia
## di marciapiede da 32. Il resto del marciapiede resta il grigio di prima, e
## chi ci cammina non se ne accorge: per la navigazione e per il traffico non è
## cambiato niente.
##
## L'ordine di disegno è la parte che conta:
##
## 1. tutti i **marciapiedi**, di tutte le strade;
## 2. tutto l'**asfalto**, a piastrelle ripetute lungo ogni strada;
## 3. le **strisce pedonali**, che stanno sull'asfalto;
## 4. gli **incroci**, che coprono le due strade che ci si accavallano.
##
## I marciapiedi per primi è la vecchia regola e vale ancora: così agli incroci
## restano sotto e le due strade si fondono senza calcolare le intersezioni. Gli
## incroci per ultimi è la regola nuova: la piastrella del quadrivio è un pezzo
## intero, e deve andare sopra alle due dritte che ci arrivano, non sotto.
##
## ## Il paesaggio del bordo
##
## Fuori dalla città ci sono colline e montagne, e quattro strade che ci
## passano in mezzo per andarsene. Qui si disegnano solo le strade; il
## paesaggio è uno shader su un nodo a parte. Vedi `_build_landscape()`.

const SIDEWALK := Color(0.72, 0.73, 0.75)
const SIDEWALK_EDGE := Color(0.60, 0.61, 0.64)
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
	# Piu' scuro del terreno del COMMERCIAL DISTRICT, che e' un grigio-azzurro quasi dello
	# stesso tono: col vecchio 0,28 il parcheggio del grossista si leggeva come
	# un rettangolo appena piu' chiaro del prato, e le righe dei posti come dei
	# graffi. L'asfalto di un piazzale e' la cosa piu' scura dell'isolato.
	"asphalt": {"fill": Color(0.205, 0.205, 0.215), "line": Color(0.86, 0.86, 0.72, 0.50)},
	"court": {"fill": Color(0.42, 0.30, 0.24), "line": Color(0.90, 0.92, 0.88, 0.45)},
	"pool": {"fill": Color(0.24, 0.48, 0.58), "line": Color(0.85, 0.92, 0.95, 0.45)},
}

# --- Le piastrelle stradali -------------------------------------------------
## Il kit di Kenney, reso dall'alto. Vedi `scripts_tools/render_road_tiles.py`
## per come nascono e `CityMap.junctions()` per come si sceglie quale mettere.
##
## Ognuna è orientata ovest-est e si gira di novanta gradi alla volta: sono
## quadrate e l'asfalto è centrato sul lato, quindi ruotandole combaciano sempre.
## Sono tre perché il reticolo è fatto di tre cose: dritti, quadrivi e
## attraversamenti.
const ROAD_TILE := 120.0
## Il rettilineo: imbocco a ovest e a est.
const TILE_STRAIGHT := preload("res://assets/sprites/roads/straight.png")
## Il quadrivio: imbocco da tutti e quattro i lati.
const TILE_CROSSROAD := preload("res://assets/sprites/roads/crossroad.png")
## Le strisce pedonali, in mezzo a un rettilineo ovest-est.
const TILE_CROSSING := preload("res://assets/sprites/roads/crossing.png")
## L'incrocio a T, chiuso a nord, e la curva da ovest a sud: servono agli
## incroci del bordo, dove la strada non prosegue da tutti e quattro i lati.
## Si girano come le altre. Vedi `CityMap.junction_sides()`.
const TILE_T := preload("res://assets/sprites/roads/tjunction.png")
const TILE_BEND := preload("res://assets/sprites/roads/bend.png")

## Dove stanno le strisce dentro alla piastrella: sono una fascia di 40 px nel
## mezzo di 120. Si ritaglia quella invece di stendere la piastrella intera,
## così l'attraversamento si può mettere **dove serve** — a ridosso
## dell'incrocio, dove attraversa la gente — e non dove capita di far cadere
## una piastrella intera, che lo spingerebbe mezzo isolato più in là.
const CROSSING_BAND := Rect2(40.0, 0.0, 40.0, ROAD_TILE)
## Quanto le strisce stanno fuori dal quadrato dell'incrocio.
const CROSSING_GAP := 16.0

# --- Il paesaggio del bordo -------------------------------------------------
const LANDSCAPE_SHADER := preload("res://assets/shaders/landscape.gdshader")
## Il seme del rumore: fisso, perché colline e montagne devono essere le stesse
## a ogni avvio. Una catena montuosa che si rimescola entrando e uscendo da una
## stanza è la cosa che si nota per prima.
const LANDSCAPE_SEED := 7
## Quanto è alta la cima più alta, in pixel di mondo. Alla vista d'insieme
## (scala netta 0,15) sono ottanta pixel di schermo: abbastanza per una catena
## che chiude l'orizzonte, non tanto da mangiarsi la cornice.
const LANDSCAPE_HEIGHT := 560.0

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

func _ready() -> void:
	# Le piastrelle si stendono con `draw_texture_rect(..., tile = true)`, e per
	# ripetersi la texture deve poter uscire dai suoi bordi. Senza questa riga
	# Godot ne disegna una sola e stira il resto: una strada lunga dieci
	# chilometri diventa una singola piastrella spalmata.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_build_landscape()

func _draw() -> void:
	_draw_districts()
	_draw_lots()
	# Marciapiedi di TUTTE le strade prima di qualsiasi asfalto: è quello che
	# fa venire bene gli incroci senza calcolarli.
	for road in CityMap.ROADS_H + CityMap.ROADS_V:
		_draw_sidewalk_band(road)
	for road in CityMap.ROADS_H:
		_draw_asphalt(road, true)
	for road in CityMap.ROADS_V:
		_draw_asphalt(road, false)
	_draw_junctions()
	_draw_exit_roads()
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

## L'asfalto di una strada: la stessa piastrella ripetuta da un capo all'altro.
##
## La fascia è alta `ROAD_TILE` e non `ROAD_WIDTH`, ed è centrata sull'asse
## della carreggiata: i 12 px di cordolo che avanzano per parte vanno a finire
## sul marciapiede, che è esattamente dove un cordolo sta.
##
## Sulle verticali si gira la tela di novanta gradi invece di tenere una seconda
## piastrella già ruotata: sono la stessa immagine, e due file sarebbero due
## cose da rifare ogni volta che se ne ritocca una.
func _draw_asphalt(road: Rect2, horizontal: bool) -> void:
	var half := ROAD_TILE * 0.5
	if horizontal:
		draw_texture_rect(TILE_STRAIGHT, Rect2(
			road.position.x, road.get_center().y - half,
			road.size.x, ROAD_TILE), true)
		return
	draw_set_transform(Vector2(road.get_center().x, 0.0), PI * 0.5, Vector2.ONE)
	draw_texture_rect(TILE_STRAIGHT, Rect2(
		road.position.y, -half, road.size.y, ROAD_TILE), true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Ogni crocevia: prima le strisce pedonali sui quattro lati, poi il quadrivio.
##
## Le strisce sono il segnale visivo di dove si può attraversare, e i percorsi
## degli NPC passano di lì. Il quadrivio va sopra perché è il pezzo intero: le
## due dritte che ci arrivano si accavallano, e coprirle è esattamente il suo
## mestiere.
func _draw_junctions() -> void:
	for junction: Dictionary in CityMap.junction_sides():
		var square: Rect2 = junction["square"]
		var open: Array = junction["open"]
		# Le strisce solo dove c'e' strada: sul lato chiuso di una T si
		# finirebbe dritti contro il marciapiede.
		for side: Vector2 in open:
			_draw_crossing(square, side)
		var size := Vector2(ROAD_TILE, ROAD_TILE)
		var tile: Texture2D = TILE_CROSSROAD
		var angle := 0.0
		if open.size() == 3:
			tile = TILE_T
			# La T di serie e' chiusa a nord: si gira finche' il lato chiuso
			# non e' quello senza strada.
			for side: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				if not side in open:
					angle = Vector2.UP.angle_to(side)
		elif open.size() == 2:
			tile = TILE_BEND
			# La curva di serie va da ovest a sud; girandola di 90 gradi in senso
			# orario i due lati diventano nord-ovest, poi nord-est, poi est-sud.
			for step in 4:
				var a := Vector2.LEFT.rotated(PI * 0.5 * step)
				var b := Vector2.DOWN.rotated(PI * 0.5 * step)
				if _has_side(open, a) and _has_side(open, b):
					angle = PI * 0.5 * step
		draw_set_transform(square.get_center(), angle, Vector2.ONE)
		draw_texture_rect(tile, Rect2(-size * 0.5, size), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)

static func _has_side(open: Array, side: Vector2) -> bool:
	for s: Vector2 in open:
		if s.distance_to(side) < 0.01:
			return true
	return false

## Le strisce pedonali su un lato dell'incrocio.
func _draw_crossing(square: Rect2, step: Vector2) -> void:
	var at := square.get_center() + step * (square.size.x * 0.5 + CROSSING_GAP
		+ CROSSING_BAND.size.x * 0.5)
	var size := Vector2(CROSSING_BAND.size.x, ROAD_TILE)
	# Le strisce stanno **di traverso** alla strada, quindi la fascia ritagliata
	# va girata quando l'attraversamento è su una verticale.
	if absf(step.y) > 0.0:
		draw_set_transform(at, PI * 0.5, Vector2.ONE)
		draw_texture_rect_region(TILE_CROSSING, Rect2(-size * 0.5, size), CROSSING_BAND)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	draw_texture_rect_region(TILE_CROSSING, Rect2(at - size * 0.5, size), CROSSING_BAND)

# --- Il paesaggio del bordo -------------------------------------------------

## Le quattro strade che se ne vanno dalla città, in mezzo alle colline.
##
## Solo l'asfalto, senza la fascia di marciapiede che hanno quelle di città:
## il cordolo se lo porta già la piastrella, e un marciapiede lastricato in
## mezzo ai monti direbbe che lì ci si passeggia. Lì non ci va nessuno — la
## griglia dei percorsi finisce prima, vedi `CityMap.view_bounds()`.
##
## Stanno qui e non nello shader del paesaggio perché sono le stesse piastrelle
## di Kenney delle strade di città: il paesaggio, che sta sopra, in quei
## rettangoli è trasparente e le lascia vedere.
func _draw_exit_roads() -> void:
	for exit_road in CityMap.exit_roads():
		_draw_asphalt(exit_road["rect"], bool(exit_road["horizontal"]))

## Le colline e le montagne intorno alla città.
##
## ## A cosa servono
##
## A far finire la mappa senza che si veda che finisce. Allo scatto di zoom più
## lontano, e camminando fino all'ultimo isolato, prima c'era una cornice di
## triangoli grigi tutti uguali su un fondo grigio piatto: si leggeva come una
## decorazione messa intorno a un disegno, non come un posto. Adesso fuori
## dalla città c'è campagna — prato e boschi — che sale in colline e poi in
## montagne rocciose e innevate, sempre più velate di foschia verso il bordo.
##
## ## Come è fatto
##
## È uno shader (`assets/shaders/landscape.gdshader`, lì c'è il perché di
## tutto) su un `Polygon2D` grande quanto la vista della camera. Sta **sopra**
## a questo nodo, perché le montagne si alzano verso nord e coprono quello che
## hanno dietro — strade d'uscita comprese; dove si vede la città o l'asfalto
## è trasparente. Figlio di questo nodo e non della City per stare nello stesso
## `z_index`: sotto a edifici, persone e lampioni.
##
## Il rumore è in due `NoiseTexture2D` senza cuciture invece che calcolato nello
## shader: per ogni pixel la quota si legge una sessantina di volte, e una
## lettura di texture costa molto meno di un rumore fatto di seni.
func _build_landscape() -> void:
	var old := get_node_or_null("Landscape")
	if old != null:
		old.free()
	var view := CityMap.view_bounds()
	var land := Polygon2D.new()
	land.name = "Landscape"
	land.polygon = PackedVector2Array([
		view.position, Vector2(view.end.x, view.position.y),
		view.end, Vector2(view.position.x, view.end.y)])
	var material := ShaderMaterial.new()
	material.shader = LANDSCAPE_SHADER
	var hills := _noise_image(FastNoiseLite.FRACTAL_FBM, 0.010, 3)
	var ridges := _noise_image(FastNoiseLite.FRACTAL_RIDGED, 0.009, 4)
	material.set_shader_parameter("colline", ImageTexture.create_from_image(hills))
	material.set_shader_parameter("creste", ImageTexture.create_from_image(ridges))
	var city := CityMap.WORLD_BOUNDS
	material.set_shader_parameter("citta", Vector4(city.position.x, city.position.y, city.size.x, city.size.y))
	var roads: Array[Vector4] = []
	for exit_road in CityMap.exit_roads():
		var r: Rect2 = exit_road["rect"]
		roads.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	material.set_shader_parameter("strade", roads)
	material.set_shader_parameter("profondita", CityMap.FRAME_DEPTH)
	material.set_shader_parameter("alt_max", LANDSCAPE_HEIGHT)
	land.material = material
	add_child(land)

	# Gli abeti delle colline, sopra al paesaggio. Leggono le stesse due
	# immagini dello shader per sapere a che quota sta ogni punto.
	var old_pines := get_node_or_null("Pines")
	if old_pines != null:
		old_pines.free()
	var pines := PineTrees.new()
	pines.name = "Pines"
	add_child(pines)
	var exit_rects: Array[Rect2] = []
	for exit_road in CityMap.exit_roads():
		exit_rects.append(exit_road["rect"])
	pines.build(hills, ridges, city, exit_rects, CityMap.FRAME_DEPTH, LANDSCAPE_HEIGHT, view)

## Un rumore senza cuciture da 512 px: lo shader lo ripete su qualche migliaio
## di pixel di mondo, quindi le ripetizioni cadono lontane fra loro e con due
## rumori a scale diverse non si allineano mai.
##
## Un'immagine e non una `NoiseTexture2D`: la stessa immagine la legge anche
## `PineTrees` per sapere dove sta il terreno, e una `NoiseTexture2D` si
## genera in un thread suo e non la si puo' leggere subito. Gli argomenti sono
## quelli che usava la `NoiseTexture2D` (senza cuciture, margine 0,1,
## normalizzato), quindi il paesaggio e' lo stesso di prima.
func _noise_image(fractal: FastNoiseLite.FractalType, frequency: float, octaves: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = LANDSCAPE_SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	noise.frequency = frequency
	return noise.get_seamless_image(512, 512, false, false, 0.1, true)

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
