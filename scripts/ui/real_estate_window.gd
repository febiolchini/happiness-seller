extends CanvasLayer

## L'elenco dell'agenzia immobiliare: cosa c'è in vendita e quanto costa.
##
## Si apre cliccando sull'agenzia in città, e il protagonista resta sul
## marciapiede: non è una stanza in cui si entra, è uno sportello a cui ci si
## affaccia. Se ne occupa `city.gd`, che quando l'edificio ha un `window` invece
## di un `interior` istanzia questa scena come figlia della mappa.
##
## ## Perché la radice è un CanvasLayer e non un Control
##
## `City` è un `Node2D`: un `Control` appeso lì dentro finisce nello spazio del
## MONDO, non su quello dello schermo. Segue la camera, si sposta con lei e si
## ingrandisce con lo zoom — a 2x la finestra si apriva davvero, ma da qualche
## parte fuori inquadratura, e cliccare sull'agenzia sembrava non fare niente.
## Il CanvasLayer stacca il ramo dalla trasformazione della camera, ed è quello
## che fanno già HUD, telefono e riquadro dei dialoghi.
##
## ## Le righe sono costruite dal codice
##
## Come nel gestionale: quante sono e cosa dicono dipende da `RealEstate.LISTINGS`
## e dalla partita in corso, e sarebbero comunque da riempire a runtime.
## Tenerle anche nella scena vorrebbe dire mantenere due volte la stessa lista.
##
## ## Perché si ricostruisce tutto dopo un acquisto
##
## Comprare cambia due cose in una riga sola — il contante in alto e lo stato di
## quell'annuncio — e con un elenco di tre voci ricostruirlo è più semplice e
## più difficile da sbagliare che aggiornare i pezzi giusti. Il bottone appena
## premuto sparisce insieme al resto, ed è voluto: dopo l'acquisto non c'è più
## niente da premere lì.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

## Quale agenzia e': "flats" (accanto a casa) o "downtown". Decide quali annunci
## mostrare e il titolo. La scena di DOWNTOWN (`RealEstateDowntownWindow.tscn`)
## e' questa stessa con questo campo cambiato.
@export var agency := "flats"

const CAPTION_COLOR := UiTheme.INK_SOFT
const VALUE_COLOR := UiTheme.INK
const OWNED_COLOR := UiTheme.GOOD
const POOR_COLOR := UiTheme.BAD

@onready var _dimmer: ColorRect = $Root/Dimmer
@onready var _window: Panel = $Root/Window
@onready var _title: Label = $Root/Window/Title
@onready var _rule: ColorRect = $Root/Window/TitleRule
@onready var _content: VBoxContainer = $Root/Window/Scroll/Content
@onready var _cash: Label = $Root/Window/Cash
@onready var _close: Button = $Root/Window/Close

func _ready() -> void:
	# L'HUD si nasconde finche' c'e' qualcuno in questo gruppo. Senza, la riga
	# dei soldi resta appesa sopra alla finestra: prima era una scritta e si
	# notava poco, adesso e' una pastiglia di carta e si vede benissimo.
	add_to_group("modal")
	_dress()
	if agency == "downtown":
		_title.text = "RE_TITLE_DOWNTOWN"
	_close.pressed.connect(queue_free)
	_rebuild()

## La stessa carta del gestionale: è la stessa città, e due sportelli non
## possono avere due interfacce diverse. Vedi `UiTheme`.
func _dress() -> void:
	_dimmer.color = UiTheme.DIMMER
	_window.add_theme_stylebox_override("panel", UiTheme.window_box())
	_title.add_theme_font_override("font", UiTheme.display())
	_title.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE)
	_title.add_theme_color_override("font_color", UiTheme.INK)
	_rule.color = UiTheme.LINE
	_cash.add_theme_font_override("font", UiTheme.body(UiTheme.W_BOLD))
	_cash.add_theme_font_size_override("font_size", UiTheme.SIZE_BIG)
	_cash.add_theme_color_override("font_color", UiTheme.ACCENT_DARK)
	# `MenuTextButton` arriva con `flat` acceso, e un bottone flat ignora i
	# riquadri: senza spegnerlo il contorno non comparirebbe mai.
	_close.flat = false
	UiTheme.dress_button(_close, UiTheme.ghost_boxes(), UiTheme.INK_SOFT,
		UiTheme.SIZE_TAB)
	_close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.dress_scrollbar(($Root/Window/Scroll as ScrollContainer).get_v_scroll_bar())

