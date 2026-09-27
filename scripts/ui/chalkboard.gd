extends Control

## La lavagna a destra dell'HUD, sotto alla sveglia: com'è messa la produzione,
## scritta col gesso.
##
## Cinque voci — l'erba pronta, i semi, i coltivatori, gli autisti, gli
## spacciatori — che sono le cose che dicono se la macchina sta girando. Prima
## stavano in un cassetto dietro al tasto a tre righe in alto a sinistra, e
## andavano aperte per leggerle; in un gestionale senza protagonista sono
## proprio quello che si guarda, e adesso stanno sempre a vista.
##
## ## Una riga per voce
##
## Nome a sinistra, numero a destra, sulla stessa riga: "WEED 456 G". Davanti
## all'erba c'è la foglia, la stessa dell'intestazione del PC (`foglia.png`):
## è la voce che conta di più, e l'icona la fa trovare senza leggere.
##
## ## Gesso, non etichette
##
## Le scritte non usano il pennello dell'HUD (`brush.fnt`), che ha l'ombra
## scura dipinta dentro e staccava le lettere dalla lavagna come adesivi: usano
## `brush_ink.fnt`, lo stesso tratto senza ombra, con sopra la grana del gesso
## (`chalk.gdshader`) e ogni riga appena storta. Anche la foglia passa dal gesso.
##
## Il testo va **dentro al verde** (`SLATE`, misurato dall'importatore), non
## sopra la cornice di legno: rifacendo la lavagna a un'altra misura basta
## rilanciare lo script e ricopiare la costante.

const BOARD := preload("res://assets/sprites/ui/board.png")
const LEAF := preload("res://assets/sprites/ui/foglia.png")
## La grana del gesso: vedi lo shader.
const CHALK_SHADER := preload("res://assets/shaders/chalk.gdshader")
## Quanto può essere storta una riga, in gradi. Scritte a mano non stanno mai
## perfettamente in bolla, ed è metà di quello che le fa sembrare scritte e non
## stampate. Pochissimo: di più e si legge come un errore.
const TILT := 1.6
## La foglia davanti all'erba, in pixel di schermo.
const LEAF_SIZE := Vector2(9.0, 10.0)
## Stampati da `scripts_tools/import_board_art.py`.
const SIZE := Vector2(84.0, 132.0)
const SLATE := Rect2(7, 7, 70, 118)
## Quanto stanno lontane le scritte dal bordo del verde.
const PAD := Vector2(2.0, 4.0)

## Il gesso: bianco sporco il numero, più spento il nome. Colori propri e non
## di `UiTheme`, per la stessa ragione dell'HUD: quella tavolozza è nero su
## bianco, e qui si scrive chiaro su scuro.
const CHALK := Color(0.93, 0.94, 0.89)
const CHALK_SOFT := Color(0.70, 0.78, 0.72)
const TEXT_SIZE := 9
## L'unità ("g", "kg") scritta in piccolo accanto al numero.
const UNIT_SIZE := 6
## Da quanti grammi in su l'erba si conta in chili.
const KILO := 1000
## Lo spazio fra una voce e l'altra: cinque righe singole lasciano parecchio
## verde, e distribuite si leggono meglio che ammucchiate in mezzo.
const ROW_GAP := 6

## Le voci, dall'alto in basso. `label` è una chiave di `Strings`, `text` ricava
## il numero dalla partita, `unit` (se c'è) l'unità che gli va scritta accanto.
var _rows := [
	{
		"label": "BOARD_WEED",
		"icon": LEAF,
		"text": func(data: SaveData) -> String: return weight_number(Economy.stock(data)),
		"unit": func(data: SaveData) -> String: return weight_unit(Economy.stock(data)),
	},
	{
		"label": "BOARD_SEEDS",
		"text": func(data: SaveData) -> String: return str(Economy.seeds_owned(data)),
	},
	{
		"label": "BOARD_GROWERS",
		"text": func(data: SaveData) -> String: return str(Staff.count(data, "grower")),
	},
	{
		"label": "BOARD_DRIVERS",
		"text": func(data: SaveData) -> String: return str(Staff.count(data, "driver")),
	},
	{
		"label": "BOARD_DEALERS",
		"text": func(data: SaveData) -> String: return str(Staff.count(data, "dealer")),
	},
]

