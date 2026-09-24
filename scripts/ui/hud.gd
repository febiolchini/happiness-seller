extends CanvasLayer

## HUD: quello che sta addosso alla città mentre si gioca.
##
## Poca roba, e è il punto: la **sveglia** in alto a destra
## (`digital_clock.gd`), il **tasto a tre righe** in alto a sinistra
## (`hud_menu.gd`) con dentro i soldi e la scorta, e sotto alla sveglia una riga
## che compare solo quando c'è qualcosa da dire. Più i messaggini che scorrono.
##
## ## Perché non è un pannello
##
## Prima era un riquadro con bordo e sfondo, con i valori impilati dentro. Un
## pannello in un angolo è una finestra piccola: ruba spazio anche quando non ha
## niente da dire, e in un gioco dove si guarda la strada e si clicca sulle
## cose, il bordo continua a segnare un rettangolo che non è parte del mondo.
##
## Niente fondo, quindi: a tenere le scritte leggibili sopra a qualunque
## fondale è l'ombra dura sotto a ognuna. Per un giro c'è stata una pastiglia di
## carta chiara dietro, per farla intonare col gestionale, e non reggeva — sopra
## alla città diventava un rettangolo bianco piantato in un angolo, cioè
## esattamente il pannello che queste righe spiegano di aver tolto.
##
## **La sveglia è l'eccezione, ed è voluta.** È un oggetto disegnato e non una
## cassa dietro a del testo: in un gestionale dove il tempo è la risorsa — le
## piante crescono a ore di gioco, Brian aspetta a ore di gioco, le paghe
## scattano a mezzanotte — l'orologio merita di essere una cosa che si guarda,
## non due numeri in mezzo ad altri numeri.
##
## ## Cosa NON sta più a schermo
##
## - **L'ora e il giorno**, che erano un segmento come gli altri: adesso sono
##   dentro alla sveglia, che è tutto quello che quella sveglia fa.
## - **L'attenzione della polizia.** Era l'unica voce che non fosse un numero ma
##   uno *stato* scritto a parole ("SORVEGLIATO"), e in un angolo pieno di cifre
##   si leggeva come un allarme acceso a metà partita e poi mai più guardato. Il
##   dato non è sparito: sta nella scheda OVERVIEW del PC (`PC_ATTENTION`),
##   che è il posto in cui uno va a guardare come sta andando.
## - **Il tempo che fa.** Scriverlo era l'unica voce che raccontasse una cosa
##   **già a schermo**: se piove, piove addosso alla città (`weather_view.gd`),
##   e la parola "PIOGGIA" in un angolo non aggiungeva niente a quello che si
##   sta già guardando. Cosa cambi il tempo — si vende meno in strada, ci si fa
##   notare meno — lo spiega la guida, che è il posto delle regole.
## - **I soldi e la scorta**, che sono finiti dentro al menu. Non sono spariti
##   come gli altri due: sono a un click, e chi li vuole davanti tiene il menu
##   aperto. Il perché sta in `hud_menu.gd`.
##
## Quello che resta nella riga **compare solo quando ha qualcosa da dire**: per
## ora solo il posto dove aspetta Brian, e solo finché aspetta. Quasi sempre
## sotto alla sveglia non c'è niente, ed è la condizione giusta per un HUD.
##
## Come prima, legge lo stato invece di aspettare segnali: qualsiasi codice che
## faccia `GameState.current.cash += 100` resta comunque mostrato giusto.

## Quanti messaggi restano a schermo insieme: oltre, i vecchi se ne vanno. Con
## "raccogli tutto" possono arrivarne diversi di fila.
const MAX_TOASTS := 4
const TOAST_LIFE := 2.6

const INFO_SIZE := 11

## I colori NON vengono da `UiTheme`, ed è l'unica interfaccia del gioco per cui
## vale: quella tavolozza è fatta per il nero su bianco di una finestra, mentre
## qui si scrive sopra alla città, e sopra a un fondale scuro serve il contrario
## — tinte chiare che si staccano dall'asfalto.
const SPOT_COLOR := Color(0.55, 0.85, 0.45)
const DOT_COLOR := Color(0.45, 0.47, 0.52)
const DOT := "·"

