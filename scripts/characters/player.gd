extends CharacterBody2D

## Protagonista. Per ora è un segnaposto: uno Sprite2D con un PNG provvisorio,
## che verrà sostituito da un AnimatedSprite2D con le animazioni vere.
##
## L'origine del nodo è ai PIEDI del personaggio: è quel punto a terra che conta
## sia per l'Y-sort sia per il click-to-move.

## Velocità di camminata in pixel al secondo. È **l'unica** velocità che ha.
##
## Quarantotto è un passo svelto, non una corsa: i passanti girano a 30
## (`npc_roster.gd`) e le auto fra i 96 e i 132, quindi si cammina una volta e
## mezza un passeggio e circa la metà del traffico. È il rapporto che si legge
## stando su un marciapiede vero, ed è quello che deve dare la città.
##
## Prima c'erano due velocità: 90 di passo e 190 oltre i 320 px dalla meta, per
## non metterci un minuto e mezzo ad attraversare la città. Erano tutte e due
## sbagliate — a 90 il protagonista camminava più forte di un'auto, a 190
## scivolava — e il problema che risolvevano non è la velocità di un pedone: è
## che le distanze grandi vogliono un mezzo. I mezzi arriveranno; il pedone
## resta un pedone.
@export var speed := 108.0
## In quanto tempo si arriva a regime, e in quanto ci si ferma.
##
## Partire e fermarsi di scatto è la cosa che più fa sembrare un personaggio una
## figurina trascinata invece di una persona che cammina. Sono due numeri e non
## uno perché fermarsi è più rapido che partire, come per chiunque.
@export var accel_time := 0.22
@export var brake_time := 0.12
## Sotto questa distanza dal bersaglio il personaggio ci si incolla e si ferma.
@export var arrive_distance := 1.5
## Ampiezza del saltello durante il cammino: sostituto temporaneo dell'animazione.
@export var bob_height := 1.0
## Quanti pixel di strada fa un passo.
##
## Il saltello va a PASSI e non a tempo: legandolo ai secondi, un personaggio che
## rallenta continua a sobbalzare alla stessa cadenza e sembra che pattini.
## Venti pixel su un personaggio alto quarantotto sono la falcata giusta — un
## metro e settanta di persona fa un passo di settanta centimetri — e a 48 px/s
## vengono due passi e mezzo al secondo, che è la cadenza di chi va di fretta.
@export var stride := 20.0

## Emesso quando il protagonista raggiunge il punto che gli era stato indicato.
signal arrived

@onready var _sprite: Sprite2D = $Sprite2D

## Le tappe che restano da percorrere, in coordinate globali. L'ultima è la
## destinazione vera: quelle prima sono le svolte che il percorso impone per
## girare intorno agli edifici.
var _path := PackedVector2Array()
var _path_index := 0
var _target := Vector2.ZERO
var _moving := false
var _bob_time := 0.0
var _sprite_rest_y := 0.0
## Quanto sta andando adesso: sale verso `speed` e scende a zero, non ci salta.
var _current_speed := 0.0
## Da quanto è fermo sul cordolo ad aspettare un buco nel traffico. Zero quando
## non sta aspettando.
var _waiting := 0.0

## Gruppo con cui gli altri ritrovano il protagonista senza sapere dove sta
## nell'albero: lo usano gli NPC per girarsi verso di lui.
const GROUP := "player"

## Quanto al massimo si resta fermi ad aspettare un buco nel traffico.
const MAX_WAIT := 8.0
## Quanto lontano si cerca il marciapiede di là, e con che passo.
const CROSSING_LOOKAHEAD := 320.0
const CROSSING_STEP := 8.0
## Ogni quanto gira la testa chi aspetta di attraversare.
const LOOK_INTERVAL := 0.55

