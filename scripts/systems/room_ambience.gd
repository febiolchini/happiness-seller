extends Control

## L'aria dentro casa: la luce che cambia con l'ora, il taglio di sole sul
## pavimento, la pioggia sui vetri, i lampi del temporale, il pulviscolo.
##
## È il corrispettivo di `atmosphere.gd` + `weather_view.gd` per le stanze, e fa
## il suo lavoro nello stesso modo: un `CanvasModulate` tinge tutta la stanza,
## e quello che deve restare acceso dentro alla tinta si disegna con
## `Daylight.emissive()`. La differenza è che qui la tela è quella di un
## `Control` e non del mondo — l'HUD sta su una tela sua e resta fuori, come in
## City.
##
## ## Dentro non è fuori
##
## La luce dell'interno **non** è quella della strada: è quella della strada
## smorzata (`INDOOR_BLEND`), e dopo il tramonto vira verso la lampadina di casa
## invece di andare sul blu. Copiare la luce esterna vorrebbe dire una cucina
## blu notte alle dieci di sera, quando invece a quell'ora una cucina è il posto
## più caldo della città — ed è il contrasto fra le due cose a far sentire che
## si è rientrati.
##
## ## Perché non è nella scena
##
## `Room.tscn` è ereditata da `Entrance`, `Kitchen` e `Basement`, che si
## riferiscono ai propri nodi per indice. Aggiungere un nodo alla scena base
## sposterebbe quegli indici. Costruita da `room.gd`, la stanza si ritrova
## l'atmosfera senza che nessuna delle tre scene venga toccata — che è la stessa
## regola della città: la scena si costruisce dai dati.

## Quanta della luce di fuori entra in casa. A 1.0 l'interno seguirebbe la
## strada nota per nota, e di notte una stanza sarebbe buia come un vicolo.
const INDOOR_BLEND := 0.58
## La lampadina di casa: è lei a illuminare quando fuori è buio.
const LAMP := Color(1.00, 0.86, 0.64)
## Quanto pesa la lampadina col buio pieno.
const LAMP_SHARE := 0.55
## La luce di una cantina: niente sole, un neon stanco. Non cambia con l'ora,
## perché sottoterra l'ora non si vede — ed è esattamente il motivo per cui si
## perde il senso del tempo a coltivare di sotto.
const CELLAR := Color(0.88, 0.90, 0.97)
## Dove tira la cantina quando le lampade da coltivazione sono accese. Più se ne
## comprano, più il rosso prende la stanza: è il modo più diretto di far vedere
## che quello che c'è di sotto è cresciuto.
const CELLAR_GROW := Color(1.00, 0.80, 0.76)

## Il taglio di luce che entra dalla finestra.
const SHAFT := Color(1.00, 0.95, 0.82)
const SHAFT_LAYERS := 3
## Quanto è lungo il taglio rispetto all'altezza della finestra, e fin dove può
## arrivare comunque. Il tetto serve: col sole radente il fattore delle ombre
## arriva a 2.3, e senza limite il taglio uscirebbe dalla stanza attraversando
## tutto lo schermo come una diagonale disegnata col righello.
const SHAFT_REACH := 2.4
const SHAFT_MAX := 190.0

## La pioggia sul vetro: gocce lente e corte, non scrosci. Da dentro si vede
## l'acqua che scende sul vetro, non le gocce che cadono.
const GLASS_DROPS := 22
const GLASS_COLOR := Color(0.72, 0.82, 0.95)

## Pulviscolo nell'aria. È la cosa che toglie a una stanza ferma l'aria di uno
## screenshot: nient'altro si muove, in un interno.
const MOTES := 34
const MOTE_COLOR := Color(1.00, 0.96, 0.86)

## Le finestre del palazzo di fronte, viste dalla propria finestra di notte.
const OUTSIDE_LIT := Color(1.00, 0.82, 0.48)

## Il lampo: fuori dalla finestra e, per un istante, su tutta la stanza.
const FLASH_FADE := 4.0
const FLASH_PEAK := 0.30

## Il tremolio del neon della cantina. Minimo e lentissimo: un neon che
## sfarfalla a vista diventa un effetto, e dopo tre minuti dà fastidio.
const FLICKER_DEPTH := 0.035

