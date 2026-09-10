extends BaseButton

## Comportamento comune di tutti i bottoni del menu: hover con glow giallino
## pulsante, leggero abbassamento al click. Funziona sia su TextureButton
## (icone/testo disegnati come immagine) sia su Button (testo con font).

## Cosa fare alla partita prima di cambiare scena. Si combina con `target_scene`:
## l'azione decide cosa succede al salvataggio, `target_scene` dove si va dopo.
enum Action {
	NONE,        ## nessun effetto sulla partita
	CONTINUE,    ## riprende il salvataggio più recente (se non c'è, ne inizia una nuova)
	NEW_GAME,    ## inizia sempre una campagna da zero
}

@export var action: Action = Action.NONE
## Dentro a un container la posizione la decide il layout, quindi l'abbassamento
## al click va spento: altrimenti le due cose si contendono la stessa proprietà.
@export var use_press_offset := true
@export var quit_on_press: bool = false
@export var target_scene: String = ""

var original_position: Vector2
var hover_tween: Tween
var press_offset := Vector2(0, 2)

func _ready() -> void:
	original_position = position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)

## Un solo handler invece di più `pressed.connect()` separati: così l'ordine fra
## "prepara la partita" e "cambia scena" è esplicito e non dipende da come sono
## state collegate le callback.
func _on_pressed() -> void:
	match action:
		Action.CONTINUE:
			# Al primo avvio non c'è ancora niente da continuare: invece di non
			# fare nulla, il tasto play avvia direttamente una partita nuova.
			if not GameState.continue_last():
				GameState.new_game()
		Action.NEW_GAME:
			GameState.new_game()

	# Riprendendo una partita si torna dove la si era lasciata, che può essere
	# dentro a una stanza e non per forza in strada.
	if action != Action.NONE:
		get_tree().change_scene_to_file(GameState.scene_for_current_state())
		return

	if quit_on_press:
		get_tree().quit()
		return
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)

const HOVER_COLOR := Color(1.0, 0.85, 0.1)

func _on_mouse_entered() -> void:
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "modulate", HOVER_COLOR, 0.1)

func _on_mouse_exited() -> void:
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

func _on_button_down() -> void:
	if not use_press_offset:
		return
	var press_tween := create_tween()
	press_tween.tween_property(self, "position", original_position + press_offset, 0.08)

func _on_button_up() -> void:
	if not use_press_offset:
		return
	var release_tween := create_tween()
	release_tween.tween_property(self, "position", original_position, 0.08)
