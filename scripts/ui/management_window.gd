extends CanvasLayer

## Il gestionale, aperto dal PC in cantina: la schermata da cui si tiene
## d'occhio l'attività e si piazza la merce senza uscire di casa.
##
## Schede: OVERVIEW (come va), GROW (i vasi), SHOP (il negozio online), MARKET
## (vendere) e, finito il prologo, STAFF (il personale).
##
## L'elenco delle schede e' calcolato e non fisso: STAFF compare solo quando il
## cugino si e' fatto vivo (vedi `GameState._check_prologue()`). Una scheda
## sempre presente ma spenta direbbe al giocatore che c'e' qualcosa che non puo'
## ancora avere, e in un gestionale che si apre un pezzo per volta la sorpresa
## vale piu' dell'anticipazione.
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
##
## ## Perché la radice è un CanvasLayer e non un Control
##
## Era un `Control`, e quindi finiva sulla **stessa tela della stanza**. Lì
## sopra c'è un `CanvasModulate` che tinge tutto col colore dell'ora (vedi
## `room.gd` e `atmosphere.gd`): il gestionale si scuriva di notte e virava
## all'arancione al tramonto, come se il monitor prendesse luce dalla finestra.
## Un `CanvasModulate` non attraversa le tele, quindi basta stare su una tela
## propria — che è già quello che fanno HUD, telefono, dialoghi e la finestra
## dell'agenzia.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")
## Lo sportello del grossista dei semi. È lo stesso file che apre l'edificio in
## città: vedi `_send_driver()`.
const SEED_WINDOW := "res://scenes/ui/SeedWholesaleWindow.tscn"

const REFRESH_INTERVAL := 0.2
## I colori dei dati vengono da `UiTheme` come tutto il resto. Restano degli
## alias perche' le funzioni che costruiscono le schede li nominano una
## trentina di volte, e `VALUE_COLOR` dice cosa e' meglio di `UiTheme.INK`.
const CAPTION_COLOR := UiTheme.INK_SOFT
const VALUE_COLOR := UiTheme.INK
const GOOD_COLOR := UiTheme.GOOD
const WARN_COLOR := UiTheme.WARN

## Le schede sono identificate dalla loro CHIAVE di traduzione: e' quella che
## finisce nel testo del bottone (che Godot traduce da solo) ed e' anche il
## nome con cui `_build_tab()` riconosce la scheda, senza un secondo elenco da
## tenere allineato.
const TAB_OVERVIEW := "PC_TAB_OVERVIEW"
const TAB_GROW := "PC_TAB_GROW"
const TAB_SHOP := "PC_TAB_SHOP"
const TAB_MARKET := "PC_TAB_MARKET"
const TAB_STAFF := "PC_TAB_STAFF"

## Schede sempre presenti, nell'ordine in cui compaiono.
const BASE_TABS := [TAB_OVERVIEW, TAB_GROW, TAB_SHOP, TAB_MARKET]

@onready var _panel: Panel = $Root/Window
@onready var _header: PanelContainer = $Root/Window/Layout/Header
@onready var _title: Label = $Root/Window/Layout/Header/Row/Title
@onready var _cash: Label = $Root/Window/Layout/Header/Row/Stats/Cash
@onready var _clock: Label = $Root/Window/Layout/Header/Row/Stats/Clock
@onready var _tab_bar: VBoxContainer = $Root/Window/Layout/Body/RailPad/Rail/Tabs
@onready var _content: VBoxContainer = $Root/Window/Layout/Body/ContentPad/Scroll/Content
@onready var _close_button: Button = $Root/Window/Layout/Body/RailPad/Rail/Close

## Quanti vasi c'erano quando la scheda GROW e' stata costruita: se cambiano,
## va rifatta. Vedi `_build_grow()`.
var _grow_slots := -1
var _tab := 0
var _tab_buttons: Array[Button] = []
## Nomi delle schede attualmente in barra, nell'ordine. `_tab` e' un indice in
## questa lista, non in `BASE_TABS`.
var _tabs: Array[String] = []
## Il personale era sbloccato all'ultima costruzione della barra? Serve ad
## accorgersi che il prologo si e' chiuso mentre la finestra era aperta.
var _staff_unlocked := false
## Il riquadro in cui finiscono le righe che si aggiungono adesso. Lo apre
## `_add_separator()` e lo chiude la scheda successiva: vedi `_card()`.
var _open_card: VBoxContainer = null
## Righe di sola lettura: { "label": Label, "text": Callable, "color": Callable }
var _fields: Array = []
## Bottoni: { "button": Button, "text": Callable, "enabled": Callable }
var _actions: Array = []
var _elapsed := 0.0
## Stato dell'appuntamento con Brian all'ultima costruzione della scheda.
## Serve ad accorgersi che è cambiato mentre la finestra era aperta.
var _seed_state := ""

func _ready() -> void:
	# L'HUD si nasconde finche' c'e' qualcuno in questo gruppo: questa finestra
	# e' un `Control` dentro alla scena, quindi su una tela piu' bassa di quella
	# dell'HUD, che senza il gruppo le comparirebbe sopra a meta' schermata.
	add_to_group(UiTheme.MODAL_GROUP)
	_dress()
	_close_button.pressed.connect(close)
	_build_tab_bar()
	_select_tab(0)

