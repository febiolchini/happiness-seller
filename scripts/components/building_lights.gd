extends Sprite2D

## Le finestre accese di un edificio, appoggiate sopra al suo disegno.
##
## ## Perché non basta dipingerle nel PNG
##
## Nel disegno le finestre accese ci sono già — è il vetro che di giorno si
## legge più chiaro degli altri. Il problema è la sera: lo sprite è una
## texture, e il `CanvasModulate` della City moltiplica tutta la tela per il
## colore dell'ora. Una finestra gialla dipinta nel PNG alle nove di sera
## diventa marrone insieme al muro che le sta intorno, e la città si spegne
## tutta in una volta come un disegno a cui si abbassa la luce.
##
## Finché gli edifici erano segnaposto il problema non c'era:
## `building_placeholder.gd` le finestre le DISEGNAVA, e le disegnava con
## `Daylight.emissive()`, che pre-divide il colore per la luce dell'ambiente
## così che la moltiplicazione lo riporti dov'era. Sostituendo i segnaposto coi
## disegni quel pezzo si è perso, e non se ne accorge nessuno di giorno.
##
## Questo nodo lo rimette: un secondo PNG con dentro solo le cose accese — lo
## fotografa `render_buildings.py`, vedi `modo_luci()` — moltiplicato per la
## stessa compensazione. Il muro sotto si spegne, le finestre no.
##
## ## Quando si accendono
##
## Con `Daylight.lamp_strength()`, la stessa curva dei lampioni: salgono
## insieme al buio invece di scattare all'ora esatta, e col brutto tempo si
## accendono anche di pomeriggio. Le luci di casa e quelle della strada devono
## accendersi insieme — a vederle sfasate sembra che in città ci siano due
## sere diverse.
##
## Si ridisegna solo quando la luce cambia davvero: si iscrive al gruppo di
## `atmosphere.gd`, come i lampioni.

func _ready() -> void:
	add_to_group(Daylight.LIGHT_GROUP)
	on_light_changed()

## Chiamata da `atmosphere.gd` quando la luce è cambiata abbastanza da vedersi.
func on_light_changed() -> void:
	var data := GameState.current
	if data == null:
		return
	var strength := Daylight.lamp_strength(data)
	# Di giorno il nodo sparisce invece di restare trasparente: sono un paio di
	# centinaia di sprite, e uno sprite invisibile non si disegna proprio.
	visible = strength > 0.01
	if not visible:
		return
	# L'opacità porta l'accensione, il colore porta la compensazione: `emissive()`
	# divide solo l'RGB e l'alpha lo lascia stare, che è esattamente quello che
	# serve qui.
	modulate = Daylight.emissive(Color(1.0, 1.0, 1.0, strength), Daylight.light(data))
