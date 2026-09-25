extends Control

## Il prestigio nell'HUD, a sinistra della sveglia: il nome del livello e sotto
## la barra che si riempie coi punti.
##
## Compare solo quando l'organizzazione ha un nome (`Prestige.active()`): prima
## non c'è niente da misurare. È un segnaposto disegnato da codice — rettangolo
## e scritta — in attesa della grafica vera dell'HUD; chi la farà deve solo
## rimpiazzare `_draw()`, i conti stanno in `Prestige`.

const BAR_SIZE := Vector2(96, 7)
const FILL := Color(0.96, 0.78, 0.30)
const TRACK := Color(0.0, 0.0, 0.0, 0.45)
const EDGE := Color(0.05, 0.05, 0.06)
const TEXT := Color(0.98, 0.95, 0.86)

var _level := ""
var _progress := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR_SIZE.x, 30)

func _process(_delta: float) -> void:
	var data := GameState.current
	visible = Prestige.active(data)
	if not visible:
		return
	var level := tr(Prestige.level_name(data))
	var progress := Prestige.progress(data)
	if level != _level or not is_equal_approx(progress, _progress):
		_level = level
		_progress = progress
		queue_redraw()

func _draw() -> void:
	# Pennello (il nome di un livello è sempre di sole parole) con l'ombra già
	# dentro al disegno, Nunito con l'ombra dura disegnata a mano se no — stessa
	# scelta di `npc.gd::_draw_name()` e per lo stesso motivo.
	var brush := UiTheme.can_brush(_level)
	var font: Font = UiTheme.menu() if brush else UiTheme.body()
	var font_size := 15 if brush else 12
	var y_bar := size.y - BAR_SIZE.y - 2.0
	var x0 := size.x - BAR_SIZE.x
	# Il livello, allineato a destra sopra alla barra.
	var text_w := font.get_string_size(_level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(size.x - text_w, y_bar - 5.0)
	if not brush:
		draw_string(font, at + Vector2(1, 1), _level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(0, 0, 0, 0.7))
	draw_string(font, at, _level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT)
	var bar := Rect2(Vector2(x0, y_bar), BAR_SIZE)
	draw_rect(bar.grow(1.0), EDGE, true)
	draw_rect(bar, TRACK, true)
	if _progress > 0.0:
		draw_rect(Rect2(bar.position, Vector2(BAR_SIZE.x * _progress, BAR_SIZE.y)), FILL, true)
