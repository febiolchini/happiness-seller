extends Node2D

## Un lampione: palo, braccio sopra la carreggiata, e di notte la pozza di luce
## sull'asfalto.
##
## L'origine è il PIEDE del palo, come per gli edifici e le persone: così si
## ordina da solo nell'Y-sort della City, e chi ci passa davanti gli passa
## davvero davanti.
##
## ## Perché non è un `PointLight2D`
##
## Godot ha le luci 2D vere, e la strada maestra sarebbe quella. Il problema è
## il terreno: `city_ground.gd` disegna tutta la città in un nodo solo, quindi
## ogni luce del mondo "tocca" quell'unico oggetto, e un oggetto può ricevere un
## numero limitato di luci per volta. Con un centinaio di lampioni le prime
## sedici si prenderebbero tutti i posti e le altre non illuminerebbero più il
## terreno, a seconda di dove guarda la camera.
##
## Qui invece la luce è disegnata: quattro ellissi sovrapposte con
## `Daylight.emissive()`, che le tiene accese dentro alla tinta della notte.
## Costa quattro poligoni per lampione acceso e solo quando è inquadrato — un
## lampione fuori schermo non disegna niente — e non ha tetti da rispettare.
## Quando arriverà la pixel art, il palo diventa uno sprite e la pozza resta.
##
## ## Ridisegna solo quando cambia la luce
##
## Sono un centinaio: un `_process` a testa per guardare l'orologio sarebbe un
## centinaio di chiamate a vuoto per frame. Si iscrivono al gruppo di
## `atmosphere.gd`, che li chiama quando la luce cambia davvero — meno di venti
## volte per giornata di gioco.

## Altezza del palo dal piede alla lampada.
const HEIGHT := 44.0
## Quanto sporge il braccio verso la strada.
const ARM := 18.0

const POLE := Color(0.28, 0.29, 0.33)
const POLE_LIT := Color(0.42, 0.43, 0.47)
## Il colore della lampada: sodio, arancione sporco. Le luci bianche fredde
## sono di un'altra città e di un altro decennio.
const BULB := Color(1.0, 0.84, 0.55)
const GLOW := Color(1.0, 0.72, 0.36)

## Raggi della pozza di luce a terra, sotto alla lampada.
const POOL := Vector2(58.0, 26.0)
## Quanti strati ha l'alone.
##
## Sette e non quattro: con pochi strati i bordi di ogni ellisse si vedono uno
## per uno e la pozza diventa un bersaglio da tiro a segno. Più strati, ognuno
## più trasparente, e la sfumatura si chiude. Costa sette poligoni per lampione
## acceso e inquadrato, che è il prezzo giusto per la cosa che si guarda di più
## in tutta la scena notturna.
const LAYERS := 7

## Da che parte sporge il braccio: verso la carreggiata. Lo passa
## `CityMap.street_lamps()`, che sa da che lato della strada sta il palo.
@export var reach := Vector2(0, 1):
	set(value):
		reach = value
		queue_redraw()

func _ready() -> void:
	add_to_group(Daylight.LIGHT_GROUP)

## Chiamata da `atmosphere.gd` quando la luce è cambiata abbastanza da vedersi.
func on_light_changed() -> void:
	queue_redraw()

func _draw() -> void:
	var data := GameState.current
	var ambient := Daylight.light(data)
	var strength := Daylight.lamp_strength(data)
	# Prima la pozza, poi il ferro: disegnata dopo, la luce finirebbe sopra al
	# palo e il lampione sembrerebbe di vetro.
	if strength > 0.01:
		_draw_pool(ambient, strength)
	_draw_pole(strength)
	if strength > 0.01:
		_draw_bulb(ambient, strength)

## La pozza di luce, centrata sotto alla lampada e non sotto al palo: è il
## braccio a dire dove cade, ed è quello che porta la luce sulla strada invece
## che sul marciapiede dietro.
func _draw_pool(ambient: Color, strength: float) -> void:
	var center := reach.normalized() * ARM
	for i in LAYERS:
		var t := float(i + 1) / float(LAYERS)
		var color := GLOW
		color.a = 0.115 * (1.0 - t * 0.55) * strength
		draw_colored_polygon(Shapes.ellipse(center, POOL * t), Daylight.emissive(color, ambient))

func _draw_pole(strength: float) -> void:
	# Il palo si schiarisce quando la lampada è accesa: è la luce che gli cade
	# addosso, ed è quello che lo stacca dal buio invece di lasciarlo una riga
	# nera con una macchia arancione in cima.
	var color := POLE.lerp(POLE_LIT, strength)
	draw_rect(Rect2(-1.5, -HEIGHT, 3.0, HEIGHT), color, true)
	# Base allargata: senza, il palo sembra infilato nel terreno.
	draw_rect(Rect2(-4.0, -4.0, 8.0, 4.0), color.darkened(0.25), true)
	var top := Vector2(0, -HEIGHT)
	var head := top + reach.normalized() * ARM
	draw_line(top, head, color, 2.0)

func _draw_bulb(ambient: Color, strength: float) -> void:
	var head := Vector2(0, -HEIGHT) + reach.normalized() * ARM
	# Alone intorno alla lampada, a due strati, e il vetro acceso dentro.
	for i in 3:
		var t := float(i + 1) / 3.0
		var halo := GLOW
		halo.a = 0.26 * (1.0 - t * 0.5) * strength
		draw_colored_polygon(Shapes.ellipse(head, Vector2(11.0, 8.0) * t), Daylight.emissive(halo, ambient))
	var bulb := BULB
	bulb.a = 0.4 + 0.6 * strength
	draw_rect(Rect2(head.x - 4.0, head.y - 1.5, 8.0, 3.0), Daylight.emissive(bulb, ambient), true)

