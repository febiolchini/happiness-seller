extends Control

## Il telefono: i messaggi che arrivano al giocatore, e la chat con Brian.
##
## La scocca è un disegno (`assets/sprites/ui/phone.png`, nel nodo `Shell`), non
## un rettangolo tracciato a mano. Il `_draw()` di qui è rimasto per quello che
## sta **sopra** al vetro e cambia mentre si gioca: il velo dello schermo
## acceso, le tacche, l'orologio, il triangolino che pulsa, la freccia indietro.
## `Shell` ha `show_behind_parent`, quindi il disegno passa sotto a tutto questo
## e le nuvolette dei messaggi gli passano sopra.
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
## 2. **Vanno ritrovate.** Il messaggino se ne va dopo due secondi e mezzo. Un
##    messaggio del telefono si rilegge, e quelli dei traguardi si rileggono
##    anche tre giorni dopo: restano nella chat. Vedi `Chat`.
##
## **Tutto quello che ha un mittente passa da qui.** Per un periodo gli annunci
## importanti — l'inizio, la fine del prologo, il chilo — comparivano invece
## dentro a una nuvoletta da fumetto a schermo intero. Adesso arrivano sul
## telefono come tutti gli altri, ed è più giusto così: Brian non ti appare
## davanti, ti scrive.
##
## ## Le due cose che il telefono fa, e restano due
##
## - **L'avviso.** Arriva un messaggio, il telefono sale quel tanto che basta a
##   leggerlo (`State.MESSAGE`), e dopo cinque secondi e mezzo torna giù. Si
##   legge senza fare niente, mentre si sta giocando.
## - **La rubrica.** Aperto (`State.OPEN`), il telefono è un'app di messaggi:
##   l'elenco dei contatti, e dentro a ognuno la chat. Da lì si chiedono i semi
##   a Brian e si rileggono i messaggi vecchi.
## - **Il tasto della guida.** In fondo alla rubrica, staccato dai contatti.
##   Quello che apre non è una terza schermata del telefono: è una finestra a
##   tutto schermo (`GuideBook`), perché sei pagine di spiegazioni su un vetro
##   largo centoquattordici pixel non si leggono. Il telefono è il posto in cui
##   la si **trova**, non quello in cui la si legge.
##
## Le due cose non si mescolano: l'avviso mostra **un** messaggio scritto grande
## sul mezzo telefono che spunta, la chat mostra **tutto** il filo e chiede di
## fermarsi a guardarla. Farle convivere vorrebbe dire scrivere lo stesso
## messaggio due volte, una sopra all'altra.
##
## ## Come si apre
##
## Chiuso non sparisce del tutto: resta fuori la cima del telefono, col
## triangolino. Si apre con la **freccia su** o cliccandoci sopra. È il motivo
## per cui il telefono non è mai completamente fuori schermo — una scorciatoia
## che non si vede da nessuna parte non la trova nessuno.
##
## Aprendolo si arriva sulla rubrica, **tranne** quando c'è un messaggio non
## letto: in quel caso si va dritti nella chat di chi ha scritto. È quello che
## fa un telefono vero quando si tocca la notifica, e toglie il click in più
## proprio quando il giocatore sa già dove vuole andare.
##
## Esc torna indietro di un passo per volta — dalla chat alla rubrica, dalla
## rubrica al telefono chiuso — mentre la freccia su apre e chiude e basta:
## sono due gesti diversi, "torna indietro" e "metti via il telefono".