## Mette addosso alla scena la pelle di `UiTheme`. In scena ci sono solo i
## contenitori: tenere anche i colori nel `.tscn` vorrebbe dire cambiare la
## tavolozza in due posti ogni volta.
func _dress() -> void:
	# Velo e filetto stavano scritti nel `.tscn` con due colori a mano: portati
	# qui restano legati alla tavolozza come tutto il resto.
	($Root/Dimmer as ColorRect).color = UiTheme.DIMMER
	($Root/Window/Layout/Body/Divider as ColorRect).color = UiTheme.LINE
	_panel.add_theme_stylebox_override("panel", UiTheme.window_box())
	_header.add_theme_stylebox_override("panel", UiTheme.header_box())

	# Titolo, "chiudi", schede ed etichette fisse col pennello delle finestre
	# (`UiTheme.WINDOW_FILE`); cifre, prezzi e spiegazioni con Nunito.
	UiTheme.dress_window_text(_title, _title.text, UiTheme.WIN_TITLE, UiTheme.SIZE_TITLE)
	_title.add_theme_color_override("font_color", UiTheme.INK)

	_cash.add_theme_font_override("font", UiTheme.body(UiTheme.W_BOLD))
	_cash.add_theme_font_size_override("font_size", UiTheme.SIZE_BIG)
	_cash.add_theme_color_override("font_color", UiTheme.ACCENT_DARK)

	_clock.add_theme_font_override("font", UiTheme.body(UiTheme.W_MEDIUM))
	_clock.add_theme_font_size_override("font_size", UiTheme.SIZE_NOTE)
	_clock.add_theme_color_override("font_color", UiTheme.INK_SOFT)

	UiTheme.dress_button(_close_button, UiTheme.ghost_boxes(), UiTheme.INK_SOFT,
		UiTheme.SIZE_TAB)
	UiTheme.dress_window_text(_close_button, _close_button.text, UiTheme.WIN_BUTTON,
		UiTheme.SIZE_TAB)
	_close_button.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var scroll: ScrollContainer = $Root/Window/Layout/Body/ContentPad/Scroll
	UiTheme.dress_scrollbar(scroll.get_v_scroll_bar())

## Il personale e' assumibile? Si legge dal flag messo alla fine del prologo,
## non dai soldi che ci sono adesso: una volta sbloccato resta sbloccato anche
## se il giocatore si rigioca tutta la cassa.
func _has_staff() -> bool:
	var data := GameState.current
	return data != null and bool(data.get_flag("staff_unlocked", false))

func _build_tab_bar() -> void:
	for child in _tab_bar.get_children():
		_tab_bar.remove_child(child)
		child.queue_free()
	_tab_buttons.clear()
	_staff_unlocked = _has_staff()
	_tabs.assign(BASE_TABS)
	if _staff_unlocked:
		_tabs.append(TAB_STAFF)
	for i in _tabs.size():
		var button := Button.new()
		button.text = _tabs[i]
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.set_script(BUTTON_SCRIPT)
		button.use_press_offset = false
		button.pressed.connect(_select_tab.bind(i))
		_tab_bar.add_child(button)
		_tab_buttons.append(button)
	_tab = clampi(_tab, 0, _tabs.size() - 1)

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
		# `set_input_as_handled()` e non `accept_event()`: quello e' un metodo
		# di `Control`, e la radice di questa scena e' un `CanvasLayer` (vedi la
		# nota in cima). Senza, Esc arriva anche alla stanza sotto.
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	queue_free()

# --- Schede ----------------------------------------------------------------

## La scheda aperta si distingue per il RIQUADRO, non solo per il colore del
## testo: in una colonna di cinque voci un colore diverso si nota poco, una
## voce con lo sfondo di carta si legge come "sono qui" a colpo d'occhio.
func _select_tab(index: int) -> void:
	_tab = index
	var boxes := UiTheme.rail_boxes()
	for i in _tab_buttons.size():
		var button := _tab_buttons[i]
		var attiva := i == index
		UiTheme.dress_button(button, {
			"normal": boxes["active"] if attiva else boxes["normal"],
			"hover": boxes["active"] if attiva else boxes["hover"],
			"pressed": boxes["active"],
			"disabled": boxes["normal"],
		}, UiTheme.ACCENT_DARK if attiva else UiTheme.INK_SOFT, UiTheme.SIZE_TAB,
			UiTheme.W_BOLD if attiva else UiTheme.W_MEDIUM)
		UiTheme.dress_window_text(button, button.text, UiTheme.WIN_TAB, UiTheme.SIZE_TAB,
			UiTheme.W_BOLD if attiva else UiTheme.W_MEDIUM)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_build_tab()

func _build_tab() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_open_card = null
	_fields.clear()
	_actions.clear()
	match _tabs[_tab] if _tab < _tabs.size() else TAB_OVERVIEW:
		TAB_GROW:
			_build_grow()
		TAB_SHOP:
			_build_shop()
		TAB_MARKET:
			_build_market()
		TAB_STAFF:
			_build_staff()
		_:
			_build_overview()
	if GameState.current != null:
		_seed_state = SeedDeal.state(GameState.current)
		_grow_slots = GameState.current.plot_slots
	_refresh()