var _tint: CanvasModulate = null
var _daylight := true
var _window := Rect2()
## La finestra come si vede davvero: quattro angoli, in alto a sinistra, in
## alto a destra, in basso a destra, in basso a sinistra. Per una finestra vista
## di fronte sono gli angoli di `_window`; per una vista di sbieco (il garage)
## è un trapezio, e `_window` è solo il rettangolo che la contiene. Tutto quello
## che si DISEGNA sul vetro usa questi, così il cielo della sera non finisce sul
## muro intorno.
var _quad := PackedVector2Array()
## Le scritte della stanza: nome e uscite. Vedi `_keep_readable()`.
var _readable: Array[CanvasItem] = []

## Ogni goccia sul vetro: posizione e velocità. Ogni granello di pulviscolo:
## posizione, fase e velocità.
var _drops: Array[Vector3] = []
var _motes: Array[Vector3] = []

var _time := 0.0
var _flash := 0.0
var _next_bolt := -1.0
## La luce dentro adesso. Tenuta qui perché serve sia al `CanvasModulate` sia a
## `emissive()` quando si disegna il taglio di sole.
var _ambient := Color.WHITE
## Piove adesso? Calcolato una volta in `_process()` e riletto sia da
## `_move_particles()` sia da `_draw()`, invece che da `Weather.of()` in tutti
## e due.
var _wet := false

## La chiama `room.gd` appena costruita la stanza.
##
## `readable` sono i nodi che la tinta NON deve spegnere: vedi `_keep_readable()`.
##
## `quad` è facoltativo: vedi `_quad`. Vuoto vuol dire una finestra dritta, e
## gli angoli si prendono da `window`.
func setup(tint: CanvasModulate, has_daylight: bool, window: Rect2, readable: Array,
		quad := PackedVector2Array()) -> void:
	_tint = tint
	_daylight = has_daylight
	_window = window
	if quad.size() == 4:
		_quad = quad
		_window = Rect2(quad[0], Vector2.ZERO)
		for corner in quad:
			_window = _window.expand(corner)
	elif window.size.x > 0.0:
		_quad = PackedVector2Array([window.position, Vector2(window.end.x, window.position.y),
				window.end, Vector2(window.position.x, window.end.y)])
	for item in readable:
		if item is CanvasItem:
			_readable.append(item)

func _ready() -> void:
	# Non deve rubare i click ai vasi, al PC e alle uscite: è un velo, non un
	# pannello.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_seed_particles()
	_next_bolt = Weather.next_bolt_delay(Weather.of(GameState.current))

func _process(delta: float) -> void:
	_time += delta
	_ambient = _indoor_light()
	_wet = Weather.is_wet(Weather.of(GameState.current))
	_flash = maxf(0.0, _flash - delta * FLASH_FADE)
	_tick_storm(delta)
	if _tint != null:
		_tint.color = _ambient.lerp(Color(1.2, 1.2, 1.3), _flash * 0.6)
	_keep_readable()
	_move_particles(delta)
	queue_redraw()

# --- La luce dentro ---------------------------------------------------------

## Che luce c'è in questa stanza adesso.
##
## Una stanza con le finestre segue l'ora smorzata e vira sul caldo quando fuori
## cala; una cantina non segue niente, perché sottoterra non c'è niente da
## seguire. Vedi i commenti su `INDOOR_BLEND` e `CELLAR`.
func _indoor_light() -> Color:
	var data := GameState.current
	if not _daylight:
		var lamps := mini(Shop.owned(data, "lamps"), 3)
		var grow := CELLAR.lerp(CELLAR_GROW, float(lamps) / 3.0 * 0.7)
		# Il tremolio del neon: lento, e sempre verso il basso, perché un neon
		# stanco cala di colpo e risale piano.
		var flicker := 1.0 - FLICKER_DEPTH * maxf(0.0, sin(_time * 2.3) * sin(_time * 0.71))
		return grow * flicker

	var outside := Daylight.light(data)
	var indoor := Color.WHITE.lerp(outside, INDOOR_BLEND)
	# Più fuori è buio, più a illuminare è la lampadina di casa.
	var dark := 1.0 - Daylight.brightness(data)
	return indoor.lerp(LAMP * indoor, dark * LAMP_SHARE)

# --- Temporale --------------------------------------------------------------