## Quanto è grande il telefono, dove sta il vetro dentro alla scocca, e dove sta
## il notch dentro al vetro.
##
## **Non sono misure prese a occhio.** Le stampa
## `scripts_tools/import_phone_art.py` misurandole sul disegno mentre lo riduce
## alla taglia del gioco: se la scocca viene ridisegnata si rilancia quello e si
## ricopiano qui. Tutto quello che `_draw()` mette a schermo, e tutti i nodi di
## `Phone.tscn`, stanno dentro a questi tre rettangoli — un vetro spostato di
## tre pixel manda il testo a finire sopra alla cornice.
##
## Largo 140 e non 132 come il segnaposto: la scocca vera ha le proporzioni di
## un telefono vero, molto più stretto, e la cornice si mangia un settimo della
## larghezza. A 132 il vetro scendeva sotto ai 112 px che servono al bottone
## (`Strings.PHONE_MENU_CHARS`), e "LLAMA A BRIAN" si tagliava. L'altezza non si
## sceglie: viene dietro alle proporzioni del disegno.
const SIZE := Vector2(140.0, 258.0)
const GLASS := Rect2(12.0, 9.0, 116.0, 240.0)
const NOTCH := Rect2(40.0, 9.0, 60.0, 9.0)
const LEFT := 10.0
## Quanto resta fuori quando è chiuso: la cima del telefono — cornice, notch, e
## il triangolino sotto. Più alta della linguetta finta di prima perché adesso
## non è una linguetta: è la fetta di telefono vero che spunta, e il triangolino
## non può stare sopra al notch.
const HANDLE := 34.0
## Quanto resta fuori quando c'è un messaggio da leggere: la cima più lo schermo
## fino in fondo al corpo del messaggio. Va tenuto allineato con il bordo
## inferiore della Label `Text` in `Phone.tscn`: se scende sotto, il messaggio
## si legge tagliato a metà dal bordo dello schermo.
##
## Centonovantaquattro e non centosettantotto perché il messaggio d'apertura —
## il più lungo che il gioco manda, ed è anche il primo che si legge — a
## centosettantotto perdeva l'ultima riga, che è proprio quella che manda alla
## guida. Una riga sola di schermo in più, e vale solo per i cinque secondi e
## mezzo in cui il messaggio è a schermo.
const PEEK := 194.0
## Il triangolino che dice da che parte si apre: sotto al notch, in mezzo.
## Sotto e non dentro — nella riga del notch ci stanno già le tacche e
## l'orologio, e in mezzo c'è il notch stesso.
const ARROW_TOP := 22.0
const ARROW_SIZE := Vector2(5.0, 7.0)
## La freccia indietro della chat, in alto a sinistra sopra al filetto. È anche
## il rettangolo che si clicca.
##
## Disegnata e non un `Button` con dentro un "<": quel segno non è una parola e
## non si traduce, e in un bottone sarebbe l'unico pezzo di interfaccia del
## gioco scritto con un carattere invece che disegnato.
const BACK := Rect2(14.0, 30.0, 12.0, 16.0)
## Il filetto sotto all'intestazione.
const HEADER_LINE := 48.0
## Fin dove arriva l'elenco. Corto solo dove sotto c'è il bottone, cioè nella
## chat: sulla rubrica quei quaranta pixel sono una riga in più di elenco.
const LIST_BOTTOM := 202.0
const LIST_BOTTOM_FULL := 242.0

## Quanto dura un messaggio a schermo prima che il telefono si richiuda da solo.
##
## Più lungo dei messaggini dell'HUD: questi hanno un mittente e una frase
## intera da leggere, non tre parole e un numero.
const MESSAGE_SECONDS := 5.5
const SLIDE_SECONDS := 0.38

const GAME_FONT := preload("res://assets/sprites/ui/alphabet.fnt")
const BUTTON_SCRIPT := preload("res://scripts/ui/interactive_button.gd")

## Il vetro spento non si disegna: c'è già nel disegno della scocca, riflesso
## compreso. Acceso ci si stende sopra un velo, che è semitrasparente apposta —
## coprirlo del tutto vorrebbe dire cancellare il riflesso e rimettere a schermo
## il rettangolo piatto di prima.
const SCREEN_LIT := Color(0.16, 0.22, 0.24, 0.72)
const RIM := Color(0.32, 0.34, 0.40)
const STATUS := Color(0.55, 0.62, 0.60)
const HANDLE_ARROW := Color(0.62, 0.66, 0.74)
## Il colore di quando c'è qualcosa da leggere: lo stesso verde del rombo sopra
## la testa di chi vende, così "c'è una cosa per te" è sempre quel verde lì.
const ALERT := Color(0.55, 0.85, 0.45)

## Le nuvolette. Due tinte spente e non due colori accesi: stanno su un vetro
## scuro, e quello che deve staccare è il testo, non lo sfondo. Da che parte
## arriva un messaggio si legge dal **lato** prima ancora che dal colore, ed è
## quello che rende un filo di messaggi leggibile senza guardarlo.
const BUBBLE_THEM := Color(0.22, 0.26, 0.29)
const BUBBLE_MINE := Color(0.22, 0.36, 0.30)
const BUBBLE_INK := Color(0.88, 0.90, 0.88)
## La riga della rubrica: da spenta non ha sfondo, si accende passandoci sopra.
const ROW_HOVER := Color(1.0, 1.0, 1.0, 0.07)
const NAME_INK := Color(1.0, 0.86, 0.35)
const PREVIEW_INK := Color(0.58, 0.63, 0.62)