## Nascosto mentre una di queste è aperta. Il gestionale del PC è un `Control`
## dentro alla scena, quindi sta su una tela più bassa di questa: senza questo
## controllo l'HUD gli comparirebbe sopra, a metà della finestra.
##
## I modali si segnano da soli mettendosi nel gruppo, invece di essere elencati
## qui: così una finestra nuova non ha bisogno che qualcuno si ricordi di
## aggiungerla a un elenco in un altro file.
const MODAL_GROUP := "modal"

const PRESTIGE_BADGE := preload("res://scripts/ui/prestige_badge.gd")
const SUSPICION_BAR := preload("res://scripts/ui/suspicion_bar.gd")
const ORG_NAME_WINDOW := preload("res://scripts/ui/org_name_window.gd")

## Spento quando la mappa fa solo da sfondo a un menu. Senza questo l'HUD si
## rimostrerebbe da solo al primo `_refresh()`, comparendo dietro ai bottoni.
@export var enabled := true:
	set(value):
		enabled = value
		set_process(value)
		if not value:
			visible = false

## Le voci della riga sotto alla sveglia, da sinistra a destra. Per aggiungerne
## una basta infilarla qui: Label, punto di separazione e aggiornamento a
## schermo vengono da soli.
##
## `text` riceve la partita corrente e restituisce la stringa già formattata.
## `show` è opzionale: quando c'è, la voce compare solo se restituisce true.
##
## **Qui ci va solo roba che serve mentre si cammina.** Tutto quello che si
## guarda per decidere — i soldi, la scorta — sta dietro al menu o dentro al
## PC: la differenza è fra un'informazione che si legge muovendosi e una che si
## legge fermi.
var _segments := [
	# Dove aspetta Brian, finché aspetta. Il messaggino che annuncia
	# l'appuntamento se ne va dopo due secondi e mezzo, e senza questa voce
	# l'unico modo di ripescare il posto sarebbe riaprire il telefono — che si
	# può fare, ma è un gesto in più per una cosa che serve mentre si cammina.
	{
		"color": SPOT_COLOR,
		"text": func(data: SaveData) -> String: return SeedDeal.place(data),
		"show": func(data: SaveData) -> bool: return SeedDeal.is_ready(data),
	},
]

@onready var _bar: HBoxContainer = $Root/Corner/Info
@onready var _toasts: VBoxContainer = $Root/Toasts

var _labels: Array[Label] = []
## Il punto che precede ogni segmento. Il primo non ce l'ha, quindi l'elemento 0
## resta `null` e l'indice resta allineato a quello dei segmenti.
var _dots: Array[Label] = []
## Ultimo testo mostrato per ogni segmento, per non riscrivere le Label ogni frame.
var _shown: Array[String] = []

func _ready() -> void:
	_build_meters()
	for i in _segments.size():
		var segment: Dictionary = _segments[i]
		_dots.append(_make_dot() if i > 0 else null)
		_labels.append(_make_label(INFO_SIZE, segment["color"]))
		_shown.append("")
	if enabled:
		GameState.notice.connect(_show_toast)
	# Cambiando lingua le stringhe composte qui dentro vanno rifatte: le abbiamo
	# scritte noi, quindi Godot non le ritraduce da solo come fa col testo messo
	# nel `.tscn`.
	GameSettings.locale_changed.connect(_on_locale_changed)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if not enabled:
		return
	var data := GameState.current
	# Aprendo la mappa dall'editor l'HUD esiste prima che ci sia una partita.
	if data == null or _modal_open():
		visible = false
		return
	visible = true
	_check_org_name(data)

	# Il punto va messo solo *fra* due segmenti visibili: quello del primo
	# segmento acceso resterebbe appeso a sinistra, davanti al nulla.
	var any_before := false
	for i in _segments.size():
		var segment: Dictionary = _segments[i]
		var condition: Callable = segment.get("show", Callable())
		var wanted := not condition.is_valid() or bool(condition.call(data))
		if _labels[i].visible != wanted:
			_labels[i].visible = wanted
		if _dots[i] != null:
			var dot_wanted := wanted and any_before
			if _dots[i].visible != dot_wanted:
				_dots[i].visible = dot_wanted
		if not wanted:
			continue
		any_before = true
		var text: String = (segment["text"] as Callable).call(data)
		if text != _shown[i]:
			_shown[i] = text
			_labels[i].text = text

## C'è una finestra aperta che si prende lo schermo?
## Il prestigio a sinistra della sveglia e il sospetto della polizia sul lato
## sinistro dello schermo. Costruiti da codice e non nella scena, cosi' le
## scene che istanziano l'HUD non si ritrovano nodi nuovi da sistemare. Sono
## segnaposto disegnati in attesa della grafica vera: vedi i due script.
func _build_meters() -> void:
	var root: Control = $Root
	var badge := Control.new()
	badge.set_script(PRESTIGE_BADGE)
	badge.name = "Prestige"
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# La sveglia e' larga 78 e sta a 8 dal bordo: il badge le sta a fianco.
	badge.offset_left = -200.0
	badge.offset_right = -94.0
	badge.offset_top = 14.0
	badge.offset_bottom = 48.0
	root.add_child(badge)
	var bar := Control.new()
	bar.set_script(SUSPICION_BAR)
	bar.name = "Suspicion"
	bar.position = Vector2(12, 40)
	bar.size = Vector2(10, 122)
	root.add_child(bar)

## Brian ha chiesto il nome e non c'e' ancora: si apre la finestra. Controllato
## qui e non con un segnale perche' deve valere anche dopo un caricamento — chi
## chiude il gioco senza aver dato il nome se la ritrova alla riapertura.
func _check_org_name(data: SaveData) -> void:
	if not data.org_name.is_empty():
		return
	if not bool(data.get_flag(GameState.ORG_NAME_FLAG, false)):
		return
	var window: CanvasLayer = ORG_NAME_WINDOW.new()
	get_tree().current_scene.add_child(window)

func _modal_open() -> bool:
	return not get_tree().get_nodes_in_group(MODAL_GROUP).is_empty()

## La lingua è cambiata: i testi si ricalcolano al prossimo giro, ma `_shown` li
## crede ancora buoni e li salterebbe. Azzerandolo si forza la riscrittura.
func _on_locale_changed(_locale: String) -> void:
	for i in _shown.size():
		_shown[i] = ""

# --- Costruzione della riga -------------------------------------------------

func _make_label(size: int, color: Color) -> Label:
	var label := UiTheme.label("", size, color, UiTheme.W_MEDIUM)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add_shadow(label)
	_bar.add_child(label)
	return label

func _make_dot() -> Label:
	var dot := UiTheme.label(DOT, INFO_SIZE, DOT_COLOR, UiTheme.W_BOLD)
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Il punto non è testo di gioco: se un giorno finisse in traduzione
	# diventerebbe una parola.
	dot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_add_shadow(dot)
	_bar.add_child(dot)
	return dot

## L'ombra dura è quello che sostituisce il pannello: sotto la riga può
## passarci un muro chiaro, l'asfalto o il cielo, e senza uno stacco netto la
## scritta ci si perde dentro.
static func _add_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

# --- Messaggini ------------------------------------------------------------

## Un avviso che compare e se ne va da solo ("+20 G RACCOLTI").
##
## Vale la pena averlo perché in un gestionale la maggior parte delle azioni
## cambia solo un numero da qualche parte: senza un riscontro immediato il
## giocatore non sa se il click ha fatto qualcosa.
func _show_toast(text: String) -> void:
	while _toasts.get_child_count() >= MAX_TOASTS:
		# `remove_child` prima di `queue_free`: il nodo sparisce dal conteggio
		# subito, invece di restare figlio fino alla fine del frame e far
		# credere al messaggio successivo che il posto sia ancora occupato.
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()

	var label := UiTheme.label(text, 12, Color(1, 0.95, 0.78), UiTheme.W_MEDIUM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_shadow(label)
	# Il messaggio arriva già tradotto da chi lo manda, e contiene numeri:
	# ritradurlo non troverebbe niente, ma tanto vale non provarci.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_toasts.add_child(label)

	# Tween creato DAL messaggio, non dall'HUD: così se il messaggio viene
	# liberato prima della fine (perché ne sono arrivati troppi) il tween muore
	# con lui, invece di restare a tenere il riferimento a un nodo che non c'è più.
	var tween := label.create_tween()
	tween.tween_interval(TOAST_LIFE * 0.6)
	tween.tween_property(label, "modulate:a", 0.0, TOAST_LIFE * 0.4)
	tween.tween_callback(label.queue_free)
