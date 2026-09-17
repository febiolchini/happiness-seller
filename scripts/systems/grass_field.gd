@tool
extends Node2D

## L'erba alta di un campo lasciato andare: un rettangolo con sopra
## `grass_field.gdshader`.
##
## Il nodo non fa quasi niente — tutto il disegno sta nello shader, qui c'e' solo
## il rettangolo su cui girarlo e la misura che arriva da `CityMap`.
##
## **Sta a (0,0) e disegna in coordinate mondo.** Non e' pigrizia: la City ha
## l'Y-sort acceso, che ordina i figli per la loro y. Messo sul bordo alto del
## campo, questo nodo prenderebbe quella y e finirebbe disegnato *davanti* a
## tutto quello che sta piu' in su. L'erba e' pavimento e deve stare dietro a
## chiunque ci cammini sopra, quindi tiene y 0 come il resto del terreno.
##
## Lo shader si anima da solo: `TIME` scorre sulla GPU e il nodo non ha bisogno
## di ridisegnarsi a ogni frame. `_draw()` gira una volta sola.

const SHADER := preload("res://assets/shaders/grass_field.gdshader")

## Il campo, in coordinate mondo.
@export var rect := Rect2():
	set(value):
		rect = value
		queue_redraw()

func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat

func _draw() -> void:
	# Bianco pieno: il colore vero lo decide lo shader, questo e' solo il
	# rettangolo di pixel su cui farlo girare.
	draw_rect(rect, Color.WHITE)
