extends CharacterBody2D

## Protagonista. Per ora è un segnaposto: uno Sprite2D con un PNG provvisorio,
## che verrà sostituito da un AnimatedSprite2D con le animazioni vere.
##
## L'origine del nodo è ai PIEDI del personaggio: è quel punto a terra che conta
## sia per l'Y-sort sia per il click-to-move.

## Velocità di camminata in pixel al secondo.
@export var speed := 90.0
## Velocità quando la meta è lontana. La città è larga più di cinquemila pixel:
## attraversarla tutta a passo d'uomo sarebbe un minuto e mezzo di niente.
@export var run_speed := 190.0
## Oltre questa distanza dalla meta si corre. Sotto, si torna a camminare: così
## l'ultimo tratto — quello in cui si mira a una porta o a una persona — resta
## preciso, e il rallentamento in arrivo si legge come una decelerazione.
@export var run_distance := 320.0
## Sotto questa distanza dal bersaglio il personaggio ci si incolla e si ferma.
@export var arrive_distance := 1.5
## Ampiezza del saltello durante il cammino: sostituto temporaneo dell'animazione.
@export var bob_height := 1.0
@export var bob_speed := 9.0

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

## Gruppo con cui gli altri ritrovano il protagonista senza sapere dove sta
## nell'albero: lo usano gli NPC per girarsi verso di lui.
const GROUP := "player"

func _ready() -> void:
	add_to_group(GROUP)
	_target = global_position
	_sprite_rest_y = _sprite.offset.y

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
	velocity = Vector2.ZERO

func is_moving() -> bool:
	return _moving

func _physics_process(delta: float) -> void:
	if not _moving:
		velocity = Vector2.ZERO
		_settle_sprite(delta)
		return

	var to_target := _target - global_position
	var distance := to_target.length()
	# Si corre o si cammina in base a quanto manca alla META, non alla prossima
	# svolta: altrimenti si rallenterebbe a ogni angolo di un tragitto lungo.
	var to_goal := global_position.distance_to(_path[_path.size() - 1])
	var current_speed := run_speed if to_goal > run_distance else speed

	if distance <= maxf(arrive_distance, current_speed * delta):
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

	velocity = to_target.normalized() * current_speed
	move_and_slide()

	# Guarda dalla parte in cui sta andando (la Y non ribalta nulla).
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0

	# Il saltello segue la velocità: correndo il passo è più fitto, e si vede
	# che sta correndo anche senza un'animazione diversa.
	_bob_time += delta * bob_speed * (current_speed / speed)
	_sprite.offset.y = _sprite_rest_y - absf(sin(_bob_time)) * bob_height

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
