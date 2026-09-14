extends Control

## Il telefono: i messaggi che arrivano al giocatore, e la scorciatoia per
## chiamare Brian senza tornare al PC in cantina.
##
## Segnaposto disegnato a mano come tutto il resto — quando arriverà la pixel
## art il `_draw()` diventa una texture e nient'altro cambia.
##
## ## Perché un telefono e non un altro messaggino dell'HUD
##
## L'HUD ha già i messaggini (`GameState.notify()`): durano due secondi e mezzo
## e servono per le cose che si leggono con la coda dell'occhio — "+40 g
## raccolti". Due cose però non ci stanno dentro:
##
## 1. **Vengono da qualcuno.** "I semi sono finiti" lo dice il personale, "sono
##    arrivato" lo dice Brian. Un messaggino senza mittente è il gioco che
##    parla; un messaggio sul telefono è una persona che scrive, ed è la
##    differenza fra un promemoria e un pezzo di mondo.
## 2. **Vanno ritrovate.** Il messaggino se ne va dopo due secondi e mezzo.
##    L'ultimo messaggio arrivato resta invece dentro al telefono finché non ne
##    arriva un altro (vive su `GameState`, quindi non si perde nemmeno
##    cambiando stanza), e si rilegge aprendolo.
##
## Resta separato anche dal riquadro a tutto schermo di `phone_notice.gd`:
## quello ferma tutto per le cose che non si possono perdere — la fine del
## prologo — e si chiude con un bottone. Questo scivola su, si legge e se ne va
## da solo, senza togliere il controllo di mano.
##
## ## Come si apre
##
## Chiuso non sparisce del tutto: resta fuori la linguetta in alto, col
## triangolino. Si apre con la **freccia su** o cliccandoci sopra. È il motivo
## per cui il telefono non è mai completamente fuori schermo — una scorciatoia
## che non si vede da nessuna parte non la trova nessuno.

## Quanto è grande il telefono, e quanto sta dentro al bordo dello schermo.
##
## Largo 132 e non 116 come al primo tentativo: a 116 il corpo del messaggio
## andava a capo ogni tre parole e una frase normale diventava sette righe, che
## non ci stavano nello schermo del telefono.
const SIZE := Vector2(132.0, 184.0)
const LEFT := 10.0
## Quanto resta fuori quando è chiuso: la linguetta con il triangolino.
const HANDLE := 16.0
## Quanto resta fuori quando c'è un messaggio da leggere: la linguetta più lo
## schermo fino in fondo al corpo del messaggio, senza il menù. Va tenuto
## allineato con il bordo inferiore della Label `Text` in `Phone.tscn`: se
## scende sotto, il messaggio si legge tagliato a metà dal bordo dello schermo.
const PEEK := 130.0

## Quanto dura un messaggio a schermo prima che il telefono si richiuda da solo.
##
## Più lungo dei messaggini dell'HUD: questi hanno un mittente e una frase
## intera da leggere, non tre parole e un numero.
const MESSAGE_SECONDS := 5.5
const SLIDE_SECONDS := 0.38

## Nascosto mentre una finestra modale è aperta, come l'HUD: il gestionale del
## PC e i riquadri del telefono coprono lo schermo, e un telefono che ci
## galleggia sopra si legge come un pezzo di quella finestra.
const MODAL_GROUP := "modal"

const GAME_FONT := preload("res://assets/sprites/ui/alphabet.fnt")
const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

const BODY := Color(0.09, 0.10, 0.13)
const RIM := Color(0.32, 0.34, 0.40)
const SCREEN := Color(0.13, 0.17, 0.19)
const SCREEN_LIT := Color(0.16, 0.22, 0.24)
const HANDLE_ARROW := Color(0.62, 0.66, 0.74)
## Il colore di quando c'è qualcosa da leggere: lo stesso verde del rombo sopra
## la testa di chi vende, così "c'è una cosa per te" è sempre quel verde lì.
const ALERT := Color(0.55, 0.85, 0.45)

## Spento quando la mappa fa solo da sfondo a un menu, come l'HUD: senza questo
## la linguetta comparirebbe dietro ai bottoni del menu principale.
@export var enabled := true:
	set(value):
		enabled = value
		set_process(value)
		set_process_unhandled_input(value)
		visible = value

enum State { CLOSED, MESSAGE, OPEN }

