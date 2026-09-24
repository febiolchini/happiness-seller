extends Node

## La serranda dell'officina: si tira giù la sera e si riapre la mattina.
##
## ## Come fa a muoversi uno sprite
##
## Lo sprite dell'officina non è un PNG solo ma una **striscia di dodici
## fotogrammi**: la stessa inquadratura con la serranda a dodici altezze, dal
## tutto su al tutto giù. Li costruisce e li fotografa
## `scripts_tools/blender_officina.py`, li mette in fila
## `import_flats_art.py`, e il `Sprite2D` dell'edificio li scorre con `frame`
## perché ha `hframes` uguale al loro numero.
##
## Questo nodo non disegna niente: sceglie il fotogramma. È figlio dello sprite
## e non lo sprite stesso perché su quel nodo c'è già `enterable_building.gd`,
## e un nodo ha un solo script.
##
## ## Perché l'ora e non un timer
##
## L'officina apre alle sette e chiude alle 19:20, e deve essere così anche se
## il giocatore arriva a mezzogiorno, se torna dopo aver chiuso il gioco per tre
## giorni, o se sta guardando l'orologio del gestionale. Un'animazione fatta
## partire da un timer sarebbe giusta solo la prima volta: qui il fotogramma è
## una FUNZIONE dell'ora, quindi a qualunque ora si guardi l'officina la
## serranda sta dove deve stare. Non c'è stato da salvare.
##
## ## Perché `_process` e non il gruppo della luce
##
## Le finestre accese si ridisegnano con `Daylight.LIGHT_GROUP`, che
## `atmosphere.gd` avvisa ogni quarto d'ora di gioco: abbastanza fitto per
## un'ombra che si allunga, troppo rado per una serranda: a quattro minuti di
## gioco al secondo sarebbe uno scatto ogni quattro secondi, cioè tre scatti in
## tutta l'animazione. Questo è UN nodo in tutta la città e si limita a leggere
## un numero e scriverne un altro.

## Ora in cui la serranda comincia ad alzarsi.
const APERTURA := 7.0
## Ora in cui comincia a scendere. Prima del tramonto (19.6): il meccanico
## chiude e se ne va mentre c'è ancora luce, e la serranda che scende sul
## crepuscolo è quello che si vede passando di lì la sera.
const CHIUSURA := 19.3
## Quanto dura la corsa, in ore di gioco. A 4 minuti di gioco al secondo
## (`GameState.GAME_MINUTES_PER_SECOND`) 0,22 ore sono tredici minuti di gioco,
## cioè poco più di tre secondi veri: il tempo che ci mette una serranda vera.
const DURATA := 0.22

var _sprite: Sprite2D
var _ultimo := -1

func _ready() -> void:
	_sprite = get_parent() as Sprite2D
	if _sprite == null:
		push_error("ShopShutter vuole stare sotto allo Sprite2D dell'edificio.")
		set_process(false)
		return
	_aggiorna()

func _process(_delta: float) -> void:
	_aggiorna()

func _aggiorna() -> void:
	var fotogrammi := _sprite.hframes
	if fotogrammi <= 1:
		return
	# 0 = tutta su, 1 = tutta giù. Fuori dalle due finestre di manovra è
	# ferma, e il conto non dipende da quello che è successo prima.
	var chiusura := 1.0
	var ora := Daylight.hour_of(GameState.current)
	if ora >= APERTURA + DURATA and ora <= CHIUSURA:
		chiusura = 0.0
	elif ora > APERTURA and ora < APERTURA + DURATA:
		chiusura = 1.0 - (ora - APERTURA) / DURATA
	elif ora > CHIUSURA and ora < CHIUSURA + DURATA:
		chiusura = (ora - CHIUSURA) / DURATA
	var frame := clampi(int(round(chiusura * (fotogrammi - 1))), 0,
		fotogrammi - 1)
	if frame == _ultimo:
		return
	_ultimo = frame
	_sprite.frame = frame
