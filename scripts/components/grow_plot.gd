extends Button

## Un vaso del seminterrato: segnaposto disegnato a mano, cliccabile.
##
## È un `Button` perché la parte difficile di un oggetto cliccabile in una
## stanza è il click, non il disegno: così hover e pressione li gestisce Godot e
## qui resta solo il `_draw()`. Quando arriverà la pixel art il disegno diventa
## una texture e il resto non cambia.
##
## ## Un click fa la cosa giusta
##
## Non c'è un menu di azioni: il vaso capisce da solo cos'è sensato fare adesso
## (piantare, annaffiare, raccogliere) e lo fa. In un gestionale si finisce a
## cliccare gli stessi vasi centinaia di volte, e ogni finestra in mezzo è un
## dazio da pagare ogni volta.
##
## Lo stato vero sta in `GameState.current.plots[index]`: questo nodo non tiene
## niente di suo, legge e disegna. Vale anche fra due partite diverse.

## Quale vaso di `SaveData.plots` rappresenta.
@export var index := 0

## Ogni quanto ricontrollare lo stato. La crescita dipende dall'orologio di
## gioco, non dai frame: non serve rifare il disegno sessanta volte al secondo.
const REFRESH_INTERVAL := 0.25

const POT := Color(0.482, 0.286, 0.212)
const POT_RIM := Color(0.565, 0.345, 0.259)
const SOIL := Color(0.212, 0.161, 0.129)
const STEM := Color(0.290, 0.451, 0.239)
const LEAF := Color(0.353, 0.549, 0.286)
const LEAF_READY := Color(0.475, 0.686, 0.325)
const BUD := Color(0.678, 0.612, 0.310)
## Un posto libero sul tavolo, non una lastra grigia: il riempimento resta
## appena accennato, altrimenti tre vasi non ancora comprati coprono metà del
## fondale e sembrano un errore di disegno.
const LOCKED := Color(0.259, 0.251, 0.271, 0.28)
const LOCKED_LINE := Color(0.478, 0.459, 0.443, 0.60)
const WATER := Color(0.400, 0.706, 0.902)
const READY_GLOW := Color(1.0, 0.878, 0.353)
const LABEL := Color(0.878, 0.898, 0.851, 0.85)
const BAR_BG := Color(0, 0, 0, 0.45)
const LABEL_SIZE := 8

var _elapsed := 0.0
var _blink := 0.0

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	_elapsed += delta
	_blink += delta
	if _elapsed < REFRESH_INTERVAL:
		return
	_elapsed = 0.0
	var plot := _plot()
	if not plot.is_empty():
		Grow.sync(plot, GameState.total_hours())
	queue_redraw()

# --- Stato -----------------------------------------------------------------

func _plot() -> Dictionary:
	if GameState.current == null:
		return {}
	return GameState.current.plot(index)

func _is_locked() -> bool:
	return GameState.current == null or index >= GameState.current.plot_slots

# --- Il click --------------------------------------------------------------

func _on_pressed() -> void:
	if GameState.current == null:
		return
	if _is_locked():
		var cost := Economy.next_plot_cost(GameState.current)
		if cost < 0:
			GameState.notify("NO ROOM LEFT DOWN HERE")
		else:
			GameState.notify("USE THE PC TO OPEN THIS POT")
		return

	var now := GameState.total_hours()
	var plot := _plot()
	Grow.sync(plot, now)

	if Grow.is_empty(plot):
		_plant(plot, now)
	elif Grow.is_ready(plot, now):
		_harvest(plot, now)
	elif Grow.is_thirsty(plot, now):
		Grow.water(plot, now)
		GameState.notify("WATERED")
	else:
		GameState.notify("%s  -  %s LEFT" % [
			Grow.stage_name(plot, now), _format_hours(Grow.hours_left(plot, now))])
	queue_redraw()

func _plant(plot: Dictionary, now: float) -> void:
	var data := GameState.current
	var item := Economy.seed_item(Economy.DEFAULT_STRAIN)
	if data.get_item(item) <= 0:
		GameState.notify("NO SEEDS  -  ASK MILO AT THE CLINIC")
		return
	data.add_item(item, -1)
	Grow.plant(plot, Economy.DEFAULT_STRAIN, now)
	GameState.notify("PLANTED")

func _harvest(plot: Dictionary, now: float) -> void:
	var grams := Grow.harvest(plot, now)
	if grams <= 0:
		return
	var data := GameState.current
	data.add_item(Economy.PRODUCT, grams)
	data.bump_stat(Economy.STAT_GRAMS_HARVESTED, grams)
	data.bump_stat(Economy.STAT_PLANTS_GROWN)
	GameState.notify("+%d G HARVESTED" % grams)

# --- Disegno segnaposto ----------------------------------------------------

func _draw() -> void:
	if _is_locked():
		_draw_locked()
		return

	var now := GameState.total_hours()
	var plot := _plot()
	var body := Rect2(Vector2.ZERO, size)

	if is_hovered():
		draw_rect(body, Color(1, 0.85, 0.1, 0.14), true)
	_draw_pot(body)

	if Grow.is_empty(plot):
		_draw_caption(body, "EMPTY", LABEL)
		return

	var progress := clampf(Grow.progress(plot, now), 0.0, 1.0)
	var ready := Grow.is_ready(plot, now)
	_draw_plant(body, progress, ready)
	_draw_progress_bar(body, progress, ready)

	if ready:
		_draw_caption(body, "READY  %d G" % Grow.yield_grams(plot), READY_GLOW)
		_draw_pulse(body, READY_GLOW)
	else:
		_draw_caption(body, Grow.stage_name(plot, now), LABEL)
	if Grow.is_thirsty(plot, now):
		_draw_droplet(body)

