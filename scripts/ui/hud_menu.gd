extends Control

## Il menu dell'HUD: il tasto a tre righe in alto a sinistra, e quello che ci
## sta dentro — **com'è messa la produzione**.
##
## Quattro righe: la merce pronta, i semi in mano, quanti vendono e quanti
## coltivano. Sono le quattro cose che dicono se la macchina sta girando, e
## hanno in comune di essere tutte cose che **si vanno a controllare**: nessuna
## di loro cambia mentre si cammina per strada, e nessuna richiede di essere
## guardata di continuo.
##
## Per un giro qui dentro c'era anche la **cassa**, ed era l'intrusa: i soldi
## non sono una cosa che si controlla, sono la cosa che dice se quello che stai
## facendo sta funzionando. Sono usciti e sono andati in cima allo schermo, da
## soli. Vedi `money_badge.gd`.
##
## **Il pannello è un interruttore, non un tasto da tenere premuto**: si apre e
## resta aperto finché non lo si chiude. Chi vuole quei numeri sempre davanti se
## li tiene aperti, chi non li vuole ha uno schermo che è tutto città.
##
## ## Perché a sinistra
##
## A destra c'è già la sveglia, e sotto ci passano i messaggini. Il tasto sta
## nell'unico angolo in alto che è rimasto vuoto, che è anche quello in cui un
## menu si cerca per abitudine.

const STOCK_COLOR := Color(0.62, 0.85, 0.55)
## I semi: lo stesso verde della merce ma più spento, perché sono la stessa
## roba a due stadi diversi della sua vita.
const SEED_COLOR := Color(0.72, 0.82, 0.60)
## Le persone: un colore diverso dalla roba, perché leggendo le quattro righe di
## fila la domanda è "quanta merce" oppure "quanta gente", mai le due insieme.
const STAFF_COLOR := Color(0.78, 0.80, 0.86)
const LABEL_COLOR := Color(0.70, 0.73, 0.78)
## Le tre righe del tasto, e la X quando è aperto.
const BARS_COLOR := Color(0.88, 0.90, 0.92)
## L'ombra dura, la stessa di tutte le scritte dell'HUD: sotto al tasto può
## passarci un muro chiaro come l'asfalto, e senza uno stacco netto le tre righe
## ci si perdono dentro.
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)

## Il tasto: quanto è grande il bersaglio, e quanto sono lunghe le righe dentro.
const BUTTON := Vector2(18.0, 16.0)
const BAR := Vector2(14.0, 2.0)
const BAR_GAP := 5.0
## Dove comincia il pannello, sotto al tasto, e quanto è largo **come minimo**:
## oltre ci pensa il numero più lungo che ha dentro. Serve a non farlo ballare
## fra una riga e l'altra quando la cassa è a tre cifre.
const PANEL_TOP := 22.0
const PANEL_WIDTH := 104.0

## Le etichette col pennello dei menu (`UiTheme.menu()`), i valori col font di
## sistema: il pennello le cifre non ce le ha.
const LABEL_SIZE := UiTheme.MENU_SMALL
const VALUE_SIZE := 14

## Le righe del pannello, dall'alto in basso. Per aggiungerne una (i semi, i
## debiti, le proprietà) basta infilarla qui: etichetta, valore e aggiornamento
## a schermo vengono da soli.
##
## `text` riceve la partita corrente e restituisce la stringa già formattata.
var _rows := [
	{
		"label": "PC_STOCK",
		"color": STOCK_COLOR,
		"text": func(data: SaveData) -> String: return "%d g" % Economy.stock(data),
	},
	{
		"label": "PC_SEEDS",
		"color": SEED_COLOR,
		"text": func(data: SaveData) -> String: return str(Economy.seeds_owned(data)),
	},
	# I nomi dei ruoli sono quelli del PC (`Staff.ROLES`) e non due parole
	# scritte qui: nel gestionale si assume "SPACCIATORE", e trovarselo chiamato
	# in un altro modo nel menu vorrebbe dire due mestieri invece di uno.
	{
		"label": "STAFF_DEALER",
		"color": STAFF_COLOR,
		"text": func(data: SaveData) -> String: return str(Staff.count(data, "dealer")),
	},
	{
		"label": "STAFF_GROWER",
		"color": STAFF_COLOR,
		"text": func(data: SaveData) -> String: return str(Staff.count(data, "grower")),
	},
]

var _open := false
var _panel: PanelContainer = null
var _values: Array[Label] = []
var _labels: Array[Label] = []
## Ultimo valore scritto per ogni riga, per non riscrivere le Label a ogni
## fotogramma.
var _shown: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel()
	GameSettings.locale_changed.connect(_on_locale_changed)
	_apply_open()

func _process(_delta: float) -> void:
	if not _open:
		return
	var data := GameState.current
	if data == null:
		return
	for i in _rows.size():
		var text: String = (_rows[i]["text"] as Callable).call(data)
		if text != _shown[i]:
			_shown[i] = text
			_values[i].text = text