func _refresh() -> void:
	var data := GameState.current
	if data == null:
		return

	# La cassa e l'ora stanno in intestazione e non fra le righe: sono le due
	# cose che si guardano mentre si decide qualunque altra cosa, e cercarle
	# ogni volta in fondo alla scheda OVERVIEW era il motivo per cui si tornava
	# li' di continuo.
	var soldi := UiFormat.money(data.cash)
	if _cash.text != soldi:
		_cash.text = soldi
	var ora := "%s %d   %s" % [tr("HUD_DAY"), data.day,
		UiFormat.clock(data.time_of_day)]
	if _clock.text != ora:
		_clock.text = ora

	# L'orologio gira anche col gestionale aperto, quindi l'appuntamento con
	# Brian può passare da "aspetto" a "è lì" mentre si guarda la scheda. Le
	# righe di spiegazione sono scritte una volta sola alla costruzione, non a
	# ogni aggiornamento: quando lo stato cambia la scheda va rifatta.
	# Stessa cosa per il prologo: puo' chiudersi mentre si guarda il gestionale —
	# basta una vendita che porti la cassa oltre la soglia — e da quel momento in
	# barra c'e' una scheda in piu'.
	if _has_staff() != _staff_unlocked:
		_build_tab_bar()
		_select_tab(_tab)
		return
	if _tabs[_tab] == TAB_GROW and SeedDeal.state(data) != _seed_state:
		_build_tab()
		return
	# Comprando un vaso l'elenco si allunga di una riga, e le righe si scrivono
	# alla costruzione: senza questo il vaso appena comprato non comparirebbe
	# fino al prossimo giro di schede. Stessa ragione dell'appuntamento qui
	# sopra e della barra delle schede.
	if _tabs[_tab] == TAB_GROW and data.plot_slots != _grow_slots:
		_build_tab()
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
				# Il pennello solo se la nuova scritta e' di sole parole:
				# "ANNAFFIA TUTTO (3)" torna a Nunito, "LICENZIA" resta a pennello.
				UiTheme.dress_window_text(button, text, UiTheme.WIN_BUTTON,
					UiTheme.SIZE_VALUE, UiTheme.W_BOLD)
		var enabled: Callable = action.get("enabled", Callable())
		if enabled.is_valid():
			button.disabled = not bool(enabled.call(data))

# --- OVERVIEW --------------------------------------------------------------

func _build_overview() -> void:
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

	# Cassa e data non sono piu' righe: stanno in intestazione, sempre a vista
	# in tutte le schede. Ripeterle qui sarebbe scriverle due volte nella stessa
	# schermata.
	_add_field("PC_STOCK", stock)
	_add_field("PC_SEEDS", seeds)
	_add_field("PC_POTS_IN_USE", pots)
	_add_field("PC_READY_TO_CUT", ready, ready_color)
	_add_separator()
	_add_field("PC_ATTENTION", heat, heat_color)

	# L'organico compare solo quando c'e': una riga "STAFF 0" prima del prologo
	# annuncerebbe una parte di gioco che non e' ancora stata sbloccata.
	var crew := func(d: SaveData) -> String:
		return tr("PC_STAFF_SUMMARY") % [Staff.total(d), UiFormat.money(Staff.daily_wages(d))]
	var crew_color := func(d: SaveData) -> Color:
		return WARN_COLOR if Staff.daily_wages(d) > d.cash else VALUE_COLOR
	if Staff.total(GameState.current) > 0:
		_add_separator()
		_add_field("PC_STAFF", crew, crew_color)
	_add_separator()
	_add_field("PC_GRAMS_HARVESTED", harvested)
	_add_field("PC_GRAMS_SOLD", sold)
	_add_field("PC_TOTAL_EARNED", earned)

func _pots_in_use(data: SaveData) -> int:
	var used := 0
	for plot in data.plots:
		if not Grow.is_empty(plot):
			used += 1
	return used

# --- GROW ------------------------------------------------------------------

## L'elenco dei vasi, raggruppato per posto.
##
## Solo quelli **aperti**, e non tutti e diciotto: prima erano sei e mostrarli
## tutti voleva dire mostrare tre righe vuote sotto a tre piene. Con diciotto
## sarebbero dodici righe di niente sopra a quelle che contano, in una finestra
## che ne fa vedere una decina per volta.
##
## Il titolo del posto compare solo quando i posti aperti sono piu' d'uno: con
## la sola cantina, scriverci sopra "CANTINA" e' dire dove si e' a chi non puo'
## essere altrove.
func _build_grow() -> void:
	var data := GameState.current
	var sites := GrowSites.open_sites(data) if data != null else []
	for entry in sites:
		var site: Dictionary = entry
		var slots := GrowSites.slots_in(data, site)
		if slots <= 0:
			continue
		if sites.size() > 1:
			_add_field(
				GrowSites.site_name(site),
				func(d: SaveData) -> String: return tr("PC_SITE_POTS") % GrowSites.slots_in(d, site),
				Callable(), true)
		for i in slots:
			var slot := int(site["from"]) + i
			var summary := func(d: SaveData) -> String: return _plot_summary(d, slot)
			var color := func(d: SaveData) -> Color: return _plot_color(d, slot)
			# Etichetta col font di sistema: "POT 3" contiene una cifra e
			# `alphabet.fnt` ha solo lettere.
			_add_field(tr("PC_POT_N") % (slot + 1), summary, color, false)

	_add_separator()

	var water_text := func(d: SaveData) -> String:
		return tr("PC_WATER_ALL") % _thirsty(d)
	var water_ready := func(d: SaveData) -> bool:
		return _thirsty(d) > 0
	_add_action(water_text, water_ready, _water_all)

	var cut_text := func(d: SaveData) -> String:
		return tr("PC_HARVEST_ALL") % Grow.count_ready(d.plots, GameState.total_hours())
	var cut_ready := func(d: SaveData) -> bool:
		return Grow.count_ready(d.plots, GameState.total_hours()) > 0
	_add_action(cut_text, cut_ready, _harvest_all)

	var plot_text := func(d: SaveData) -> String:
		var cost := Economy.next_plot_cost(d)
		if cost >= 0:
			return tr("PC_OPEN_POT") % UiFormat.money(cost)
		return _no_pot_reason(d)
	var plot_ready := func(d: SaveData) -> bool:
		var cost := Economy.next_plot_cost(d)
		return cost >= 0 and d.cash >= cost
	_add_action(plot_text, plot_ready, _buy_plot)

	_add_separator()
	_build_seeds()

	var strain := Economy.strain(Economy.DEFAULT_STRAIN)
	# La resa mostrata e' quella che darebbe una pianta seminata ADESSO, con
	# l'attrezzatura che si ha adesso: scrivere il valore di listino dopo aver
	# venduto un toolkit al giocatore vorrebbe dire dargli un numero falso.
	#
	# La lampada e' un effetto per vaso (vedi `Shop.grow_mods()`), quindi
	# l'anteprima usa il PRIMO VASO LIBERO: e' quello in cui finirebbe
	# davvero il prossimo seme piantato a mano. A cantina piena non c'e' niente
	# da anticipare — non si puo' piantare comunque — e allora si mostra il
	# valore di listino, senza inventare un bonus che potrebbe non esserci.
	var mods := Shop.grow_mods(
		GameState.current, float(strain["grow_hours"]), int(strain["grams"]),
		_first_empty_plot())
	_add_note(tr("PC_YIELD_NOTE") % [
		int(mods["grams"]), UiFormat.duration(float(mods["hours"]))])