var _state := State.CLOSED
var _slide: Tween = null
var _left_open := 0.0
## Pulsa finché il messaggio non è stato aperto almeno una volta.
var _unread := false
var _time := 0.0

@onready var _sender: Label = $Sender
@onready var _body: Label = $Text
@onready var _menu: VBoxContainer = $Menu
var _call: Button = null

func _ready() -> void:
	size = SIZE
	position = Vector2(LEFT, _target_y())
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_menu()
	GameState.phone_message.connect(_on_message)
	GameSettings.locale_changed.connect(_on_locale_changed)
	# Un messaggio può essere arrivato mentre si era in un'altra scena: il
	# telefono è per scena, ma quello che c'è scritto dentro vive su
	# `GameState` e lo ritrova entrando.
	_show_stored()
	_refresh()

func _process(delta: float) -> void:
	_time += delta
	if _state == State.MESSAGE:
		_left_open -= delta
		if _left_open <= 0.0:
			_set_state(State.CLOSED)
	# Il modale copre lo schermo: il telefono si toglie di mezzo e torna quando
	# la finestra si chiude, senza perdere quello che aveva dentro.
	var hidden := _modal_open()
	if hidden == visible and enabled:
		visible = not hidden
	if _state != State.CLOSED or _unread:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _modal_open():
		return
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_set_state(State.CLOSED if _state == State.OPEN else State.OPEN)
		return
	# Esc chiude il telefono invece di uscire dalla partita: chi lo ha appena
	# aperto si aspetta che il primo Esc chiuda quello, non il gioco.
	if _state == State.OPEN and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_set_state(State.CLOSED)

## Un click sulla linguetta apre e chiude, come la freccia su. Il resto del
## corpo si mangia il click e basta: è un oggetto davanti alla scena, e un click
## che lo attraversa manderebbe il protagonista a camminare sotto al telefono.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if (event as InputEventMouseButton).position.y <= HANDLE:
		_set_state(State.CLOSED if _state == State.OPEN else State.OPEN)

# --- I messaggi -------------------------------------------------------------

func _on_message(sender: String, body: String) -> void:
	_sender.text = sender
	_body.text = body
	_unread = true
	_set_state(State.MESSAGE)

## L'ultimo messaggio arrivato, ripescato da `GameState` entrando in scena.
func _show_stored() -> void:
	var stored := GameState.last_text
	if stored.is_empty():
		return
	_sender.text = str(stored.get("sender", ""))
	_body.text = str(stored.get("body", ""))

func _on_locale_changed(_locale: String) -> void:
	_refresh()

# --- Stato e scivolata ------------------------------------------------------

func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next
	if _state == State.MESSAGE:
		_left_open = MESSAGE_SECONDS
	if _state == State.OPEN:
		# Aperto vuol dire letto: la linguetta smette di pulsare.
		_unread = false
	_menu.visible = _state == State.OPEN
	_refresh()

	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	# Un rimbalzo corto in uscita: un telefono che sale dritto e si ferma di
	# netto si legge come un pannello che compare, non come una cosa che entra.
	_slide.set_trans(Tween.TRANS_BACK if _state != State.CLOSED else Tween.TRANS_QUAD)
	_slide.set_ease(Tween.EASE_OUT if _state != State.CLOSED else Tween.EASE_IN)
	_slide.tween_property(self, "position:y", _target_y(), SLIDE_SECONDS)

func _target_y() -> float:
	var view := get_viewport_rect().size.y
	match _state:
		State.OPEN:
			return view - SIZE.y - 4.0
		State.MESSAGE:
			return view - PEEK
		_:
			return view - HANDLE

# --- Il menù ----------------------------------------------------------------

## Per ora una voce sola: chiamare Brian. È la stessa cosa che fa il bottone
## nella scheda GROW del PC, e non è un doppione per sbaglio — i semi finiscono
## mentre si è in giro per la città, e l'unico modo di chiederne altri era
## tornare in cantina ad aprire il PC, cioè attraversare la mappa per premere un
## bottone.
func _build_menu() -> void:
	_call = Button.new()
	_call.flat = true
	_call.focus_mode = Control.FOCUS_NONE
	_call.clip_text = true
	_call.add_theme_font_override("font", GAME_FONT)
	_call.add_theme_font_size_override("font_size", 12)
	_call.add_theme_color_override("font_color", Color(0.90, 0.92, 0.86))
	_call.add_theme_color_override("font_disabled_color", Color(0.42, 0.45, 0.50))
	_call.set_script(BUTTON_SCRIPT)
	_call.use_press_offset = false
	_call.pressed.connect(_call_brian)
	_menu.add_child(_call)

