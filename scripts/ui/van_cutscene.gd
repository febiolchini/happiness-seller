extends CanvasLayer

## Il filmato della partenza: il furgone che lascia la città col carico.
##
## ## Perché un filmato e non un'animazione sulla mappa
##
## La spedizione si ordina dal PC, e il PC sta **in cantina**. Fino a ieri
## l'unica cosa che si vedeva partire era il furgone in strada — cioè in una
## scena in cui, nel momento in cui si preme il bottone, non si è. Chi vendeva
## all'ingrosso vedeva un messaggino e nient'altro: il carico spariva dal
## magazzino e non succedeva niente.
##
## Questo invece è un `CanvasLayer` appeso a `GameState`, come le vignette:
## sta sopra alla scena corrente qualunque essa sia, quindi si vede uguale in
## cantina, in cucina e in strada. Non sa niente della City e non la usa.
##
## ## È un segnaposto, e si vede
##
## Non c'è pixel art di un viaggio: qui ci sono lo sprite del furgone del pacco
## delle auto e una strada di campagna disegnata a rettangoli che scorre. Serve a dare **peso** al momento — il carico se ne va davvero,
## e per qualche ora non c'è né merce né soldi — e a tenere il posto a quello
## che ci andrà. Il colore del cielo però non è inventato: lo chiede a
## `Daylight`, quindi una partenza all'alba e una a mezzanotte sono diverse.
##
## Il ritorno **non** ha filmato, ed è voluto: si torna a casa, e a raccontarlo
## basta il furgone che rientra e parcheggia (`delivery_van.gd`). Un filmato a
## ogni consegna diventerebbe una cosa da saltare.
##
## Si chiude da solo, e un click lo chiude subito: chi l'ha già visto dieci
## volte non deve aspettarlo.

const GAME_FONT := preload("res://assets/sprites/ui/alphabet.fnt")
const VAN := preload("res://assets/sprites/props/cars/pickupTruck02.png")

## Sopra a tutto, vignette comprese (che stanno a 50).
const LAYER := 60

## Quanto dura, in secondi veri. Abbastanza da leggere la riga e vedere il
## furgone attraversare, poco abbastanza da non essere un dazio.
const FADE_IN := 0.35
const HOLD := 2.6
const FADE_OUT := 0.45

## Le bande nere sopra e sotto: sono il segno che quello che si sta guardando
## non è più il gioco ma un filmato.
const BAR := 30.0

## Quanto scorre la città dietro, in pixel al secondo. Il furgone sta fermo al
## centro e si muove il mondo: è il trucco più vecchio che c'è, e qui serve a
## non dover disegnare una strada lunga.
const SCROLL := 210.0

## Quanto e' alta la carreggiata, in frazione dell'altezza fra le due bande. Il
## resto sono le due banchine, una sopra e una sotto.
const ROAD_HEIGHT := 0.46

## I colori della campagna fuori citta'. Vanno **moltiplicati** per il colore
## dell'aria e non usati da soli, che e' poi il modo in cui `Atmosphere` tinge
## la mappa: `Daylight.air()` non e' un cielo, e' un filtro, e a mezzogiorno e'
## quasi bianco — preso per un colore darebbe una campagna bianca.
const FIELD := Color(0.38, 0.42, 0.30)
const BUSH := Color(0.26, 0.31, 0.21)
const ROAD := Color(0.17, 0.17, 0.19)
const STRIPE := Color(0.72, 0.68, 0.45)

var _frame: Control = null
var _stage: Control = null
var _caption: Label = null
## La riga sotto. Arriva da `setup()` prima che il nodo sia nell'albero, quindi
## si tiene qui e si scrive nella Label quando esiste.
var _line := ""
var _scroll := 0.0
var _closing := false

func _ready() -> void:
	layer = LAYER
	# Un filmato è l'unica cosa che davvero copre il gioco: HUD e telefono si
	# tolgono di mezzo come per gli avvisi. Vedi `hud.gd`.
	add_to_group("modal")

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_child(shade)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Il disegno sta nello script del filmato e non in uno script a parte per
	# un `Control` di due righe: il segnale `draw` fa la stessa cosa senza
	# aggiungere un file.
	_stage.draw.connect(_draw_stage)
	_frame.add_child(_stage)

	_caption = Label.new()
	_caption.add_theme_font_override("font", GAME_FONT)
	_caption.add_theme_font_size_override("font_size", 16)
	# Chiaro, e non nero come nelle vignette: l'ombra del font è dipinta dentro
	# ai glifi e non si toglie, quindi la si fa sparire nel fondo. Sulla carta
	# bianca del fumetto il fondo è chiaro e quindi si scrive nero; qui la
	# banda è nera e quindi si scrive chiaro.
	_caption.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.anchor_left = 0.0
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -BAR - 2.0
	_caption.offset_bottom = -2.0
	_caption.text = _line
	_frame.add_child(_caption)

	_frame.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_frame, "modulate:a", 1.0, FADE_IN)
	tween.tween_interval(HOLD)
	tween.tween_callback(close)

## Il testo sotto. Si chiama da fuori prima di aggiungerlo all'albero.
func setup(line: String) -> void:
	_line = line
	if _caption != null:
		_caption.text = line

func _process(delta: float) -> void:
	_scroll += delta
	_stage.queue_redraw()

