@tool
extends EnterableBuilding
class_name BuildingPlaceholder

## Segnaposto di un edificio, in attesa del PNG pixel art definitivo.
##
## L'origine del nodo è il PUNTO A TERRA al centro della facciata: il rettangolo
## viene disegnato verso l'alto. Così il nodo si ordina correttamente con l'Y-sort
## e, quando arriverà lo sprite vero, basta sostituirlo con uno Sprite2D che ha
## lo stesso pivot (offset = -size/2 sull'asse X, -altezza sull'asse Y).
##
## Estende `EnterableBuilding` perché un edificio è cliccabile per definizione:
## quelli senza `interior_scene` fanno solo avvicinare il protagonista, quelli
## con l'interno ci fanno entrare. Così un segnaposto diventa visitabile
## riempiendo un campo, senza cambiargli nodo o script.
##
## ## Le finestre
##
## Un quartiere di rettangoli colorati si legge come una scacchiera anche
## quando la pianta è giusta: manca la scala. Le finestre gliela danno di
## giorno, e di notte fanno il resto del lavoro — una fila di edifici spenti con
## dentro una trentina di luci accese è una città abitata, la stessa fila senza
## è un magazzino.
##
## Quali sono accese lo decide `Daylight.window_lit_ratio()`, ma **quale
## finestra** si accende prima delle altre è deciso una volta per sempre dalla
## posizione della finestra stessa: ogni finestra ha la sua soglia, e si accende
## quando la quota dell'ora la supera. Non c'è nessuno stato da tenere e da
## salvare, e soprattutto le finestre non sfarfallano — le accende e le spegne
## il passare delle ore, una per volta, sempre nello stesso ordine.
##
## ## L'ombra
##
## L'ombra a terra segue il sole: lunga e sbiadita all'alba, corta e netta a
## mezzogiorno, dall'altra parte al tramonto. Col cielo coperto resta solo il
## velo di contatto. È la cosa che fa leggere l'ora guardando la strada invece
## che l'orologio dell'HUD.

## Ingombro della facciata in pixel (larghezza x altezza).
@export var size := Vector2(128, 96):
	set(value):
		size = value
		_windows.clear()
		queue_redraw()
## Nome mostrato al centro del segnaposto.
@export var label := "PLACEHOLDER":
	set(value):
		label = value
		queue_redraw()
## Colore di riempimento del blocco.
@export var fill_color := Color(0.42, 0.40, 0.44):
	set(value):
		fill_color = value
		queue_redraw()
## Colore del bordo e del testo.
@export var line_color := Color(0.92, 0.94, 0.98, 0.85):
	set(value):
		line_color = value
		queue_redraw()
## Numero di piani: se > 1 disegna delle linee orizzontali che li suggeriscono.
@export_range(1, 12) var floors := 1:
	set(value):
		floors = value
		_windows.clear()
		queue_redraw()

const FONT_SIZE := 8

## Griglia delle finestre. Il passo è quello di un palazzo vero e non una
## frazione della facciata: un edificio largo il doppio ha il doppio delle
## finestre, non finestre larghe il doppio.
const WINDOW_SIZE := Vector2(7.0, 9.0)
const WINDOW_STEP := Vector2(15.0, 17.0)
## Margine dai bordi della facciata. Sotto ai 10 px le finestre finiscono
## incollate allo spigolo e l'edificio perde il suo muro.
const WINDOW_MARGIN := Vector2(10.0, 9.0)
## Sotto a questa larghezza (o altezza) non ci sta una finestra che si veda:
## capanni, garage, chioschi restano ciechi, ed è giusto che lo siano.
const WINDOW_MIN_FACE := Vector2(44.0, 30.0)

## Le tinte delle finestre accese. Tre e non una: il giallo caldo delle lampade,
## l'ambra delle stanze sul retro, e il bluastro di chi sta guardando la TV.
## È il terzo colore quello che fa capire che dentro c'è qualcuno.
const WINDOW_LIT := [
	Color(1.00, 0.84, 0.50),
	Color(1.00, 0.72, 0.36),
	Color(0.62, 0.80, 1.00),
]
## Il vetro spento: scuro e appena azzurrino, come un vetro che riflette il cielo.
const WINDOW_DARK := Color(0.16, 0.17, 0.23, 0.70)
## Dove va a finire una finestra accesa quando fuori è giorno pieno: un vetro
## chiaro e spento, non una luce. Vedi `_draw_windows()`.
const DAYLIT := Color(0.62, 0.60, 0.55)