## Quanto può essere larga la scritta dentro a una nuvoletta. Il resto lo decide
## la frase: una nuvoletta larga sempre uguale farebbe di "ci penso io" un
## rettangolo mezzo vuoto, e a quel punto tanto varrebbe scrivere il filo senza
## nuvolette.
const BUBBLE_TEXT_MAX := 82.0
const BUBBLE_SIZE := 9
const PREVIEW_SIZE := 8
## Il titolo di una riga scritto col font di sistema — quelli che hanno delle
## cifre dentro. Più grande dell'anteprima e più piccolo di una nuvoletta: è un
## titolo, non una frase.
const ROW_TITLE_SIZE := 10

## Spento quando la mappa fa solo da sfondo a un menu, come l'HUD: senza questo
## la cima del telefono comparirebbe dietro ai bottoni del menu principale.
@export var enabled := true:
	set(value):
		enabled = value
		set_process(value)
		set_process_unhandled_input(value)
		visible = value

enum State { CLOSED, MESSAGE, OPEN }
## Le schermate del telefono aperto. La guida non è una di queste: si apre
## fuori dal telefono, a tutto schermo.
##
## `PICK` è il menu dei tagli di semi da mandare a prendere all'autista. È una
## pagina e non una finestra sopra alla chat perché lo schermo è largo
## centoquattordici pixel: una tendina dentro a un vetro così coprirebbe la
## conversazione e lascerebbe metà bottone fuori. Tre righe cliccabili al posto
## del filo, e la freccia indietro torna alla chat — che è poi come sceglie le
## cose un telefono vero.
enum Page { CONTACTS, CHAT, PICK }

var _state := State.CLOSED
var _page := Page.CONTACTS
## Con chi si sta chattando, "" sulla rubrica.
var _contact := ""
var _slide: Tween = null
var _left_open := 0.0
## Pulsa finché il messaggio non è stato aperto almeno una volta.
var _unread := false
var _time := 0.0
## Fotografia del filo già a schermo, per non rifare le nuvolette a ogni
## fotogramma. Vedi `_sync_thread()`.
var _drawn := ""

@onready var _sender: Label = $Sender
@onready var _body: Label = $Text
@onready var _title: Label = $Title
@onready var _list: ScrollContainer = $List
@onready var _rows: VBoxContainer = $List/Rows
@onready var _action: VBoxContainer = $Action
var _call: Button = null

func _ready() -> void:
	size = SIZE
	position = Vector2(LEFT, _target_y())
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_action()
	_dress_list()
	GameState.phone_message.connect(_on_message)
	GameSettings.locale_changed.connect(_on_locale_changed)
	# Un messaggio può essere arrivato mentre si era in un'altra scena: il
	# telefono è per scena, ma l'ultimo messaggio vive su `GameState` e la chat
	# nel salvataggio, e li ritrova entrando.
	_show_stored()
	_show_page()
	_refresh()

func _process(delta: float) -> void:
	_time += delta
	if _state == State.MESSAGE:
		_left_open -= delta
		if _left_open <= 0.0:
			_set_state(State.CLOSED)
	# Il modale copre lo schermo: il telefono si toglie di mezzo e torna quando
	# la finestra si chiude, senza perdere quello che aveva dentro.
	var hidden := UiTheme.modal_open()
	if hidden == visible and enabled:
		visible = not hidden
	if _state == State.OPEN:
		_sync_thread()
	if _state != State.CLOSED or _unread:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or UiTheme.modal_open():
		return
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_toggle()
		return
	# Esc torna indietro di un passo invece di uscire dalla partita: chi ha
	# appena aperto una chat si aspetta che il primo Esc chiuda quella, non il
	# gioco.
	if _state == State.OPEN and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

## Un click sulla cima apre e chiude, come la freccia su; uno sulla freccia
## indietro torna alla rubrica. Il resto del corpo si mangia il click e basta:
## è un oggetto davanti alla scena, e un click che lo attraversa manderebbe il
## protagonista a camminare sotto al telefono.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if click.position.y <= HANDLE:
		_toggle()
		return
	if _state == State.OPEN and _page != Page.CONTACTS and BACK.has_point(click.position):
		_back()

# --- Aprire, chiudere, tornare indietro -------------------------------------

## La freccia su e il click sulla cima: aprono e chiudono, e basta. Aprendo si
## va dritti nella chat di chi ha scritto se c'è un messaggio non letto — vedi
## l'intestazione del file.
func _toggle() -> void:
	if _state == State.OPEN:
		_set_state(State.CLOSED)
		return
	var waiting := str(GameState.last_text.get("contact", "")) if _unread else ""
	if waiting.is_empty():
		_go_contacts()
	else:
		_go_chat(waiting)
	_set_state(State.OPEN)