## Come in `atmosphere.gd`, i fulmini scorrono in secondi veri: sono un evento
## che si guarda mentre succede. La cadenza la decide la tabella del meteo, così
## il temporale che si sente da dentro casa è lo stesso che c'è fuori.
func _tick_storm(delta: float) -> void:
	if _next_bolt < 0.0:
		# Il tempo può cambiare mentre si è in casa: a mezzanotte scatta il
		# giorno nuovo anche stando di sotto a annaffiare.
		_next_bolt = Weather.next_bolt_delay(Weather.of(GameState.current))
		return
	_next_bolt -= delta
	if _next_bolt > 0.0:
		return
	_flash = 1.0
	_next_bolt = Weather.next_bolt_delay(Weather.of(GameState.current))

## Il nome della stanza e le uscite restano sempre della stessa luminosità.
##
## Sono interfaccia e non arredamento: il giocatore ci deve leggere dove sta e
## dove può andare, e una scritta che si spegne alle dieci di sera sembra un
## errore, non un effetto. Non si possono togliere dalla tinta — stanno sulla
## stessa tela del resto della stanza — quindi gli si rimette addosso l'inverso
## della tinta, che è lo stesso giro di `Daylight.emissive()`.
func _keep_readable() -> void:
	var compensation := Daylight.emissive(Color.WHITE, _tint.color if _tint != null else Color.WHITE)
	for item in _readable:
		item.modulate = compensation

# --- Particelle -------------------------------------------------------------

func _seed_particles() -> void:
	var view := size if size.x > 0.0 else get_viewport_rect().size
	_motes.resize(MOTES)
	for i in MOTES:
		_motes[i] = Vector3(randf() * view.x, randf() * view.y, randf())
	_drops.resize(GLASS_DROPS)
	for i in GLASS_DROPS:
		_drops[i] = Vector3(randf(), randf(), 0.4 + randf())

func _move_particles(delta: float) -> void:
	var view := _view()
	for i in _motes.size():
		var mote := _motes[i]
		# Salgono pianissimo e ondeggiano: il pulviscolo in una stanza non cade,
		# galleggia nelle correnti.
		mote.y -= (3.0 + mote.z * 5.0) * delta
		mote.x += sin(_time * 0.5 + mote.z * TAU) * 4.0 * delta
		if mote.y < -4.0:
			mote = Vector3(randf() * view.x, view.y + 4.0, randf())
		_motes[i] = mote

	if not _wet or _window.size.y <= 0.0:
		return
	for i in _drops.size():
		var drop := _drops[i]
		# Le gocce sul vetro sono in coordinate 0-1 dentro alla finestra, così
		# spostare la finestra non richiede di rifare i conti alle gocce.
		drop.y += drop.z * 0.22 * delta
		if drop.y > 1.0:
			drop = Vector3(randf(), -0.1, 0.4 + randf())
		_drops[i] = drop

# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	if _window.size.x > 0.0:
		# Prima cosa si vede fuori, poi la luce che entra, poi l'acqua sul
		# vetro: dal più lontano al più vicino, come si guarda una finestra.
		_draw_outside()
		if _daylight:
			_draw_shaft()
		if _wet:
			_draw_glass()
	_draw_motes()
	if _flash > 0.01:
		# Il lampo entra dalla finestra prima di riempire la stanza: senza la
		# finestra più accesa del resto, sembra che si accenda una luce dentro.
		if _window.size.x > 0.0:
			draw_colored_polygon(_quad, Color(0.95, 0.96, 1.0, _flash * 0.55))
		draw_rect(Rect2(Vector2.ZERO, _view()), Color(0.92, 0.94, 1.0, _flash * FLASH_PEAK), true)

## Il taglio di luce dalla finestra al pavimento.
##
## Cade nella stessa direzione delle ombre di fuori (`Daylight.shadow()`), che è
## quanto basta perché la stanza e la strada raccontino la stessa ora: entrando
## in casa a mezzogiorno il taglio è corto e ripido, alle sette di sera è lungo
## e sbieco. Tre strati di lunghezza diversa, come i fari delle auto, perché la
## luce si spenga verso la punta invece di finire di netto.
func _draw_shaft() -> void:
	var data := GameState.current
	var sun := Daylight.sun_height(Daylight.hour_of(data))
	# Col cielo coperto non entra nessun taglio: entra luce diffusa, che è già
	# nella tinta della stanza.
	var sharp := float(Weather.entry(Weather.of(data))["shadows"])
	var power := sun * sharp
	if power <= 0.02:
		return

	var info := Daylight.shadow(data)
	var direction: Vector2 = info["direction"]
	var across := Vector2(-direction.y, direction.x)
	var left := _quad[3]
	var right := _quad[2]

	var span := minf(_window.size.y * SHAFT_REACH * float(info["length"]), SHAFT_MAX)
	for i in SHAFT_LAYERS:
		var step := 0.45 + 0.275 * float(i)
		var reach := direction * span * step
		var spread := across * _window.size.x * 0.3 * step
		var color := SHAFT
		color.a = 0.055 * power
		draw_colored_polygon(PackedVector2Array([
			left, right, right + reach + spread, left + reach - spread,
		]), Daylight.emissive(color, _ambient))

