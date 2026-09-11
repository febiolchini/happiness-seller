extends Control

## La lampada rossa appesa sopra ai vasi: segnaposto disegnato a mano, come
## tutto il resto della cantina.
##
## Non è cliccabile e non ha logica sua — è un `Control` e non un `Button`
## proprio per questo: le lampade si comprano dal negozio online del PC, e qui
## si vede solo se ci sono. `lamp_set` è quale set di lampade rappresenta: la prima
## si accende col primo acquisto, la seconda col secondo e così via, così il
## seminterrato si riempie man mano che l'attività cresce invece di passare da
## buio a illuminato in un colpo solo.
##
## Spenta resta comunque disegnata, in grigio e appena visibile: dice "qui ci
## andrebbe una lampada", che è il modo in cui un gestionale fa vedere al
## giocatore la roba che non ha ancora comprato.
##
## Quando arriverà la pixel art il `_draw()` diventa una texture e il resto —
## chi decide se è accesa, e il cono di luce sui vasi — non cambia.

## Quale set di lampade del negozio accende questa (0 = il primo acquisto).
## Non si chiama `set` perché quello è già un metodo di `Object`.
@export var lamp_set := 0
## Mezza ampiezza del cono di luce, in pixel, all'altezza dei vasi.
@export var beam_spread := 26.0
## Quanto in basso arriva il cono. Va portato fino ai vasi sotto la lampada:
## è quello che collega le due cose a colpo d'occhio.
@export var beam_length := 74.0

const REFRESH_INTERVAL := 0.4

const BODY := Color(0.231, 0.239, 0.271)
const BODY_RIM := Color(0.333, 0.345, 0.388)
const CORD := Color(0.161, 0.169, 0.196)
const TUBE_ON := Color(1.0, 0.298, 0.310)
const TUBE_OFF := Color(0.278, 0.267, 0.290)
const GLOW := Color(1.0, 0.188, 0.220)
const OFF_TINT := Color(1, 1, 1, 0.35)

var _lit := false
var _elapsed := 0.0
var _flicker := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lit = _should_be_lit()

func _process(delta: float) -> void:
	_flicker += delta
	_elapsed += delta
	if _elapsed < REFRESH_INTERVAL:
		# Accesa il disegno va rifatto comunque: il cono di luce respira.
		if _lit:
			queue_redraw()
		return
	_elapsed = 0.0
	var lit := _should_be_lit()
	if lit != _lit:
		_lit = lit
	queue_redraw()

## Le lampade comprate si accendono dalla prima all'ultima.
func _should_be_lit() -> bool:
	return Shop.owned(GameState.current, "lamps") > lamp_set

# --- Disegno segnaposto ----------------------------------------------------

func _draw() -> void:
	var center := size.x * 0.5
	# Il cono va sotto al corpo della lampada, quindi si disegna per primo.
	if _lit:
		_draw_beam(center)
	_draw_fixture(center)

## Cono morbido: quattro strati sempre più larghi e sempre più trasparenti.
## Costa quattro poligoni e a 640x360 rende meglio di uno shader.
func _draw_beam(center: float) -> void:
	var top := 22.0
	var pulse := 0.88 + 0.12 * sin(_flicker * 1.7)
	for i in 4:
		var t := float(i + 1) / 4.0
		var glow := GLOW
		glow.a = 0.16 * (1.0 - t * 0.55) * pulse
		draw_colored_polygon(PackedVector2Array([
			Vector2(center - 7.0, top),
			Vector2(center + 7.0, top),
			Vector2(center + beam_spread * t, top + beam_length * t),
			Vector2(center - beam_spread * t, top + beam_length * t),
		]), glow)

func _draw_fixture(center: float) -> void:
	var tint := Color.WHITE if _lit else OFF_TINT
	# Il filo che la tiene appesa al soffitto: senza, la lampada galleggia.
	draw_line(Vector2(center - 12.0, 0.0), Vector2(center - 12.0, 6.0), CORD * tint, 1.0)
	draw_line(Vector2(center + 12.0, 0.0), Vector2(center + 12.0, 6.0), CORD * tint, 1.0)

	# Riflettore: trapezio rovesciato, largo sotto.
	draw_colored_polygon(PackedVector2Array([
		Vector2(center - 20.0, 6.0),
		Vector2(center + 20.0, 6.0),
		Vector2(center + 26.0, 20.0),
		Vector2(center - 26.0, 20.0),
	]), BODY * tint)
	draw_line(Vector2(center - 20.0, 6.0), Vector2(center + 20.0, 6.0), BODY_RIM * tint, 1.0)

	# I due tubi. Accesi hanno un alone attaccato, che è quello che si legge da
	# lontano molto più del colore del tubo in sé.
	var tube := TUBE_ON if _lit else TUBE_OFF
	for offset in [-9.0, 9.0]:
		var bar := Rect2(center + offset - 3.5, 18.0, 7.0, 4.0)
		if _lit:
			var halo := GLOW
			halo.a = 0.35
			draw_rect(bar.grow(2.0), halo, true)
		draw_rect(bar, tube, true)