## Esc e la freccia indietro: un passo per volta. Dalla chat si torna alla
## rubrica, dalla rubrica si chiude il telefono.
func _back() -> void:
	# Dal menu dei tagli si torna alla chat e non alla rubrica: si è dentro a
	# una conversazione, e il menu è un passo di quella.
	if _page == Page.PICK:
		_go_chat(_contact)
		return
	if _page != Page.CONTACTS:
		_go_contacts()
		return
	_set_state(State.CLOSED)

func _go_contacts() -> void:
	_page = Page.CONTACTS
	_contact = ""
	_drawn = ""
	_show_page()

func _go_chat(contact: String) -> void:
	_page = Page.CHAT
	_contact = contact
	_drawn = ""
	_show_page()

## Il menu dei tagli: quanti semi mandare a prendere.
func _go_pick() -> void:
	_page = Page.PICK
	_drawn = ""
	_show_page()

## Apre la guida, che non è una schermata del telefono: è una finestra a tutto
## schermo, appesa a `GameState` come il riquadro dei messaggi e il filmato del
## furgone. Entra nel gruppo `modal`, quindi il telefono si toglie di mezzo da
## solo mentre è aperta (vedi `_process()`) e torna quando si chiude.
func _open_guide() -> void:
	GameState.open_guide()

# --- I messaggi che arrivano ------------------------------------------------

func _on_message(sender: String, body: String) -> void:
	_sender.text = sender
	_body.text = body
	_unread = true
	# Col telefono già aperto l'avviso non serve e sarebbe un dispetto: il
	# messaggio è appena comparso nella chat che si sta guardando, e far
	# ripiegare il telefono per annunciarlo chiuderebbe quello che il giocatore
	# sta leggendo. Se ne accorge `_sync_thread()`.
	if _state == State.OPEN:
		return
	_set_state(State.MESSAGE)

## L'ultimo messaggio arrivato, ripescato da `GameState` entrando in scena.
func _show_stored() -> void:
	var stored := GameState.last_text
	if stored.is_empty():
		return
	_sender.text = str(stored.get("sender", ""))
	_body.text = str(stored.get("body", ""))

func _on_locale_changed(_locale: String) -> void:
	# Le nuvolette tengono il testo già scritto, non la chiave: cambiando lingua
	# vanno rifatte, non ritradotte.
	_drawn = ""
	_show_page()
	_refresh()

# --- Stato e scivolata ------------------------------------------------------

func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next
	if _state == State.MESSAGE:
		_left_open = MESSAGE_SECONDS
	if _state == State.OPEN:
		# Aperto vuol dire letto: la cima smette di pulsare.
		_unread = false
	_show_page()
	_refresh()
	# Chiuso il telefono smette di ridisegnarsi (vedi `_process`): senza questo
	# resterebbe a schermo l'ultimo fotogramma, quello acceso.
	queue_redraw()

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

# --- Cosa si vede: l'avviso o l'app -----------------------------------------

## Accende i nodi della schermata giusta e la riempie.
func _show_page() -> void:
	var open := _state == State.OPEN
	# Il bottone in fondo sta solo nella chat: nel menu dei tagli le righe sono
	# già i bottoni, e lasciarne uno sotto vorrebbe dire due modi di scegliere.
	var chat := open and _page == Page.CHAT
	_sender.visible = _state == State.MESSAGE
	_body.visible = _state == State.MESSAGE
	_title.visible = open
	_list.visible = open
	_action.visible = chat
	if not open:
		# Chiuso non c'è niente a schermo: la fotografia va azzerata, altrimenti
		# riaprendo il telefono la troverebbe già buona e non rifarebbe l'elenco.
		_drawn = ""
		return
	# L'elenco si allunga dove il bottone non c'è.
	_list.size.y = (LIST_BOTTOM if chat else LIST_BOTTOM_FULL) - _list.position.y
	_clear(_rows)
	if _page == Page.CONTACTS:
		_title.text = tr("CHAT_TITLE")
		_fill_contacts()
	elif _page == Page.PICK:
		_title.text = tr(Chat.name_key(_contact))
		_fill_packs()
	else:
		_title.text = tr(Chat.name_key(_contact))
		_fill_thread()
	# Anche il bottone: dice una cosa diversa a seconda di con chi si parla, e
	# senza questa riga entrando nella chat dell'autista restava quello di
	# prima — `_sync_thread()` non lo riscrive, perché la fotografia del filo
	# l'ha appena presa questa funzione e per lui non è cambiato niente.
	_refresh()
	_drawn = _mark()

func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

## Rifà l'elenco solo quando è cambiato davvero.
##
## Serve perché il filo cambia anche **senza che nessuno avvisi**: la risposta
## di Brian compare un paio di secondi dopo la richiesta (`Chat.REPLY_GAP`), la
## sua posizione arriva mentre si sta guardando la chat, e quando se ne va
## l'appuntamento si svuota e quei messaggi spariscono senza nessun segnale. Un
## confronto per fotogramma su una decina di righe costa niente; ricostruire
## dieci nuvolette sessanta volte al secondo, quello sì.
func _sync_thread() -> void:
	if _mark() == _drawn:
		return
	_show_page()
	_refresh()

