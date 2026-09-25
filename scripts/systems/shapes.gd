class_name Shapes
extends RefCounted

## Geometria da disegno a mano, condivisa da tutti gli oggetti che ne hanno
## bisogno.
##
## `ellipse()` era la stessa decina di righe ripetuta identica — a volte al
## carattere — in una dozzina di `_draw()` diversi: le ombre per terra di
## auto, lampioni, alberi, protagonista, furgone del filmato, più le vasche
## della fontana, gli aloni dei lampioni, l'onda del click. Un punto solo, e
## chi lo chiama passa centro, raggi e quanti punti vuole sul giro.
##
## `camera_world_rect()` era lo stesso altro conto ripetuto due volte, per lo
## stesso motivo: chi disegna solo quello che la camera inquadra adesso lo
## chiede a un posto solo.

## `segments` punti sul perimetro di un'ellisse, chiusa: l'ultimo punto cade
## sullo stesso angolo del primo (`TAU * i / (segments - 1)`), così
## `draw_colored_polygon()`/`draw_polyline()` la vedono come un giro completo
## e non con uno spicchio mancante.
static func ellipse(center: Vector2, radius: Vector2, segments: int = 17) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments - 1)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points

## Il rettangolo di mondo inquadrato dalla camera adesso, allargato di
## `margin` pixel. È quello che tiene il costo di un disegno legato allo
## schermo e non alla mappa: nuvole, pozze e prati non hanno bisogno di
## sapere quanto è grande la città, solo quanto se ne vede — era lo stesso
## conto ripetuto in `ground_weather.gd` e `layered_grass.gd`, ognuno col suo
## margine.
static func camera_world_rect(node: CanvasItem, margin: float) -> Rect2:
	var to_world := node.get_viewport().get_canvas_transform().affine_inverse()
	var top_left := to_world * Vector2.ZERO
	var bottom_right := to_world * node.get_viewport_rect().size
	return Rect2(top_left, bottom_right - top_left).grow(margin)
