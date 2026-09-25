extends CanvasLayer

## Il banco del grossista dei semi: i tagli ordinabili e quanto costano.
##
## Si apre cliccando sul magazzino in centro, e come all'agenzia il protagonista
## resta sul marciapiede: è uno sportello a cui ci si affaccia, non una stanza
## in cui si entra. Se ne occupa `city.gd`, che per gli edifici con un `window`
## invece di un `interior` istanzia la scena indicata.
##
## ## Cosa fa davvero il bottone
##
## Non consegna i semi: manda il furgone. Ordinato un taglio, la finestra si
## chiude e da lì in poi il lavoro è di `SeedRun` — due ore di gioco, e i semi
## arrivano anche a partita chiusa. Chiudere la finestra subito è voluto: da qui
## in avanti non c'è più niente da decidere, e lasciarla aperta su tre bottoni
## spenti farebbe sembrare rotto l'ordine appena fatto.
##
## ## Le righe sono costruite dal codice
##
## Come nel gestionale e all'agenzia: i tagli vengono da `SeedRun.PACKS` e i
## prezzi dal listino del giorno, quindi sarebbero comunque da riempire a
## runtime. Tenerli anche nella scena vorrebbe dire mantenere due volte la
## stessa lista.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

@onready var _dimmer: ColorRect = $Root/Dimmer
@onready var _window: Panel = $Root/Window
@onready var _title: Label = $Root/Window/Title
@onready var _rule: ColorRect = $Root/Window/TitleRule
@onready var _content: VBoxContainer = $Root/Window/Scroll/Content
@onready var _cash: Label = $Root/Window/Cash
@onready var _close: Button = $Root/Window/Close

func _ready() -> void:
	# L'HUD si nasconde finché c'è qualcuno in questo gruppo.
	add_to_group(UiTheme.MODAL_GROUP)
	_dress()
	_close.pressed.connect(queue_free)
	_rebuild()

func _dress() -> void:
	_dimmer.color = UiTheme.DIMMER
	_window.add_theme_stylebox_override("panel", UiTheme.window_box())
	UiTheme.dress_window_text(_title, _title.text, UiTheme.WIN_TITLE, UiTheme.SIZE_TITLE)
	_title.add_theme_color_override("font_color", UiTheme.INK)
	_rule.color = UiTheme.LINE
	# La riga della cassa e' alta sedici pixel (vedi il `.tscn`): il pennello
	# alla misura della cassa del PC ne uscirebbe e finirebbe sul primo riquadro.
	UiTheme.dress_window_text(_cash, _cash.text, UiTheme.WIN_BUTTON)
	_cash.add_theme_color_override("font_color", UiTheme.ACCENT_DARK)
	_close.flat = false
	UiTheme.dress_button(_close, UiTheme.ghost_boxes(), UiTheme.INK_SOFT,
		UiTheme.SIZE_TAB)
	UiTheme.dress_window_text(_close, _close.text, UiTheme.WIN_BUTTON, UiTheme.SIZE_TAB)
	_close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.dress_scrollbar(($Root/Window/Scroll as ScrollContainer).get_v_scroll_bar())

## Esc chiude, come in tutte le finestre del gioco.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var data := GameState.current
	var cash := data.cash if data != null else 0
	_cash.text = UiFormat.money(cash)

	# Il furgone è uno solo e fa un viaggio alla volta: se è già in giro — per i
	# semi o per l'ingrosso della merce — qui non c'è niente da ordinare, e
	# dirlo è meglio che mostrare tre bottoni spenti senza spiegare perché.
	if SeedRun.is_running(data):
		_content.add_child(_card([_label(
			tr("SW_ON_THE_WAY") % UiFormat.duration(
				SeedRun.hours_left(data, GameState.total_hours())),
			UiTheme.INK, UiTheme.SIZE_VALUE, UiTheme.W_BOLD, true)]))
		return
	if Delivery.is_running(data) or BusImport.holds_van(data):
		_content.add_child(_card([_label(tr("SW_VAN_OUT"), UiTheme.WARN,
			UiTheme.SIZE_VALUE, UiTheme.W_BOLD, true)]))
		return

	for entry in SeedRun.PACKS:
		_content.add_child(_pack_card(entry, data, cash))
	_content.add_child(_card([_label(tr("SW_NOTE"), UiTheme.INK_FAINT,
		UiTheme.SIZE_NOTE, UiTheme.W_REGULAR, true)]))

func _pack_card(pack: Dictionary, data: SaveData, cash: int) -> Control:
	var seeds := int(pack["seeds"])
	var price := SeedRun.pack_price(pack)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var name_label := _label(tr("SW_PACK") % seeds, UiTheme.INK,
		UiTheme.SIZE_VALUE, UiTheme.W_BOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var price_label := _label(UiFormat.money(price), UiTheme.ACCENT_DARK,
		UiTheme.SIZE_VALUE, UiTheme.W_BOLD)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(price_label)

	var nota := _label(
		tr("SW_PACK_NOTE") % int(roundf(float(pack["discount"]) * 100.0)),
		UiTheme.INK_SOFT, UiTheme.SIZE_NOTE, UiTheme.W_REGULAR, true)

	var action := HBoxContainer.new()
	action.alignment = BoxContainer.ALIGNMENT_END
	if cash < price:
		# Niente bottone spento: un tasto che non si può premere invita a
		# provarci. Si dice perché non si può, e basta. Come all'agenzia.
		action.add_child(UiTheme.window_label(tr("SW_NO_CASH"), UiTheme.WIN_LABEL,
			UiTheme.SIZE_LABEL, UiTheme.BAD, UiTheme.W_MEDIUM))
	else:
		var button := Button.new()
		button.text = tr("SW_ORDER")
		button.focus_mode = Control.FOCUS_NONE
		UiTheme.dress_button(button, UiTheme.primary_boxes(), UiTheme.CARD,
			UiTheme.SIZE_LABEL, UiTheme.W_BOLD)
		UiTheme.dress_window_text(button, button.text, UiTheme.WIN_BUTTON,
			UiTheme.SIZE_LABEL, UiTheme.W_BOLD)
		button.custom_minimum_size = Vector2(76, 0)
		button.set_script(BUTTON_SCRIPT)
		button.pressed.connect(_on_order.bind(pack))
		action.add_child(button)

	return _card([head, nota, action])

func _on_order(pack: Dictionary) -> void:
	var seeds := SeedRun.order(GameState.current, pack, GameState.total_hours())
	if seeds <= 0:
		_rebuild()
		return
	# Il furgone parte: la City lo fa uscire da casa e lo riporta quando è ora.
	GameState.seed_run_left.emit(seeds)
	GameState.save_game()
	queue_free()

# --- Mattoncini ------------------------------------------------------------

func _card(rows: Array) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card_box())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for row in rows:
		box.add_child(row)
	card.add_child(box)
	return card

## `wrap` solo per le frasi. Su un prezzo l'a-capo automatico e' un disastro
## silenzioso: dentro a una riga in cui il nome si prende tutto lo spazio, la
## cifra si ritrova larga un carattere e va a capo a ogni numero — "3", "6",
## "0", "$" uno sotto l'altro.
func _label(text: String, color: Color, size: int,
		weight := UiTheme.W_REGULAR, wrap := false) -> Label:
	var node := UiTheme.window_label(text, UiTheme.brush_size(size), size, color, weight)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node