## Le finestre in coordinate locali, calcolate una volta sola.
##
## Ogni voce è `[Rect2, soglia, tinta]`: la soglia è il punto in cui questa
## finestra si accende sulla curva delle ore, la tinta l'indice in `WINDOW_LIT`.
## Sono qualche migliaio in tutta la città e non cambiano mai: ricavarle a ogni
## ridisegno vorrebbe dire rifare lo stesso conto venti volte per giornata di
## gioco, per ognuno dei quattrocento edifici.
var _windows: Array = []

func _ready() -> void:
	add_to_group(Daylight.LIGHT_GROUP)

## Chiamata da `atmosphere.gd` quando la luce è cambiata abbastanza da vedersi.
func on_light_changed() -> void:
	queue_redraw()

## Il rettangolo del segnaposto, in coordinate locali: origine a terra al
## centro, corpo verso l'alto.
func body_rect() -> Rect2:
	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)

## L'area cliccabile è il segnaposto stesso, quindi `click_rect` non serve:
## sarebbe un secondo rettangolo da tenere in sincrono con `size` a ogni
## ritocco del quartiere, e prima o poi i due divergono.
func contains_point(global_point: Vector2) -> bool:
	return body_rect().has_point(to_local(global_point))

func _draw() -> void:
	var rect := body_rect()
	var data := _game_data()
	var ambient := Daylight.light(data)
	# L'ombra a terra va PRIMA della facciata: disegnata dopo, la parte che
	# ricade sull'edificio sembra una macchia sul muro.
	_draw_ground_shadow(data)
	draw_rect(rect, fill_color, true)
	# Tetto/parte alta leggermente più chiara: aiuta a leggere il volume.
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), fill_color.lightened(0.18), true)
	_draw_windows(data, ambient)
	draw_rect(rect, line_color, false, 1.0)

	for i in range(1, floors):
		var y := rect.position.y + rect.size.y * float(i) / float(floors)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color * Color(1, 1, 1, 0.35), 1.0)

	_draw_label(rect)

# --- Ombra ------------------------------------------------------------------

## L'ombra portata: la base dell'edificio trascinata nella direzione opposta al
## sole, più il velo di contatto sotto.
##
## Sono due cose diverse e servono tutte e due. Il trascinamento dice che ore
## sono; il velo dice che l'edificio poggia per terra, e senza quello a
## mezzogiorno — quando l'ombra è cortissima — l'edificio tornerebbe a
## galleggiare proprio nell'ora di luce più piena.
func _draw_ground_shadow(data: SaveData) -> void:
	var info := Daylight.shadow(data)
	var alpha := float(info["alpha"])
	var half := size.x * 0.5
	var cast: Vector2 = (info["direction"] as Vector2) * size.y * float(info["length"])

	if alpha > 0.02 and cast.length() > 4.0:
		# L'ombra si allarga un po' allontanandosi: un parallelogramma a lati
		# paralleli si legge come un pezzo di cartone, non come un'ombra.
		var spread := half * 1.12
		draw_colored_polygon(PackedVector2Array([
			Vector2(-half, 0), Vector2(half, 0),
			Vector2(spread, 0) + cast, Vector2(-spread, 0) + cast,
		]), Color(0, 0, 0, alpha * 0.55))

	var contact := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		contact.append(Vector2(cos(a) * half, sin(a) * 6.0))
	draw_colored_polygon(contact, Color(0, 0, 0, maxf(alpha, 0.16) * 0.65))

# --- Finestre ---------------------------------------------------------------

