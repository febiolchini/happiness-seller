extends CanvasModulate

## L'aria della città: il colore della luce sul mondo, il fondale oltre ai
## bordi, e i lampi del temporale.
##
## È un `CanvasModulate` con uno script addosso e non un nodo che ne comanda un
## altro: il suo lavoro **è** tingere la tela, e un nodo in più che gli scrive
## dentro sarebbe solo un passaggio da leggere.
##
## ## Cosa tinge e cosa no
##
## Un `CanvasModulate` moltiplica tutto quello che sta sulla sua tela — terreno,
## edifici, persone, auto, effetti — e **non tocca gli altri `CanvasLayer`**.
## In City questo vuol dire che HUD, dialoghi e la tela della pioggia restano
## fuori da sé, gratis e senza che nessuno se ne debba ricordare. Il fondale
## oltre ai bordi del mondo sta anche lui su una tela sua (`GroundLayer`), quindi
## il colore glielo scriviamo noi qui sotto.
##
## ## Le cose accese
##
## Quello che deve restare illuminato dentro al buio — lampioni, finestre, fari
## — non sfugge alla tinta: si disegna con `Daylight.emissive()`, che pre-divide
## il colore per questa stessa luce. Vedi `daylight.gd`.
##
## ## Perché avvisa invece di far controllare
##
## Edifici, lampioni e persone devono ridisegnarsi quando la luce cambia, ma
## sono qualche centinaio e un `_process` a testa per guardare l'orologio
## sarebbe qualche centinaio di chiamate a vuoto per frame. Qui l'ora viene
## arrotondata al quarto d'ora di gioco, e solo quando quel numero cambia parte
## un avviso al gruppo. Sono meno di venti avvisi per giornata di gioco.

## In quanti pezzi si taglia l'ora per decidere quando avvisare. A 4 è un
## quarto d'ora di gioco, cioè meno di quattro secondi veri: abbastanza fitto
## perché l'ombra si allunghi senza scatti visibili, abbastanza rado perché non
## sia un ridisegno continuo.
const STEPS_PER_HOUR := 4.0

## Il fondale oltre ai confini del mondo. Sta su una tela sua, quindi questa
## tinta non lo raggiunge e il colore glielo diamo a mano.
@export var void_rect_path := NodePath("../GroundLayer/Sky")

## Quanto schiarisce il mondo un lampo, e in quanto si spegne.
const BOLT_COLOR := Color(1.25, 1.24, 1.35)
const BOLT_FADE := 5.0
## Il lampo non è una cosa sola: è un bagliore corto seguito da uno più lungo.
## Un flash singolo si legge come un errore di rendering, due come un fulmine.
const BOLT_SECOND_CHANCE := 0.6

## Un fulmine è appena caduto. Ci si aggancia chi deve reagire — per ora la
## pioggia a schermo, che ci disegna sopra il suo lampo.
signal lightning(strength: float)

var _void: ColorRect = null
## Ultimo quarto d'ora annunciato, e ultimo tempo annunciato. A -1 e stringa
## vuota così il primo giro avvisa sempre.
var _step := -1
var _weather := ""
## Quanto è acceso il lampo adesso, 0-1.
var _bolt := 0.0
## Secondi veri prima del prossimo fulmine.
var _next_bolt := 0.0

func _ready() -> void:
	_void = get_node_or_null(void_rect_path) as ColorRect
	if _void == null:
		push_warning("Atmosphere non trova il fondale in %s: resterà del colore che ha." % void_rect_path)
	_schedule_bolt()
	_apply(0.0)

func _process(delta: float) -> void:
	_apply(delta)

func _apply(delta: float) -> void:
	var data := GameState.current
	_bolt = maxf(0.0, _bolt - delta * BOLT_FADE)
	_tick_storm(delta, data)

	var ambient := Daylight.light(data)
	# Il lampo non sostituisce la luce, ci si somma sopra: per un istante la
	# notte è quasi giorno e poi torna esattamente dov'era.
	color = ambient.lerp(BOLT_COLOR, _bolt * 0.75)
	if _void != null:
		_void.color = Daylight.void_color(Daylight.hour_of(data)).lerp(BOLT_COLOR, _bolt * 0.6)

	_announce(data)

## Avvisa chi si ridisegna con la luce, ma solo quando è cambiato qualcosa che
## si vedrebbe. Vedi il commento in cima.
func _announce(data: SaveData) -> void:
	var step := int(Daylight.hour_of(data) * STEPS_PER_HOUR)
	var weather := Weather.of(data)
	if step == _step and weather == _weather:
		return
	_step = step
	_weather = weather
	get_tree().call_group(Daylight.LIGHT_GROUP, "on_light_changed")

# --- Temporale --------------------------------------------------------------

## I fulmini scorrono in secondi veri e non in ore di gioco: sono un evento che
## si guarda mentre succede, e a quattro minuti di gioco al secondo un tuono
## ogni "nove minuti di gioco" cadrebbe una volta ogni due secondi.
func _tick_storm(delta: float, data: SaveData) -> void:
	if not Weather.has_thunder(Weather.of(data)):
		return
	_next_bolt -= delta
	if _next_bolt > 0.0:
		return
	_strike()

func _strike() -> void:
	_bolt = 1.0
	lightning.emit(1.0)
	_schedule_bolt()
	# Il secondo bagliore, quello che fa sembrare un fulmine un fulmine.
	if randf() < BOLT_SECOND_CHANCE:
		var timer := get_tree().create_timer(randf_range(0.10, 0.22))
		timer.timeout.connect(func() -> void:
			_bolt = maxf(_bolt, 0.8)
			lightning.emit(0.8))

## Quando cade il prossimo. Il conto sta in `Weather` perché il temporale lo
## sentono anche le stanze, che sono un'altra scena: vedi `room_ambience.gd`.
func _schedule_bolt() -> void:
	_next_bolt = maxf(1.0, Weather.next_bolt_delay(Weather.of(GameState.current)))