func _ready() -> void:
	add_to_group(GROUP)
	# Fermo, il protagonista non si ridisegna: senza questo la sua ombra
	# resterebbe indietro mentre quella di tutto il resto gira col sole.
	add_to_group(Daylight.LIGHT_GROUP)
	_target = global_position
	_sprite_rest_y = _sprite.offset.y

## Chiamata da `atmosphere.gd` quando la luce è cambiata abbastanza da vedersi.
func on_light_changed() -> void:
	queue_redraw()

## L'ombra ai piedi del protagonista.
##
## È disegnata qui e non messa come nodo nella scena perché deve girare col
## sole: un `Polygon2D` figlio avrebbe una forma sola e andrebbe comunque
## spostato da uno script. Sotto allo sprite, sopra al terreno.
##
## Fino ad ora il protagonista era l'unica cosa della città senza ombra, e si
## vedeva: camminava un centimetro sopra l'asfalto.
func _draw() -> void:
	var info := Daylight.shadow(GameState.current)
	var slide: Vector2 = (info["direction"] as Vector2) * minf(float(info["length"]) * 9.0, 20.0)
	var points := Shapes.ellipse(slide, Vector2(9.0, 3.6))
	draw_colored_polygon(points, Color(0, 0, 0, 0.14 + float(info["alpha"]) * 0.45))

## Ordina di raggiungere un punto della mappa in linea retta (coordinate
## globali). È il caso semplice: per andare da una parte all'altra della città
## si usa `follow_path()`, che sa girare intorno agli edifici.
func move_to(world_position: Vector2) -> void:
	follow_path(PackedVector2Array([world_position]))

## Percorre una fila di tappe e, arrivato all'ultima, emette `arrived`.
##
## Il segnale scatta **solo alla fine**: chi ha ordinato il movimento per
## entrare in un edificio o parlare a qualcuno non deve vederselo arrivare a
## ogni svolta del percorso.
func follow_path(points: PackedVector2Array) -> void:
	if points.is_empty():
		stop()
		return
	_path = points
	_path_index = 0
	# Un percorso comincia dalla posizione attuale: quella tappa è già fatta.
	if _path.size() > 1 and global_position.distance_to(_path[0]) <= arrive_distance:
		_path_index = 1
	_target = _path[_path_index]
	_moving = true

func stop() -> void:
	_moving = false
	_path = PackedVector2Array()
	_path_index = 0
	_waiting = 0.0
	velocity = Vector2.ZERO
	_current_speed = 0.0

func is_moving() -> bool:
	return _moving

## Sta aspettando un buco nel traffico per attraversare? Serve a chi guarda da
## fuori — la mappa, e i controlli automatici.
func is_waiting_to_cross() -> bool:
	return _waiting > 0.0

func _physics_process(delta: float) -> void:
	if not _moving:
		velocity = Vector2.ZERO
		_current_speed = move_toward(_current_speed, 0.0, speed / brake_time * delta)
		_settle_sprite(delta)
		return

	var to_target := _target - global_position
	var distance := to_target.length()
	var direction := to_target / maxf(distance, 0.0001)

	if _must_wait(direction, delta):
		# Fermo sul cordolo. Non è un arresto della camminata — la meta resta
		# quella, e appena passa l'ultima auto si riparte — quindi il percorso
		# non si tocca.
		_waiting += delta
		_current_speed = move_toward(_current_speed, 0.0, speed / brake_time * delta)
		velocity = Vector2.ZERO
		_look_both_ways()
		_settle_sprite(delta)
		return
	_waiting = 0.0

	# Si rallenta arrivando alla META, non a ogni svolta: frenare a ogni angolo
	# di un tragitto lungo sarebbe un singhiozzo continuo.
	var to_goal := global_position.distance_to(_path[_path.size() - 1])
	var wanted := speed
	# Lo spazio di frenata a questa velocità. Sotto, si scala: è quello che fa
	# sembrare l'arrivo una fermata e non uno spegnimento.
	if to_goal < _current_speed * brake_time * 0.5 + arrive_distance:
		wanted = 0.0
	var rate := speed / (accel_time if wanted > _current_speed else brake_time)
	_current_speed = move_toward(_current_speed, wanted, rate * delta)
	var step := maxf(_current_speed, speed * 0.25) * delta

	if distance <= maxf(arrive_distance, step):
		global_position = _target
		if _path_index < _path.size() - 1:
			# Tappa intermedia: si prosegue senza fermarsi né avvisare nessuno.
			_path_index += 1
			_target = _path[_path_index]
			return
		stop()
		_settle_sprite(delta)
		arrived.emit()
		return

	velocity = direction * maxf(_current_speed, speed * 0.25)
	var before := global_position
	move_and_slide()

	# Guarda dalla parte in cui sta andando (la Y non ribalta nulla).
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0

	# Il saltello va a PASSI: si avanza di `stride` pixel, si fa un passo. Legato
	# al tempo invece che alla strada, un personaggio che rallenta continuerebbe
	# a sobbalzare alla stessa cadenza e sembrerebbe pattinare.
	_bob_time += global_position.distance_to(before) / stride * PI
	_sprite.offset.y = _sprite_rest_y - absf(sin(_bob_time)) * bob_height