## Esc chiude, come in tutte le finestre del gioco. `set_input_as_handled()` per
## non far arrivare lo stesso Esc alla mappa sotto, che aprirebbe il menu.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()

	var data := GameState.current
	var cash := 0 if data == null else int(data.cash)
	_cash.text = UiFormat.money(cash)

	var listings := RealEstate.for_agency(agency)
	if listings.is_empty():
		_content.add_child(_label(tr("RE_EMPTY"), CAPTION_COLOR, 13))
		return

	for listing in listings:
		_content.add_child(_listing_row(listing, data, cash))

func _listing_row(listing: Dictionary, data: SaveData, cash: int) -> Control:
	var id := str(listing["id"])
	var price := int(listing["prezzo"])
	var owned: bool = data != null and data.owns(id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card_box())
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	card.add_child(row)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var name_label := _label(tr(str(listing["titolo"])), VALUE_COLOR,
		UiTheme.SIZE_VALUE, UiTheme.W_BOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var prezzo := _label(UiFormat.money(price), UiTheme.ACCENT_DARK,
		UiTheme.SIZE_VALUE, UiTheme.W_BOLD)
	prezzo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(prezzo)
	row.add_child(head)

	row.add_child(_label(tr(str(listing["riga"])), CAPTION_COLOR,
		UiTheme.SIZE_NOTE))

	var action := HBoxContainer.new()
	action.alignment = BoxContainer.ALIGNMENT_END
	if owned:
		action.add_child(_label(tr("RE_OWNED"), OWNED_COLOR, UiTheme.SIZE_LABEL,
			UiTheme.W_BOLD))
	elif cash < price:
		# Niente bottone spento: un tasto che non si puo' premere invita a
		# provarci. Si dice perche' non si puo', e basta.
		action.add_child(_label(tr("RE_NO_CASH"), POOR_COLOR, UiTheme.SIZE_LABEL,
			UiTheme.W_MEDIUM))
	else:
		var button := _button(tr("RE_BUY"), UiTheme.SIZE_LABEL)
		button.pressed.connect(_on_buy.bind(id))
		action.add_child(button)
	row.add_child(action)
	# Niente filetto sotto: a separare gli annunci adesso c'e' il riquadro.
	return card

func _on_buy(id: String) -> void:
	if RealEstate.buy(id):
		# Il segnalino sopra all'edificio deve diventare verde adesso, non la
		# prossima volta che si carica la città.
		GameState.property_bought.emit(id)
		GameState.save_game()
	_rebuild()

## Una riga di testo. Prima ce n'erano due versioni — `_label()` col font del
## gioco e `_numero()` con quello di sistema — perche' `alphabet.fnt` le cifre
## non ce le ha e un prezzo scritto con quello usciva vuoto. Il font del testo
## adesso e' Nunito, che le cifre ce le ha: una funzione sola, e un tranello in
## meno per chi aggiunge una riga.
func _label(text: String, color: Color, size: int,
		weight := UiTheme.W_REGULAR) -> Label:
	return UiTheme.label(text, size, color, weight)

func _button(text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	UiTheme.dress_button(button, UiTheme.primary_boxes(), UiTheme.CARD, size,
		UiTheme.W_BOLD)
	button.custom_minimum_size = Vector2(76, 0)
	button.set_script(BUTTON_SCRIPT)
	return button