func _call_brian() -> void:
	if not SeedDeal.ask(GameState.current, GameState.total_hours()):
		return
	GameState.notify(tr("NOTE_ASKED_BRIAN"))
	_refresh()

## Riscrive quello che cambia con lo stato della partita: il testo del bottone e
## se è premibile. Come nel PC, **un bottone solo che cambia faccia** invece di
## tre che si accendono a turno — la riga dice sempre qual è la prossima cosa
## che succede, e quando non c'è niente da fare lo dice spenta.
func _refresh() -> void:
	if _call == null:
		return
	var data := GameState.current
	if data == null:
		_call.disabled = true
		return
	if SeedDeal.is_waiting(data):
		_call.text = tr("PHONE_WAITING")
	elif SeedDeal.is_ready(data):
		_call.text = tr("PHONE_BRIAN_HERE")
	else:
		_call.text = tr("PHONE_CALL_BRIAN")
	_call.disabled = not SeedDeal.can_ask(data)

func _modal_open() -> bool:
	return not get_tree().get_nodes_in_group(MODAL_GROUP).is_empty()

# --- Disegno segnaposto -----------------------------------------------------

func _draw() -> void:
	# Scocca e bordo. Il corpo è più alto del telefono di qualche pixel: quando
	# è chiuso, il bordo inferiore non deve comparire a mezz'aria sopra al
	# fondo dello schermo.
	draw_rect(Rect2(0, 0, SIZE.x, SIZE.y + 8.0), BODY, true)
	draw_rect(Rect2(0, 0, SIZE.x, SIZE.y + 8.0), RIM, false, 1.0)
	_draw_handle()

	var lit := _state != State.CLOSED
	var glass := Rect2(6.0, HANDLE + 6.0, SIZE.x - 12.0, SIZE.y - HANDLE - 14.0)
	draw_rect(glass, SCREEN_LIT if lit else SCREEN, true)
	if not lit:
		return
	_draw_status(glass)
	if _state == State.OPEN and _sender.text.is_empty():
		return
	# La riga che separa il messaggio dal menù, tracciata solo quando il menù
	# c'è: a telefono chiuso sarebbe una riga sospesa sotto al testo.
	if _state == State.OPEN:
		var y := _menu.position.y - 6.0
		draw_line(Vector2(glass.position.x + 6.0, y), Vector2(glass.end.x - 6.0, y), RIM, 1.0)

## La linguetta che resta fuori a telefono chiuso, col triangolino che dice da
## che parte si apre. Pulsa finché c'è un messaggio non letto: è l'unica cosa
## che si vede di questo telefono per la maggior parte della partita, quindi è
## anche l'unico posto in cui si può dire "c'è qualcosa per te".
func _draw_handle() -> void:
	var color := HANDLE_ARROW
	if _unread:
		color = ALERT
		color.a = 0.65 + 0.35 * sin(_time * 5.0)
	var middle := SIZE.x * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(middle, 4.0), Vector2(middle + 5.0, 11.0), Vector2(middle - 5.0, 11.0),
	]), color)
	draw_line(Vector2(6.0, HANDLE), Vector2(SIZE.x - 6.0, HANDLE), RIM, 1.0)

## La riga di stato in cima allo schermo: tacche e orologio. Non serve a
## niente, ed è esattamente il motivo per cui c'è — è quello che rende uno
## schermo un telefono invece di un rettangolo con del testo dentro.
func _draw_status(glass: Rect2) -> void:
	var font := ThemeDB.fallback_font
	for i in 3:
		var tall := 3.0 + float(i) * 2.0
		draw_rect(Rect2(glass.position.x + 5.0 + float(i) * 4.0, glass.position.y + 9.0 - tall, 2.0, tall),
			Color(0.55, 0.62, 0.60), true)
	if font == null or GameState.current == null:
		return
	var clock := UiFormat.clock(GameState.current.time_of_day)
	var width := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(
		font, Vector2(glass.end.x - width - 5.0, glass.position.y + 9.0), clock,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.62, 0.60))
