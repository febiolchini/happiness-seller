class_name CityNavigation
extends RefCounted

## Come si va da un punto all'altro della città senza attraversare i muri.
##
## È una griglia A* (`AStarGrid2D`) costruita dalla stessa pianta che disegna la
## mappa: gli edifici diventano celle bloccate, e ogni cella calpestabile ha un
## **costo** diverso a seconda di dove si trova.
##
## Il costo è la parte che conta. Non basta impedire di passare dentro agli
## edifici: senza costi il protagonista taglierebbe in diagonale attraverso
## cortili e prati perché è più corto, e non camminerebbe mai su un marciapiede.
## Rendendo il marciapiede la superficie più economica, il percorso più
## conveniente diventa da solo quello che farebbe una persona: si segue la via,
## si attraversa la carreggiata invece di percorrerla, e si taglia per un prato
## solo quando il giro sarebbe molto più lungo.
##
## Il terreno non è mai *impraticabile*, solo caro: un edificio in mezzo a un
## isolato deve restare raggiungibile, e un giocatore che clicca in mezzo a un
## parco deve andarci.

## Lato di una cella. Sedici e non trentadue perché tutta la pianta è allineata
## a multipli di 16: così il bordo di un marciapiede cade esattamente su un
## confine fra celle, invece di tagliarne una a metà e dimezzare il passaggio.
const CELL := 16.0

const COST_SIDEWALK := 1.0
## L'asfalto. Caro sul serio, e non di poco: quattro volte il marciapiede.
##
## Non è il rischio di essere investiti — quello lo guarda `Traffic`, al
## momento di scendere dal cordolo — è che una persona sulla carreggiata **non
## ci cammina**, ci passa e basta. Con un costo appena più alto del marciapiede
## il percorso più conveniente restava spesso quello dritto in mezzo alla
## strada, che è più corto: si misurava più di metà del tragitto sull'asfalto.
##
## Quattro volte tanto lascia comunque passare l'attraversamento, che di celle
## ne costa sei (la strada è larga 96 px), e rende invece impagabile
## percorrerla per il lungo. Di riflesso l'attraversamento diventa anche
## **perpendicolare** da solo, senza doverlo scrivere da nessuna parte: in
## diagonale di celle d'asfalto se ne toccherebbero la metà in più.
const COST_ROAD := 4.0
const COST_GROUND := 3.0

## Quanto si sta larghi dai muri. Il protagonista è largo una ventina di pixel e
## il percorso passa per il centro delle celle: senza margine rasenterebbe gli
## spigoli e sembrerebbe incastrarsi.
const WALL_MARGIN := 8.0

## Ogni quanti pixel si controlla una linea quando si semplifica il percorso.
const LINE_STEP := 8.0
## Quanto lunga può essere una scorciatoia cercata dalla semplificazione.
##
## Senza un tetto il confronto fra i due costi si allunga col percorso — per
## ogni punto si ripesa tutta la linea dall'ultimo tenuto — e un tragitto da un
## capo all'altro della città arrivava a 70 ms, che è una pausa che si sente
## nel momento del click. Oltre questo tetto la scorciatoia viene semplicemente
## troncata: su un rettilineo restano due o tre tappe in più, che stanno sulla
## stessa retta e non cambiano di un pixel il tragitto camminato.
const SHORTCUT_REACH := 400.0

var _grid := AStarGrid2D.new()
var _origin := Vector2.ZERO
var _cols := 0
var _rows := 0
var _ready := false

# --- Costruzione -----------------------------------------------------------

## Prepara la griglia. `buildings` è l'elenco già completo (punti di riferimento
## più riempimento), lo stesso che la mappa usa per costruire i nodi.
func build(buildings: Array) -> void:
	var bounds := CityMap.WORLD_BOUNDS
	_origin = bounds.position
	_cols = int(ceilf(bounds.size.x / CELL))
	_rows = int(ceilf(bounds.size.y / CELL))

	_grid.region = Rect2i(0, 0, _cols, _rows)
	_grid.cell_size = Vector2(CELL, CELL)
	# In diagonale solo quando entrambi i lati sono liberi: senza, il percorso
	# taglia gli angoli passando attraverso lo spigolo di un edificio.
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()

	_paint_costs()
	_block(buildings)
	_ready = true

