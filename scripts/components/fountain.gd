extends Node2D

## Fontana del parco: segnaposto, ma con l'acqua che si muove.
##
## Serve a due cose. La prima è che il centro civico abbia un punto di
## riferimento riconoscibile invece di essere un prato con un municipio in
## fondo. La seconda è più concreta: è l'unico oggetto della mappa che si
## anima, quindi è il posto dove si vede subito se un giorno l'Y-sort o la
## camera smettono di funzionare.
##
## L'origine è a terra al centro della vasca, come per gli edifici.

@export var radius := 34.0
@export var basin_color := Color(0.58, 0.57, 0.55)
@export var water_color := Color(0.30, 0.52, 0.62)

const JETS := 6

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## Il colore dell'acqua adesso: la sua tinta, mescolata a quella del cielo.
##
## Serve perché l'acqua è l'unica superficie della città che **riflette**
## invece di limitarsi a essere illuminata. La tinta dell'aria
## (`atmosphere.gd`) scurisce tutto allo stesso modo, compresa la vasca: se
## l'acqua non prendesse per conto suo l'arancione del tramonto e il blu della
## notte, al calare del sole diventerebbe semplicemente una macchia scura come
## il resto, e la fontana smetterebbe di essere il punto di riferimento del
## parco proprio nell'ora in cui si guarda di più.
func _water_now() -> Color:
	var sky := Daylight.air(Daylight.hour_of(GameState.current))
	return water_color.lerp(sky, 0.45)

func _draw() -> void:
	var water := _water_now()
	# Vasca: due ellissi, una più scura sotto, per dare lo spessore del bordo.
	draw_colored_polygon(Shapes.ellipse(Vector2(0, 2), Vector2(radius, radius * 0.42), 25), basin_color.darkened(0.35))
	draw_colored_polygon(Shapes.ellipse(Vector2(0, -4), Vector2(radius, radius * 0.42), 25), basin_color)
	draw_colored_polygon(Shapes.ellipse(Vector2(0, -4), Vector2(radius - 7.0, radius * 0.30), 25), water)

	# Colonna centrale.
	draw_rect(Rect2(-5, -30, 10, 26), basin_color, true)
	draw_colored_polygon(Shapes.ellipse(Vector2(0, -30), Vector2(13, 5), 25), basin_color.lightened(0.15))

	_draw_jets()
	# Riflessi sull'acqua, sfasati fra loro così non pulsano all'unisono.
	for i in 3:
		var phase := _time * 1.4 + float(i) * 2.1
		var shine := water.lightened(0.35)
		shine.a = 0.35 + 0.25 * sin(phase)
		var offset := Vector2(cos(phase * 0.7) * radius * 0.45, -4 + sin(phase) * radius * 0.12)
		draw_colored_polygon(Shapes.ellipse(offset, Vector2(9, 3), 25), shine)

## Getti d'acqua: parabole che partono dalla cima della colonna e ricadono nella
## vasca. L'altezza oscilla piano, così la fontana non sembra un fermo immagine.
func _draw_jets() -> void:
	var pulse := 1.0 + 0.12 * sin(_time * 2.2)
	var jet := _water_now().lightened(0.45)
	jet.a = 0.8
	for i in JETS:
		var angle := TAU * float(i) / float(JETS) + _time * 0.25
		var dir := Vector2(cos(angle), sin(angle) * 0.42)
		var points := PackedVector2Array()
		for step in 7:
			var t := float(step) / 6.0
			var reach := dir * (radius - 8.0) * t
			var height := -30.0 - 14.0 * pulse * sin(t * PI)
			points.append(Vector2(reach.x, reach.y + height + 26.0 * t))
		draw_polyline(points, jet, 1.0)
