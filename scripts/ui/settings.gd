extends "res://scripts/ui/menu_cursor.gd"

## Le impostazioni. Per ora l'unica voce che fa davvero qualcosa è la lingua:
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

const GAME_FONT := preload("res://assets/sprites/ui/alphabet.fnt")
const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

const ACTIVE_COLOR := Color(1, 0.86, 0.35)
const IDLE_COLOR := Color(0.78, 0.79, 0.82)
const LABEL_COLOR := Color(0.55, 0.57, 0.62)

## Dove comincia la colonna delle lingue, a destra delle voci di sezione.
const COLUMN_X := 240.0
const ROW_HEIGHT := 24.0
const FONT_SIZE := 16

@onready var _ui: CanvasLayer = $UI

## locale -> bottone, per riaccendere quello giusto quando la lingua cambia.
var _buttons: Dictionary = {}

func _ready() -> void:
	super()
	_build_language_column()
	GameSettings.locale_changed.connect(_on_locale_changed)
	_highlight(GameSettings.locale)

func _build_language_column() -> void:
	var title := Label.new()
	title.text = "MENU_LANGUAGE"
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", FONT_SIZE)
	title.add_theme_color_override("font_color", LABEL_COLOR)
	_place(title, 0)
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
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", GAME_FONT)
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.set_script(BUTTON_SCRIPT)
		button.use_press_offset = false
		button.pressed.connect(_choose.bind(locale))
		_place(button, i + 1)
		_ui.add_child(button)
		_buttons[locale] = button

## Riga `row` della colonna, agganciata al centro verticale come le voci di
## sezione a sinistra: così le due colonne restano allineate a qualunque
## risoluzione.
func _place(node: Control, row: int) -> void:
	node.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	node.offset_left = COLUMN_X
	node.offset_right = COLUMN_X + 200.0
	node.offset_top = -30.0 + ROW_HEIGHT * float(row)
	node.offset_bottom = node.offset_top + 18.0

func _choose(locale: String) -> void:
	GameSettings.locale = locale
	GameSettings.save()

func _on_locale_changed(locale: String) -> void:
	_highlight(locale)

func _highlight(locale: String) -> void:
	for key in _buttons:
		var button: Button = _buttons[key]
		button.add_theme_color_override(
			"font_color", ACTIVE_COLOR if key == locale else IDLE_COLOR)