## Dipinge i costi a strati, dal più generico al più specifico.
##
## Si passa per rettangoli e non cella per cella: interrogare ogni cella contro
## ogni strada vorrebbe dire un milione di controlli, dipingere le fasce ne
## costa una frazione.
func _paint_costs() -> void:
	for y in _rows:
		for x in _cols:
			_grid.set_point_weight_scale(Vector2i(x, y), COST_GROUND)
	# Prima tutta la fascia stradale come marciapiede, poi l'asfalto sopra:
	# così agli incroci l'asfalto resta asfalto e non torna marciapiede.
	for road: Rect2 in CityMap.ROADS_H + CityMap.ROADS_V:
		_fill(road.grow(CityMap.SIDEWALK_DEPTH), COST_SIDEWALK)
	for road: Rect2 in CityMap.ROADS_H + CityMap.ROADS_V:
		_fill(road, COST_ROAD)

func _fill(rect: Rect2, weight: float) -> void:
	var from := _clamped_cell(rect.position)
	var to := _clamped_cell(rect.end - Vector2.ONE)
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			_grid.set_point_weight_scale(Vector2i(x, y), weight)

func _block(buildings: Array) -> void:
	for entry in buildings:
		var rect := CityMap.footprint(entry).grow(WALL_MARGIN)
		var from := _clamped_cell(rect.position)
		var to := _clamped_cell(rect.end - Vector2.ONE)
		for y in range(from.y, to.y + 1):
			for x in range(from.x, to.x + 1):
				_grid.set_point_solid(Vector2i(x, y), true)

# --- Percorso --------------------------------------------------------------

## Il percorso da `from` a `to`, già semplificato. Vuoto se non se ne trova uno.
##
## Il primo punto è la posizione di partenza vera e l'ultimo la destinazione
## vera: agganciarsi al centro delle celle farebbe partire il personaggio con
## uno scatto laterale.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not _ready:
		return PackedVector2Array()
	var start := _free_cell_near(_clamped_cell(from))
	var goal_cell := _clamped_cell(to)
	var goal := _free_cell_near(goal_cell)
	if start == goal:
		return PackedVector2Array([to])

	var ids := _grid.get_id_path(start, goal)
	if ids.is_empty():
		return PackedVector2Array()

	var points := PackedVector2Array()
	for id: Vector2i in ids:
		points.append(_center(id))
	points[0] = from
	# La destinazione vera solo se era raggiungibile: se il click era dentro a un
	# muro ci si ferma sul bordo, non ci si infila dentro.
	if goal == goal_cell:
		points[points.size() - 1] = to
	return _simplify(points)