## Un click sul tasto apre e chiude. Il resto del pannello si mangia il click e
## basta: è un oggetto davanti alla scena, e un click che lo attraversa
## manderebbe il protagonista a camminare sotto al menu.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if Rect2(Vector2.ZERO, BUTTON).has_point(click.position):
		_toggle()

## Esc chiude il pannello invece di uscire dalla partita, come fa il telefono:
## chi ha appena aperto una cosa si aspetta che il primo Esc chiuda quella.
func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_toggle()

func _toggle() -> void:
	_open = not _open
	_apply_open()

func _apply_open() -> void:
	_panel.visible = _open
	if not _open:
		size = BUTTON
	else:
		# Davanti a tutto il resto dell'HUD. La barra dell'attenzione viene
		# aggiunta dopo di lui (`hud.gd`) e sta proprio sotto al tasto: senza,
		# il pannello aperto le finiva sotto e le etichette restavano tagliate
		# a sinistra ("TOCK", "EEDS").
		get_parent().move_child(self, -1)
		# **La misura si chiede al pannello, non si scrive.** Il pannello si
		# allarga col numero che ha dentro — "1.250.000 $" è metà più largo di
		# "4.820 $" — e il rettangolo di questo nodo è quello che si mangia i
		# click: se resta della misura scritta a mano, cliccare sulla parte di
		# pannello che avanza manda il protagonista a camminare sotto al menu.
		var wanted := _panel.get_combined_minimum_size()
		size = Vector2(maxf(BUTTON.x, wanted.x), PANEL_TOP + wanted.y)
	queue_redraw()
	if _open:
		_refresh_now()

## Riscrive tutto subito invece di aspettare il fotogramma dopo: aprendo il
## pannello i valori devono esserci già, non comparire un attimo dopo.
func _refresh_now() -> void:
	for i in _shown.size():
		_shown[i] = ""
	_process(0.0)

func _on_locale_changed(_locale: String) -> void:
	for i in _rows.size():
		_labels[i].text = tr(str(_rows[i]["label"]))
	_refresh_now()

# --- Il pannello ------------------------------------------------------------

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(0.0, PANEL_TOP)
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _box())
	add_child(_panel)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lines)

	for row: Dictionary in _rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(line)

		# Senza `UiTheme.add_hard_shadow()`: il pennello l'ombra ce l'ha gia'
		# dentro al disegno, e una seconda la farebbe sembrare scritta due volte.
		var label := Label.new()
		label.text = tr(str(row["label"]))
		UiTheme.dress_menu_text(label, LABEL_SIZE)
		label.add_theme_color_override("font_color", LABEL_COLOR)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		_labels.append(label)

		# Lo spazio che si allarga sta in mezzo: le etichette restano a sinistra
		# e i valori incolonnati a destra, che è l'unico modo di confrontarli a
		# colpo d'occhio quando le cifre cambiano di lunghezza.
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(gap)

		var value := UiTheme.label("", VALUE_SIZE, row["color"], UiTheme.W_BOLD)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiTheme.add_hard_shadow(value, SHADOW)
		line.add_child(value)
		_values.append(value)
		_shown.append("")

## Il fondo del pannello. È l'unico dell'HUD, e non contraddice il "niente
## fondo" del resto: quella regola vale per le cose che stanno lì sempre, mentre
## questo è un cassetto che si apre — un cassetto senza pareti non si legge come
## aperto.
func _box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.09, 0.11, 0.84)
	box.border_color = Color(1.0, 1.0, 1.0, 0.10)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 5
	box.content_margin_bottom = 6
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 1)
	return box

# --- Il tasto ---------------------------------------------------------------

## Tre righe da chiuso, una X da aperto. La X non è decorazione: il pannello
## sotto dice che c'è qualcosa di aperto, ma non dice **dove si clicca per
## chiuderlo**, e tre righe che non cambiano sembrano un tasto che non ha fatto
## niente.
func _draw() -> void:
	var middle := BUTTON * 0.5
	if _open:
		var arm := BAR.x * 0.5 - 2.0
		for offset in [Vector2.ONE, Vector2.ZERO]:
			var ink := SHADOW if offset != Vector2.ZERO else BARS_COLOR
			draw_line(middle + Vector2(-arm, -arm) + offset,
				middle + Vector2(arm, arm) + offset, ink, BAR.y)
			draw_line(middle + Vector2(arm, -arm) + offset,
				middle + Vector2(-arm, arm) + offset, ink, BAR.y)
		return
	var left := middle.x - BAR.x * 0.5
	var top := middle.y - (BAR.y * 3.0 + BAR_GAP * 2.0) * 0.5
	for i in 3:
		var at := Vector2(left, top + float(i) * (BAR.y + BAR_GAP))
		draw_rect(Rect2(at + Vector2.ONE, BAR), SHADOW, true)
		draw_rect(Rect2(at, BAR), BARS_COLOR, true)
