extends Control

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

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")
const GAME_FONT := preload("res://assets/sprites/ui/alphabet.fnt")

const REFRESH_INTERVAL := 0.2
const CAPTION_COLOR := Color(0.68, 0.71, 0.65)
const VALUE_COLOR := Color(0.95, 0.94, 0.86)
const GOOD_COLOR := Color(0.65, 0.87, 0.48)
const WARN_COLOR := Color(0.95, 0.62, 0.35)

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

@onready var _tab_bar: HBoxContainer = $Window/Tabs
@onready var _content: VBoxContainer = $Window/Scroll/Content
@onready var _close_button: BaseButton = $Window/Close

var _tab := 0
var _tab_buttons: Array[Button] = []
## Nomi delle schede attualmente in barra, nell'ordine. `_tab` e' un indice in
## questa lista, non in `BASE_TABS`.
var _tabs: Array[String] = []
## Il personale era sbloccato all'ultima costruzione della barra? Serve ad
## accorgersi che il prologo si e' chiuso mentre la finestra era aperta.
var _staff_unlocked := false
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
	add_to_group("modal")
	_close_button.pressed.connect(close)
	_build_tab_bar()
	_select_tab(0)

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
		var button := _make_button(_tabs[i], GAME_FONT, 16)
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
	_refresh()

func _refresh() -> void:
	var data := GameState.current
	if data == null:
		return

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
	var day := func(d: SaveData) -> String:
		return tr("PC_DAY_VALUE") % [d.day, UiFormat.clock(d.time_of_day)]
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

	_add_field("PC_CASH", cash)
	_add_field("PC_DAY", day)
	_add_separator()
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

func _build_grow() -> void:
	for i in Economy.MAX_PLOTS:
		var slot := i
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
		return tr("PC_NO_ROOM_POTS") if cost < 0 else tr("PC_OPEN_POT") % UiFormat.money(cost)
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
	var mods := Shop.grow_mods(
		GameState.current, float(strain["grow_hours"]), int(strain["grams"]))
	_add_note(tr("PC_YIELD_NOTE") % [
		int(mods["grams"]), UiFormat.duration(float(mods["hours"]))])

## I semi: da qui si chiede a Brian, e da qui si vede a che punto è la cosa.
##
## Sta nella scheda GROW e non in una sua perché è lì che ci si accorge di
## essere a secco — davanti ai vasi vuoti — ed è lì che deve esserci il modo di
## rimediare, senza cambiare scheda per cercarlo.
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
	if SeedDeal.is_ready(data):
		_add_note(tr("PC_BRIAN_NOTE_READY") % [
			SeedDeal.seeds_left(data), SeedDeal.place(data),
			UiFormat.duration(SeedDeal.hours_left(data, GameState.total_hours()))])
	elif SeedDeal.is_waiting(data):
		_add_note(tr("PC_BRIAN_NOTE_WAITING"))
	elif Economy.seeds_owned(data) <= 0:
		_add_note(tr("PC_BRIAN_NOTE_EMPTY"))

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
	data.bump_stat(Economy.STAT_GRAMS_HARVESTED, grams)
	data.bump_stat(Economy.STAT_PLANTS_GROWN, plants)
	GameState.notify(tr("NOTE_HARVESTED") % grams)
	_refresh()

func _buy_plot() -> void:
	if Economy.buy_plot(GameState.current):
		GameState.notify(tr("NOTE_NEW_POT"))
	_refresh()

# --- MARKET ----------------------------------------------------------------

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

	# `amount` arriva da un array non tipizzato, quindi è un Variant: il tipo va
	# scritto, altrimenti `grams` non è inferibile e lo script non compila.
	for amount in [10, 50]:
		var grams: int = amount
		var text := func(d: SaveData) -> String:
			return tr("PC_SELL_N") % [grams, UiFormat.money(grams * Economy.wholesale_price(d))]
		var enabled := func(d: SaveData) -> bool: return Economy.stock(d) >= grams
		var action := func() -> void: _sell(grams)
		_add_action(text, enabled, action)

	var all_text := func(d: SaveData) -> String:
		return tr("PC_SELL_ALL") % UiFormat.money(Economy.stock(d) * Economy.wholesale_price(d))
	var all_enabled := func(d: SaveData) -> bool: return Economy.stock(d) > 0
	var all_action := func() -> void: _sell(Economy.stock(GameState.current))
	_add_action(all_text, all_enabled, all_action)

	_add_note(tr("PC_MARKET_NOTE") % int(roundf((Economy.RETAIL_MULTIPLIER - 1.0) * 100.0)))

func _sell(grams: int) -> void:
	var revenue := Economy.sell_wholesale(GameState.current, grams)
	if revenue > 0:
		GameState.notify(tr("NOTE_SOLD") % [UiFormat.money(revenue), grams])
	_refresh()

# --- SHOP ------------------------------------------------------------------

## Il negozio online: l'attrezzatura che si compra una volta e resta.
##
## Ogni voce e' un bottone che dice nome, prezzo e quanti pezzi si hanno gia',
## seguito dalla riga che spiega cosa fa. La spiegazione sta sotto al bottone e
## non dentro a un tooltip perche' queste sono scelte di spesa da qualche
## centinaio di dollari: vanno lette prima di cliccare, non dopo.
func _build_shop() -> void:
	var cash := func(d: SaveData) -> String: return UiFormat.money(d.cash)
	_add_field("PC_CASH", cash)
	_add_separator()

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
		return tr("PC_NO_ROOM_POTS") if cost < 0 else tr("PC_SHOP_EXTRA_POT") % UiFormat.money(cost)
	var plot_enabled := func(d: SaveData) -> bool:
		var cost := Economy.next_plot_cost(d)
		return cost >= 0 and d.cash >= cost
	_add_action(plot_text, plot_enabled, _buy_plot)
	_add_note(tr("PC_SHOP_POT_NOTE") % Economy.MAX_PLOTS)

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
	var cash := func(d: SaveData) -> String: return UiFormat.money(d.cash)
	var wages := func(d: SaveData) -> String:
		return tr("PC_WAGES_VALUE") % UiFormat.money(Staff.daily_wages(d))
	var wages_color := func(d: SaveData) -> Color:
		return WARN_COLOR if Staff.daily_wages(d) > d.cash else VALUE_COLOR
	_add_field("PC_CASH", cash)
	_add_field("PC_WAGES", wages, wages_color)
	_add_separator()

	for role_id in Staff.ORDER:
		var role: String = role_id
		var head_count := func(d: SaveData) -> String:
			return tr("PC_STAFF_COUNT") % [
				Staff.count(d, role), Staff.MAX_PER_ROLE, UiFormat.money(Staff.wage(role))]
		# Etichetta col font di sistema: il conteggio contiene cifre e
		# `alphabet.fnt` ha solo lettere.
		_add_field(Staff.role_name(role), head_count, Callable(), false)

		var hire_text := func(d: SaveData) -> String:
			if Staff.count(d, role) >= Staff.MAX_PER_ROLE:
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

	_build_split()

## Come i dealer dividono la merce fra ingrosso e strada.
##
## Due bottoni e una riga invece di uno slider: a passi di dieci le scelte sono
## undici, e undici scelte non hanno bisogno di un controllo continuo. Uno
## slider a 640x360 sarebbe largo sessanta pixel e impossibile da mirare.
func _build_split() -> void:
	var split := func(d: SaveData) -> String:
		return tr("PC_SPLIT_VALUE") % [
			Staff.wholesale_share(d), 100 - Staff.wholesale_share(d)]
	_add_field(tr("PC_SALES_SPLIT"), split, Callable(), false)

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