## Cosa c'è a schermo, in una stringa da confrontare.
##
## Nella chat è il filo intero, perché ogni riga si vede. Sulla rubrica è
## l'ultima riga di ognuno più il pallino: il filo lì dentro non si vede, e
## rifare l'elenco perché è cambiato un messaggio in mezzo sarebbe lavoro per
## niente.
func _mark() -> String:
	var data := GameState.current
	if data == null or _state != State.OPEN:
		return ""
	var now := GameState.total_hours()
	if _page == Page.CHAT:
		return str(Chat.thread(data, _contact, now))
	var mark := str(GameState.last_text.get("contact", "")) if _unread else ""
	if _page == Page.PICK:
		# Il menu cambia quando cambiano i soldi, o quando il furgone parte o
		# rientra per uno qualunque dei suoi tre lavori: una riga che diventa
		# raggiungibile mentre la si guarda deve accendersi da sola.
		return "pick|%d|%s|%s|%s" % [
			data.cash, SeedRun.is_running(data), Delivery.is_running(data),
			BusImport.is_running(data)]
	for entry in Chat.contacts(data):
		var thread := Chat.thread(data, str(entry["id"]), now)
		mark += "|" + (str(thread[-1]) if not thread.is_empty() else "")
	return mark

# --- La rubrica -------------------------------------------------------------

## Una riga per contatto: il nome, l'ultima cosa che si sono detti, e il pallino
## verde se c'è qualcosa da leggere.
##
## L'anteprima non è decorazione: con un contatto solo, la rubrica sarebbe una
## riga con scritto "BRIAN", cioè una schermata che non dice niente e che si
## attraversa a occhi chiusi. Con l'ultima riga sotto al nome, invece, è già una
## risposta — "che mi aveva detto?" — e il click serve solo a leggere il resto.
func _fill_contacts() -> void:
	var data := GameState.current
	var now := GameState.total_hours()
	for entry in Chat.contacts(data):
		var id := str(entry["id"])
		var thread := Chat.thread(data, id, now)
		var last := Chat.body(thread[-1]) if not thread.is_empty() else tr("CHAT_EMPTY")
		var alert := _unread and str(GameState.last_text.get("contact", "")) == id
		_rows.add_child(_list_row(
			tr(str(entry["name_key"])), last, NAME_INK, alert, _go_chat.bind(id)))

	# La guida sta **sotto ai contatti e staccata da un filetto**: non è una
	# persona, e messa in fila con Brian si leggerebbe come un secondo contatto
	# che non risponde mai. Anche il nome è di un altro colore, per la stessa
	# ragione: da lì si apre una cosa, non una conversazione.
	_rows.add_child(_rule_node(RIM))
	_rows.add_child(_list_row(
		tr("GUIDE_TITLE"), tr("GUIDE_ROW_NOTE"), HANDLE_ARROW, false, _open_guide))

## I tagli da mandare a prendere: gli stessi tre dello sportello del grossista,
## con lo stesso prezzo e lo stesso sconto.
##
## Non è una seconda tabella: `SeedRun.PACKS` è una sola, e questo è il terzo
## posto che la mostra (l'edificio, il PC, il telefono) senza che nessuno dei
## tre sappia niente degli altri. Un taglio nuovo compare in tutti e tre.
##
## Una riga che non ci si può permettere resta lì e lo dice, invece di sparire:
## sapere quanto manca è metà del motivo per cui si guarda il listino.
func _fill_packs() -> void:
	var data := GameState.current
	var now := GameState.total_hours()
	for entry in SeedRun.PACKS:
		var pack: Dictionary = entry
		var prezzo := SeedRun.pack_price(pack)
		var puoi := SeedRun.can_order(data, pack)
		var nota := UiFormat.money(prezzo) if puoi else tr("SW_NO_CASH")
		# Il titolo porta il numero, quindi va col font di sistema: quello del
		# gioco le cifre non le disegna. Vedi `_list_row()`.
		_rows.add_child(_list_row(
			tr("SW_PACK") % int(pack["seeds"]), nota,
			NAME_INK if puoi else PREVIEW_INK, false,
			func() -> void: _order_pack(pack, now), false))

