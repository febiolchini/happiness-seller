extends CanvasLayer

## HUD segnaposto: soldi, orologio, scorta e attenzione in alto a destra, più i
## messaggini che scorrono sotto.
##
## Come tutto il resto della grafica attuale è provvisorio — andrà rifatto con
## la cornice pixel art — ma legge già i dati veri della partita, quindi quando
## arriverà il disegno definitivo cambierà solo l'aspetto, non la logica.

const PANEL_FONT_SIZE := 15
## Quanti messaggi restano a schermo insieme: oltre, i vecchi se ne vanno. Con
## "raccogli tutto" possono arrivarne diversi di fila.
const MAX_TOASTS := 4
const TOAST_LIFE := 2.6

## Spento quando la mappa fa solo da sfondo a un menu. Senza questo l'HUD si
## rimostrerebbe da solo al primo `_refresh()`, comparendo dietro ai bottoni.
@export var enabled := true:
	set(value):
		enabled = value
		set_process(value)
		if not value:
			visible = false

## Righe mostrate, dall'alto in basso. Per aggiungerne una (proprietà,
## reputazione, debiti...) basta infilare una voce qui: creazione della Label e
## aggiornamento a schermo vengono da soli.
##
## `text` riceve la partita corrente e restituisce la stringa già formattata.
## `show` è opzionale: quando c'è, la riga compare solo se restituisce true —
## così l'HUD resta pulito all'inizio e si popola man mano che la partita
## acquista pezzi.
var _rows := [
	{
		"size": PANEL_FONT_SIZE,
		"color": Color(0.85, 0.92, 0.62),
		"text": func(data: SaveData) -> String: return UiFormat.money(data.cash),
	},
	{
		"size": 11,
		"color": Color(0.78, 0.81, 0.86),
		"text": func(data: SaveData) -> String:
			return "giorno %d   %s" % [data.day, UiFormat.clock(data.time_of_day)],
	},
	{
		"size": 11,
		"color": Color(0.62, 0.85, 0.55),
		"text": func(data: SaveData) -> String: return "%d g" % Economy.stock(data),
		"show": func(data: SaveData) -> bool: return Economy.stock(data) > 0,
	},
	{
		"size": 11,
		"color": Color(0.95, 0.62, 0.35),
		"text": func(data: SaveData) -> String: return Economy.heat_label(data.heat),
		"show": func(data: SaveData) -> bool: return data.heat >= 10.0,
	},
]

## Il pannello sta in un HBoxContainer allineato a destra, così si stringe sul
## contenuto invece di avere una larghezza fissa: quando i soldi passano da
## "80 $" a "1.234.567 $" la cornice si allarga da sola.
@onready var _rows_box: VBoxContainer = $Root/TopBar/Panel/Margin/Rows
@onready var _toasts: VBoxContainer = $Root/Toasts

var _labels: Array[Label] = []
## Ultimo testo mostrato per ogni riga, per non riscrivere le Label ogni frame.
var _shown: Array[String] = []

func _ready() -> void:
	for row in _rows:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", row["size"])
		label.add_theme_color_override("font_color", row["color"])
		# I numeri hanno bisogno del font di sistema: `alphabet.fnt` ha solo
		# lettere e spazio, con quello soldi e orario sparirebbero.
		_rows_box.add_child(label)
		_labels.append(label)
		_shown.append("")
	if enabled:
		GameState.notice.connect(_show_toast)
	_refresh()

## L'HUD legge lo stato invece di aspettare dei segnali: qualsiasi codice futuro
## che faccia `GameState.current.cash += 100` direttamente resta comunque
## mostrato giusto, senza doversi ricordare di emettere niente.
func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if not enabled:
		return
	var data := GameState.current
	# Aprendo la mappa dall'editor l'HUD esiste prima che ci sia una partita.
	if data == null:
		visible = false
		return
	visible = true
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var condition: Callable = row.get("show", Callable())
		var wanted := not condition.is_valid() or bool(condition.call(data))
		if _labels[i].visible != wanted:
			_labels[i].visible = wanted
		if not wanted:
			continue
		var text: String = (row["text"] as Callable).call(data)
		if text != _shown[i]:
			_shown[i] = text
			_labels[i].text = text

# --- Messaggini ------------------------------------------------------------

## Un avviso che compare e se ne va da solo ("+20 G HARVESTED").
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
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(label)

	# Tween creato DAL messaggio, non dall'HUD: così se il messaggio viene
	# liberato prima della fine (perché ne sono arrivati troppi) il tween muore
	# con lui, invece di restare a tenere il riferimento a un nodo che non c'è più.
	var tween := label.create_tween()
	tween.tween_interval(TOAST_LIFE * 0.6)
	tween.tween_property(label, "modulate:a", 0.0, TOAST_LIFE * 0.4)
	tween.tween_callback(label.queue_free)
