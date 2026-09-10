extends "res://scripts/ui/interactive_button.gd"

## Segnaposto cliccabile dentro a una stanza (il PC in cantina, un domani il
## telefono, la cassaforte, il banco di lavoro...).
##
## Eredita da `interactive_button.gd` per avere lo stesso hover giallino di
## tutti gli altri tasti del gioco, e aggiunge l'unica cosa che gli serve:
## aprire una finestra invece di cambiare scena.
##
## La finestra viene appesa alla scena corrente, non al segnaposto: così copre
## tutto lo schermo anche se l'oggetto cliccato è un francobollo in un angolo,
## e resta viva finché non la si chiude.

## Finestra da aprire al click. Se è vuota, il segnaposto non fa niente.
@export var window_scene: PackedScene

## L'istanza aperta, per non aprirne due sovrapposte con un doppio click.
var _window: Node = null

func _ready() -> void:
	super()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_open_window)

func _open_window() -> void:
	if window_scene == null or _window != null:
		return
	_window = window_scene.instantiate()
	# `tree_exited` invece di `tree_exiting`: scatta a nodo già staccato, quindi
	# quando torna il riferimento è davvero libero.
	_window.tree_exited.connect(func() -> void: _window = null)
	get_tree().current_scene.add_child(_window)