## I semi: da qui si chiede a Brian, e da qui si vede a che punto è la cosa.
##
## Sta nella scheda GROW e non in una sua perché è lì che ci si accorge di
## essere a secco — davanti ai vasi vuoti — ed è lì che deve esserci il modo di
## rimediare, senza cambiare scheda per cercarlo.
## Indice del primo vaso vuoto, -1 se non ce n'e'. Vedi la nota su `_build_grow()`.
func _first_empty_plot() -> int:
	var data := GameState.current
	if data == null:
		return -1
	for i in data.plots.size():
		if Grow.is_empty(data.plots[i]):
			return i
	return -1

func _build_seeds() -> void:
	var seeds := func(d: SaveData) -> String: return str(Economy.seeds_owned(d))
	_add_field("PC_SEEDS", seeds)

	# Un bottone solo che cambia faccia con lo stato dell'appuntamento, invece
	# di tre che si accendono a turno: la riga dice sempre qual è la prossima
	# cosa che succede, e quando non c'è niente da fare lo dice spenta.
	var text := func(d: SaveData) -> String:
		var now := GameState.total_hours()
		if SeedDeal.is_waiting(d):
			return tr("PC_WAITING_BRIAN") % UiFormat.duration(SeedDeal.hours_left(d, now))
		if SeedDeal.is_ready(d):
			return tr("PC_BRIAN_WAITING") % SeedDeal.place(d)
		return tr("PC_ASK_BRIAN")
	var enabled := func(d: SaveData) -> bool: return SeedDeal.can_ask(d)
	_add_action(text, enabled, _ask_brian)

	var data := GameState.current
	if data == null:
		return

	# L'autista: c'è solo se è stato assunto, e allora i semi si ordinano da
	# qui. Senza di lui la riga non compare affatto — un bottone spento che
	# dice "assumi un autista" sarebbe pubblicità, e il consiglio lo dà già
	# Brian al momento giusto (`MSG_DRIVER_BODY`).
	if Staff.has_driver(data) and SeedRun.is_unlocked(data):
		var driver_text := func(d: SaveData) -> String:
			var now := GameState.total_hours()
			if SeedRun.is_running(d):
				return tr("SW_ON_THE_WAY") % UiFormat.duration(SeedRun.hours_left(d, now))
			return tr("PC_SEND_DRIVER")
		var driver_enabled := func(d: SaveData) -> bool:
			return (
				not SeedRun.is_running(d) and not Delivery.is_running(d)
				and not BusImport.is_running(d))
		_add_action(driver_text, driver_enabled, _send_driver)
		_add_note(tr("PC_DRIVER_NOTE"))

	if SeedDeal.is_ready(data):
		_add_note(tr("PC_BRIAN_NOTE_READY") % [
			SeedDeal.seeds_left(data), SeedDeal.place(data),
			UiFormat.duration(SeedDeal.hours_left(data, GameState.total_hours()))])
	elif SeedDeal.is_waiting(data):
		_add_note(tr("PC_BRIAN_NOTE_WAITING"))
	elif Economy.seeds_owned(data) <= 0:
		_add_note(tr("PC_BRIAN_NOTE_EMPTY"))

## Il grossista aperto dal PC, che è tutto quello che l'autista fa: lo stesso
## sportello che sta sull'edificio nel COMMERCIAL DISTRICT, ma senza doverci andare.
##
## Si riusa la finestra invece di rifare qui i tagli e i prezzi: sono gli stessi
## ordini, e averne due copie vorrebbe dire due posti in cui aggiustare uno
## sconto. La finestra sta su una tela più alta di questa (layer 6 contro 4),
## quindi si apre sopra e il PC resta dietro dov'era.
func _send_driver() -> void:
	var scena: PackedScene = load(SEED_WINDOW)
	if scena == null:
		return
	add_child(scena.instantiate())

func _ask_brian() -> void:
	if SeedDeal.ask(GameState.current, GameState.total_hours()):
		GameState.notify(tr("NOTE_ASKED_BRIAN"))
		# La riga di spiegazione sotto al bottone dipende dallo stato, e le note
		# non sono fra le cose che `_refresh()` riscrive: qui la scheda va
		# proprio ricostruita.
		_build_tab()
		return
	_refresh()

func _plot_summary(data: SaveData, slot: int) -> String:
	if slot >= data.plot_slots:
		var cost := Economy.next_plot_cost(data)
		if slot == data.plot_slots and cost >= 0:
			return tr("PC_PLOT_LOCKED_COST") % UiFormat.money(cost)
		return tr("PC_PLOT_LOCKED")
	var plot := data.plot(slot)
	if Grow.is_empty(plot):
		return tr("PC_PLOT_EMPTY")
	var now := GameState.total_hours()
	Grow.sync(plot, now)
	if Grow.is_ready(plot, now):
		return tr("PC_PLOT_READY") % Grow.yield_grams(plot)
	var text := tr("PC_PLOT_GROWING") % [
		Grow.stage_name(plot, now).to_lower(),
		int(roundf(Grow.progress(plot, now) * 100.0)),
		UiFormat.duration(Grow.hours_left(plot, now)),
	]
	if Grow.is_thirsty(plot, now):
		text += tr("PC_PLOT_DRY")
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

