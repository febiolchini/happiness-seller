extends Node2D
class_name Npc

## Personaggio di strada segnaposto: cammina un percorso, si ferma alle tappe,
## e cliccandoci sopra ci si parla.
##
## L'origine del nodo è ai PIEDI, come per il protagonista e gli edifici: è
## quel punto che conta per l'Y-sort e per il click.
##
## Non è un `CharacterBody2D` di proposito. Non deve urtare niente — il
## percorso passa già sui marciapiedi — e undici corpi fisici che si spingono
## a vicenda costerebbero senza dare niente in cambio.
##
## Cosa succede parlandogli lo decide il RUOLO (vedi `NpcRoster`), e lo decide
## qui: `talk()` costruisce le battute e le scelte e le passa alla finestra di
## dialogo. La UI resta generica e non sa niente di semi e di grammi.

## Tutti gli NPC stanno in questo gruppo, così la mappa li interroga in blocco
## per capire su quale si è cliccato. Stessa idea di `EnterableBuilding.GROUP`.
const GROUP := "npc"

const CLICK_RECT := Rect2(-12, -46, 24, 48)
const SKIN := Color(0.85, 0.71, 0.58)
const HAIR := Color(0.24, 0.19, 0.16)

## Marcatore sopra la testa di chi ha qualcosa da offrire: senza, in una città
## con undici passanti non si capisce con chi vale la pena parlare.
const MARKER_SELLER := Color(0.55, 0.85, 0.45)
const MARKER_BUYER := Color(1.0, 0.85, 0.25)

var entry: Dictionary = {}
var npc_id := ""
var npc_name := ""
var role := NpcRoster.ROLE_WANDER

var _route: Array = []
var _index := 0
var _speed := 30.0
var _pause := 2.0
var _wait_left := 0.0
var _color := Color(0.5, 0.4, 0.35)
var _accent := Color(0.28, 0.28, 0.33)
var _facing := 1.0
var _bob := 0.0
var _out := true
## Fermo mentre gli si parla: continuare a camminare durante il dialogo
## lascerebbe il giocatore a parlare con la schiena di qualcuno.
var _busy := false

func _ready() -> void:
	add_to_group(GROUP)

func setup(data: Dictionary) -> void:
	entry = data
	npc_id = str(data["id"])
	npc_name = str(data["name"])
	role = str(data["role"])
	_route = data["route"]
	_speed = float(data.get("speed", 30.0))
	_pause = float(data.get("pause", 2.0))
	_color = data.get("color", _color)
	_accent = data.get("accent", _accent)
	name = npc_id
	# Non partono tutti dalla prima tappa, altrimenti chi condivide un percorso
	# cammina in fila indiana come una processione.
	_index = randi() % maxi(1, _route.size())
	position = _route[_index] if not _route.is_empty() else Vector2.ZERO
	_advance_target()

func _process(delta: float) -> void:
	_update_presence()
	if not _out or _busy or _route.is_empty():
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		_settle(delta)
		return

	var target: Vector2 = _route[_index]
	var to_target := target - position
	var step := _speed * delta
	if to_target.length() <= step:
		position = target
		_wait_left = _pause * randf_range(0.6, 1.6)
		_advance_target()
		return

	position += to_target.normalized() * step
	if absf(to_target.x) > 1.0:
		var facing := 1.0 if to_target.x > 0.0 else -1.0
		if facing != _facing:
			_facing = facing
			queue_redraw()
	_bob += delta * 9.0
	queue_redraw()

func _advance_target() -> void:
	if _route.size() > 1:
		_index = (_index + 1) % _route.size()

func _settle(_delta: float) -> void:
	if not is_equal_approx(_bob, 0.0):
		_bob = 0.0
		queue_redraw()

## Fuori dalla sua fascia oraria il personaggio non c'è: di notte i marciapiedi
## si svuotano e restano solo le pattuglie. È il modo più economico di far
## sentire che l'orologio di gioco conta.
func _update_presence() -> void:
	if GameState.current == null:
		return
	var out := NpcRoster.is_out_at(entry, GameState.current.time_of_day)
	if out == _out:
		return
	_out = out
	visible = out

# --- Click -----------------------------------------------------------------

func contains_point(global_point: Vector2) -> bool:
	if not _out:
		return false
	return CLICK_RECT.has_point(to_local(global_point))

## Punto in cui si va a finire per parlargli: di fianco, non addosso.
func approach_point() -> Vector2:
	return global_position + Vector2(-26.0 * _facing, 0.0)

## Piccolo saltello quando lo si clicca: dice che il click è stato registrato
## anche se il protagonista deve ancora arrivare.
func acknowledge() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(0.94, 1.06), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK)

# --- Dialogo ---------------------------------------------------------------

## Costruisce e apre la conversazione. Prende la finestra invece di crearsela:
## ce n'è una sola nella City, e chi la possiede è la mappa.
func talk(dialogue: Node) -> void:
	_busy = true
	if not dialogue.closed.is_connected(_on_dialogue_closed):
		dialogue.closed.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)
	_face_toward_player()
	match role:
		NpcRoster.ROLE_SEEDS:
			_talk_seeds(dialogue)
		NpcRoster.ROLE_BUYER:
			_talk_buyer(dialogue)
		NpcRoster.ROLE_COP:
			_talk_cop(dialogue)
		_:
			dialogue.open(npc_name, NpcRoster.random_line(entry), [])