# --- Attraversare ----------------------------------------------------------

## Sta per mettere piede sulla carreggiata, e sta passando qualcuno?
##
## Si guarda solo il passaggio dal marciapiede all'asfalto: una volta in mezzo
## alla strada non ci si ferma più per nessun motivo. Fermarsi lì sarebbe la cosa
## peggiore da fare — per il pedone e da guardare — e comunque le auto frenano
## per chi è sulla carreggiata (`car.gd`).
func _must_wait(direction: Vector2, delta: float) -> bool:
	if CityMap.on_road(global_position):
		return false
	var step := global_position + direction * maxf(speed * delta, 2.0)
	if not CityMap.on_road(step):
		return false
	# Dopo tanto fermo si passa comunque. Non dovrebbe mai servire — le auto non
	# frenano per chi aspetta sul marciapiede, quindi un buco arriva sempre — ma
	# un protagonista che non riparte più è un gioco rotto, e questa riga è
	# l'assicurazione contro una corsia storta o un mezzo fermo di traverso.
	if _waiting > MAX_WAIT:
		return false
	var exit := _far_kerb(step, direction)
	return not Traffic.crossing_clear(
		get_tree().get_nodes_in_group(Traffic.GROUP), global_position, exit, speed)

## Dove si torna sul marciapiede continuando dritti: il punto in cui la
## carreggiata finisce.
##
## Serve perché l'attesa ragiona su tutto l'attraversamento e non sul primo
## passo: quanto tempo si resta in mezzo alla strada dipende da quanto è larga
## quella strada lì, e agli incroci è il doppio.
func _far_kerb(from: Vector2, direction: Vector2) -> Vector2:
	var point := from
	for i in int(CROSSING_LOOKAHEAD / CROSSING_STEP):
		point += direction * CROSSING_STEP
		if not CityMap.on_road(point):
			return point
	return point

## Guarda a destra e a sinistra mentre aspetta. Costa una riga e racconta cosa
## sta facendo: fermo e basta sembrerebbe bloccato.
func _look_both_ways() -> void:
	_sprite.flip_h = fmod(_waiting, LOOK_INTERVAL * 2.0) > LOOK_INTERVAL

func _settle_sprite(delta: float) -> void:
	_bob_time = 0.0
	_sprite.offset.y = move_toward(_sprite.offset.y, _sprite_rest_y, 12.0 * delta)

## Sparisce dentro a un edificio: rimpicciolisce e svanisce. Lo sprite ha
## l'origine ai piedi, quindi sembra che venga risucchiato verso la porta.
## Restituisce il Tween così chi chiama può aspettarne la fine.
func vanish() -> Tween:
	stop()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.28)
	tween.tween_property(_sprite, "scale", Vector2(0.65, 0.65), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween
