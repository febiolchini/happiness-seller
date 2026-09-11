extends CanvasLayer

## HUD: una riga sola in alto a destra, e i messaggini che scorrono sotto.
##
## ## Perché una riga e non un pannello
##
## Prima era un riquadro con bordo e sfondo, con i valori impilati dentro. Un
## pannello in un angolo è una finestra piccola: ruba spazio anche quando non ha
## niente da dire, e in un gioco dove si guarda la strada e si clicca sulle
## cose, il bordo continua a segnare un rettangolo che non è parte del mondo.
##
## Adesso è una riga sola, senza sfondo: i soldi in evidenza, il resto più
## piccolo e più spento, separato da punti. A tenerla leggibile sopra a
## qualunque fondale è l'ombra dura sotto a ogni scritta, non una cassa dietro.
##
## I segmenti **compaiono solo quando hanno qualcosa da dire** — la scorta
## quando ce n'è, l'attenzione quando è salita, il posto dove aspetta Brian
## finché aspetta — così a inizio partita la riga è due voci e si allunga man
## mano che la partita cresce.
##
## Come prima, legge lo stato invece di aspettare segnali: qualsiasi codice che
## faccia `GameState.current.cash += 100` resta comunque mostrato giusto.

## Quanti messaggi restano a schermo insieme: oltre, i vecchi se ne vanno. Con
## "raccogli tutto" possono arrivarne diversi di fila.
const MAX_TOASTS := 4
const TOAST_LIFE := 2.6

const MONEY_SIZE := 16
const INFO_SIZE := 11
const MONEY_COLOR := Color(0.90, 0.95, 0.66)
const INFO_COLOR := Color(0.74, 0.77, 0.82)
const STOCK_COLOR := Color(0.62, 0.85, 0.55)
const HEAT_COLOR := Color(0.95, 0.62, 0.35)
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

## Spento quando la mappa fa solo da sfondo a un menu. Senza questo l'HUD si
## rimostrerebbe da solo al primo `_refresh()`, comparendo dietro ai bottoni.
@export var enabled := true:
	set(value):
		enabled = value
		set_process(value)
		if not value:
			visible = false

## I segmenti della riga, da sinistra a destra. Per aggiungerne uno (proprietà,
## debiti, reputazione...) basta infilare una voce qui: Label, punto di
## separazione e aggiornamento a schermo vengono da soli.
##
## `text` riceve la partita corrente e restituisce la stringa già formattata.
## `show` è opzionale: quando c'è, il segmento compare solo se restituisce true.
var _segments := [
	{
		"size": MONEY_SIZE,
		"color": MONEY_COLOR,
		"text": func(data: SaveData) -> String: return UiFormat.money(data.cash),
	},
	{
		"size": INFO_SIZE,
		"color": INFO_COLOR,
		"text": func(data: SaveData) -> String:
			return "%s %d  %s" % [tr("HUD_DAY"), data.day, UiFormat.clock(data.time_of_day)],
	},
	{
		"size": INFO_SIZE,
		"color": STOCK_COLOR,
		"text": func(data: SaveData) -> String: return "%d g" % Economy.stock(data),
		"show": func(data: SaveData) -> bool: return Economy.stock(data) > 0,
	},
	{
		"size": INFO_SIZE,
		"color": HEAT_COLOR,
		"text": func(data: SaveData) -> String: return Economy.heat_label(data.heat),
		"show": func(data: SaveData) -> bool: return data.heat >= 10.0,
	},
	# Dove aspetta Brian, finché aspetta. Il messaggino che annuncia
	# l'appuntamento se ne va dopo due secondi e mezzo, e senza questo segmento
	# l'unico modo di ripescare il posto sarebbe tornare in cantina a riaprire
	# il PC — cioè attraversare la città al contrario.
	{
		"size": INFO_SIZE,
		"color": SPOT_COLOR,
		"text": func(data: SaveData) -> String: return SeedDeal.place(data),
		"show": func(data: SaveData) -> bool: return SeedDeal.is_ready(data),
	},
]

@onready var _bar: HBoxContainer = $Root/TopBar
@onready var _toasts: VBoxContainer = $Root/Toasts

var _labels: Array[Label] = []
## Il punto che precede ogni segmento. Il primo non ce l'ha, quindi l'elemento 0
## resta `null` e l'indice resta allineato a quello dei segmenti.
var _dots: Array[Label] = []
## Ultimo testo mostrato per ogni segmento, per non riscrivere le Label ogni frame.
var _shown: Array[String] = []

func _ready() -> void:
	for i in _segments.size():
		var segment: Dictionary = _segments[i]
		_dots.append(_make_dot() if i > 0 else null)
		_labels.append(_make_label(int(segment["size"]), segment["color"]))
		_shown.append("")
	if enabled:
		GameState.notice.connect(_show_toast)
	# Cambiando lingua le stringhe composte qui dentro ("GIORNO 3  08:40") vanno
	# rifatte: sono state scritte da noi, quindi Godot non le ritraduce.
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
func _modal_open() -> bool:
	return not get_tree().get_nodes_in_group(MODAL_GROUP).is_empty()

## La lingua è cambiata: i testi si ricalcolano al prossimo giro, ma `_shown` li
## crede ancora buoni e li salterebbe. Azzerandolo si forza la riscrittura.
func _on_locale_changed(_locale: String) -> void:
	for i in _shown.size():
		_shown[i] = ""

# --- Costruzione della riga -------------------------------------------------

func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	# L'ombra dura è quello che sostituisce il pannello: sotto la riga può
	# passarci un muro chiaro, l'asfalto o il cielo, e senza uno stacco netto
	# la scritta ci si perde dentro.
	_add_shadow(label)
	# Le cifre hanno bisogno del font di sistema: `alphabet.fnt` ha solo lettere
	# e spazio, e con quello soldi e orario sparirebbero.
	_bar.add_child(label)
	return label

func _make_dot() -> Label:
	var dot := Label.new()
	dot.text = DOT
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_theme_font_size_override("font_size", INFO_SIZE)
	dot.add_theme_color_override("font_color", DOT_COLOR)
	# Il punto non è testo di gioco: se un giorno finisse in traduzione
	# diventerebbe una parola.
	dot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_add_shadow(dot)
	_bar.add_child(dot)
	return dot

static func _add_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.78))
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
