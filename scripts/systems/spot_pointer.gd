extends Node2D

## La freccia che dice da che parte sta Brian mentre aspetta.
##
## ## Perché serve
##
## Il nome del posto ("MILL ROAD NORTH OF MAIN STREET") dice il quartiere, non
## l'indirizzo: in una città a reticolo fra due incroci ci sono settecento
## pixel, e più appuntamenti diversi finiscono per chiamarsi nello stesso modo.
## Su uno schermo da 640x360 quello vuol dire che si arriva "nel posto giusto" e
## Brian è comunque fuori inquadratura — che è esattamente il modo in cui questa
## cosa si rompeva: il gioco diceva dov'era, il giocatore ci andava, e lì non
## c'era nessuno.
##
## Il nome fa il primo pezzo di strada, questa freccia fa l'ultimo.
##
## ## Come sa dove puntare
##
## Sta su una tela sua (`SpotLayer`), quindi disegna in coordinate schermo e non
## si muove con la camera. Il punto dell'appuntamento è in coordinate mondo: a
## tradurlo è `get_canvas_transform()`, la stessa trasformazione che la camera
## applica al mondo. Finché il punto è **dentro** allo schermo la freccia non si
## disegna: lì Brian ha già il suo rombo verde sopra la testa, e due indicatori
## per la stessa cosa sono uno di troppo.
##
## Essendo su una tela a parte, la tinta della notte (`atmosphere.gd`) non la
## tocca: è un segnale al giocatore, non un oggetto della città, e deve restare
## dello stesso verde alle due di notte sotto la pioggia.

## Quanto sta dentro al bordo dello schermo.
##
## In alto di più: lassù c'è la riga dell'HUD, e una freccia che le finisce
## sopra si legge come un pezzo dell'HUD invece che come un'indicazione sul
## mondo. È lo stesso motivo per cui l'HUD stesso si toglie di mezzo davanti
## alle finestre modali.
const MARGIN := 20.0
const MARGIN_TOP := 34.0
## Mezza larghezza e lunghezza della punta.
const SIZE := Vector2(7.0, 11.0)
## Oltre questa distanza la freccia è al minimo, addosso al punto è al massimo:
## è il modo di dire "quanto manca" senza scrivere un numero che non avrebbe
## unità di misura.
const FAR := 2200.0

## Nascosta mentre una finestra modale è aperta, come l'HUD: il gestionale del
## PC e i messaggi del telefono coprono lo schermo, e una freccia che galleggia
## sopra a un riquadro si legge come un pezzo del riquadro.
const MODAL_GROUP := "modal"

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var data := GameState.current
	if data == null or not SeedDeal.is_ready(data) or _modal_open():
		return

	var spot := SeedDeal.spot(data)
	var view := get_viewport_rect().size
	var on_screen := get_viewport().get_canvas_transform() * spot
	var frame := Rect2(
		Vector2(MARGIN, MARGIN_TOP),
		view - Vector2(MARGIN * 2.0, MARGIN + MARGIN_TOP))
	if frame.has_point(on_screen):
		# Brian è già in vista: ci pensa il rombo sopra la sua testa.
		return

	# Il centro della CORNICE e non dello schermo: il margine in alto è più
	# grande degli altri, quindi i due punti non coincidono, e partire dal centro
	# dello schermo farebbe uscire la freccia dal bordo sbagliato.
	var centre := frame.get_center()
	var direction := (on_screen - centre)
	if direction.length() < 0.001:
		return
	direction = direction.normalized()

	var at := _edge_point(centre, direction, frame)
	# Più si è vicini, più la freccia è grande e piena: è il "quanto manca",
	# senza scrivere un numero che in questo gioco non avrebbe unità.
	var closeness := 1.0 - clampf(centre.distance_to(on_screen) / FAR, 0.0, 1.0)
	var scale := 0.75 + closeness * 0.45
	# Un respiro lento, perché si veda che è viva e non un segno disegnato sopra.
	scale *= 1.0 + 0.06 * sin(_time * 3.0)
	_draw_arrow(at, direction, scale, 0.55 + closeness * 0.45)

## Dove la freccia tocca il bordo dello schermo, andando dal centro verso il
## punto. Si prova prima il bordo verticale e poi quello orizzontale, e vince
## quello che si incontra per primo: è il modo più corto di far scorrere una
## freccia lungo tutto il perimetro senza casi particolari agli angoli.
func _edge_point(centre: Vector2, direction: Vector2, frame: Rect2) -> Vector2:
	var half := frame.size * 0.5
	var steps := PackedFloat32Array()
	if absf(direction.x) > 0.0001:
		steps.append(half.x / absf(direction.x))
	if absf(direction.y) > 0.0001:
		steps.append(half.y / absf(direction.y))
	var reach := steps[0]
	for step in steps:
		reach = minf(reach, step)
	return centre + direction * reach

func _draw_arrow(at: Vector2, direction: Vector2, scale: float, alpha: float) -> void:
	var forward := direction * SIZE.y * scale
	var side := Vector2(-direction.y, direction.x) * SIZE.x * scale
	var points := PackedVector2Array([
		at + forward,
		at - forward * 0.45 + side,
		at - forward * 0.45 - side,
	])
	# Prima il contorno scuro, poi la punta: sotto ci può passare un muro chiaro,
	# l'asfalto o una pozza di luce, ed è lo stesso motivo per cui le scritte
	# dell'HUD hanno l'ombra dura invece di un pannello dietro.
	var outline := PackedVector2Array()
	for point in points:
		outline.append(at + (point - at) * 1.35)
	draw_colored_polygon(outline, Color(0, 0, 0, alpha * 0.55))
	var color := Npc.MARKER_SELLER
	color.a = alpha
	draw_colored_polygon(points, color)

func _modal_open() -> bool:
	return not get_tree().get_nodes_in_group(MODAL_GROUP).is_empty()