func _thirsty(data: SaveData) -> int:
	return Grow.count_thirsty(data.plots, GameState.total_hours())

func _water_all() -> void:
	var count := Grow.water_all(GameState.current.plots, GameState.total_hours())
	if count > 0:
		GameState.notify(tr("NOTE_WATERED_N") % count)
	_refresh()

func _harvest_all() -> void:
	var data := GameState.current
	var now := GameState.total_hours()
	var plants := Grow.count_ready(data.plots, now)
	var grams := Grow.harvest_all(data.plots, now)
	if grams <= 0:
		return
	data.add_item(Economy.PRODUCT, grams)
	Staff.reserve_harvest(data, grams)
	data.bump_stat(Economy.STAT_GRAMS_HARVESTED, grams)
	data.bump_stat(Economy.STAT_PLANTS_GROWN, plants)
	GameState.notify(tr("NOTE_HARVESTED") % grams)
	_refresh()

func _buy_plot() -> void:
	if Economy.buy_plot(GameState.current):
		GameState.notify(tr("NOTE_NEW_POT"))
	_refresh()

# --- MARKET ----------------------------------------------------------------

## Il mercato: i prezzi del giorno e il furgone.
##
## Non c'e' piu' nessun bottone "vendi dieci grammi": l'ingrosso adesso e' un
## viaggio (vedi `Delivery`), e la scheda cambia faccia tre volte — prima del
## chilo spiega cosa manca, col chilo ma senza furgone offre di comprarlo, col
## furgone manda i carichi.
func _build_market() -> void:
	var stock := func(d: SaveData) -> String: return "%d g" % Economy.stock(d)
	var wholesale := func(d: SaveData) -> String: return "%s / g" % UiFormat.money(Economy.wholesale_price(d))
	var street := func(d: SaveData) -> String: return "%s / g" % UiFormat.money(Economy.retail_price(d))
	var value := func(d: SaveData) -> String: return UiFormat.money(Economy.stock(d) * Economy.wholesale_price(d))

	_add_field("PC_STOCK", stock)
	_add_field("PC_WHOLESALE_TODAY", wholesale)
	_add_field("PC_STREET_PRICE", street)
	_add_field("PC_STOCK_VALUE", value)
	_add_separator()

	var data := GameState.current
	if data == null:
		return
	if not Delivery.is_unlocked(data):
		_add_note(tr("PC_WHOLESALE_LOCKED") % Delivery.UNLOCK_GRAMS)
		return
	if not Delivery.has_van(data):
		_build_van_offer()
		return
	_build_van_runs()

## Col chilo raggiunto ma senza mezzo: il furgone si compra anche da qui, non
## solo dal negozio. E' qui che ci si accorge di averne bisogno, ed e' lo stesso
## bottone e la stessa logica — come il vaso in piu', che sta sia in SHOP sia in
## GROW.
func _build_van_offer() -> void:
	var text := func(d: SaveData) -> String:
		return tr("PC_BUY_VAN") % UiFormat.money(Shop.price(Delivery.VAN_ITEM))
	var enabled := func(d: SaveData) -> bool: return Shop.can_buy(d, Delivery.VAN_ITEM)
	_add_action(text, enabled, func() -> void: _buy_item(Delivery.VAN_ITEM))
	_add_note(tr("PC_VAN_NOTE") % Delivery.TANK_RUNS)

## Col furgone in garage: i carichi, il serbatoio, e il viaggio in corso.
func _build_van_runs() -> void:
	var data := GameState.current
	if Delivery.is_running(data):
		var away := func(d: SaveData) -> String:
			return tr("PC_VAN_AWAY") % [
				Delivery.load_grams(d) / 1000,
				UiFormat.money(Delivery.load_value(d)),
				UiFormat.duration(Delivery.hours_left(d, GameState.total_hours()))]
		_add_field("PC_VAN", away, Callable(), false)
		return

	var fuel := func(d: SaveData) -> String:
		return tr("PC_VAN_FUEL") % [Delivery.fuel(d), Delivery.TANK_RUNS]
	var fuel_color := func(d: SaveData) -> Color:
		return WARN_COLOR if Delivery.needs_fuel(d) else VALUE_COLOR
	_add_field("PC_VAN_TANK", fuel, fuel_color, false)

	var refuel_text := func(d: SaveData) -> String:
		return tr("PC_REFUEL") % UiFormat.money(Delivery.TANK_PRICE)
	var refuel_ok := func(d: SaveData) -> bool:
		return Delivery.fuel(d) < Delivery.TANK_RUNS and d.cash >= Delivery.TANK_PRICE
	_add_action(refuel_text, refuel_ok, _refuel)
	_add_separator()

	# `amount` arriva da un array non tipizzato, quindi e' un Variant: il tipo va
	# scritto, altrimenti `grams` non e' inferibile e lo script non compila.
	for amount in Delivery.LOADS:
		var grams: int = amount
		var text := func(d: SaveData) -> String:
			return tr("PC_SEND_KG") % [
				grams / 1000, UiFormat.money(grams * Economy.wholesale_price(d))]
		var enabled := func(d: SaveData) -> bool:
			return Delivery.can_dispatch(d) and Economy.stock(d) >= grams
		_add_action(text, enabled, func() -> void: _dispatch(grams))

	if Delivery.needs_fuel(data):
		_add_note(tr("PC_VAN_DRY"))
	else:
		_add_note(tr("PC_MARKET_NOTE") % int(roundf((Economy.RETAIL_MULTIPLIER - 1.0) * 100.0)))

