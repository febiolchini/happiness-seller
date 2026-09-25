extends CanvasLayer

## La finestra in cui si dà il nome all'organizzazione.
##
## Si apre una volta sola, dopo il messaggio di Brian al primo assunto (vedi
## `GameState._check_milestones()`), e la apre l'HUD: c'è sia in città sia
## nelle stanze, quindi la finestra arriva dovunque si sia quando si assume.
## Non si chiude senza un nome — è il momento in cui si diventa un'attività, e
## una X per saltarlo lo renderebbe un fastidio invece che un passaggio.
##
## Sta nel gruppo "modal": l'HUD sotto si nasconde da solo mentre è aperta.
## Costruita da codice come le righe del gestionale: è una finestra sola, con
## tre pezzi, e una scena in più da tenere allineata non varrebbe la pena.

const MAX_LEN := 24

var _field: LineEdit
var _ok: Button

func _ready() -> void:
	layer = 20
	add_to_group(UiTheme.MODAL_GROUP)
	# Anchors E offset: con il solo preset gli offset restano quelli di prima
	# e il velo e la finestra finivano di traverso in un angolo.
	var dim := ColorRect.new()
	dim.color = UiTheme.DIMMER
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.window_box())
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("ORG_NAME_TITLE")
	UiTheme.dress_window_text(title, title.text, UiTheme.WIN_TITLE, UiTheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := UiTheme.window_label(tr("ORG_NAME_HINT"), UiTheme.brush_size(UiTheme.SIZE_NOTE),
		UiTheme.SIZE_NOTE, UiTheme.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_field = LineEdit.new()
	_field.placeholder_text = tr("ORG_NAME_PLACEHOLDER")
	_field.max_length = MAX_LEN
	_field.add_theme_font_override("font", UiTheme.body(UiTheme.W_BOLD))
	_field.add_theme_font_size_override("font_size", UiTheme.SIZE_VALUE)
	_field.text_changed.connect(func(_t: String) -> void: _update())
	_field.text_submitted.connect(func(_t: String) -> void: _confirm())
	box.add_child(_field)

	_ok = Button.new()
	_ok.text = tr("ORG_NAME_OK")
	UiTheme.dress_button(_ok, UiTheme.primary_boxes(), Color.WHITE)
	UiTheme.dress_window_text(_ok, _ok.text, UiTheme.WIN_BUTTON, UiTheme.SIZE_VALUE,
		UiTheme.W_BOLD)
	_ok.pressed.connect(_confirm)
	box.add_child(_ok)

	_update()
	_field.grab_focus()

func _update() -> void:
	_ok.disabled = _field.text.strip_edges().is_empty()

func _confirm() -> void:
	var name := _field.text.strip_edges()
	if name.is_empty() or GameState.current == null:
		return
	GameState.current.org_name = name
	GameState.save_game()
	queue_free()
