@tool
extends Node2D
class_name EnterableBuilding

## Edificio su cui si può cliccare: reagisce come un pulsante, dice dove ci si
## ferma davanti e, se ha un interno, in quale stanza si entra.
##
## Lo script si attacca direttamente al nodo che disegna l'edificio (uno
## `Sprite2D` quando c'è il PNG, un `BuildingPlaceholder` finché non c'è), così
## l'animazione di pressione agisce sul disegno vero.
##
## Con `interior_scene` vuoto l'edificio è cliccabile ma non visitabile: il
## protagonista ci cammina davanti e si ferma. È il caso di quasi tutta la
## città, ed è voluto — un edificio è un oggetto, non pavimento su cui passare.

## Tutti gli edifici visitabili stanno in questo gruppo: la mappa li interroga
## in blocco per capire su quale si è cliccato.
const GROUP := "enterable"

## Area cliccabile in coordinate locali. Di default combacia con lo sprite della
## casa; per gli altri edifici andrà ridisegnata.
@export var click_rect := Rect2(-73, -161, 140, 176)
## Punto in cui il protagonista si ferma prima di entrare, relativo all'origine
## dell'edificio. Deve cadere sul marciapiede, non dentro al muro.
@export var entry_offset := Vector2(0, 40)
## Scena della stanza in cui si entra.
@export_file("*.tscn") var interior_scene := ""

var _tween: Tween

func _ready() -> void:
	add_to_group(GROUP)

func contains_point(global_point: Vector2) -> bool:
	return click_rect.has_point(to_local(global_point))

func entry_point() -> Vector2:
	return global_position + entry_offset

## Schiacciata breve, come un tasto premuto. L'origine dell'edificio è a terra,
## quindi lo schiacciamento va verso il basso e sembra che poggi sul marciapiede.
##
## Durante l'animazione la scala non è intera e per qualche frame i pixel non
## sono perfetti: è voluto, il movimento lo nasconde, e si torna esatti a 1.0.
func press() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.04, 0.94), 0.07)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK)