func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseButton and event.pressed:
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	var tween := create_tween()
	tween.tween_property(_frame, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)

# --- Il disegno -------------------------------------------------------------

## La strada vista dall'alto, come tutto il resto del gioco: due banchine, la
## carreggiata in mezzo, la riga tratteggiata che scorre.
##
## Dall'alto e non di profilo, ed e' la scelta che conta: di profilo servirebbe
## un orizzonte, un cielo e delle facciate, cioe' tre cose che il gioco non ha
## e che a disegnarle a rettangoli stonano con la pixel art. Dall'alto invece si
## riusa quello che c'e' gia' — lo sprite del mezzo, l'ombra, il colore
## dell'ora — e il filmato sembra un pezzo dello stesso gioco.
func _draw_stage() -> void:
	var size := _stage.size
	var top := BAR
	var bottom := size.y - BAR
	var height := bottom - top
	var road_top := top + height * (1.0 - ROAD_HEIGHT) * 0.5
	var road_bottom := bottom - height * (1.0 - ROAD_HEIGHT) * 0.5

	var air: Color = Daylight.air(Daylight.hour_of(GameState.current))
	_stage.draw_rect(Rect2(0, top, size.x, height), FIELD * air)
	_draw_verge(size, top, road_top, air)
	_draw_verge(size, road_bottom, bottom, air)
	_draw_road(size, road_top, road_bottom, air)
	_draw_van(size, road_top, road_bottom)

	# Le bande, sempre per ultime: coprono tutto quello che sborda.
	_stage.draw_rect(Rect2(0, 0, size.x, top), Color(0, 0, 0))
	_stage.draw_rect(Rect2(0, bottom, size.x, size.y - bottom), Color(0, 0, 0))

## La campagna che scorre ai lati: macchie di verde piu' scuro. Le dimensioni
## escono dall'indice e non dal caso, cosi' non ballano da un fotogramma
## all'altro e la sequenza si ripete uguale.
func _draw_verge(size: Vector2, from: float, to: float, air: Color) -> void:
	var step := 74.0
	var shift := fposmod(_scroll * SCROLL * 0.75, step)
	var band := to - from
	for i in range(-1, int(size.x / step) + 3):
		var slot := int(floor((float(i) * step) / step)) + int(from)
		var kind := absi(slot) % 4
		var x := float(i) * step - shift + float(kind) * 9.0
		var width := 18.0 + float(kind) * 7.0
		var y := from + band * (0.22 + 0.16 * float(kind % 3))
		# Macchie tonde e non rettangoli: un cespuglio quadrato si legge come un
		# pezzo di interfaccia rimasto li' per sbaglio.
		_blob(Rect2(x, y, width, band * 0.30), BUSH * air)

## Un'ellisse dentro a un rettangolo. `draw_circle()` non basta: i cespugli sono
## piu' larghi che alti.
func _blob(box: Rect2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(box.get_center() + Vector2(
			cos(a) * box.size.x * 0.5, sin(a) * box.size.y * 0.5))
	_stage.draw_colored_polygon(points, tint)

## L'asfalto, i bordi e la riga tratteggiata. La riga e' l'unica cosa che dice
## quanto si sta andando forte.
func _draw_road(size: Vector2, road_top: float, road_bottom: float, air: Color) -> void:
	_stage.draw_rect(Rect2(0, road_top, size.x, road_bottom - road_top), ROAD * air)
	_stage.draw_rect(Rect2(0, road_top, size.x, 2.0), (ROAD * air).lightened(0.18))
	_stage.draw_rect(Rect2(0, road_bottom - 2.0, size.x, 2.0), (ROAD * air).lightened(0.18))

	var y := (road_top + road_bottom) * 0.5 - 1.5
	var step := 58.0
	var shift := fposmod(_scroll * SCROLL, step)
	for i in range(-1, int(size.x / step) + 3):
		_stage.draw_rect(Rect2(float(i) * step - shift, y, 26.0, 3.0), STRIPE * air)

## Il furgone: fermo al centro dello schermo, nella corsia di destra come in
## citta', con un sobbalzo che basta a non farlo sembrare un adesivo e l'ombra
## sotto.
func _draw_van(size: Vector2, road_top: float, road_bottom: float) -> void:
	var texture_size := VAN.get_size() * 2.6
	var bob := sin(_scroll * 11.0) * 1.5
	var lane := road_top + (road_bottom - road_top) * 0.72
	var x := size.x * 0.5 - texture_size.x * 0.5
	var y := lane - texture_size.y * 0.5 + bob

	# L'ombra, come quella che il furgone si porta dietro sulla mappa: segue il
	# sole invece di stare sempre nello stesso posto.
	var info := Daylight.shadow(GameState.current)
	var slide: Vector2 = (info["direction"] as Vector2) * minf(float(info["length"]) * 7.0, 14.0)
	var centre := Vector2(x + texture_size.x * 0.5, y + texture_size.y * 0.5) + slide
	var points := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(centre + Vector2(
			cos(a) * texture_size.x * 0.44, sin(a) * texture_size.y * 0.30))
	_stage.draw_colored_polygon(points, Color(0, 0, 0, 0.16 + float(info["alpha"]) * 0.35))
	_stage.draw_texture_rect(VAN, Rect2(Vector2(x, y), texture_size), false)