## Manda l'autista. Le due righe della chat non le scrive nessuno: se le ricava
## `Chat.driver_live()` dal viaggio in corso, ed è per questo che spariscono
## quando il furgone rientra.
func _order_pack(pack: Dictionary, now: float) -> void:
	var seeds := SeedRun.order(GameState.current, pack, now)
	if seeds <= 0:
		return
	# Lo stesso giro dello sportello: il furgone esce dalla città e la partita
	# si salva. Vedi `seed_wholesale_window.gd`.
	GameState.seed_run_left.emit(seeds)
	GameState.save_game()
	_go_chat(_contact)

## Una riga dell'elenco: un titolo col font del gioco, una riga di spiegazione
## sotto, e tutto il riquadro che si clicca.
## `pixel` decide il font del titolo. Col font del gioco — lettere e spazio —
## si scrivono i nomi in rubrica; col font di sistema i titoli che contengono
## cifre, come i tagli di semi del menu dell'autista. È la stessa scelta che fa
## il PC riga per riga.
func _list_row(title: String, note: String, ink: Color, alert: bool,
		on_press: Callable, pixel := true) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_box(Color(1, 1, 1, 0)))

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(head)
	var label: Label = null
	if pixel:
		label = Label.new()
		label.text = title
		label.add_theme_font_override("font", GAME_FONT)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", ink)
	else:
		label = UiTheme.label(title, ROW_TITLE_SIZE, ink, UiTheme.W_BOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(label)
	if alert:
		head.add_child(_dot())

	# La riga sotto è una sola e tagliata: un messaggio intero qui dentro
	# farebbe della rubrica una seconda chat, più stretta e peggiore.
	var caption := UiTheme.label(note.replace("\n", " "), PREVIEW_SIZE, PREVIEW_INK)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.clip_text = true
	lines.add_child(caption)

	# Il bottone è l'ultimo figlio e riempie il riquadro: le etichette lasciano
	# passare il mouse, quindi si clicca tutta la riga e non solo il nome. Un
	# bersaglio grande quanto la riga, su uno schermo largo centoquattordici
	# pixel, non è un lusso.
	var press := Button.new()
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.add_theme_stylebox_override("hover", _row_box(ROW_HOVER))
	press.add_theme_stylebox_override("pressed", _row_box(ROW_HOVER))
	press.set_script(BUTTON_SCRIPT)
	press.use_press_offset = false
	press.pressed.connect(on_press)
	row.add_child(press)
	return row

## Un filetto orizzontale dentro all'elenco. Non passa da `_draw()` perché sta
## **dentro** a una lista che scorre: disegnato sul vetro resterebbe fermo
## mentre il testo gli scivola sotto.
func _rule_node(color: Color) -> Control:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	var rule := Panel.new()
	rule.add_theme_stylebox_override("panel", box)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

func _row_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	return box

## Il pallino verde: lo stesso verde del triangolino che pulsa sulla cima del
## telefono, perché è la stessa notizia vista da vicino.
func _dot() -> Control:
	var box := StyleBoxFlat.new()
	box.bg_color = ALERT
	box.set_corner_radius_all(3)
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", box)
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot

# --- La chat ----------------------------------------------------------------

## Il filo intero, in nuvolette: le sue a sinistra, le tue a destra.
##
## Quali righe restino e quali spariranno con l'appuntamento lo decide `Chat`, e
## qui non si sa e non serve saperlo: sono messaggi, e si disegnano uguali.
func _fill_thread() -> void:
	var thread := Chat.thread(GameState.current, _contact, GameState.total_hours())
	if thread.is_empty():
		var empty := UiTheme.label(tr("CHAT_EMPTY"), PREVIEW_SIZE, PREVIEW_INK)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows.add_child(empty)
		return
	for row: Dictionary in thread:
		_rows.add_child(_bubble(Chat.body(row), Chat.is_mine(row)))
	# In fondo, che è dove sta il messaggio nuovo. Va rimandato: adesso le
	# nuvolette non hanno ancora una dimensione, e la barra non sa ancora fin
	# dove può scorrere.
	_scroll_to_end.call_deferred()

func _scroll_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_list):
		_list.scroll_vertical = int(_list.get_v_scroll_bar().max_value)

