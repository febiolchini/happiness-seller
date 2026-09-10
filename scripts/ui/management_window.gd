extends Control

## Il gestionale, aperto dal PC in cantina: la schermata da cui si tiene
## d'occhio l'attività e si piazza la merce senza uscire di casa.
##
## Tre schede: OVERVIEW (come va), GROW (i vasi), MARKET (vendere).
##
## ## Come è costruita
##
## Il contenuto è creato dal codice, non dalla scena. In un gestionale le righe
## dipendono dalla partita — quanti vasi hai, quanti tagli di vendita ti puoi
## permettere — e sarebbero comunque da riempire a runtime; tenerle anche nella
## scena vorrebbe dire mantenere due volte la stessa lista.
##
## Le righe vengono **costruite una volta** per scheda e poi solo aggiornate:
## `_fields` e `_actions` tengono la Label o il Button insieme alla funzione che
## ne ricava il testo. È lo stesso schema dell'HUD, e serve a non ricreare i
## bottoni sotto al mouse mentre il giocatore ci sta cliccando sopra.
##
## Viene istanziata da `scripts/components/room_hotspot.gd` come figlia della
## scena corrente, quindi si chiude liberandosi (`queue_free()`): la stanza
## sotto non sa che esiste e non va avvisata.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")
const GAME_FONT := preload("res://assets/sprites/ui/alphabet.fnt")

const REFRESH_INTERVAL := 0.2
const CAPTION_COLOR := Color(0.68, 0.71, 0.65)
const VALUE_COLOR := Color(0.95, 0.94, 0.86)
const GOOD_COLOR := Color(0.65, 0.87, 0.48)
const WARN_COLOR := Color(0.95, 0.62, 0.35)

const TABS := ["OVERVIEW", "GROW", "MARKET"]

@onready var _tab_bar: HBoxContainer = $Window/Tabs
@onready var _content: VBoxContainer = $Window/Scroll/Content
@onready var _close_button: BaseButton = $Window/Close

var _tab := 0
var _tab_buttons: Array[Button] = []
## Righe di sola lettura: { "label": Label, "text": Callable, "color": Callable }
var _fields: Array = []
## Bottoni: { "button": Button, "text": Callable, "enabled": Callable }
var _actions: Array = []
var _elapsed := 0.0

func _ready() -> void:
	_close_button.pressed.connect(close)
	for i in TABS.size():
		var button := _make_button(TABS[i], GAME_FONT, 16)
		button.pressed.connect(_select_tab.bind(i))
		_tab_bar.add_child(button)
		_tab_buttons.append(button)
	_select_tab(0)

## Il tempo di gioco continua a scorrere col gestionale aperto — le piante
## crescono mentre si fanno i conti — quindi i valori vanno riletti, non solo
## ridisegnati quando si clicca.
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < REFRESH_INTERVAL:
		return
	_elapsed = 0.0
	_refresh()

## Esc chiude la finestra invece di arrivare alla stanza. Fuori dalle stanze Esc
## torna al menu (`city.gd`), qui deve fare il gesto più vicino: un passo
## indietro, non uscire dalla partita.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()

func close() -> void:
	queue_free()

# --- Schede ----------------------------------------------------------------

func _select_tab(index: int) -> void:
	_tab = index
	for i in _tab_buttons.size():
		_tab_buttons[i].add_theme_color_override(
			"font_color", Color(1, 0.86, 0.35) if i == index else CAPTION_COLOR)
	_build_tab()

func _build_tab() -> void:
	for child in _content.get_children():
		child.queue_free()
	_fields.clear()
	_actions.clear()
	match _tab:
		0:
			_build_overview()
		1:
			_build_grow()
		2:
			_build_market()
	_refresh()

func _refresh() -> void:
	var data := GameState.current
	if data == null:
		return
	for field in _fields:
		var label: Label = field["label"]
		var text: String = (field["text"] as Callable).call(data)
		if label.text != text:
			label.text = text
		var color: Callable = field.get("color", Callable())
		if color.is_valid():
			label.add_theme_color_override("font_color", color.call(data))
	for action in _actions:
		var button: Button = action["button"]
		var text_source: Callable = action.get("text", Callable())
		if text_source.is_valid():
			var text: String = text_source.call(data)
			if button.text != text:
				button.text = text
		var enabled: Callable = action.get("enabled", Callable())
		if enabled.is_valid():
			button.disabled = not bool(enabled.call(data))

# --- OVERVIEW --------------------------------------------------------------