## Quello che si vede FUORI dalla finestra.
##
## Il fondale è un disegno fisso, e nel disegno fuori è sempre giorno: alle
## dieci di sera si vedeva ancora un cortile assolato dietro ai vetri, che è la
## cosa che rompeva di più l'illusione in tutta la stanza. Qui sopra al vetro va
## il colore del cielo di quest'ora, con l'opacità che sale quanto scende la
## luce — a mezzogiorno non copre niente, di notte copre quasi tutto.
##
## Le tre luci in fondo sono le finestre del palazzo di fronte. Costano tre
## rettangoli e sono quello che fa la differenza fra "è notte" e "è notte e
## fuori c'è una città".
func _draw_outside() -> void:
	var data := GameState.current
	var hour := Daylight.hour_of(data)
	var dark := 1.0 - Daylight.brightness(data)
	if dark <= 0.04:
		return
	var sky := Daylight.void_color(hour)
	sky.a = clampf(dark * 1.25, 0.0, 0.88)
	draw_colored_polygon(_quad, sky)

	if not Daylight.lamps_on(data):
		return
	var lit := OUTSIDE_LIT
	lit.a = 0.75 * dark
	var bright := Daylight.emissive(lit, _ambient)
	# Posizioni fisse dentro alla finestra: sono finestre di un palazzo, non
	# lucciole, e se si spostassero si vedrebbe subito.
	for spot in [Vector2(0.18, 0.34), Vector2(0.52, 0.22), Vector2(0.74, 0.46)]:
		draw_rect(Rect2(_on_glass(spot.x, spot.y), Vector2(3, 4)), bright, true)

## L'acqua che scende sul vetro. Sta dentro al rettangolo della finestra e non
## davanti a tutta la stanza: da dentro, la pioggia si vede solo lì.
func _draw_glass() -> void:
	var wash := GLASS_COLOR
	wash.a = 0.16
	draw_colored_polygon(_quad, Daylight.emissive(wash, _ambient))
	var streak := GLASS_COLOR
	streak.a = 0.42
	var bright := Daylight.emissive(streak, _ambient)
	for drop in _drops:
		if drop.y < 0.0 or drop.y > 1.0:
			continue
		var head := _on_glass(drop.x, drop.y)
		var length := (4.0 + drop.z * 5.0) / _window.size.y
		draw_line(head, _on_glass(drop.x, minf(drop.y + length, 1.0)), bright, 1.0)

func _draw_motes() -> void:
	var color := MOTE_COLOR
	for mote in _motes:
		# Più vicino alla finestra, più si vedono: è la luce radente a farli
		# comparire, e in una stanza buia il pulviscolo non lo vede nessuno.
		var near := 1.0
		if _window.size.x > 0.0:
			var distance := _window.get_center().distance_to(Vector2(mote.x, mote.y))
			near = clampf(1.4 - distance / 260.0, 0.25, 1.4)
		color.a = (0.05 + mote.z * 0.07) * near
		draw_rect(Rect2(mote.x, mote.y, 1.0, 1.0), Daylight.emissive(color, _ambient), true)

## Un punto del vetro, da coordinate 0-1 dentro alla finestra (0,0 in alto a
## sinistra). Interpola fra i quattro angoli, quindi segue anche il trapezio di
## una finestra vista di sbieco: la pioggia scende lungo il vetro, non dritta
## attraverso il muro.
func _on_glass(u: float, v: float) -> Vector2:
	var top := _quad[0].lerp(_quad[1], u)
	var bottom := _quad[3].lerp(_quad[2], u)
	return top.lerp(bottom, v)

func _view() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size
