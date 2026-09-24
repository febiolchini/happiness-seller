extends Control

## Il sospetto della polizia: una barra verticale sul lato sinistro dello
## schermo, verde quando è bassa e rossa quando è alta.
##
## Legge `SaveData.heat` (0-100), l'attenzione che c'era già — sale vendendo in
## strada e scende ogni notte (vedi `Economy`). Come deve salire e scendere
## d'ora in poi è ancora da decidere; la barra mostra quel numero e basta, e
## non cambierà quando cambieranno le regole.
##
## Segnaposto disegnato da codice come il badge del prestigio: con l'HUD vero
## si rimpiazza `_draw()`.

const BAR_SIZE := Vector2(8, 120)
const TRACK := Color(0.0, 0.0, 0.0, 0.45)
const EDGE := Color(0.05, 0.05, 0.06)
const LOW := Color(0.30, 0.78, 0.35)
const MID := Color(0.95, 0.78, 0.25)
const HIGH := Color(0.90, 0.22, 0.20)
## Quanto velocemente la barra insegue il valore vero: un salto netto di
## venti punti si legge meglio come una barra che sale.
const FOLLOW := 3.0

var _shown := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BAR_SIZE + Vector2(2, 2)
	if GameState.current != null:
		_shown = _target()

func _target() -> float:
	return clampf(GameState.current.heat / 100.0, 0.0, 1.0)

func _process(delta: float) -> void:
	if GameState.current == null:
		return
	var target := _target()
	if not is_equal_approx(target, _shown):
		_shown = move_toward(_shown, target, delta * FOLLOW * maxf(0.05, absf(target - _shown)))
		queue_redraw()

## Verde, giallo, rosso: il colore dice quanto preoccuparsi prima ancora che si
## guardi quanto è piena.
func color_for(value: float) -> Color:
	if value < 0.5:
		return LOW.lerp(MID, value * 2.0)
	return MID.lerp(HIGH, (value - 0.5) * 2.0)

func _draw() -> void:
	var bar := Rect2(Vector2(1, 1), BAR_SIZE)
	draw_rect(bar.grow(1.0), EDGE, true)
	draw_rect(bar, TRACK, true)
	var h := BAR_SIZE.y * _shown
	if h > 0.0:
		# Si riempie dal basso.
		draw_rect(Rect2(bar.position.x, bar.end.y - h, BAR_SIZE.x, h), color_for(_shown), true)
	# Tacche ogni quarto, per leggere a che punto si è senza numeri.
	for i in range(1, 4):
		var y := bar.end.y - BAR_SIZE.y * i / 4.0
		draw_line(Vector2(bar.position.x, y), Vector2(bar.position.x + 3, y), EDGE, 1.0)