func _build_overview() -> void:
	var cash := func(d: SaveData) -> String: return UiFormat.money(d.cash)
	var day := func(d: SaveData) -> String: return "%d   %s" % [d.day, UiFormat.clock(d.time_of_day)]
	var stock := func(d: SaveData) -> String: return "%d g" % Economy.stock(d)
	var seeds := func(d: SaveData) -> String: return str(Economy.seeds_owned(d))
	var pots := func(d: SaveData) -> String: return "%d / %d" % [_pots_in_use(d), d.plot_slots]
	var ready := func(d: SaveData) -> String: return str(Grow.count_ready(d.plots, GameState.total_hours()))
	var ready_color := func(d: SaveData) -> Color:
		return GOOD_COLOR if Grow.count_ready(d.plots, GameState.total_hours()) > 0 else VALUE_COLOR
	var heat := func(d: SaveData) -> String: return "%s   %d" % [Economy.heat_label(d.heat), int(roundf(d.heat))]
	var heat_color := func(d: SaveData) -> Color: return WARN_COLOR if d.heat >= 35.0 else VALUE_COLOR
	var harvested := func(d: SaveData) -> String: return UiFormat.number(d.get_stat(Economy.STAT_GRAMS_HARVESTED))
	var sold := func(d: SaveData) -> String: return UiFormat.number(d.get_stat(Economy.STAT_GRAMS_SOLD))
	var earned := func(d: SaveData) -> String: return UiFormat.money(d.get_stat(Economy.STAT_EARNED))

	_add_field("CASH", cash)
	_add_field("DAY", day)
	_add_separator()
	_add_field("STOCK", stock)
	_add_field("SEEDS", seeds)
	_add_field("POTS IN USE", pots)
	_add_field("READY TO CUT", ready, ready_color)
	_add_separator()
	_add_field("ATTENTION", heat, heat_color)
	_add_separator()
	_add_field("GRAMS HARVESTED", harvested)
	_add_field("GRAMS SOLD", sold)
	_add_field("TOTAL EARNED", earned)

func _pots_in_use(data: SaveData) -> int:
	var used := 0
	for plot in data.plots:
		if not Grow.is_empty(plot):
			used += 1
	return used

# --- GROW ------------------------------------------------------------------

func _build_grow() -> void:
	for i in Economy.MAX_PLOTS:
		var slot := i
		var summary := func(d: SaveData) -> String: return _plot_summary(d, slot)
		var color := func(d: SaveData) -> Color: return _plot_color(d, slot)
		# Etichetta col font di sistema: "POT 3" contiene una cifra e
		# `alphabet.fnt` ha solo lettere.
		_add_field("POT %d" % (slot + 1), summary, color, false)

	_add_separator()

	var water_text := func(d: SaveData) -> String:
		return "WATER ALL  (%d thirsty)" % Grow.count_thirsty(d.plots, GameState.total_hours())
	var water_ready := func(d: SaveData) -> bool:
		return Grow.count_thirsty(d.plots, GameState.total_hours()) > 0
	_add_action(water_text, water_ready, _water_all)

	var cut_text := func(d: SaveData) -> String:
		return "HARVEST ALL  (%d ready)" % Grow.count_ready(d.plots, GameState.total_hours())
	var cut_ready := func(d: SaveData) -> bool:
		return Grow.count_ready(d.plots, GameState.total_hours()) > 0
	_add_action(cut_text, cut_ready, _harvest_all)

	var plot_text := func(d: SaveData) -> String:
		var cost := Economy.next_plot_cost(d)
		return "NO ROOM FOR MORE POTS" if cost < 0 else "OPEN NEW POT  -  %s" % UiFormat.money(cost)
	var plot_ready := func(d: SaveData) -> bool:
		var cost := Economy.next_plot_cost(d)
		return cost >= 0 and d.cash >= cost
	_add_action(plot_text, plot_ready, _buy_plot)

	_add_note("A plant yields about %d g. Water it or the yield drops." % int(
		Economy.strain(Economy.DEFAULT_STRAIN)["grams"]))
	var data := GameState.current
	if data != null and Economy.seeds_owned(data) <= 0:
		_add_note("Out of seeds. Milo works at the clinic downtown.")

func _plot_summary(data: SaveData, slot: int) -> String:
	if slot >= data.plot_slots:
		var cost := Economy.next_plot_cost(data)
		if slot == data.plot_slots and cost >= 0:
			return "locked  -  %s" % UiFormat.money(cost)
		return "locked"
	var plot := data.plot(slot)
	if Grow.is_empty(plot):
		return "empty"
	var now := GameState.total_hours()
	Grow.sync(plot, now)
	if Grow.is_ready(plot, now):
		return "READY  -  %d g" % Grow.yield_grams(plot)
	var text := "%s  %d%%  -  %s" % [
		Grow.stage_name(plot, now).to_lower(),
		int(roundf(Grow.progress(plot, now) * 100.0)),
		UiFormat.duration(Grow.hours_left(plot, now)),
	]
	if Grow.is_thirsty(plot, now):
		text += "  (dry)"
	return text