func _dispatch(grams: int) -> void:
	if Delivery.dispatch(GameState.current, grams, GameState.total_hours()) <= 0:
		_refresh()
		return
	GameState.notify(tr("NOTE_VAN_LEFT") % (grams / 1000))
	GameState.van_left.emit(grams)
	# Il filmato: si ordina da qui, cioe' dalla cantina, ed e' l'unico modo di
	# vedere partire una cosa che succede fuori. Vedi `GameState.van_cutscene()`.
	GameState.van_cutscene(grams)
	GameState.save_game()
	# La scheda cambia faccia: da "manda un carico" a "il furgone e' fuori".
	_build_tab()

func _refuel() -> void:
	if Delivery.refuel(GameState.current):
		GameState.notify(tr("NOTE_REFUELLED"))
		GameState.save_game()
	_build_tab()

# --- SHOP ------------------------------------------------------------------

## Il negozio online: l'attrezzatura che si compra una volta e resta.
##
## Ogni voce e' un bottone che dice nome, prezzo e quanti pezzi si hanno gia',
## seguito dalla riga che spiega cosa fa. La spiegazione sta sotto al bottone e
## non dentro a un tooltip perche' queste sono scelte di spesa da qualche
## centinaio di dollari: vanno lette prima di cliccare, non dopo.
func _build_shop() -> void:

	for id in Shop.ORDER:
		var item_id: String = id
		var text := func(d: SaveData) -> String:
			var have := Shop.owned(d, item_id)
			var cap := Shop.max_owned(item_id)
			if have >= cap:
				return tr("PC_SHOP_OWNED") % [Shop.item_name(item_id), have]
			var label := tr("PC_SHOP_BUY") % [Shop.item_name(item_id), UiFormat.money(Shop.price(item_id))]
			return label if have <= 0 else tr("PC_SHOP_BUY_MORE") % [label, have, cap]
		var enabled := func(d: SaveData) -> bool: return Shop.can_buy(d, item_id)
		var action := func() -> void: _buy_item(item_id)
		_add_action(text, enabled, action)
		_add_note(Shop.note(item_id))

	_add_separator()

	# Il vaso in piu' sta anche qui, oltre che nella scheda GROW: chi e' venuto a
	# comprare attrezzatura sta pensando "come faccio a produrre di piu'", e la
	# risposta piu' diretta e' un vaso in piu'. Il bottone e' lo stesso, la
	# logica una sola (`Economy.buy_plot()`).
	var plot_text := func(d: SaveData) -> String:
		var cost := Economy.next_plot_cost(d)
		if cost >= 0:
			return tr("PC_SHOP_EXTRA_POT") % UiFormat.money(cost)
		return _no_pot_reason(d)
	var plot_enabled := func(d: SaveData) -> bool:
		var cost := Economy.next_plot_cost(d)
		return cost >= 0 and d.cash >= cost
	_add_action(plot_text, plot_enabled, _buy_plot)
	# Il tetto di QUESTA partita, non quello del gioco: senza il garage i vasi
	# sono sei, e scrivere diciotto vorrebbe dire promettere dodici vasi che non
	# si possono ancora comprare.
	_add_note(tr("PC_SHOP_POT_NOTE") % GrowSites.reachable_slots(GameState.current))

## Perche' non si puo' aprire un altro vaso.
##
## "Non ci sta altro" e "non ci sta altro QUI" sono due risposte diverse: la
## prima e' la fine della strada, la seconda vuol dire che i vasi che restano
## stanno in una proprieta' che non e' ancora tua. Senza distinguerle, riempita
## la cantina il negozio sembra esaurito e non c'e' piu' niente che mandi in
## agenzia — che e' proprio il passo successivo.
func _no_pot_reason(data: SaveData) -> String:
	return tr("PC_POTS_NEED_ROOM") if GrowSites.has_locked_room(data) else tr("PC_NO_ROOM_POTS")

func _buy_item(id: String) -> void:
	if Shop.buy(GameState.current, id):
		GameState.notify(tr("NOTE_BOUGHT") % Shop.item_name(id))
		GameState.save_game()
		# I testi dei bottoni si aggiornano da soli, le note no: e una voce che
		# passa a "gia' tuo" cambia anche quello che c'e' scritto sotto, quindi
		# la scheda va proprio rifatta.
		_build_tab()
		return
	_refresh()

# --- STAFF -----------------------------------------------------------------

## Il personale: chi e' assunto, quanto costa, e come deve piazzare la merce.
##
## La scheda esiste solo dopo il prologo — vedi `_build_tab_bar()`.
func _build_staff() -> void:
	var wages := func(d: SaveData) -> String:
		return tr("PC_WAGES_VALUE") % UiFormat.money(Staff.daily_wages(d))
	var wages_color := func(d: SaveData) -> Color:
		return WARN_COLOR if Staff.daily_wages(d) > d.cash else VALUE_COLOR
	_add_field("PC_WAGES", wages, wages_color)
	_add_separator()

	for role_id in Staff.roles_for(GameState.current):
		var role: String = role_id
		var head_count := func(d: SaveData) -> String:
			return tr("PC_STAFF_COUNT") % [
				Staff.count(d, role), Staff.max_for(d, role), Staff.pay_label(role)]
		# Etichetta col font di sistema: il conteggio contiene cifre e
		# `alphabet.fnt` ha solo lettere.
		_add_field(Staff.role_name(role), head_count, Callable(), false)

		var hire_text := func(d: SaveData) -> String:
			if Staff.count(d, role) >= Staff.max_for(d, role):
				return tr("PC_NO_ROOM_STAFF")
			return tr("PC_HIRE") % UiFormat.money(Staff.hire_cost(role))
		var hire_enabled := func(d: SaveData) -> bool: return Staff.can_hire(d, role)
		var hire_action := func() -> void: _hire(role)
		_add_action(hire_text, hire_enabled, hire_action)

		var fire_text := func(_d: SaveData) -> String: return tr("PC_LET_GO")
		var fire_enabled := func(d: SaveData) -> bool: return Staff.count(d, role) > 0
		var fire_action := func() -> void: _fire(role)
		_add_action(fire_text, fire_enabled, fire_action)

		_add_note(Staff.note(role))
		_add_separator()

	_build_grower_sites()

	# La ripartizione compare solo a ingrosso aperto: vedi `_build_split()`.
	if Delivery.is_unlocked(GameState.current):
		_build_split()

