extends Camera2D

## Zoom della mappa con la rotellina, pensato per restare sempre pixel-perfect.
##
## Il progetto usa stretch mode "canvas_items": la finestra reale (es. 1280x720)
## viene divisa per la risoluzione di design (640x360), quindi ogni cosa è già
## moltiplicata per un fattore di stretch (2 a 720p). La nitidezza dipende dalla
## SCALA NETTA = zoom * stretch: se è intera, un pixel dello sprite copre un
## numero esatto di pixel a schermo e resta netto; se è frazionaria (es. 2.81)
## alcuni pixel ne occupano 2 e altri 3, e l'immagine "balla".
##
## Per questo lo zoom non è continuo ma scatta tra scale nette intere.

## Scale nette selezionabili: 1 = un pixel sprite per pixel schermo, 3 =
## massimo avvicinamento. Arrivava a 8: Federico (2026-09-24) ha tolto via via
## sia gli ultimi livelli — cosi' da vicino molte cose perdono qualita', un
## pixel dello sprite diventava un quadrato grosso come un dito — sia il primo
## (0.15, troppo lontano, mostrava oltre il bordo della cornice di montagne).
## Sotto l'1 si allarga oltre il pixel-perfect, fino a inquadrare praticamente
## tutta la città.
##
## Da 1 in su devono restare INTERI: a 1.5 un pixel dello sprite ne coprirebbe
## a volte 1 e a volte 2, e l'immagine "balla". Sotto l'1 quella garanzia si
## perde comunque (lo sprite viene rimpicciolito), quindi lì è solo una
## questione di leggibilità: bastano pochi scalini per non rendere la mappa
## illeggibile prima di arrivare alla vista d'insieme.
##
## Il valore più basso resta comunque solo un punto di partenza: `_apply()`
## non lo usa mai se è troppo basso per la finestra corrente, vedi
## `_min_scale_to_fit_frame()`.
@export var net_scales: Array[float] = [0.25, 0.4, 0.6, 1, 2, 3]
## Livello iniziale (indice in net_scales): 2x è la vista di default.
@export var default_level := 4
## Disattiva zoom, pan e cursore custom: usata quando la mappa è solo sfondo
## decorativo (es. dietro al menu principale) e non deve reagire al mouse.
@export var interactive := true

const HAND_OPEN := preload("res://assets/sprites/ui/cursors/hand_open.png")
const HAND_CLOSED := preload("res://assets/sprites/ui/cursors/hand_closed.png")
const HAND_CLICK := preload("res://assets/sprites/ui/cursors/hand_click.png")
const HAND_HOTSPOT := Vector2(22, 22)

## Nodo da seguire, di solito il protagonista. Lo assegna `city.gd`.
##
## La città è larga qualche migliaio di pixel: con una camera ferma il
## giocatore uscirebbe dallo schermo dopo tre passi e la mappa sarebbe
## inservibile. Il pan col tasto destro resta, ma diventa un'occhiata in giro.
var follow: Node2D = null

## Quanto velocemente la camera recupera il bersaglio. Non è una velocità in
## pixel: è la rapidità con cui si chiude la distanza, quindi il movimento
## parte deciso e arriva morbido senza dipendere dal frame rate.
const FOLLOW_SPEED := 6.0
## La camera guarda un po' sopra ai piedi del personaggio, altrimenti metà
## schermo è il pavimento davanti a lui.
const FOLLOW_OFFSET := Vector2(0, -24)

var _level := 0
var _panning := false
var _clicking := false
## Falso mentre il giocatore si sta guardando intorno col tasto destro: la
## camera resta dove l'ha lasciata finché non riprende a muoversi.
var _following := true
## Posizione continua della camera: `position` è la sua versione arrotondata.
## Serve per non perdere i movimenti di mouse più piccoli di un pixel mondo.
var _pan_position := Vector2.ZERO

func _ready() -> void:
	_validate_net_scales()
	_level = clampi(default_level, 0, net_scales.size() - 1)
	_pan_position = position
	_apply()
	get_window().size_changed.connect(_apply)
	if interactive:
		Input.set_custom_mouse_cursor(HAND_OPEN, Input.CURSOR_ARROW, HAND_HOTSPOT)

