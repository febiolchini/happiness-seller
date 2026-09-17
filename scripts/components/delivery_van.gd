extends Node2D

## Il furgone della consegna: sta parcheggiato a fianco di casa, esce dalla
## città col carico e rientra coi soldi.
##
## È solo l'**animazione** di una cosa che è già successa nei dati: a decidere
## quanto dura il viaggio e quanto si incassa è `Delivery`, che lavora in ore di
## gioco e va avanti anche in cantina e col gioco chiuso. Questo nodo non sa
## niente di quello — gli viene detto "stai fermo", "parti" o "rientra",
## percorre la strada e basta.
##
## È il motivo per cui perdersi l'animazione non costa niente: chi manda il
## furgone e poi scende in cantina ritrova i soldi lo stesso, e in strada vede
## solo il messaggino. L'animazione è la ciliegina, non il meccanismo.
##
## ## Fermo è uno stato, non l'assenza di uno stato
##
## Il furgone non compare solo mentre si muove: comprato e non in viaggio, sta
## in sosta dove dice `CityMap.van_parking()`. Prima esisteva unicamente dentro
## all'animazione della partenza, e una spesa da cinquemila dollari non si
## vedeva da nessuna parte. Chi lo tiene in vita è `city.gd`, che lo mette e lo
## toglie guardando `Delivery`.
##
## L'origine del nodo è a terra al centro del mezzo, come per le auto del
## traffico: così l'Y-sort della City lo mette davanti o dietro alle cose in
## base a dove sta sulla strada.

## Lo sprite: il pickup marrone da lavoro del pacco delle auto. Era il `01`,
## che è viola — un furgone da consegne viola sembrava una macchina del
## traffico finita lì per sbaglio. Quando arriverà la pixel art dedicata cambia
## solo questa riga.
const SPRITE := preload("res://assets/sprites/props/cars/pickupTruck02.png")

## Quanto è lungo il tratto percorso a schermo, oltre il bordo del mondo: il
## furgone deve sparire *fuori* dalla città, non svanire in mezzo alla strada.
const RUN_LENGTH := 900.0
const SPEED := 150.0

## Quanto è lunga l'immissione in carreggiata: il tratto in diagonale fra il
## posto in sosta, che è al bordo dell'asfalto, e la corsia vera.
const MERGE_LENGTH := 120.0

## Quanto sta fermo prima di partire, e dopo essere rientrato. Senza, parte
## nello stesso istante in cui compare e non si capisce da dove sia uscito.
const PAUSE := 0.45

@onready var _body: Sprite2D = $Body

## Quanto il mezzo è lungo a schermo, per non far sbucare l'ombra dai fianchi.
var _size := Vector2(46, 33)

func _ready() -> void:
	# In sosta è a fianco di casa, dentro al giardino: l'Y-sort da solo lo
	# metterebbe dietro alla facciata. Uno z_index fisso lo tiene sempre
	# davanti, senza intaccare l'Y-sort delle auto in strada (loro restano a 0).
	z_index = 1
	_body.texture = SPRITE
	# A dimensione nativa, come le auto del traffico: gli sprite del pacco sono
	# già renderizzati tutti con lo stesso rapporto fra unità e pixel, quindi
	# riscalarli qui li metterebbe fuori scala con il resto della strada.
	_size = SPRITE.get_size()
	queue_redraw()

## Lo mette in sosta e lo lascia lì: nessun tween, nessuna scadenza. In sosta
## guarda la strada (`CityMap.VAN_PARK_ANGLE`) e non il verso di marcia: è
## fermo nel vialetto, non incolonnato.
func park(at: Vector2) -> void:
	global_position = at
	_turn(CityMap.VAN_PARK_ANGLE)

## Esce di scena verso est partendo dal posto in sosta `from`, immettendosi
## nella corsia a quota `lane_y`. `done` viene chiamata alla fine, e poi il nodo
## si toglie di mezzo: mentre è in viaggio non deve esserci.
##
## La manovra è in due tempi — prima si entra in carreggiata, poi si va — e non
## perché serva la manovra: il posto in sosta è al bordo dell'asfalto e la
## corsia è mezza strada più in là, quindi partire dritti vorrebbe dire
## teletrasportarsi in mezzo alla strada nel primo fotogramma.
func drive_out(from: Vector2, lane_y: float, done: Callable) -> void:
	var merge := Vector2(from.x + MERGE_LENGTH, lane_y)
	# Parte dal vialetto, quindi parte **girato**: la prima tratta raddrizza il
	# muso mentre scende in strada. Una rotazione istantanea al primo fotogramma
	# si legge come un errore di disegno.
	_path(
		[from, merge, Vector2(merge.x + RUN_LENGTH, lane_y)],
		CityMap.VAN_PARK_ANGLE, 0.0, done, true)

