extends Control

## Applica il cursore a freccia del pack UI a qualsiasi schermata di menu.

const ARROW := preload("res://assets/sprites/ui/cursors/arrow_menu.png")
const HOTSPOT := Vector2(40, 28)

func _ready() -> void:
	Input.set_custom_mouse_cursor(ARROW, Input.CURSOR_ARROW, HOTSPOT)