func _process(delta: float) -> void:
	if not _following or follow == null:
		return
	var target := follow.global_position + FOLLOW_OFFSET
	_pan_position = _pan_position.lerp(target, 1.0 - exp(-delta * FOLLOW_SPEED))
	_snap()

## Riattacca la camera al personaggio. La mappa la chiama quando il giocatore
## dà un ordine di movimento: chi ha appena cliccato dove andare vuole vedere
## dove sta andando, anche se un momento prima stava guardando altrove.
func recenter() -> void:
	_following = true

## Limita l'inquadratura ai confini del mondo, così non si finisce a guardare
## il vuoto oltre il bordo della città.
func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)

## Il pan col destro sta in `_input()` e non in `_unhandled_input()`, al
## contrario di tutto il resto.
##
## Il motivo e' che l'interfaccia si mangia i click. Un `Control` con
## `MOUSE_FILTER_STOP` — il telefono in fondo allo schermo, il tasto del menu
## in alto — consuma QUALUNQUE tasto del mouse che cade dentro al suo
## rettangolo, anche se poi nel suo `_gui_input()` guarda solo il sinistro. Da
## `_unhandled_input()` questo faceva due danni:
##
## - iniziare la trascinata sopra al telefono non muoveva niente, perche' la
##   pressione non arrivava mai qui;
## - lasciare il tasto sopra al telefono lasciava `_panning` acceso, e da li'
##   in poi la visuale seguiva il mouse senza che nessuno la trascinasse. E'
##   questo il "va a scatti": la camera si muoveva da sola.
##
## Il tasto destro non lo usa nessun pezzo di interfaccia, quindi prenderlo
## prima della GUI non toglie niente a nessuno. Ruota e tasto sinistro restano
## in `_unhandled_input()`: quelli l'interfaccia li usa davvero.
func _input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_panning = event.pressed
		if _panning:
			# Guardarsi intorno stacca la camera dal personaggio: se
			# continuasse a inseguirlo, il pan tornerebbe indietro da solo.
			_following = false
		_update_cursor()
	elif event is InputEventMouseMotion and _panning:
		# `event.relative` e' gia' nei 640x360 di progetto — Godot riporta gli
		# eventi nello spazio di disegno prima di consegnarli — quindi basta
		# dividere per lo zoom per sapere quanti pixel di MONDO ha percorso il
		# cursore.
		_pan_position -= event.relative / zoom
		_snap()

func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_step(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_step(-1)
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Il comando di movimento lo gestisce la mappa (city.gd): qui cambia
			# solo il cursore, così il click resta "non gestito" e arriva a entrambi.
			_clicking = event.pressed
			_update_cursor()

func _update_cursor() -> void:
	var cursor := HAND_OPEN
	if _panning:
		cursor = HAND_CLOSED
	elif _clicking:
		cursor = HAND_CLICK
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, HAND_HOTSPOT)

## Porta lo zoom a un livello preciso, indice in `net_scales`.
##
## Serve agli strumenti che devono inquadrare da soli (`flats_shot.gd`): una
## foto va composta, e la rotellina del mouse non si gira da uno script.
func set_level(livello: int) -> void:
	_level = clampi(livello, 0, net_scales.size() - 1)
	_apply()

func _step(direction: int) -> void:
	var next := clampi(_level + direction, 0, net_scales.size() - 1)
	if next != _level:
		_level = next
		_apply()

## Traduce la scala netta desiderata nello zoom della camera, tenendo conto
## di quanto la finestra corrente sta già ingrandendo il canvas.
func _apply() -> void:
	var level: float = max(net_scales[_level], _min_scale_to_fit_frame()) / _stretch()
	zoom = Vector2(level, level)
	_snap()

