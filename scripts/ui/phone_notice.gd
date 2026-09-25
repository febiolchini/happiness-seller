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
##
## **Non è il posto dei messaggi di Brian.** Quelli arrivano sul telefono
## (`GameState.text_message()`): lui scrive, non ti compare davanti. Qui ci
## finisce solo quello che non ha un mittente umano — la bolletta, il personale
## che se ne va, il resoconto di quello che è successo a gioco chiuso.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

## Sopra all'HUD (che sta a 1) e sopra alle finestre della stanza.
const LAYER := 50

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
	shade.color = UiTheme.DIMMER
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var style := UiTheme.window_box()
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)

	var speaker_label := UiTheme.window_label(_speaker, UiTheme.brush_size(UiTheme.SIZE_BIG),
		UiTheme.SIZE_BIG, UiTheme.INK, UiTheme.W_BOLD)
	rows.add_child(speaker_label)

	var body_label := UiTheme.window_label(_body, UiTheme.brush_size(UiTheme.SIZE_VALUE),
		UiTheme.SIZE_VALUE, UiTheme.INK_SOFT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(body_label)

	var close_button := Button.new()
	close_button.text = "MSG_OK"
	close_button.focus_mode = Control.FOCUS_NONE
	UiTheme.dress_button(close_button, UiTheme.primary_boxes(), UiTheme.CARD,
		UiTheme.SIZE_VALUE, UiTheme.W_BOLD)
	close_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
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