func _on_dialogue_closed() -> void:
	_busy = false

func _face_toward_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var facing := 1.0 if player.global_position.x > global_position.x else -1.0
	if facing != _facing:
		_facing = facing
		queue_redraw()

## L'amico della clinica: è da lui che arrivano i semi.
func _talk_seeds(dialogue: Node) -> void:
	var data := GameState.current
	var price := Economy.seed_price(Economy.DEFAULT_STRAIN)
	var owned := Economy.seeds_owned(data)
	var body := "Straight out of the clinic stock. %d $ a seed, and you never got them from me.\n\nYou have %d seed(s). Cash: %d $." % [price, owned, data.cash]
	var choices: Array = []
	for count in [1, 3, 5]:
		choices.append({
			"label": "BUY %d  -  %d $" % [count, price * count],
			"enabled": data.cash >= price * count,
			"keep_open": true,
			"action": func() -> void: _buy_seeds(dialogue, count),
		})
	choices.append({"label": "MAYBE LATER", "action": func() -> void: pass})
	dialogue.open(npc_name, body, choices)

func _buy_seeds(dialogue: Node, count: int) -> void:
	if Economy.buy_seeds(GameState.current, count):
		GameState.notify("+%d SEEDS" % count)
	# Si riapre invece di chiudere: comprare tre volte di fila non deve
	# costare tre giri di camminata fino alla clinica.
	_talk_seeds(dialogue)

## Cliente di strada: paga più del prezzo all'ingrosso, ma ogni grammo che
## passa di mano in pubblico alza l'attenzione addosso al giocatore.
func _talk_buyer(dialogue: Node) -> void:
	var data := GameState.current
	var wanted := Economy.street_demand_left(data, npc_id)
	var price := Economy.retail_price(data)
	var stock := Economy.stock(data)

	if wanted <= 0:
		dialogue.open(npc_name, "I am good for today. Come find me tomorrow.", [])
		return
	if stock <= 0:
		dialogue.open(npc_name, "You are empty handed. I need %d g, whenever you sort yourself out." % wanted, [])
		return

	var body := "I can take %d g today, %d $ a gram.\n\nYou are carrying %d g." % [wanted, price, stock]
	var choices: Array = []
	for amount in _sale_steps(mini(wanted, stock)):
		choices.append({
			"label": "SELL %d G  -  %d $" % [amount, amount * price],
			"keep_open": true,
			"action": func() -> void: _sell_to(dialogue, amount),
		})
	choices.append({"label": "NOT NOW", "action": func() -> void: pass})
	dialogue.open(npc_name, body, choices)

## Tagli di vendita sensati per la quantità in gioco: pochi bottoni, e sempre
## uno che svuota le tasche in un colpo.
func _sale_steps(most: int) -> Array:
	var steps: Array = []
	for amount in [5, 10]:
		if amount < most:
			steps.append(amount)
	steps.append(most)
	return steps

func _sell_to(dialogue: Node, grams: int) -> void:
	var revenue := Economy.sell_street(GameState.current, npc_id, grams)
	if revenue > 0:
		GameState.notify("+%d $  (%d G)" % [revenue, grams])
	_talk_buyer(dialogue)

## La polizia: per ora non fa niente, ma dice a che punto sei. È il gancio
## pronto per le retate.
func _talk_cop(dialogue: Node) -> void:
	var heat := GameState.current.heat
	var body := "Move along."
	if heat >= 60.0:
		body = "We know what you are doing down in the Flats. We are just waiting to prove it."
	elif heat >= 30.0:
		body = "Funny. People keep mentioning your name lately."
	elif heat >= 15.0:
		body = "New face. I remember faces."
	dialogue.open(npc_name, body, [])

# --- Disegno segnaposto ----------------------------------------------------

func _draw() -> void:
	var hop := -absf(sin(_bob)) * 1.5
	draw_colored_polygon(_ellipse(Vector2(1, -1), Vector2(10, 4)), Color(0, 0, 0, 0.28))
	# Gambe, torso, testa: tre rettangoli e un cerchio, dal basso verso l'alto.
	draw_rect(Rect2(-7, -16 + hop, 14, 16), _accent, true)
	draw_rect(Rect2(-9, -34 + hop, 18, 19), _color, true)
	draw_rect(Rect2(-9, -34 + hop, 18, 3), _color.lightened(0.2), true)
	draw_circle(Vector2(_facing * 1.0, -40 + hop), 6.5, SKIN)
	draw_circle(Vector2(_facing * 1.0, -42.5 + hop), 6.0, HAIR)
	# Naso: basta un pixel per capire da che parte guarda.
	draw_rect(Rect2(_facing * 6.0 - 1.0, -41 + hop, 2, 2), SKIN, true)
	_draw_marker(hop)
	_draw_name()

func _draw_marker(hop: float) -> void:
	var color := Color.TRANSPARENT
	if role == NpcRoster.ROLE_SEEDS:
		color = MARKER_SELLER
	elif role == NpcRoster.ROLE_BUYER:
		color = MARKER_BUYER
	if color.a <= 0.0:
		return
	var tip := Vector2(0, -58 + hop)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(0, -5), tip + Vector2(5, 0), tip + Vector2(0, 5), tip + Vector2(-5, 0),
	]), color)

func _draw_name() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var width := font.get_string_size(npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(
		font, Vector2(-width * 0.5, -66), npc_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.94, 0.95, 0.92, 0.75))

func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points