func _plot_color(data: SaveData, slot: int) -> Color:
	if slot >= data.plot_slots:
		return CAPTION_COLOR
	var plot := data.plot(slot)
	var now := GameState.total_hours()
	if Grow.is_ready(plot, now):
		return GOOD_COLOR
	if Grow.is_thirsty(plot, now):
		return WARN_COLOR
	return VALUE_COLOR

func _water_all() -> void:
	var count := Grow.water_all(GameState.current.plots, GameState.total_hours())
	if count > 0:
		GameState.notify("WATERED %d POTS" % count)
	_refresh()

func _harvest_all() -> void:
	var data := GameState.current
	var now := GameState.total_hours()
	var plants := Grow.count_ready(data.plots, now)
	var grams := Grow.harvest_all(data.plots, now)
	if grams <= 0:
		return
	data.add_item(Economy.PRODUCT, grams)
	data.bump_stat(Economy.STAT_GRAMS_HARVESTED, grams)
	data.bump_stat(Economy.STAT_PLANTS_GROWN, plants)
	GameState.notify("+%d G HARVESTED" % grams)
	_refresh()

func _buy_plot() -> void:
	if Economy.buy_plot(GameState.current):
		GameState.notify("NEW POT OPENED")
	_refresh()

# --- MARKET ----------------------------------------------------------------

func _build_market() -> void:
	var stock := func(d: SaveData) -> String: return "%d g" % Economy.stock(d)
	var wholesale := func(d: SaveData) -> String: return "%s / g" % UiFormat.money(Economy.wholesale_price(d))
	var street := func(d: SaveData) -> String: return "%s / g" % UiFormat.money(Economy.retail_price(d))
	var value := func(d: SaveData) -> String: return UiFormat.money(Economy.stock(d) * Economy.wholesale_price(d))

	_add_field("STOCK", stock)
	_add_field("WHOLESALE TODAY", wholesale)
	_add_field("STREET PRICE", street)
	_add_field("STOCK VALUE", value)
	_add_separator()

	# `amount` arriva da un array non tipizzato, quindi è un Variant: il tipo va
	# scritto, altrimenti `grams` non è inferibile e lo script non compila.
	for amount in [10, 50]:
		var grams: int = amount
		var text := func(d: SaveData) -> String:
			return "SELL %d G  -  %s" % [grams, UiFormat.money(grams * Economy.wholesale_price(d))]
		var enabled := func(d: SaveData) -> bool: return Economy.stock(d) >= grams
		var action := func() -> void: _sell(grams)
		_add_action(text, enabled, action)

	var all_text := func(d: SaveData) -> String:
		return "SELL EVERYTHING  -  %s" % UiFormat.money(Economy.stock(d) * Economy.wholesale_price(d))
	var all_enabled := func(d: SaveData) -> bool: return Economy.stock(d) > 0
	var all_action := func() -> void: _sell(Economy.stock(GameState.current))
	_add_action(all_text, all_enabled, all_action)

	_add_note("Wholesale is safe and does not raise attention. Selling to people on the street pays %d%% more, but one customer at a time." % int(roundf((Economy.RETAIL_MULTIPLIER - 1.0) * 100.0)))

func _sell(grams: int) -> void:
	var revenue := Economy.sell_wholesale(GameState.current, grams)
	if revenue > 0:
		GameState.notify("+%s  (%d G)" % [UiFormat.money(revenue), grams])
	_refresh()

# --- Costruzione delle righe ----------------------------------------------

## Riga "etichetta ......... valore". `pixel_caption` a false quando
## l'etichetta contiene cifre: il font del gioco ha solo lettere e spazio.
func _add_field(caption: String, text: Callable, color := Callable(), pixel_caption := true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", CAPTION_COLOR)
	if pixel_caption:
		name_label.add_theme_font_override("font", GAME_FONT)
		name_label.add_theme_font_size_override("font_size", 16)
	else:
		name_label.add_theme_font_size_override("font_size", 12)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", VALUE_COLOR)
	row.add_child(value_label)

	_content.add_child(row)
	_fields.append({"label": value_label, "text": text, "color": color})

func _add_action(text: Callable, enabled: Callable, action: Callable) -> void:
	var button := _make_button("", null, 13)
	button.pressed.connect(action)
	_content.add_child(button)
	_actions.append({"button": button, "text": text, "enabled": enabled})

func _add_separator() -> void:
	var rule := ColorRect.new()
	rule.color = Color(0.69, 0.54, 0.31, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(rule)

## Riga di spiegazione: è il posto dove dire al giocatore la regola che sta
## dietro ai numeri, senza un tutorial a parte.
func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.60, 0.63, 0.58))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(label)

func _make_button(text: String, font: Font, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.44, 0.42))
	button.set_script(BUTTON_SCRIPT)
	button.use_press_offset = false
	return button