func _draw_windows(data: SaveData, ambient: Color) -> void:
	if _windows.is_empty():
		_build_windows()
	if _windows.is_empty():
		return
	var ratio := Daylight.window_lit_ratio(Daylight.hour_of(data))
	# Col brutto tempo si accende la luce anche a metà pomeriggio: è lo stesso
	# motivo per cui si accendono i lampioni, e si legge subito.
	if bool(Weather.entry(Weather.of(data))["dark"]):
		ratio = maxf(ratio, 0.30)
	# Quanto è buio fuori, 0 a mezzogiorno e 1 a notte fonda. Una finestra
	# accesa si vede in proporzione a quanto è scuro intorno: in pieno giorno è
	# un vetro appena più chiaro, e disegnarla arancione accesa la farebbe
	# sembrare una luce al neon in mezzo al sole.
	var dark := 1.0 - Daylight.brightness(data)

	for window in _windows:
		var rect: Rect2 = window[0]
		if float(window[1]) < ratio:
			var lit: Color = (WINDOW_LIT[int(window[2])] as Color).lerp(DAYLIT, 1.0 - dark)
			# L'alone intorno al vetro: è quello che si vede da lontano, molto
			# più del vetro stesso, che a questa scala è alto nove pixel. Di
			# giorno non c'è: un alone in pieno sole non esiste.
			var halo := lit
			halo.a = 0.30 * dark
			if halo.a > 0.02:
				draw_rect(rect.grow(2.0), Daylight.emissive(halo, ambient), true)
			draw_rect(rect, Daylight.emissive(lit, ambient), true)
		else:
			draw_rect(rect, WINDOW_DARK, true)

## Dispone le finestre sulla facciata e dà a ognuna la sua soglia di accensione.
##
## Le soglie vengono dalla posizione della finestra nel mondo e non da un
## `randf()`: due partite diverse devono trovare la stessa città, e ricaricando
## il salvataggio le stesse luci devono essere ancora accese.
func _build_windows() -> void:
	if size.x < WINDOW_MIN_FACE.x or size.y < WINDOW_MIN_FACE.y:
		return
	var rect := body_rect()
	var usable := rect.grow(-1.0)
	usable.position += WINDOW_MARGIN
	usable.size -= WINDOW_MARGIN * 2.0
	# Il tetto più chiaro non ha finestre: sono otto pixel di cornicione.
	usable.position.y += 6.0
	usable.size.y -= 6.0
	if usable.size.x < WINDOW_SIZE.x or usable.size.y < WINDOW_SIZE.y:
		return

	var columns := maxi(1, int((usable.size.x + WINDOW_STEP.x - WINDOW_SIZE.x) / WINDOW_STEP.x))
	var rows := maxi(1, int((usable.size.y + WINDOW_STEP.y - WINDOW_SIZE.y) / WINDOW_STEP.y))
	# Centrate sulla facciata: appoggiate al margine sinistro, un edificio
	# largo lascerebbe una striscia di muro cieco tutta da una parte.
	var spread := Vector2(
		float(columns - 1) * WINDOW_STEP.x + WINDOW_SIZE.x,
		float(rows - 1) * WINDOW_STEP.y + WINDOW_SIZE.y)
	var origin := usable.position + (usable.size - spread) * Vector2(0.5, 0.5)
	# Il seme parte dalla posizione nel mondo: due edifici identici in due
	# quartieri diversi non si accendono con lo stesso disegno.
	var seed_base := int(global_position.x) * 7919 + int(global_position.y) * 104729

	for row in rows:
		for column in columns:
			var noise := absi(hash(seed_base + row * 131 + column * 17))
			_windows.append([
				Rect2(origin + Vector2(column, row) * WINDOW_STEP, WINDOW_SIZE),
				float(noise % 1000) / 1000.0,
				(noise / 1000) % WINDOW_LIT.size(),
			])

# --- Etichetta --------------------------------------------------------------

func _draw_label(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var lines := label.split(" ")
	var total := float(lines.size()) * FONT_SIZE
	var y := rect.get_center().y - total * 0.5 + FONT_SIZE
	for line in lines:
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(-w * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, line_color)
		y += FONT_SIZE

# --- Utilità ----------------------------------------------------------------

## La partita in corso, oppure `null` nell'editor.
##
## Questo è uno script `@tool`: gira anche dentro all'editor, dove gli autoload
## non esistono e nominare `GameState` sarebbe un errore. Con `null` tutta la
## catena di `Daylight` ricade sull'ora del menu, quindi nell'editor l'edificio
## si vede come si vedrebbe di sera — che è anche il modo più utile di vederlo,
## visto che è di sera che le finestre servono.
func _game_data() -> SaveData:
	if Engine.is_editor_hint():
		return null
	return GameState.current