func _bubble(text: String, mine: bool) -> Control:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := StyleBoxFlat.new()
	box.bg_color = BUBBLE_MINE if mine else BUBBLE_THEM
	box.set_corner_radius_all(4)
	# L'angolo dalla parte di chi scrive resta squadrato: è la codina della
	# nuvoletta, e dice da che parte arriva prima ancora del colore.
	if mine:
		box.corner_radius_bottom_right = 1
	else:
		box.corner_radius_bottom_left = 1
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 3
	box.content_margin_bottom = 4

	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", box)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(bubble)

	var label := UiTheme.label(text, BUBBLE_SIZE, BUBBLE_INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# La nuvoletta è larga quanto la frase, fino a un tetto. Senza questa riga
	# `autowrap` lascerebbe la Label larga zero e le nuvolette uscirebbero
	# tutte strettissime; con una larghezza fissa invece "ci penso io"
	# diventerebbe un rettangolo mezzo vuoto.
	label.custom_minimum_size.x = minf(_text_width(text), BUBBLE_TEXT_MAX)
	bubble.add_child(label)
	return line

## Quanto sarebbe larga la frase senza andare a capo. Riga per riga, perché i
## messaggi dei traguardi gli a-capo ce li hanno già dentro (vedi
## `MSG_INTRO_BODY`) e misurati tutti insieme darebbero una riga sola lunga
## quanto tre.
func _text_width(text: String) -> float:
	var font := UiTheme.body()
	var widest := 0.0
	for piece in text.split("\n"):
		widest = maxf(widest, font.get_string_size(
			piece, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_SIZE).x)
	return widest

## La barra di scorrimento di serie è chiara e larga dieci pixel: su uno schermo
## di telefono scuro largo centoquattordici si mangia un decimo della riga, ed è
## l'unico pezzo che tradisce che sotto c'è un'interfaccia di sistema.
func _dress_list() -> void:
	var bar := _list.get_v_scroll_bar()
	bar.custom_minimum_size.x = 3
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.45, 0.50, 0.52, 0.65)
	grabber.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, grabber)

# --- Il bottone in fondo alla chat ------------------------------------------

## Una voce sola: chiedere i semi a Brian. È la stessa cosa che fa il bottone
## nella scheda GROW del PC, e non è un doppione per sbaglio — i semi finiscono
## mentre si è in giro per la città, e l'unico modo di chiederne altri era
## tornare in cantina ad aprire il PC, cioè attraversare la mappa per premere un
## bottone.
##
## Sta in fondo alla chat, dove in un'app di messaggi c'è la casella da cui si
## scrive: è lì che uno guarda quando ha qualcosa da dire.
func _build_action() -> void:
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
	_call.pressed.connect(_on_action)
	_action.add_child(_call)

## Il bottone fa una cosa diversa a seconda di con chi si sta parlando: a Brian
## si chiedono i semi, all'autista si dice di andarli a prendere — e lì serve
## sapere quanti, quindi si apre il menu invece di partire.
func _on_action() -> void:
	if _contact == Chat.DRIVER:
		_go_pick()
		return
	_call_brian()

## Premendo il bottone non si scrive niente da nessuna parte: si apre
## l'appuntamento, e le due righe — la richiesta e la risposta — se le ricava
## `Chat.live()` da quello. È il motivo per cui poi si cancellano da sole.
func _call_brian() -> void:
	if not SeedDeal.ask(GameState.current, GameState.total_hours()):
		return
	GameState.notify(tr("NOTE_ASKED_BRIAN"))
	_drawn = ""
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
	if _contact == Chat.DRIVER:
		# Fuori è fuori: che sia andato a prendere i semi, a portare la merce, o
		# dal contatto fuori stato di Kevin, il furgone è uno e non si sdoppia.
		var fuori := (
			SeedRun.is_running(data) or Delivery.is_running(data)
			or BusImport.is_running(data))
		_call.text = tr("PHONE_DRIVER_OUT") if fuori else tr("PHONE_SEND_DRIVER")
		_call.disabled = fuori
		return
	if SeedDeal.is_waiting(data):
		_call.text = tr("PHONE_WAITING")
	elif SeedDeal.is_ready(data):
		_call.text = tr("PHONE_BRIAN_HERE")
	else:
		_call.text = tr("PHONE_CALL_BRIAN")
	_call.disabled = not SeedDeal.can_ask(data)

# --- Quello che si disegna sopra al vetro -----------------------------------

## La scocca non passa di qui: è il disegno nel nodo `Shell`, che sta sotto a
## questo `_draw()` perché ha `show_behind_parent`. Qui c'è solo quello che
## cambia mentre si gioca — quello che un telefono vero avrebbe acceso dietro al
## vetro invece che stampato sulla scocca.
func _draw() -> void:
	# Chiuso lo schermo resta quello del disegno, spento e col suo riflesso:
	# sopra ci va solo il triangolino, che è l'unica cosa che dice che il
	# telefono si apre.
	if _state == State.CLOSED:
		_draw_arrow()
		return
	# **Il fondo prima del triangolino.** Al contrario il velo dello schermo
	# acceso lo smorzava (è semitrasparente, quindi si vedeva lo stesso e non se
	# ne accorgeva nessuno) e la carta della guida lo cancellava del tutto.
	_draw_glass()
	_draw_arrow()
	_draw_status()
	if _state != State.OPEN:
		return
	# I due filetti dell'app: sotto all'intestazione, e sopra al bottone. Il
	# secondo solo dove il bottone c'è davvero, cioè nella chat: sulla rubrica
	# sarebbe una riga sospesa in fondo allo schermo.
	_draw_rule(HEADER_LINE)
	if _page == Page.CONTACTS:
		return
	# Il filetto sopra al bottone solo dove il bottone c'è davvero.
	if _page == Page.CHAT:
		_draw_rule(_action.position.y - 6.0)
	_draw_back()

