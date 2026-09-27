extends Control

## Sotto alla sveglia: l'ingranaggio delle impostazioni e i tre tasti del
## tempo, come nei gestionali di città.
##
##     ⚙   ◀◀   ❚❚   ▶▶
##
## ◀◀ dimezza, ▶▶ raddoppia, fra le tre velocità di `GameState.SPEEDS` (0.5×,
## normale, 2×) e senza andare oltre. ❚❚ ferma l'orologio, e da fermo diventa
## ▶ per ripartire. Il tasto della velocità in uso resta acceso, così si vede a
## colpo d'occhio se il tempo corre diverso dal normale. Barra spaziatrice =
## pausa.
##
## Disegnati a codice e non con delle texture: sono quattro forme semplici, e
## a questa misura un disegno non direbbe di più.

const SETTINGS_SCENE := "res://scenes/ui/Settings.tscn"

## Un tasto, e lo spazio fra uno e l'altro.
const KEY := Vector2(16.0, 13.0)
const GAP := 3.0
const SIZE := Vector2(KEY.x * 4.0 + GAP * 3.0, KEY.y)

const FACE := Color(0.08, 0.09, 0.11, 0.72)
const FACE_ON := Color(0.184, 0.627, 0.353, 0.95)
const INK := Color(0.93, 0.94, 0.90)
const EDGE := Color(1, 1, 1, 0.14)

var _hover := -1

func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.speed_changed.connect(queue_redraw)
	mouse_exited.connect(func() -> void:
		_hover = -1
		queue_redraw())

func _key_rect(i: int) -> Rect2:
	# Allineati a destra, sotto alla sveglia.
	var x := size.x - SIZE.x + float(i) * (KEY.x + GAP)
	return Rect2(Vector2(x, 0), KEY)

func _key_at(point: Vector2) -> int:
	for i in 4:
		if _key_rect(i).has_point(point):
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _key_at(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		match _key_at(event.position):
			0:
				_open_settings()
			1:
				GameState.change_speed(-1)
			2:
				GameState.toggle_pause()
			3:
				GameState.change_speed(1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE and not UiTheme.modal_open():
		get_viewport().set_input_as_handled()
		GameState.toggle_pause()

func _open_settings() -> void:
	var scene: PackedScene = load(SETTINGS_SCENE)
	var settings := scene.instantiate()
	settings.in_game = true
	get_tree().current_scene.add_child(settings)

func _draw() -> void:
	var on := [false, GameState.speed_index == 0, GameState.paused,
		GameState.speed_index == GameState.SPEEDS.size() - 1]
	for i in 4:
		var r := _key_rect(i)
		var face: Color = FACE_ON if on[i] else FACE
		if i == _hover and not on[i]:
			face = face.lightened(0.18)
		draw_rect(r, face, true)
		draw_rect(r, EDGE, false, 1.0)
		var c := r.get_center()
		match i:
			0:
				_gear(c)
			1:
				_arrow(c + Vector2(-2, 0), -1)
				_arrow(c + Vector2(2, 0), -1)
			2:
				if GameState.paused:
					_arrow(c, 1)
				else:
					draw_rect(Rect2(c + Vector2(-3, -3.5), Vector2(2, 7)), INK, true)
					draw_rect(Rect2(c + Vector2(1, -3.5), Vector2(2, 7)), INK, true)
			3:
				_arrow(c + Vector2(-2, 0), 1)
				_arrow(c + Vector2(2, 0), 1)

## Un triangolo che punta a destra (1) o a sinistra (-1).
func _arrow(c: Vector2, dir: int) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-2.5 * d, -3.5), c + Vector2(2.5 * d, 0), c + Vector2(-2.5 * d, 3.5)]), INK)

## L'ingranaggio: un disco con otto denti e il buco in mezzo.
func _gear(c: Vector2) -> void:
	for k in 8:
		var a := TAU * float(k) / 8.0
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * 1.1
		var tip := c + dir * 4.6
		var base := c + dir * 3.0
		draw_colored_polygon(PackedVector2Array([
			base - side, tip - side, tip + side, base + side]), INK)
	draw_circle(c, 3.4, INK)
	draw_circle(c, 1.4, FACE)