## La scala netta più bassa che non mostra oltre il bordo esterno delle
## montagne (`CityMap.view_bounds()`).
##
## Sotto questa soglia l'inquadratura, allargandosi, diventa più larga o più
## alta della cornice di montagne: siccome `Camera2D` limita solo dove può
## stare il centro e non cosa disegna oltre il bordo, il resto dello schermo
## restava il colore di sfondo del viewport — l'azzurro visto fuori dalle
## montagne negli angoli alla vista più lontana. Qui si calcola, dalla
## finestra corrente, la scala minima che tiene l'inquadratura dentro alla
## cornice su entrambi gli assi, e `_apply()` non scende mai sotto.
func _min_scale_to_fit_frame() -> float:
	var frame: Rect2 = CityMap.view_bounds()
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return 0.0
	return max(viewport_size.x / frame.size.x, viewport_size.y / frame.size.y)

## Di quanto la finestra corrente sta gia' ingrandendo il canvas: 2 a 720p.
##
## Serve allo zoom, che deve arrivare a una scala netta intera, e ai confini:
## `get_viewport_rect()` e' in pixel DI FINESTRA, quindi per sapere quanto mondo
## si vede si divide per la scala netta (`zoom * stretch`) e non per il solo
## `zoom`.
func _stretch() -> float:
	var design_height: float = ProjectSettings.get_setting("display/window/size/viewport_height")
	var stretch: float = float(get_window().size.y) / design_height
	if stretch <= 0.0:
		return 1.0
	return stretch

## Ferma la camera dentro ai confini e la posa su pixel interi DI SCHERMO.
##
## Due cose in un posto solo, perche' sono la stessa: dove finisce la camera.
##
## **I confini.** `Camera2D` per conto suo limita solo l'inquadratura disegnata,
## non `position`: trascinando oltre il bordo della citta' l'immagine si fermava
## ma `_pan_position` continuava a scappare, e per tornare indietro bisognava
## ripercorrere al contrario tutto quello che si era trascinato a vuoto. Da
## fuori sembrava una visuale bloccata. Fermando qui anche la posizione
## continua, il bordo e' un muro e non un elastico.
##
## **Il passo.** Prima si arrotondava al pixel di mondo: a zoom 8 un pixel di
## mondo sono otto pixel a schermo, e la mappa avanzava a blocchi di otto. Il
## pixel-perfect pero' non chiede coordinate di mondo intere, chiede che lo
## scostamento a schermo sia intero — cioe' `position * scala netta`. Snappando
## li' il passo diventa un pixel di schermo a qualunque zoom: gli sprite restano
## netti e il trascinamento e' liscio.
func _snap() -> void:
	var net: float = net_scales[_level]
	_pan_position = _clamp_to_limits(_pan_position)
	position = (_pan_position * net).round() / net

## Il rettangolo in cui puo' stare il CENTRO della camera: i confini del mondo
## rientrati di mezza inquadratura. Se il mondo e' piu' piccolo dello schermo il
## rientro si mangia il rettangolo, e allora l'unica posizione giusta e' il
## centro del mondo.
func _clamp_to_limits(at: Vector2) -> Vector2:
	var half: Vector2 = get_viewport_rect().size * 0.5 / (zoom * _stretch())
	var low := Vector2(limit_left, limit_top) + half
	var high := Vector2(limit_right, limit_bottom) - half
	var middle := (Vector2(limit_left, limit_top) + Vector2(limit_right, limit_bottom)) * 0.5
	return Vector2(
		clampf(at.x, low.x, high.x) if low.x <= high.x else middle.x,
		clampf(at.y, low.y, high.y) if low.y <= high.y else middle.y)

## La nitidezza dipende da questa lista: se qualcuno ci infila un valore sbagliato
## è meglio accorgersene subito invece di inseguire uno sfarfallio a video.
func _validate_net_scales() -> void:
	if net_scales.is_empty():
		push_error("net_scales è vuoto: la camera non ha nessun livello di zoom.")
		net_scales = [1]
		return
	for scale in net_scales:
		if scale <= 0.0:
			push_warning("Scala netta %f <= 0: livello di zoom inutilizzabile." % scale)
		elif scale >= 1.0 and not is_equal_approx(scale, roundf(scale)):
			push_warning("Scala netta %f fra 1 e 8 dovrebbe essere intera, altrimenti l'immagine 'balla'." % scale)