## Rientra da est lungo la corsia e **parcheggia** in `to`, dove resta. Non si
## cancella alla fine: rientrare vuol dire tornare a essere il furgone fermo
## davanti a casa, non sparire un'altra volta.
func drive_in(to: Vector2, lane_y: float, done: Callable) -> void:
	var merge := Vector2(to.x + MERGE_LENGTH, lane_y)
	# Arriva da est, quindi col muso a ovest (mezzo giro: lo sprite è disegnato
	# verso est, come le auto del traffico in `car.gd::setup()`), e finisce
	# girato verso la strada, cioè in sosta.
	_path(
		[Vector2(merge.x + RUN_LENGTH, lane_y), merge, to],
		PI, CityMap.VAN_PARK_ANGLE, done, false)

## Percorre una spezzata a velocità costante, girando il muso da `from_angle` a
## `to_angle` lungo l'ultima tratta che cambia direzione.
##
## I punti si sanno tutti in partenza, ed è il motivo per cui il percorso si
## costruisce così invece che una tratta alla volta: la durata di ogni pezzo
## esce dalla sua lunghezza, quindi la manovra corta dura poco e il rettilineo
## dura tanto, e per calcolarla bisogna conoscere il punto di arrivo prima di
## partire.
func _path(
	points: Array, from_angle: float, to_angle: float, done: Callable, vanish: bool
) -> void:
	global_position = points[0]
	_turn(from_angle)
	var tween := create_tween()
	if vanish:
		# In partenza sta fermo un attimo: senza, si muove nello stesso istante
		# in cui compare e non si capisce da dove sia uscito.
		tween.tween_interval(PAUSE)
	# La manovra è la tratta in cui il muso cambia verso: uscendo è la prima
	# (dal vialetto alla corsia), rientrando è l'ultima (dalla corsia al
	# vialetto). In tutti e due i casi è quella che tocca il posto in sosta.
	var turning := 1 if vanish else points.size() - 1
	for i in range(1, points.size()):
		var leg: Vector2 = points[i]
		var seconds: float = (points[i - 1] as Vector2).distance_to(leg) / SPEED
		tween.tween_property(self, "global_position", leg, seconds)
		if i == turning and not is_equal_approx(from_angle, to_angle):
			# `parallel()` aggancia il tweener successivo a quello appena messo:
			# il muso gira **mentre** il mezzo percorre la tratta, non prima.
			tween.parallel().tween_property(_body, "rotation", to_angle, seconds)
	tween.tween_interval(PAUSE)
	tween.tween_callback(done)
	if vanish:
		tween.tween_callback(queue_free)

## Gira il muso. Lo sprite è renderizzato verso est, quindi l'angolo è quanto
## va ruotato a partire da lì — come fanno le auto del traffico
## (`car.gd::setup()`), che per andare a ovest si girano di mezzo giro.
func _turn(angle: float) -> void:
	if _body == null:
		_body = $Body
	_body.rotation = angle

## L'ombra a terra, come per le auto del traffico: è quello che fa sembrare il
## mezzo appoggiato all'asfalto invece che incollato sopra. Segue il sole come
## tutte le altre.
func _draw() -> void:
	var info := Daylight.shadow(GameState.current)
	var slide: Vector2 = (info["direction"] as Vector2) * minf(float(info["length"]) * 7.0, 16.0)
	# L'ombra gira col mezzo: in sosta il furgone è di traverso, e un'ombra
	# rimasta larga come quando è in marcia gli spunterebbe dai fianchi.
	var body_size := _size.rotated(_body.rotation).abs()
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(Vector2(0, 3) + slide + Vector2(
			cos(a) * body_size.x * 0.34, sin(a) * body_size.y * 0.20))
	draw_colored_polygon(points, Color(0, 0, 0, 0.16 + float(info["alpha"]) * 0.35))
