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
## ## Gli stessi pezzi della città
##
## La strada è la piastrella del kit di Kenney che asfalta la città
## (`assets/sprites/roads/straight.png`), e le banchine sono l'erba a strati di
## `layered_grass.gdshader`, con le tinte del prato curato. Tutto alla stessa
## scala, `SCALE`: pixel di strada, d'erba e di furgone grandi uguali, come
## sulla mappa. Serve a dare **peso** al momento — il carico se ne va davvero,
## e per qualche ora non c'è né merce né soldi. Il colore del cielo non è
## inventato: lo chiede a `Daylight`, quindi una partenza all'alba e una a
## mezzanotte sono diverse.
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

## Quanto è ingrandito il mondo del filmato rispetto alla mappa. A 1,6 la
## piastrella (120 px) occupa quasi due terzi dello spazio fra le bande, e
## sopra e sotto resta una striscia di prato che si legge come campagna.
const SCALE := 1.6

const ROAD_TILE := preload("res://assets/sprites/roads/straight.png")
## Dove corre il furgone dentro alla piastrella, in pixel della piastrella:
## l'asfalto va da 12 a 108, e la corsia di destra per chi va verso est è
## quella di sotto.
const LANE_Y := 84.0

## Il colore che moltiplica tutto: `Daylight.air()` non e' un cielo, e' un
## filtro, ed e' il modo in cui `Atmosphere` tinge la mappa. Qui non c'e' un
## `CanvasModulate`, quindi lo si passa a mano a strada ed erba.

var _frame: Control = null
var _stage: Control = null
## Le banchine: un nodo col materiale dell'erba, sotto allo `_stage` perché la
## strada e il furgone ci vanno sopra.
var _grass: Node2D = null
var _grass_material: ShaderMaterial = null
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
	add_to_group(UiTheme.MODAL_GROUP)

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_child(shade)

	_grass_material = ShaderMaterial.new()
	_grass_material.shader = LayeredGrass.SHADER
	var colors: Dictionary = LayeredGrass.STYLES["curato"]
	for key in colors:
		_grass_material.set_shader_parameter(key, colors[key])
	_grass = Node2D.new()
	_grass.scale = Vector2(SCALE, SCALE)
	_grass.material = _grass_material
	_grass.draw.connect(_draw_grass)
	_frame.add_child(_grass)

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
	var entry := Weather.entry(Weather.of(GameState.current))
	_grass_material.set_shader_parameter("scorrimento", _scroll * SCROLL / SCALE)
	_grass_material.set_shader_parameter("vento", 0.25 + absf(float(entry["wind"])))
	_grass_material.set_shader_parameter(
		"sole", Daylight.sun_height(Daylight.hour_of(GameState.current)) * float(entry["shadows"]))
	_grass.queue_redraw()
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

## La strada vista dall'alto, come tutto il resto del gioco: la piastrella
## della città ripetuta e fatta scorrere, il prato sopra e sotto.
##
## Dall'alto e non di profilo, ed e' la scelta che conta: di profilo servirebbe
## un orizzonte, un cielo e delle facciate, cioe' tre cose che il gioco non ha.
## Dall'alto invece si riusa quello che c'e' gia' — la strada, l'erba, lo sprite
## del mezzo, l'ombra, il colore dell'ora — e il filmato sembra un pezzo dello
## stesso gioco.
func _draw_stage() -> void:
	var size := _stage.size
	var air := _air()
	var road_top := _road_top(size)
	var tile := ROAD_TILE.get_size().x * SCALE
	var shift := fposmod(_scroll * SCROLL, tile)
	for i in range(-1, int(size.x / tile) + 2):
		_stage.draw_texture_rect(ROAD_TILE, Rect2(float(i) * tile - shift, road_top, tile, tile), false, air)
	_draw_van(road_top + LANE_Y * SCALE)

	# Le bande, sempre per ultime: coprono tutto quello che sborda.
	_stage.draw_rect(Rect2(0, 0, size.x, BAR), Color(0, 0, 0))
	_stage.draw_rect(Rect2(0, size.y - BAR, size.x, BAR), Color(0, 0, 0))

## Le due banchine, in pixel del nodo dell'erba (cioè divisi per `SCALE`).
## Tutte e due passano sotto alla strada: il prato comincia con una fila vuota e
## un bordo seghettato, e quel pezzo lo deve coprire la piastrella.
func _draw_grass() -> void:
	var size := _stage.size / SCALE
	var road_top := _road_top(_stage.size) / SCALE
	var road_bottom := road_top + ROAD_TILE.get_size().y
	var top := BAR / SCALE - 24.0
	_grass_rect(Rect2(0, top, size.x, road_top + 16.0 - top))
	_grass_rect(Rect2(0, road_bottom - 48.0, size.x, size.y - road_bottom + 48.0))

func _grass_rect(rect: Rect2) -> void:
	# La UV porta il bordo alto del prato: vedi `layered_grass.gdshader`.
	var uv := Vector2(rect.position.y, 0.0)
	_grass.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([_air()]),
		PackedVector2Array([uv, uv, uv, uv]))

func _road_top(size: Vector2) -> float:
	return (size.y - ROAD_TILE.get_size().y * SCALE) * 0.5

func _air() -> Color:
	var air: Color = Daylight.light(GameState.current)
	air.a = 1.0
	return air

## Il furgone: fermo al centro dello schermo, nella corsia di destra come in
## citta', con un sobbalzo che basta a non farlo sembrare un adesivo e l'ombra
## sotto.
func _draw_van(lane: float) -> void:
	var texture_size := VAN.get_size() * SCALE
	var bob := roundf(sin(_scroll * 11.0) * 1.2)
	var x := _stage.size.x * 0.5 - texture_size.x * 0.5
	var y := lane - texture_size.y * 0.5 + bob

	# L'ombra, come quella che il furgone si porta dietro sulla mappa: segue il
	# sole invece di stare sempre nello stesso posto.
	var info := Daylight.shadow(GameState.current)
	var slide: Vector2 = (info["direction"] as Vector2) * minf(float(info["length"]) * 4.0, 9.0)
	var centre := Vector2(x + texture_size.x * 0.5, y + texture_size.y * 0.5) + slide
	var points := Shapes.ellipse(centre, texture_size * Vector2(0.44, 0.30))
	_stage.draw_colored_polygon(points, Color(0, 0, 0, 0.16 + float(info["alpha"]) * 0.35))
	_stage.draw_texture_rect(VAN, Rect2(Vector2(x, y), texture_size), false, _air())