func _draw_rule(y: float) -> void:
	draw_line(Vector2(GLASS.position.x + 6.0, y), Vector2(GLASS.end.x - 6.0, y), RIM, 1.0)

## La freccia indietro: due segmenti, dentro al rettangolo che `_gui_input()`
## ascolta.
func _draw_back() -> void:
	var middle := BACK.position.y + BACK.size.y * 0.5
	var right := BACK.end.x - 3.0
	var left := BACK.position.x + 3.0
	draw_line(Vector2(right, middle - 4.0), Vector2(left, middle), HANDLE_ARROW, 1.0)
	draw_line(Vector2(left, middle), Vector2(right, middle + 4.0), HANDLE_ARROW, 1.0)

## Il velo dello schermo acceso. Non è un rettangolo solo: il notch resta
## fuori. È un buco nello schermo, e accenderlo insieme al resto cancella
## l'unica cosa che fa capire, a colpo d'occhio, che quello è un telefono e non
## un pannello — che era poi il motivo per cui la scocca disegnata ha sostituito
## il rettangolo.
func _draw_glass() -> void:
	var below := NOTCH.end.y
	draw_rect(Rect2(GLASS.position.x, below, GLASS.size.x, GLASS.end.y - below),
		SCREEN_LIT, true)
	draw_rect(Rect2(GLASS.position.x, GLASS.position.y,
		NOTCH.position.x - GLASS.position.x, NOTCH.size.y), SCREEN_LIT, true)
	draw_rect(Rect2(NOTCH.end.x, GLASS.position.y,
		GLASS.end.x - NOTCH.end.x, NOTCH.size.y), SCREEN_LIT, true)

## Il triangolino sotto al notch, che dice da che parte si apre. Pulsa finché c'è
## un messaggio non letto: sta nella fetta di telefono che resta fuori a
## schermata chiusa, cioè nell'unica cosa che si vede di questo telefono per la
## maggior parte della partita, ed è quindi anche l'unico posto in cui si può
## dire "c'è qualcosa per te".
func _draw_arrow() -> void:
	var color := HANDLE_ARROW
	if _unread:
		color = ALERT
		color.a = 0.65 + 0.35 * sin(_time * 5.0)
	# Punta in su quando c'è da aprire e in giù quando c'è da chiudere: è la
	# stessa freccia della tastiera, e a telefono aperto una freccia che punta
	# ancora in su direbbe di premere il tasto che non fa niente.
	var middle := SIZE.x * 0.5
	var up := _state != State.OPEN
	var tip := ARROW_TOP if up else ARROW_TOP + ARROW_SIZE.y
	var base := ARROW_TOP + ARROW_SIZE.y if up else ARROW_TOP
	draw_colored_polygon(PackedVector2Array([
		Vector2(middle, tip),
		Vector2(middle + ARROW_SIZE.x, base),
		Vector2(middle - ARROW_SIZE.x, base),
	]), color)

## La riga di stato in cima allo schermo: tacche a sinistra del notch, orologio
## a destra. Non serve a niente, ed è esattamente il motivo per cui c'è — è
## quello che rende uno schermo un telefono invece di un rettangolo con del
## testo dentro.
##
## Sta **di fianco** al notch e non sotto: è dove sta su un telefono vero, ed è
## anche l'unico modo di non rubare una riga al messaggio. Ai due lati restano
## ventisei pixel per parte, che bastano alle tacche e all'orologio e a
## nient'altro: se qui ci finisse una terza cosa, andrebbe sotto al notch.
func _draw_status() -> void:
	var base := NOTCH.end.y - 2.0
	for i in 3:
		var tall := 3.0 + float(i) * 2.0
		draw_rect(Rect2(GLASS.position.x + 4.0 + float(i) * 4.0, base - tall, 2.0, tall),
			STATUS, true)
	var font := ThemeDB.fallback_font
	if font == null or GameState.current == null:
		return
	var clock := UiFormat.clock(GameState.current.time_of_day)
	var width := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(
		font, Vector2(GLASS.end.x - width - 4.0, base), clock,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, STATUS)