## Chi coltiva dove.
##
## Una riga per posto con due bottoni: un coltivatore sta in **una** stanza e
## segue i vasi di quella, quindi mandarne due in cantina mentre il garage ha
## dodici piante da annaffiare deve essere possibile — e' una scelta sbagliata,
## non una cosa da impedire.
##
## La sezione compare solo quando c'e' davvero qualcosa da scegliere, cioe' da
## quando si ha un secondo posto in cui coltivare: con la sola cantina l'unica
## assegnazione possibile la fa gia' il gioco da solo, e due bottoni che portano
## sempre allo stesso risultato sono rumore. E' la stessa regola della
## ripartizione delle vendite, che compare col canale dell'ingrosso.
func _build_grower_sites() -> void:
	var data := GameState.current
	if data == null or GrowSites.open_sites(data).size() < 2:
		return
	_add_separator()
	_add_field(tr("PC_GROWER_SITES"), func(_d: SaveData) -> String: return "", Callable(), true)

	for entry in GrowSites.all():
		var site: Dictionary = entry
		var key := str(site["key"])
		var line := func(d: SaveData) -> String:
			if not GrowSites.is_open(d, site):
				return tr("PC_SITE_SHUT")
			# Aperti **e** totali, non solo aperti: la capienza in coltivatori
			# sale coi vasi che si comprano, e con scritto solo "6 vasi" il
			# tetto sembra una proprieta' fissa del posto invece che qualcosa
			# che si alza spendendo. Il garage ne regge due, ma solo dal
			# settimo vaso in poi.
			return tr("PC_SITE_ROW") % [
				Staff.growers_on(d, key), GrowSites.capacity(d, site),
				GrowSites.slots_in(d, site), int(site["count"])]
		# Etichetta col font di sistema: la riga e' fatta di cifre, e
		# `alphabet.fnt` ha solo lettere.
		_add_field(GrowSites.site_name(site), line, Callable(), false)

		var more_text := func(_d: SaveData) -> String: return tr("PC_SEND_HERE")
		var more_enabled := func(d: SaveData) -> bool:
			return GrowSites.is_open(d, site) \
				and Staff.idle_growers(d) > 0 \
				and Staff.growers_on(d, key) < GrowSites.capacity(d, site)
		var more_action := func() -> void: _move_grower(key, 1)
		_add_action(more_text, more_enabled, more_action)

		var less_text := func(_d: SaveData) -> String: return tr("PC_TAKE_AWAY")
		var less_enabled := func(d: SaveData) -> bool: return Staff.growers_on(d, key) > 0
		var less_action := func() -> void: _move_grower(key, -1)
		_add_action(less_text, less_enabled, less_action)

	# Quanti sono senza posto. Compare solo quando ce n'e' almeno uno, ed e'
	# l'unica riga della sezione che segnala un problema: un coltivatore in
	# panchina si paga ogni notte e non produce niente.
	var idle := func(d: SaveData) -> String: return tr("PC_SITE_IDLE") % Staff.idle_growers(d)
	var idle_color := func(d: SaveData) -> Color:
		return WARN_COLOR if Staff.idle_growers(d) > 0 else VALUE_COLOR
	_add_field(tr("PC_SITE_SPARE"), idle, idle_color, false)
	_add_note(tr("PC_SITES_NOTE") % GrowSites.POTS_PER_GROWER)

func _move_grower(key: String, amount: int) -> void:
	if Staff.assign(GameState.current, key, amount):
		GameState.save_game()
	_refresh()

## Quanta merce si mette da parte per l'ingrosso, e quanta resta ai dealer.
##
## **Solo a ingrosso aperto.** Prima la riga c'era comunque, con i suoi due
## bottoni, e chiedeva di ripartire le vendite fra due canali di cui uno non
## esisteva ancora: qualunque cosa si scegliesse il risultato era lo stesso, e
## l'unica cosa che si imparava era che quel comando non faceva niente. Un
## comando che non fa niente e' peggio di un comando che non c'e', perche' il
## giocatore ci torna sopra a cercare cosa ha sbagliato. Adesso compare col
## canale, insieme al furgone e al resto dell'ingrosso.
##
## Due bottoni e una riga invece di uno slider: a passi di dieci le scelte sono
## undici, e undici scelte non hanno bisogno di un controllo continuo. Uno
## slider a 640x360 sarebbe largo sessanta pixel e impossibile da mirare.
func _build_split() -> void:
	var split := func(d: SaveData) -> String:
		return tr("PC_SPLIT_VALUE") % [
			Staff.wholesale_share(d), 100 - Staff.wholesale_share(d)]
	_add_field(tr("PC_SALES_SPLIT"), split, Callable(), false)

	# Quanto c'e' da parte adesso, in grammi. La percentuale da sola non basta a
	# capire cosa sta succedendo in magazzino: dice la regola, non il risultato,
	# e il risultato e' il numero che decide se il furgone puo' partire.
	var put_aside := func(d: SaveData) -> String:
		return tr("PC_RESERVED_VALUE") % [Staff.reserved(d), Staff.sellable(d)]
	_add_field(tr("PC_RESERVED"), put_aside, Callable(), false)

	var more_text := func(_d: SaveData) -> String: return tr("PC_MORE_WHOLESALE")
	var more_enabled := func(d: SaveData) -> bool: return Staff.wholesale_share(d) < 100
	var more_action := func() -> void: _shift_split(Staff.SHARE_STEP)
	_add_action(more_text, more_enabled, more_action)

	var less_text := func(_d: SaveData) -> String: return tr("PC_MORE_STREET")
	var less_enabled := func(d: SaveData) -> bool: return Staff.wholesale_share(d) > 0
	var less_action := func() -> void: _shift_split(-Staff.SHARE_STEP)
	_add_action(less_text, less_enabled, less_action)

	_add_note(tr("PC_SPLIT_NOTE") % int(roundf((Economy.RETAIL_MULTIPLIER - 1.0) * 100.0)))