## Il numero del peso: grammi sotto al chilo, chili sopra con tre cifre
## significative — 1.23, 12.3, 123. Più cifre non ci starebbero: la lavagna è
## larga settanta pixel, e "1009 G" usciva dalla cornice.
static func weight_number(grams: int) -> String:
	if grams < KILO:
		return str(grams)
	var kg := float(grams) / float(KILO)
	if kg < 10.0:
		return "%.2f" % kg
	if kg < 100.0:
		return "%.1f" % kg
	return str(int(kg))

static func weight_unit(grams: int) -> String:
	return "g" if grams < KILO else "kg"

var _labels: Array[Label] = []
var _values: Array[Label] = []
## L'unità di ogni voce, `null` per quelle che non ne hanno.
var _units: Array = []
## Ultimo valore scritto per ogni voce, per non riscrivere le Label a ogni
## fotogramma.
var _shown: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE

	var board := TextureRect.new()
	board.texture = BOARD
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size = SIZE
	add_child(board)

	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ancorato alla lavagna e non posato con `size`: dentro alla colonna della
	# sveglia la misura del nodo la decide il contenitore, e una misura scritta
	# prima di entrare nell'albero si perdeva — le voci finivano ammucchiate
	# in cima invece che distribuite sul verde.
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = SLATE.position.x + PAD.x
	lines.offset_top = SLATE.position.y + PAD.y
	lines.offset_right = -(SIZE.x - SLATE.end.x + PAD.x)
	lines.offset_bottom = -(SIZE.y - SLATE.end.y + PAD.y)
	# Lo spazio avanza in mezzo alle voci, non tutto in fondo: cinque voci
	# ammassate in cima a una lavagna mezza vuota sembrano un elenco
	# interrotto.
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", ROW_GAP)
	add_child(lines)

	var chalk := ShaderMaterial.new()
	chalk.shader = CHALK_SHADER
	# Storta sempre allo stesso modo: una lavagna che si riscrive da sola a ogni
	# avvio sembrerebbe viva, e non lo è.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row: Dictionary in _rows:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 2)
		line.material = chalk
		lines.add_child(line)
		# Dopo `add_child()`: il contenitore riposiziona i figli ma la rotazione
		# la lascia com'è. Il perno al centro, o la riga girerebbe sul bordo.
		line.rotation_degrees = rng.randf_range(-TILT, TILT)
		line.resized.connect(func() -> void: line.pivot_offset = line.size * 0.5)
		if row.has("icon"):
			var icon := TextureRect.new()
			icon.texture = row["icon"]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = LEAF_SIZE
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Schiarita verso il gesso: a colori pieni sembrava un adesivo.
			icon.modulate = Color(0.85, 1.0, 0.85, 0.9)
			icon.use_parent_material = true
			line.add_child(icon)
		var label := _chalk_label(tr(str(row["label"])), TEXT_SIZE, CHALK_SOFT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Se la riga non ci sta, cede il nome e non il numero: senza, un numero
		# lungo spingeva la riga oltre la cornice invece di restarci dentro.
		label.clip_text = true
		line.add_child(label)
		_labels.append(label)
		var value := _chalk_label("", TEXT_SIZE, CHALK)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		_values.append(value)
		if row.has("unit"):
			var unit := _chalk_label("", UNIT_SIZE, CHALK_SOFT)
			# In basso, allineata al piede del numero come si scrive a mano.
			unit.size_flags_vertical = Control.SIZE_SHRINK_END
			line.add_child(unit)
			_units.append(unit)
		else:
			_units.append(null)
		_shown.append("")
	GameSettings.locale_changed.connect(_on_locale_changed)

## Una scritta col gesso: il pennello senza ombra, e il materiale della riga.
func _chalk_label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", UiTheme.WINDOW_FILE)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.use_parent_material = true
	return node

func _process(_delta: float) -> void:
	var data := GameState.current
	if data == null:
		return
	for i in _rows.size():
		var text: String = (_rows[i]["text"] as Callable).call(data)
		if text != _shown[i]:
			_shown[i] = text
			_values[i].text = text
			if _units[i] != null:
				(_units[i] as Label).text = (_rows[i]["unit"] as Callable).call(data)

func _on_locale_changed(_locale: String) -> void:
	for i in _rows.size():
		_labels[i].text = tr(str(_rows[i]["label"]))
