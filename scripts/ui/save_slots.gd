extends Control

## Schermata "gestione salvataggi": elenca le partite presenti sul dispositivo
## e permette di caricarle o cancellarle.
##
## Le righe sono costruite da codice perché il numero di salvataggi non è noto
## in anticipo.

const CITY := "res://scenes/levels/City.tscn"
const ARROW := preload("res://assets/sprites/ui/cursors/arrow_menu.png")
const HOTSPOT := Vector2(40, 28)
const MENU_FONT := preload("res://assets/sprites/ui/alphabet.fnt")
const HOVER_COLOR := Color(1.0, 0.85, 0.1)
## Secondi entro cui va confermata la cancellazione, prima che il tasto torni normale.
const CONFIRM_TIMEOUT := 3.0

@onready var _list: VBoxContainer = $UI/Panel/Scroll/List

## Slot in attesa di conferma di cancellazione (il tasto è stato premuto una volta).
var _pending_delete := ""

func _ready() -> void:
	Input.set_custom_mouse_cursor(ARROW, Input.CURSOR_ARROW, HOTSPOT)
	_rebuild()

func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()

	var saves := GameState.list_saves()
	if saves.is_empty():
		_list.add_child(_info_label(tr("SAVES_EMPTY")))
		return
	for save in saves:
		_list.add_child(_build_row(save))

func _build_row(save: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.add_child(_info_label("%s  —  %s" % [save["display_name"], save["chapter"]]))
	info.add_child(_info_label(tr("SAVES_LINE") % [
		save["day"], save["cash"], save["properties"], _format_play_time(save["play_time"]),
	], Color(0.75, 0.78, 0.82)))
	info.add_child(_info_label(tr("SAVES_SAVED_ON") % _format_date(save["saved_at"]), Color(0.55, 0.58, 0.62)))
	row.add_child(info)

	var slot_id: String = save["slot_id"]
	row.add_child(_action_button(tr("MENU_LOAD"), func(): _load(slot_id)))

	var delete_button := _action_button(tr("MENU_DELETE"), func(): return)
	delete_button.pressed.connect(func(): _ask_delete(slot_id, delete_button))
	row.add_child(delete_button)
	return row

## I testi con dei numeri usano il font di sistema: `alphabet.fnt` contiene solo
## lettere e spazio, quindi con lui cifre, "$" e "—" sparirebbero dallo schermo.
func _info_label(text: String, color := Color(0.94, 0.95, 0.97)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	return label

## I tasti invece hanno solo lettere, quindi possono usare il font del gioco.
func _action_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Hover semplice a colore: qui non si può spostare il tasto come nei menu
	# fissi, perché è dentro a un container che gli riscrive la posizione.
	button.mouse_entered.connect(func(): button.modulate = HOVER_COLOR)
	button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	return button

func _load(slot_id: String) -> void:
	if GameState.load_slot(slot_id):
		get_tree().change_scene_to_file(CITY)

## Cancellare una campagna è irreversibile, quindi ci vogliono due click: il
## primo trasforma il tasto in "sicuro?", il secondo cancella davvero.
func _ask_delete(slot_id: String, button: Button) -> void:
	if _pending_delete == slot_id:
		_pending_delete = ""
		GameState.delete_slot(slot_id)
		_rebuild()
		return
	_pending_delete = slot_id
	button.text = tr("MENU_SURE")
	await get_tree().create_timer(CONFIRM_TIMEOUT).timeout
	if _pending_delete == slot_id:
		_pending_delete = ""
		if is_instance_valid(button):
			button.text = tr("MENU_DELETE")

func _format_play_time(seconds: float) -> String:
	var total := int(seconds)
	if total < 3600:
		return "%dm" % (total / 60)
	return "%dh %dm" % [total / 3600, (total % 3600) / 60]

func _format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "?"
	# Gli unix time sono in UTC: senza lo scarto del fuso orario un salvataggio
	# fatto alle 12:18 in Italia comparirebbe come fatto alle 10:18.
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias * 60)
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]