func _draw_pot(body: Rect2) -> void:
	var bottom := body.end.y - 2.0
	var width := body.size.x * 0.46
	var center := body.get_center().x
	# Tronco di cono: sopra più largo di sotto, come un vaso vero.
	draw_colored_polygon(PackedVector2Array([
		Vector2(center - width * 0.5, bottom - 16.0),
		Vector2(center + width * 0.5, bottom - 16.0),
		Vector2(center + width * 0.38, bottom),
		Vector2(center - width * 0.38, bottom),
	]), POT)
	draw_rect(Rect2(center - width * 0.54, bottom - 19.0, width * 1.08, 4.0), POT_RIM, true)
	draw_rect(Rect2(center - width * 0.46, bottom - 16.0, width * 0.92, 3.0), SOIL, true)

func _draw_plant(body: Rect2, progress: float, ready: bool) -> void:
	var bottom := body.end.y - 18.0
	var center := body.get_center().x
	# Altezza e numero di foglie crescono con l'avanzamento: è tutto quello che
	# serve per leggere lo stadio a colpo d'occhio, senza aprire nulla.
	var height := lerpf(5.0, body.size.y - 26.0, progress)
	var leaf_color := LEAF_READY if ready else LEAF
	draw_line(Vector2(center, bottom), Vector2(center, bottom - height), STEM, 2.0)

	var pairs := 1 + int(progress * 3.0)
	for i in pairs:
		var t := float(i + 1) / float(pairs + 1)
		var y := bottom - height * t
		var span := lerpf(4.0, body.size.x * 0.30, progress) * (1.0 - t * 0.35)
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(center, y),
				Vector2(center + span * side, y - 3.0),
				Vector2(center + span * side * 0.85, y + 3.0),
			]), leaf_color)

	# Le cime compaiono solo in fioritura: sono il segnale che si sta arrivando.
	if progress >= 0.55:
		var buds := 2 + int((progress - 0.55) * 6.0)
		for i in buds:
			var y := bottom - height * (0.45 + 0.5 * float(i) / float(maxi(1, buds - 1)))
			draw_circle(Vector2(center + (2.0 if i % 2 == 0 else -2.0), y), 2.2, BUD)

## Barra larga quanto il vaso, non quanto il riquadro: sul tavolo i vasi sono
## vicini e una barra a tutta larghezza sembra appoggiata al piano invece che
## appartenere alla pianta.
func _draw_progress_bar(body: Rect2, progress: float, ready: bool) -> void:
	var width := body.size.x * 0.5
	var bar := Rect2(body.get_center().x - width * 0.5, body.end.y - 4.0, width, 3.0)
	draw_rect(bar, BAR_BG, true)
	var fill := bar
	fill.size.x *= progress
	draw_rect(fill, READY_GLOW if ready else LEAF, true)

func _draw_locked() -> void:
	var body := Rect2(Vector2.ZERO, size)
	draw_rect(body, LOCKED, true)
	draw_rect(body, LOCKED_LINE, false, 1.0)
	# Tratteggio incrociato: dice "qui ci starebbe qualcosa" meglio di un vuoto.
	var step := 10.0
	var x := body.position.x - body.size.y
	while x < body.end.x:
		draw_line(
			Vector2(maxf(x, body.position.x), body.position.y + maxf(0.0, body.position.x - x)),
			Vector2(minf(x + body.size.y, body.end.x), body.position.y + minf(body.size.y, body.end.x - x)),
			LOCKED_LINE * Color(1, 1, 1, 0.35), 1.0)
		x += step
	_draw_caption(body, "LOCKED", LOCKED_LINE)

## Etichetta con l'ombra sotto: sul tavolo i vasi si sovrappongono, e senza
## un contorno scuro il nome dello stadio si perde dentro alle foglie della
## pianta che sta dietro.
func _draw_caption(body: Rect2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var at := Vector2(body.get_center().x - width * 0.5, body.position.y + 9.0)
	for offset in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_string(
			font, at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
			Color(0, 0, 0, 0.75))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)

## Goccia lampeggiante: la pianta ha sete e la resa sta scendendo adesso.
func _draw_droplet(body: Rect2) -> void:
	var color := WATER
	color.a = 0.55 + 0.45 * sin(_blink * 4.0)
	var at := Vector2(body.end.x - 9.0, body.position.y + 15.0)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -5), at + Vector2(4, 2), at + Vector2(0, 6), at + Vector2(-4, 2),
	]), color)

func _draw_pulse(body: Rect2, color: Color) -> void:
	var ring := color
	ring.a = 0.25 + 0.25 * sin(_blink * 3.0)
	draw_rect(body.grow(-1.0), ring, false, 1.0)

## "18.5" -> "18H", "0.6" -> "35M": in un tycoon interessa l'ordine di
## grandezza, non il decimale.
func _format_hours(hours: float) -> String:
	if hours >= 1.0:
		return "%dH" % int(roundf(hours))
	return "%dM" % maxi(1, int(roundf(hours * 60.0)))
