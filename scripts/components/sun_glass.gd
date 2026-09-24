extends Node

## Tiene il riflesso del vetro allineato col sole della città.
##
## Non disegna niente: passa tre numeri allo shader dello sprite
## (`assets/shaders/glass_sheen.gdshader`) e lascia fare a lui. Sta in un figlio
## perché sul nodo dell'edificio lo script è già occupato da
## `enterable_building.gd`, e un nodo ha un solo script.
##
## ## Dove prende l'ora
##
## Da `Daylight`, come tutto il resto che cambia con la luce, e attraverso il
## **gruppo** `skywatch` invece che da `_process`. Il gruppo lo avvisa quando
## l'ora è cambiata di un quarto d'ora di gioco (vedi `atmosphere.gd`): sono
## meno di venti avvisi per giornata, e per questo bastano.
##
## La serranda dell'officina, che ha lo stesso problema, `_process` invece lo usa
## — e la differenza dice come si sceglie fra i due. Lì la corsa dura tredici
## minuti di gioco in tutto: a un avviso ogni quindici minuti la serranda
## scenderebbe in tre scatti. Qui il riflesso attraversa la torre in tredici
## ORE, quindi a ogni avviso si sposta di un cinquantesimo di facciata, che su
## un velo sfumato non si vede proprio. Il passo giusto non è una regola
## generale: è quanto dura il movimento diviso quanto è fitto l'avviso.

var _materiale: ShaderMaterial

func _ready() -> void:
	var sprite := get_parent() as CanvasItem
	if sprite == null:
		push_error("SunGlass vuole stare sotto allo sprite dell'edificio.")
		return
	_materiale = sprite.material as ShaderMaterial
	if _materiale == null:
		push_error("SunGlass non trova lo ShaderMaterial del vetro su %s."
			% sprite.name)
		return
	add_to_group(Daylight.LIGHT_GROUP)
	on_light_changed()

## Chiamata da `atmosphere.gd` quando la luce è cambiata abbastanza da vedersi.
func on_light_changed() -> void:
	if _materiale == null:
		return
	var data := GameState.current
	var hour := Daylight.hour_of(data)
	_materiale.set_shader_parameter("sole_x", Daylight.sun_across(hour))
	# Sotto l'orizzonte `sun_height()` è già zero, quindi di notte il riflesso
	# si spegne da sé senza un caso a parte.
	_materiale.set_shader_parameter("sole_alto", Daylight.sun_height(hour))
	# La stessa nitidezza che decide se la città fa ombra: col cielo coperto
	# non c'è un sole da riflettere, e una torre che brilla sotto il temporale
	# è la cosa che si nota per prima.
	_materiale.set_shader_parameter(
		"nitidezza", float(Weather.entry(Weather.of(data))["shadows"]))
