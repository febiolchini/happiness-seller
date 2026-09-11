extends CanvasLayer

## Il messaggio che arriva sul telefono: un riquadro con chi scrive, cosa dice e
## un bottone per chiuderlo.
##
## Serve per le cose che il giocatore non deve perdersi — la fine del prologo,
## il cugino che suggerisce di assumere qualcuno — e per quelle i messaggini
## dell'HUD non bastano: durano due secondi e mezzo, l'HUD non c'è dentro alle
## stanze, e proprio in cantina davanti al PC è dove il giocatore si trova più
## spesso quando questa roba succede.
##
## Viene appesa a `GameState`, che è un autoload e quindi sta nell'albero sopra
## alla scena corrente: così il messaggio compare uguale in strada e in cantina,
## e non sparisce se nel frattempo si cambia stanza. Vedi `GameState.message()`.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")
const GAME_FONT := preload("res://assets/sprites/ui/alphabet.fnt")

## Sopra all'HUD (che sta a 1) e sopra alle finestre della stanza.
const LAYER := 50
const PANEL := Color(0.11, 0.12, 0.15, 0.97)
const BORDER := Color(0.69, 0.54, 0.31, 0.9)

var _speaker := ""
var _body := ""

## Riempie il riquadro. Va chiamata **prima** di aggiungerlo all'albero: i nodi
## veri si creano in `_ready()`, e questo evita di doverli tenere insieme a un
## `@onready` che non c'è ancora.
func setup(speaker: String, body: String) -> void:
	_speaker = speaker
	_body = body

func _ready() -> void:
	layer = LAYER
	# Copre tutto lo schermo con la tendina scura: l'HUD dietro non serve.
	add_to_group("modal")
	# Il tempo di gioco continua a scorrere: un messaggio non è una pausa, e
	# fermare l'orologio qui vorrebbe dire fermarlo anche a chi lo lascia aperto.
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)

	var speaker_label := Label.new()
	speaker_label.text = _speaker
	speaker_label.add_theme_font_override("font", GAME_FONT)
	speaker_label.add_theme_font_size_override("font_size", 18)
	speaker_label.add_theme_color_override("font_color", Color(1, 0.86, 0.35))
	rows.add_child(speaker_label)

	var body_label := Label.new()
	body_label.text = _body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 13)
	body_label.add_theme_color_override("font_color", Color(0.92, 0.91, 0.85))
	rows.add_child(body_label)

	var close_button := Button.new()
	close_button.text = "MSG_OK"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_override("font", GAME_FONT)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	close_button.set_script(BUTTON_SCRIPT)
	close_button.use_press_offset = false
	close_button.pressed.connect(queue_free)
	rows.add_child(close_button)

## Esc (o invio) chiude il messaggio, come il bottone.
##
## L'evento va segnato come già gestito, altrimenti arriva anche alla scena
## sotto: fuori dalle stanze Esc torna al menu principale, e chiudere un
## messaggio butterebbe fuori dalla partita. `set_input_as_handled()` e non
## `accept_event()`, che è un metodo di `Control` e qui non c'è: questo è un
## `CanvasLayer`, per stare sopra alla scena qualunque essa sia.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		queue_free()
