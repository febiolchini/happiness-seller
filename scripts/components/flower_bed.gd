extends Node2D
class_name FlowerBed

## Qualche fiorellino sparso sull'erba di un'aiuola: non una pianta vera come
## `WindTree` — è pavimento, piatto e fermo, come i fiori di un prato vero visti
## da lontano — solo qualche punto di colore in mezzo al verde.
##
## **Sta sopra all'erba e non sotto.** `LayeredGrass` disegna il suo rettangolo
## con lo shader dei fili d'erba, e un fiore sotto sparirebbe schiacciato. In
## `city.gd` questo nodo viene aggiunto DOPO tutti i prati, con lo stesso
## `z_index`: fra nodi allo stesso z_index vince l'ordine nell'albero, quindi
## disegnato per ultimo sta sopra.
##
## **Pochi e piccoli apposta.** Il compito è "dare un po' di colore", non fare
## un'aiuola fiorita: tre o quattro punti per aiuola, due pixel l'uno, bastano a
## farsi notare senza affollare l'erba.
##
## La semina è deterministica (un seed dalla posizione del rettangolo, come
## `_draw_scatter` in `city_ground.gd`): la stessa aiuola ha sempre gli stessi
## fiori, non ne spuntano di nuovi ogni volta che si ricarica la città.
##
## **Non sotto a un cespuglio o a un albero.** Un fiore disegnato PRIMA del
## cespuglio (che sta sopra all'erba, vedi `city.gd`) sparirebbe sotto alle sue
## foglie — soldi buttati, letteralmente pixel che non si vedono mai. `avoid`
## sono i rettangoli da evitare (l'ingombro di ogni pianta, `WindTree.footprint()`):
## un punto che ci cade dentro si ripesca, e se non trova posto in poche
## prove quel fiore semplicemente non nasce.

## I colori dei petali: pochi, tenui, da fiore di campo — non un'aiuola curata
## a tinte sature, che qui stonerebbe.
const COLORS := [
	Color(0.90, 0.78, 0.30), # giallo
	Color(0.88, 0.55, 0.62), # rosa
	Color(0.72, 0.58, 0.86), # lilla
	Color(0.93, 0.91, 0.85), # bianco panna
]
## Quanti fiori per metro quadrato di aiuola, circa: bassa apposta.
const DENSITY := 0.00035
## Margine dal bordo dell'aiuola, per non finire sul cordolo.
const MARGIN := 6.0

## Le aiuole da riempire, in coordinate mondo.
var rects: Array[Rect2] = []
## Gli ingombri da evitare: cespugli e alberi che stanno sopra a un'aiuola.
var avoid: Array[Rect2] = []

## Quanti punti si ripescano prima di rinunciare a un fiore: pochi bastano, la
## densità è già bassa e l'aiuola piccola.
const ATTEMPTS := 8

func _draw() -> void:
	for rect in rects:
		var inner := rect.grow(-MARGIN)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			continue
		var seed := int(absf(rect.position.x) * 7.0 + absf(rect.position.y) * 13.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		# La banda libera è piccola quando un cespuglio copre quasi tutta
		# l'aiuola: più punti tentati vuol dire più fiori che trovano posto
		# lì, invece che diradarsi ovunque compreso sotto alle foglie.
		var count := maxi(4, roundi(rect.size.x * rect.size.y * DENSITY * 2.5))
		for i in count:
			for attempt in ATTEMPTS:
				var at := inner.position + Vector2(
					rng.randf() * inner.size.x, rng.randf() * inner.size.y)
				if _is_covered(at):
					continue
				var color: Color = COLORS[rng.randi() % COLORS.size()]
				_flower(at, color)
				break

func _is_covered(at: Vector2) -> bool:
	for zone in avoid:
		if zone.has_point(at):
			return true
	return false

## Un fiorellino minuscolo: quattro petali di un pixel intorno a un centro più
## scuro. A questa scala non serve altro — un disco pieno si leggerebbe come
## una macchia, non come un fiore.
func _flower(at: Vector2, color: Color) -> void:
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_rect(Rect2(at + offset, Vector2.ONE), color, true)
	draw_rect(Rect2(at, Vector2.ONE), color.darkened(0.35), true)
