extends CanvasLayer

## La guida: come funziona il giro, aperta dal telefono e letta a tutto schermo.
##
## ## Perché non sta dentro al telefono
##
## Il **tasto** sta lì, in fondo alla rubrica, e quello è giusto: il telefono è
## il posto in cui uno va a cercare le cose, e una guida nascosta in un menu di
## impostazioni non la trova nessuno. Ma il vetro del telefono è largo
## centoquattordici pixel, e sei pagine di spiegazioni lì dentro vengono fuori a
## quattro parole per riga: si scorre per un minuto e non si è letto niente.
##
## Quindi il telefono è dove la si **trova**, questa finestra è dove la si
## **legge**. Sono due lavori diversi e li fanno due schermate diverse.
##
## ## Perché una guida e non un tutorial
##
## Questo è un gestionale, e un gestionale si gioca su dei numeri che il
## giocatore non può indovinare: che una pianta ci metta venti ore, che la sete
## tolga due terzi del raccolto, che una lampada valga per **un** vaso solo e
## non per tutti. Senza queste cose scritte da qualche parte i primi giorni di
## partita sono lenti e sembrano rotti — si pianta, si aspetta, si raccoglie
## meno del previsto, e non c'è modo di capire perché.
##
## Un tutorial le direbbe una volta all'inizio, quando non servono ancora e
## infatti non le legge nessuno. La guida sta sempre lì e si apre quando ci si
## impantana, che è il momento in cui uno ha una domanda — l'unico in cui una
## risposta si legge davvero. È anche il motivo per cui il messaggio d'apertura
## di Brian la nomina: quel messaggio dice che la lentezza è normale, la guida
## dice cosa farci.
##
## ## Com'è fatta
##
## Le sezioni e il loro ordine stanno in `Guide`, il testo in `Strings`: qui non
## c'è una parola scritta a mano. La pelle è quella del gestionale del PC
## (`UiTheme`) e non una nuova: sono la stessa cosa — roba da leggere, non da
## guardare — e due carte diverse nello stesso gioco si notano.
##
## Come il gestionale è un `CanvasLayer` e non un `Control`: sulla tela della
## stanza c'è un `CanvasModulate` che tinge tutto col colore dell'ora, e una
## pagina da leggere che si scurisce di notte è una pagina che di notte non si
## legge.

const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

## Sopra all'HUD e alle finestre delle stanze, sotto al riquadro dei messaggi
## (che sta a 50): un messaggio che arriva mentre si legge deve comparire sopra,
## non sotto.
const LAYER := 48

## Il gruppo che dice all'HUD e al telefono di togliersi di mezzo. La guida
## copre lo schermo, e un telefono che ci galleggia sopra si legge come un pezzo
## di questa finestra.
const MODAL_GROUP := "modal"

## Quanto stanno larghe le righe di testo.
##
## Non è la larghezza della finestra: una riga lunga quattrocentocinquanta pixel
## si legge male perché l'occhio perde il capo della riga dopo. Il margine
## destro in `GuideBook.tscn` è più largo del sinistro apposta, ed è l'unico
## posto del gioco in cui la simmetria si rompe di proposito.
const LINE_SPACING := 3

## Una riga tutta maiuscola che finisce con un punto, all'inizio di un
## paragrafo, diventa un occhiello in grassetto: "PIÙ VASI.", "GROW TOOLKIT.".
##
## È un trucco tipografico e non una struttura dati, e deve restare tale: il
## testo si scrive in `Strings` come si scriverebbe comunque, e chi lo traduce
## non deve imparare nessuna convenzione. Il tetto di caratteri è quello che
## tiene il trucco sicuro — una frase intera maiuscola non è un occhiello.
const CAPTION_MAX := 26

var _sections: Array = []
var _buttons: Array[Button] = []
var _open := 0

@onready var _dimmer: ColorRect = $Root/Dimmer
@onready var _panel: Panel = $Root/Window
@onready var _header: PanelContainer = $Root/Window/Layout/Header
@onready var _title: Label = $Root/Window/Layout/Header/Row/Title
@onready var _lead: Label = $Root/Window/Layout/Header/Row/Lead
@onready var _close: Button = $Root/Window/Layout/Header/Row/Close
@onready var _divider: ColorRect = $Root/Window/Layout/Body/Divider
@onready var _rail: VBoxContainer = $Root/Window/Layout/Body/RailPad/Rail
@onready var _content: VBoxContainer = $Root/Window/Layout/Body/ContentPad/Scroll/Content
@onready var _scroll: ScrollContainer = $Root/Window/Layout/Body/ContentPad/Scroll

func _ready() -> void:
	layer = LAYER
	add_to_group(MODAL_GROUP)
	_sections = Guide.SECTIONS
	_dress()
	_close.pressed.connect(close)
	_build_rail()
	_select(0)