func _hire(role: String) -> void:
	if Staff.hire(GameState.current, role, GameState.total_hours()):
		GameState.notify(tr("NOTE_HIRED") % Staff.role_name(role))
		GameState.save_game()
	_refresh()

func _fire(role: String) -> void:
	if Staff.fire(GameState.current, role):
		GameState.notify(tr("NOTE_LET_GO") % Staff.role_name(role))
		GameState.save_game()
	_refresh()

func _shift_split(amount: int) -> void:
	var data := GameState.current
	Staff.set_wholesale_share(data, Staff.wholesale_share(data) + amount)
	_refresh()

# --- Costruzione delle righe ----------------------------------------------

## Riga "etichetta ......... valore". `pixel_caption` a false quando
## l'etichetta contiene cifre: il font del gioco ha solo lettere e spazio.
## Il riquadro in cui scrivere adesso, aprendone uno se non ce n'e'.
##
## **E' questo che ha riorganizzato la schermata.** Prima le righe finivano
## tutte di seguito in un'unica colonna lunga, separate da un filetto: una
## scheda era un elenco, e per ritrovare un dato bisognava rileggerla dall'alto.
## Adesso un filetto apre un riquadro nuovo, e gli stessi identici gruppi
## diventano blocchi che si distinguono da lontano. Le funzioni che costruiscono
## le schede non sono cambiate: chiamano `_add_separator()` dove chiamavano
## prima, ed e' li' che adesso comincia un riquadro.
func _card() -> VBoxContainer:
	if _open_card != null:
		return _open_card
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.card_box())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_content.add_child(panel)
	_open_card = box
	return box

## Riga di sola lettura: etichetta a sinistra, valore a destra.
##
## `pixel_caption` sceglieva il font disegnato a mano per le etichette fisse e
## quello di sistema per quelle composte (i nomi dei vasi, che hanno un numero
## dentro, e `alphabet.fnt` le cifre non ce le ha). Adesso il font del testo e'
## uno solo e le cifre ce le ha: il parametro resta perche' le chiamate sono
## una trentina, ma distingue il PESO invece del font — le etichette fisse sono
## intestazioni di riga, quelle composte sono voci di un elenco.
func _add_field(caption: String, text: Callable, color := Callable(), pixel_caption := true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Col pennello se l'etichetta e' di sole parole ("SCORTA"), con Nunito se ha
	# cifre dentro ("VASO 3"): lo decide `UiTheme` guardando il testo.
	var name_label := UiTheme.window_label(caption, UiTheme.WIN_LABEL, UiTheme.SIZE_LABEL,
		UiTheme.INK_SOFT, UiTheme.W_MEDIUM if pixel_caption else UiTheme.W_REGULAR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := UiTheme.label("", UiTheme.SIZE_VALUE, UiTheme.INK,
		UiTheme.W_BOLD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	_card().add_child(row)
	_fields.append({"label": value_label, "text": text, "color": color})

## Un bottone d'azione, dentro al riquadro in cui si sta scrivendo.
##
## Pieno di terracotta e non piatto come prima: in un gestionale le righe sono
## quasi tutte da leggere e poche da premere, e se le seconde hanno lo stesso
## aspetto delle prime non si trovano. Largo quanto il riquadro, perche' in
## colonna un bottone stretto in mezzo alla carta sembra sganciato.
func _add_action(text: Callable, enabled: Callable, action: Callable) -> void:
	var button := _make_button("", null, UiTheme.SIZE_VALUE)
	UiTheme.dress_button(button, UiTheme.primary_boxes(), UiTheme.CARD,
		UiTheme.SIZE_VALUE, UiTheme.W_BOLD)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(action)
	var spazio := Control.new()
	spazio.custom_minimum_size = Vector2(0, 2)
	spazio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card().add_child(spazio)
	_card().add_child(button)
	_actions.append({"button": button, "text": text, "enabled": enabled})

## Chiude il riquadro aperto: il prossimo campo ne comincia un altro.
func _add_separator() -> void:
	_open_card = null

## Riga di spiegazione: è il posto dove dire al giocatore la regola che sta
## dietro ai numeri, senza un tutorial a parte.
##
## `RichTextLabel` e non `Label`, per una ragione sola: una Label con
## l'a-capo automatico chiede comunque al contenitore la larghezza di tutta la
## riga, quindi il riquadro si allarga per contenerla e la frase esce dalla
## finestra invece di andare a capo. Il RichText chiede poco e si adatta.
func _add_note(text: String) -> void:
	var nota := RichTextLabel.new()
	nota.bbcode_enabled = false
	nota.text = text
	nota.fit_content = true
	nota.scroll_active = false
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nota.add_theme_font_override("normal_font", UiTheme.body())
	nota.add_theme_font_size_override("normal_font_size", UiTheme.SIZE_NOTE)
	nota.add_theme_color_override("default_color", UiTheme.INK_FAINT)
	_card().add_child(nota)

func _make_button(text: String, font: Font, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	UiTheme.dress_button(button, UiTheme.ghost_boxes(), UiTheme.INK, font_size)
	if font != null:
		button.add_theme_font_override("font", font)
	button.set_script(BUTTON_SCRIPT)
	button.use_press_offset = false
	return button