## Toglie i punti intermedi che non servono.
##
## A* su una griglia restituisce una scaletta di celle: seguita così com'è, il
## personaggio cammina a zig-zag anche in mezzo a una strada dritta. Si tiene un
## punto solo quando togliendolo il tragitto **peggiora**.
##
## "Peggiora" è la parte delicata, ed è cambiata. Prima era un tetto di spesa:
## la scorciatoia era permessa se non metteva piede su un terreno più caro del
## più caro già attraversato. Sembra la stessa cosa e non lo è — il tetto non
## guarda **quanto** terreno caro si attraversa, solo di che tipo è. Bastava
## quindi toccare l'asfalto una volta, per un attraversamento, perché da lì in
## poi tutta l'asfalto fosse gratis: la scorciatoia successiva poteva tagliare
## per la carreggiata in diagonale per centinaia di pixel. Misurato su una
## quarantina di tragitti lunghi, il protagonista camminava sull'asfalto per
## **metà** del percorso.
##
## Adesso si confrontano i due costi per intero: la linea diretta si prende solo
## se costa quanto o meno del pezzo di percorso che sostituisce. Un
## attraversamento resta (accorcia davvero), un tratto in diagonale sulla strada
## no (costa quattro volte il marciapiede che aveva accanto), e su terreno
## uniforme la semplificazione è la stessa di prima.
func _simplify(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var result := PackedVector2Array([points[0]])
	var anchor := 0
	# Quanto costa il percorso originale da `anchor` fino al punto corrente.
	var walked := 0.0
	for i in range(1, points.size() - 1):
		walked += _segment_cost(points[i - 1], points[i])
		if points[anchor].distance_to(points[i + 1]) <= SHORTCUT_REACH:
			var direct := _segment_cost(points[anchor], points[i + 1])
			var original := walked + _segment_cost(points[i], points[i + 1])
			if direct >= 0.0 and direct <= original + 0.001:
				continue
		result.append(points[i])
		anchor = i
		walked = 0.0
	result.append(points[points.size() - 1])
	return result

## Quanto costa andare da `a` a `b` in linea retta: la lunghezza pesata dal
## terreno che si calpesta. `-1` se si finisce dentro a un muro.
##
## È la stessa misura che usa A* sulle celle — peso x distanza — così i due
## numeri si possono confrontare senza convertire niente.
func _segment_cost(a: Vector2, b: Vector2) -> float:
	var distance := a.distance_to(b)
	if distance <= 0.0:
		return 0.0
	var steps := maxi(1, int(distance / LINE_STEP))
	var step := distance / float(steps)
	var total := 0.0
	for i in range(steps + 1):
		var point := a.lerp(b, float(i) / float(steps))
		if not is_walkable(point):
			return -1.0
		# Gli estremi contano mezzo passo: sono il bordo del tratto, non il
		# centro di un pezzetto come tutti gli altri campioni.
		var weight := 0.5 if i == 0 or i == steps else 1.0
		total += cost_at(point) * step * weight
	return total

## Vero se fra due punti si può andare in linea retta senza entrare in un muro
## e senza mettere piede su un terreno più caro di `limit`.
##
## Di suo non guarda il costo — il limite parte dal più caro che ci sia — perché
## la domanda che gli si fa quasi sempre è "c'è un muro in mezzo?". Chi vuole
## anche il terreno lo dice.
func is_clear(a: Vector2, b: Vector2, limit := COST_ROAD) -> bool:
	var distance := a.distance_to(b)
	var steps := int(distance / LINE_STEP)
	for i in range(1, steps + 1):
		var point := a.lerp(b, float(i) / float(steps))
		if not is_walkable(point):
			return false
		if cost_at(point) > limit + 0.001:
			return false
	return true

func is_walkable(point: Vector2) -> bool:
	if not _ready:
		return true
	return not _grid.is_point_solid(_clamped_cell(point))

## Quanto costa camminare in un punto: marciapiede, asfalto o terreno libero.
func cost_at(point: Vector2) -> float:
	if not _ready:
		return COST_SIDEWALK
	return _grid.get_point_weight_scale(_clamped_cell(point))

# --- Celle -----------------------------------------------------------------

func _clamped_cell(point: Vector2) -> Vector2i:
	var cell := Vector2i(
		int(floorf((point.x - _origin.x) / CELL)),
		int(floorf((point.y - _origin.y) / CELL)))
	return Vector2i(clampi(cell.x, 0, _cols - 1), clampi(cell.y, 0, _rows - 1))

func _center(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5

## La cella libera più vicina, in anelli concentrici.
##
## Serve per i due estremi: si può cliccare sopra a un edificio, e il
## protagonista può ritrovarsi dentro a un muro (per esempio riprendendo un
## salvataggio fatto prima che quell'edificio esistesse). In entrambi i casi
## meglio partire dal bordo che non muoversi affatto.
func _free_cell_near(cell: Vector2i) -> Vector2i:
	if not _grid.is_point_solid(cell):
		return cell
	for radius in range(1, 24):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				# Solo il perimetro dell'anello: l'interno è già stato provato.
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var probe := Vector2i(cell.x + dx, cell.y + dy)
				if not _grid.is_in_boundsv(probe):
					continue
				if not _grid.is_point_solid(probe):
					return probe
	return cell
