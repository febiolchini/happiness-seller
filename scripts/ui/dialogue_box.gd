extends CanvasLayer

## Finestra di dialogo con scelte: la usano tutti gli NPC della città.
##
## È volutamente **generica**: non sa niente di semi, grammi o prezzi. Chi apre
## il dialogo passa il testo già scritto e una lista di scelte, dove ogni scelta
## è un'etichetta e una `Callable`. Così la logica di un personaggio sta nel suo
## ruolo (`npc.gd`) e questa scena resta l'unico posto in cui si decide come
## sono fatti i dialoghi.
##
## Le scelte vengono create a runtime perché il loro numero cambia da un
## personaggio all'altro e da un momento all'altro della partita: quanti tagli
## di vendita può offrire un cliente dipende da quanta merce hai in tasca.

## Emesso alla chiusura, in qualunque modo sia avvenuta. Gli NPC lo usano per
## ricominciare a camminare.
signal closed

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")
const BODY_FONT_SIZE := 12
const CHOICE_FONT_SIZE := 13

@onready var _speaker: Label = $Root/Panel/Margin/Rows/Speaker
@onready var _body: Label = $Root/Panel/Margin/Rows/Body
@onready var _choices: VBoxContainer = $Root/Panel/Margin/Rows/Choices

## Alzata da `open()` per sapere se l'azione di una scelta ha riaperto il
## dialogo (i negozi si riscrivono da soli dopo un acquisto). Senza questo
## controllo la finestra si chiuderebbe subito dopo essere stata riaperta.
var _reopened := false

func _ready() -> void:
	visible = false

func is_open() -> bool:
	return visible

## `choices` è una lista di dizionari:
##   `label`     testo del bottone
##   `action`    Callable chiamata al click (opzionale)
##   `enabled`   false per mostrarla spenta, es. soldi insufficienti (opzionale)
##   `keep_open` true se l'azione si occupa lei di riaprire o chiudere
func open(speaker: String, body: String, choices: Array = []) -> void:
	_reopened = true
	_speaker.text = speaker
	_body.text = body
	for child in _choices.get_children():
		child.queue_free()
	for choice in choices:
		_choices.add_child(_build_choice(choice))
	_choices.visible = not choices.is_empty()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _build_choice(choice: Dictionary) -> Button:
	var button := Button.new()
	button.text = str(choice["label"])
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	# Font di sistema e non quello del gioco: le scelte contengono cifre e
	# `alphabet.fnt` ha solo lettere, quindi i prezzi sparirebbero.
	button.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	button.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.50))
	button.disabled = not bool(choice.get("enabled", true))
	button.set_script(BUTTON_SCRIPT)
	button.use_press_offset = false
	button.pressed.connect(_on_choice.bind(choice))
	return button

func _on_choice(choice: Dictionary) -> void:
	_reopened = false
	var action: Callable = choice.get("action", Callable())
	if action.is_valid():
		action.call()
	# Chi ha `keep_open` si è già riscritto da solo (o ha chiuso di proposito):
	# in tutti gli altri casi una scelta conclude la conversazione.
	if not _reopened and not bool(choice.get("keep_open", false)):
		close()

## Esc chiude il dialogo e **non** deve arrivare alla mappa, che con Esc torna
## al menu principale. `_input` gira prima di `_unhandled_input` di `city.gd`,
## quindi basta segnare l'evento come gestito.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		close()
