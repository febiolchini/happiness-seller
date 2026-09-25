extends "res://scripts/ui/menu_cursor.gd"

## Le impostazioni. Le voci che fanno davvero qualcosa sono due — la lingua e
## se il mondo va avanti a gioco chiuso — e stanno in due colonne a destra;
## video, audio e comandi sono lì come segnaposto delle sezioni che verranno.
##
## I bottoni della lingua sono costruiti dal codice e non messi nella scena,
## per la stessa ragione per cui lo sono le righe del gestionale: l'elenco è
## `Strings.LOCALES`, e aggiungere una lingua deve voler dire aggiungere una
## riga alla tabella e nient'altro. Tre bottoni scritti a mano nel `.tscn`
## sarebbero la stessa lista mantenuta due volte.
##
## Il cambio è **immediato e definitivo**: si clicca e la schermata è già
## nell'altra lingua, senza un tasto "applica" da premere dopo. Il riscontro è
## la schermata stessa che cambia sotto le mani, ed è più chiaro di qualunque
## conferma; e salvare subito vuol dire che chiudere il gioco dalla croce non
## butta via la scelta.
##
## Il mondo offline segue la stessa regola, e anche lui è fatto di bottoni e non
## di una casella da spuntare: sono due scelte in fila, quella accesa si legge
## dal colore come la lingua, e chi apre questa schermata vede subito **quale
## delle due** è la sua senza dover sapere cosa vuol dire una casella vuota.
## Vale da subito per tutte le partite: vedi `GameSettings.offline_progress`.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

const ACTIVE_COLOR := Color(1, 0.86, 0.35)
const IDLE_COLOR := Color(0.78, 0.79, 0.82)
const LABEL_COLOR := Color(0.55, 0.57, 0.62)

## Dove cominciano le due colonne, a destra delle voci di sezione: la lingua e
## il mondo offline. Affiancate e non una sotto l'altra perché sono due elenchi
## corti e indipendenti, e messi in colonna unica arriverebbero a sfiorare il
## fondo dello schermo mentre a sinistra resta tutto vuoto.
const LANGUAGE_X := 232.0
const OFFLINE_X := 408.0
const COLUMN_WIDTH := 180.0
## Un passo di riga uguale a quello delle voci di sezione in `Settings.tscn`
## (28 px, a partire da -36): le due colonne restano allineate a loro.
const ROW_HEIGHT := 28.0
const ROW_TOP := -36.0
const FONT_SIZE := UiTheme.MENU_ITEM

## Le due scelte del mondo offline, nell'ordine in cui stanno in colonna: prima
## quella accesa, che è anche quella di ripiego.
const OFFLINE_KEYS := ["MENU_OFFLINE_ON", "MENU_OFFLINE_OFF"]

@onready var _ui: CanvasLayer = $UI

## locale -> bottone, per riaccendere quello giusto quando la lingua cambia.
var _buttons: Dictionary = {}

## I due bottoni del mondo offline, nell'ordine [acceso, spento].
var _offline_buttons: Array[Button] = []

func _ready() -> void:
	super()
	_build_language_column()
	_build_offline_column()
	GameSettings.locale_changed.connect(_on_locale_changed)
	_highlight(GameSettings.locale)
	_highlight_offline()

func _build_language_column() -> void:
	var title := Label.new()
	title.text = "MENU_LANGUAGE"
	UiTheme.dress_menu_text(title, FONT_SIZE)
	title.add_theme_color_override("font_color", LABEL_COLOR)
	_place(title, 0, LANGUAGE_X)
	_ui.add_child(title)

	for i in Strings.LOCALES.size():
		var locale: String = Strings.LOCALES[i]
		var button := Button.new()
		# Il nome della lingua si scrive **nella lingua stessa** e non si
		# traduce: chi apre le impostazioni per uscire da una lingua che non
		# capisce deve poter riconoscere la sua, e "ITALIANO" tradotto in
		# spagnolo non aiuterebbe nessuno.
		button.text = Strings.locale_name(locale)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_dress(button)
		button.pressed.connect(_choose.bind(locale))
		_place(button, i + 1, LANGUAGE_X)
		_ui.add_child(button)
		_buttons[locale] = button

## La colonna del mondo offline: il titolo e le due scelte.
##
## I bottoni sono due e non uno che cambia scritta: un bottone solo direbbe o
## quello che il mondo fa adesso o quello che succederebbe a premerlo, e da
## fuori non si capisce quale delle due — è lo stesso equivoco di un
## interruttore senza etichetta.
func _build_offline_column() -> void:
	var title := Label.new()
	title.text = "MENU_OFFLINE"
	UiTheme.dress_menu_text(title, FONT_SIZE)
	title.add_theme_color_override("font_color", LABEL_COLOR)
	_place(title, 0, OFFLINE_X)
	_ui.add_child(title)

	for i in OFFLINE_KEYS.size():
		var button := Button.new()
		button.text = OFFLINE_KEYS[i]
		_dress(button)
		button.pressed.connect(_choose_offline.bind(i == 0))
		_place(button, i + 1, OFFLINE_X)
		_ui.add_child(button)
		_offline_buttons.append(button)

## Tutto quello che i bottoni di questa schermata hanno in comune. Sta in un
## posto solo o le due colonne finirebbero per assomigliarsi solo finché
## qualcuno non tocca una delle due.
func _dress(button: Button) -> void:
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	UiTheme.dress_menu_text(button, FONT_SIZE)
	button.set_script(BUTTON_SCRIPT)
	button.use_press_offset = false

## Riga `row` della colonna, agganciata al centro verticale come le voci di
## sezione a sinistra: così le due colonne restano allineate a qualunque
## risoluzione.
func _place(node: Control, row: int, column_x: float) -> void:
	node.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	node.offset_left = column_x
	node.offset_right = column_x + COLUMN_WIDTH
	node.offset_top = ROW_TOP + ROW_HEIGHT * float(row)
	node.offset_bottom = node.offset_top + 26.0

func _choose(locale: String) -> void:
	GameSettings.locale = locale
	GameSettings.save()

func _choose_offline(enabled: bool) -> void:
	GameSettings.offline_progress = enabled
	GameSettings.save()
	_highlight_offline()

func _on_locale_changed(locale: String) -> void:
	_highlight(locale)

func _highlight(locale: String) -> void:
	for key in _buttons:
		var button: Button = _buttons[key]
		button.add_theme_color_override(
			"font_color", ACTIVE_COLOR if key == locale else IDLE_COLOR)

func _highlight_offline() -> void:
	for i in _offline_buttons.size():
		_offline_buttons[i].add_theme_color_override(
			"font_color",
			ACTIVE_COLOR if (i == 0) == GameSettings.offline_progress else IDLE_COLOR)
