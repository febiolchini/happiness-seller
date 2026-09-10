@tool
extends EnterableBuilding
class_name BuildingPlaceholder

## Segnaposto di un edificio, in attesa del PNG pixel art definitivo.
##
## L'origine del nodo è il PUNTO A TERRA al centro della facciata: il rettangolo
## viene disegnato verso l'alto. Così il nodo si ordina correttamente con l'Y-sort
## e, quando arriverà lo sprite vero, basta sostituirlo con uno Sprite2D che ha
## lo stesso pivot (offset = -size/2 sull'asse X, -altezza sull'asse Y).
##
## Estende `EnterableBuilding` perché un edificio è cliccabile per definizione:
## quelli senza `interior_scene` fanno solo avvicinare il protagonista, quelli
## con l'interno ci fanno entrare. Così un segnaposto diventa visitabile
## riempiendo un campo, senza cambiargli nodo o script.

## Ingombro della facciata in pixel (larghezza x altezza).
@export var size := Vector2(128, 96):
	set(value):
		size = value
		queue_redraw()
## Nome mostrato al centro del segnaposto.
@export var label := "PLACEHOLDER":
	set(value):
		label = value
		queue_redraw()
## Colore di riempimento del blocco.
@export var fill_color := Color(0.42, 0.40, 0.44):
	set(value):
		fill_color = value
		queue_redraw()
## Colore del bordo e del testo.
@export var line_color := Color(0.92, 0.94, 0.98, 0.85):
	set(value):
		line_color = value
		queue_redraw()
## Numero di piani: se > 1 disegna delle linee orizzontali che li suggeriscono.
@export_range(1, 12) var floors := 1:
	set(value):
		floors = value
		queue_redraw()

const FONT_SIZE := 8

## Il rettangolo del segnaposto, in coordinate locali: origine a terra al
## centro, corpo verso l'alto.
func body_rect() -> Rect2:
	return Rect2(-size.x * 0.5, -size.y, size.x, size.y)

## L'area cliccabile è il segnaposto stesso, quindi `click_rect` non serve:
## sarebbe un secondo rettangolo da tenere in sincrono con `size` a ogni
## ritocco del quartiere, e prima o poi i due divergono.
func contains_point(global_point: Vector2) -> bool:
	return body_rect().has_point(to_local(global_point))

func _draw() -> void:
	var rect := body_rect()
	# L'ombra a terra va PRIMA della facciata: disegnata dopo, la sua metà
	# superiore finisce sopra all'edificio e sembra una macchia sul muro.
	_draw_ground_shadow()
	draw_rect(rect, fill_color, true)
	# Tetto/parte alta leggermente più chiara: aiuta a leggere il volume.
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), fill_color.lightened(0.18), true)
	draw_rect(rect, line_color, false, 1.0)

	for i in range(1, floors):
		var y := rect.position.y + rect.size.y * float(i) / float(floors)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color * Color(1, 1, 1, 0.35), 1.0)

	_draw_label(rect)

func _draw_ground_shadow() -> void:
	var points := PackedVector2Array()
	var half := size.x * 0.5
	for i in range(17):
		var a := TAU * float(i) / 16.0
		points.append(Vector2(cos(a) * half, sin(a) * 6.0))
	draw_colored_polygon(points, Color(0, 0, 0, 0.18))

func _draw_label(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var lines := label.split(" ")
	var total := float(lines.size()) * FONT_SIZE
	var y := rect.get_center().y - total * 0.5 + FONT_SIZE
	for line in lines:
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(-w * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, line_color)
		y += FONT_SIZE