## Mette addosso alla scena la pelle di `UiTheme`. In scena ci sono solo i
## contenitori: tenere anche i colori nel `.tscn` vorrebbe dire cambiare la
## tavolozza in due posti ogni volta.
func _dress() -> void:
	_dimmer.color = UiTheme.DIMMER
	_divider.color = UiTheme.LINE
	_panel.add_theme_stylebox_override("panel", UiTheme.window_box())
	_header.add_theme_stylebox_override("panel", UiTheme.header_box())

	# Il titolo col font disegnato a mano del gioco, come il gestionale: è
	# l'unica riga di questa finestra che deve dire di che gioco è, e le altre
	# quattrocento parole hanno bisogno di un font che si legga.
	_title.add_theme_font_override("font", UiTheme.display())
	_title.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE)
	_title.add_theme_color_override("font_color", UiTheme.INK)

	_lead.add_theme_font_override("font", UiTheme.body(UiTheme.W_MEDIUM))
	_lead.add_theme_font_size_override("font_size", UiTheme.SIZE_LABEL)
	_lead.add_theme_color_override("font_color", UiTheme.INK_FAINT)

	UiTheme.dress_button(_close, UiTheme.ghost_boxes(), UiTheme.INK_SOFT,
		UiTheme.SIZE_LABEL, UiTheme.W_BOLD)
	_close.set_script(BUTTON_SCRIPT)
	_close.use_press_offset = false
	UiTheme.dress_scrollbar(_scroll.get_v_scroll_bar())

func _build_rail() -> void:
	for i in _sections.size():
		var button := Button.new()
		button.text = str(_sections[i]["title"])
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.set_script(BUTTON_SCRIPT)
		button.use_press_offset = false
		button.pressed.connect(_select.bind(i))
		_rail.add_child(button)
		_buttons.append(button)

## Apre una sezione. La voce aperta si accende nella colonna e il testo cambia:
## come il gestionale, e per la stessa ragione — sei paragrafi uno sotto
## l'altro si scorrono, ma per ritrovare quello che serve bisogna rileggerli
## tutti.
func _select(index: int) -> void:
	_open = index
	var boxes := UiTheme.rail_boxes()
	for i in _buttons.size():
		var active := i == index
		UiTheme.dress_button(_buttons[i], {
			"normal": boxes["active"] if active else boxes["normal"],
			"hover": boxes["active"] if active else boxes["hover"],
			"pressed": boxes["active"],
			"disabled": boxes["normal"],
		}, UiTheme.ACCENT_DARK if active else UiTheme.INK_SOFT, UiTheme.SIZE_LABEL,
			UiTheme.W_BOLD if active else UiTheme.W_MEDIUM)
		_buttons[i].alignment = HORIZONTAL_ALIGNMENT_LEFT
	_build_page()

func _build_page() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if _open < 0 or _open >= _sections.size():
		return
	var section: Dictionary = _sections[_open]

	var heading := UiTheme.label(
		tr(str(section["title"])), UiTheme.SIZE_BIG, UiTheme.ACCENT, UiTheme.W_BOLD)
	_content.add_child(heading)
	_content.add_child(_rule())

	# I paragrafi si separano sulla riga vuota. Uno per nodo e non uno solo con
	# gli a-capo dentro: così fra un paragrafo e l'altro c'è l'aria del
	# contenitore invece di una riga vuota, che è il doppio del necessario.
	for piece in tr(str(section["body"])).split("\n\n"):
		var text := str(piece).strip_edges()
		if text.is_empty():
			continue
		var caption := _caption_of(text)
		if not caption.is_empty():
			_content.add_child(UiTheme.label(
				caption, UiTheme.SIZE_LABEL, UiTheme.ACCENT_DARK, UiTheme.W_BOLD))
			text = text.substr(caption.length() + 1).strip_edges()
		_content.add_child(_paragraph(text))
	_scroll.scroll_vertical = 0

## L'occhiello di un paragrafo, "" se non ce n'è uno. Vedi `CAPTION_MAX`.
func _caption_of(text: String) -> String:
	var stop := text.find(". ")
	if stop <= 0 or stop > CAPTION_MAX:
		return ""
	var head := text.substr(0, stop)
	return head if head == head.to_upper() else ""

func _paragraph(text: String) -> Label:
	var label := UiTheme.label(text, UiTheme.SIZE_VALUE, UiTheme.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Un filo d'aria fra le righe. Su un paragrafo di sei righe è la differenza
	# fra un blocco di testo e qualcosa che si legge volentieri.
	label.add_theme_constant_override("line_spacing", LINE_SPACING)
	return label

func _rule() -> Control:
	var rule := ColorRect.new()
	rule.color = UiTheme.LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

## Esc chiude la guida invece di arrivare alla scena sotto: fuori dalle stanze
## Esc torna al menu principale, e chiudere una pagina di appunti non deve
## buttare fuori dalla partita.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	queue_free()
