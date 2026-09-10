extends Node2D

## Onda che compare per un istante nel punto cliccato col tasto sinistro.
## Gli anelli sono schiacciati sulla Y perché la vista della città è obliqua:
## un cerchio a terra si legge come un'ellisse.

@export var duration := 0.45
@export var max_radius := 20.0
@export var rings := 2
## Ritardo fra un anello e il successivo, in frazione di durata.
@export var ring_delay := 0.18
## 1 = cerchio perfetto, 0.5 = schiacciato a metà.
@export var flatten := 0.45
@export var color := Color(1.0, 0.98, 0.85)

var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration + ring_delay * duration * float(rings):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for i in rings:
		var progress := _elapsed / duration - float(i) * ring_delay
		if progress <= 0.0 or progress >= 1.0:
			continue
		# Parte veloce e rallenta: dà lo scatto tipico dell'onda.
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		var radius := lerpf(3.0, max_radius, eased)
		var ring_color := color
		ring_color.a = (1.0 - progress) * 0.9
		draw_polyline(_ellipse(radius), ring_color, 1.0)

func _ellipse(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		points.append(Vector2(cos(a) * radius, sin(a) * radius * flatten))
	return points
