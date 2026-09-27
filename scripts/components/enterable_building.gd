@tool
extends Node2D
class_name EnterableBuilding

## Edificio su cui si può cliccare: reagisce come un pulsante, dice dove ci si
## ferma davanti e, se ha un interno, in quale stanza si entra.
##
## Lo script si attacca direttamente allo `Sprite2D` che disegna l'edificio,
## così l'animazione di pressione agisce sul disegno vero.
##
## Non ce l'hanno tutti gli edifici: i fondali dentro agli isolati restano uno
## sprite nudo. Vedi `CityMap._fill_interior()`.
##
## Con `interior_scene` vuoto l'edificio è cliccabile ma non visitabile: il
## protagonista ci cammina davanti e si ferma. È il caso di quasi tutta la
## città, ed è voluto — un edificio è un oggetto, non pavimento su cui passare.
##
## ## Le proprietà si aprono comprandole
##
## Un edificio con `needs_ownership` ha un interno che esiste già ma resta
## chiuso finché quell'id non è fra le proprietà della partita. La chiave è
## l'`id` della pianta, lo stesso che usa l'agenzia (vedi `real_estate.gd`):
## comprare l'annuncio e poter aprire la porta sono la stessa cosa scritta una
## volta sola, quindi una proprietà nuova è una riga di dati e basta.

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
## Finestra da aprire all'arrivo, invece di entrare in una stanza.
##
## Sono due modi diversi di "aprire" un edificio e non uno la variante
## dell'altro: entrare cambia scena e sposta il protagonista dentro, aprire una
## finestra lo lascia sul marciapiede e ci mette sopra un pannello. L'agenzia
## immobiliare e' del secondo tipo — ci si va a guardare cosa c'e' in vendita,
## non ci si entra a vivere — e da lei in poi lo saranno gli sportelli, le
## bacheche e tutto quello che si consulta stando fuori.
##
## Se sono valorizzati tutti e due vince la stanza: e' il caso piu' forte, e
## averli entrambi e' un errore di dati, non una scelta.
@export_file("*.tscn") var window_scene := ""
## Il flag della partita che apre lo sportello. Vuoto: aperto sempre. Serve a
## un edificio che sta in città da subito ma con cui si tratta solo più avanti —
## la stazione degli autobus, finché Kevin non gira il contatto. Prima di
## allora l'insegna si legge, ma il click non apre niente e il segnalino non
## c'è, come per una proprietà non ancora comprata.
@export var window_flag := ""

## L'insegna, mostrata passandoci sopra col mouse. Vuota vuol dire nessuna
## etichetta: l'edificio resta cliccabile, semplicemente non ha un nome da dire.
@export var display_name := ""
## L'id della voce in `CityMap.BUILDINGS`, che è anche quello con cui la partita
## segna le proprietà. Serve solo a chi ha `needs_ownership`.
@export var building_id := ""
## Ci si entra solo se è roba propria.
@export var needs_ownership := false
## La proprietà che apre la porta, se non è l'edificio intero: un appartamento
## della torre apre la torre. Vuoto = `building_id`.
@export var property_id := ""

# --- Il segnalino ----------------------------------------------------------
## Un triangolo sopra al tetto, per dire a colpo d'occhio che lì si fa
## qualcosa. La città è fatta di disegni e non di cartelli: senza, l'unico modo
## di sapere quali dei trenta edifici si aprono era provarli tutti.
##
## Due colori, e la differenza è "è tuo o no":
##
## - **verde** — ci entri quando vuoi: casa, e le proprietà che hai comprato;
## - **giallo-arancio** — uno sportello: l'agenzia, il grossista, la stazione.
##
## Una proprietà in vendita e non ancora comprata **non ha segnalino**, e
## nemmeno uno sportello ancora chiuso: non c'è niente da farci, e accenderlo
## prima sarebbe promettere una porta che non si apre.
##
## Tutti e due sono il triangolo disegnato da Federico, grande, sopra al tetto e
## che dondola (quello giallo-arancio è lo stesso ricolorato da
## `import_segni_ui.py`). Prima lo sportello aveva un triangolino disegnato
## a codice sopra alla porta, sette pixel: in una città vista da lontano non
## lo trovava nessuno.
const OWNED_MARKER := preload("res://assets/sprites/ui/triangolo_verde.png")
const WINDOW_MARKER := preload("res://assets/sprites/ui/triangolo_arancio.png")
## Quanto sta sopra al tetto la punta del triangolo, e quanto dondola.
const OWNED_MARKER_GAP := 6.0
const OWNED_MARKER_BOB := 3.0
const OWNED_MARKER_PERIOD := 1.6

var _tween: Tween
var _owned_marker: Sprite2D
var _bob_time := 0.0

func _ready() -> void:
	add_to_group(GROUP)
	# Comprare una proprietà accende il suo segnalino: vedi
	# `GameState.property_bought`.
	GameState.property_bought.connect(_on_property_bought)
	# Nel gruppo della luce: `atmosphere.gd` avvisa quando l'ora è cambiata
	# abbastanza da vedersi, e il segnalino si ridisegna con la tinta nuova.
	# È lo stesso giro dei lampioni.
	add_to_group(Daylight.LIGHT_GROUP)
	_owned_marker = Sprite2D.new()
	# Sopra agli edifici davanti: il triangolo sta in aria, sopra al tetto, e
	# con l'ordinamento per y lo coprirebbe il palazzo della fila sotto.
	_owned_marker.z_index = 50
	add_child(_owned_marker)
	_update_owned_marker()

## C'è qualcosa da aprire cliccandoci sopra? Falso per la maggior parte della
## città, e falso per una proprietà non ancora comprata.
func can_open() -> bool:
	if interior_scene.is_empty() and window_scene.is_empty():
		return false
	return is_unlocked()

## La porta è aperta? Lo è sempre, tranne per le proprietà che vanno comprate.
##
## Senza partita in corso — la mappa aperta dall'editor — si risponde di sì:
## un interno che non si apre mai sarebbe indistinguibile da uno rotto.
func is_unlocked() -> bool:
	var data := GameState.current
	if data == null:
		return true
	if not window_flag.is_empty() and not bool(data.get_flag(window_flag, false)):
		return false
	return not needs_ownership or data.owns(ownership_key())

## L'id che la partita deve possedere perché la porta si apra.
func ownership_key() -> String:
	return building_id if property_id.is_empty() else property_id

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


func _on_property_bought(id: String) -> void:
	if id == ownership_key():
		_update_owned_marker()

func _update_owned_marker() -> void:
	var texture := marker_texture()
	var visibile := texture != null
	_owned_marker.visible = visibile
	set_process(visibile)
	if not visibile:
		return
	_owned_marker.texture = texture
	# Non si spegne di notte insieme al muro: `emissive()` pre-divide il colore
	# per la luce dell'ora, e il `CanvasModulate` della città lo riporta pieno.
	_owned_marker.modulate = Daylight.emissive(Color.WHITE, Daylight.light(GameState.current))
	_place_owned_marker()

func _place_owned_marker() -> void:
	# Lo script sta sullo Sprite2D dell'edificio (vedi in cima), ma e' scritto
	# come Node2D: il riquadro del disegno si chiede per nome.
	var tetto: Rect2 = call("get_rect") if has_method("get_rect") else click_rect
	var alto := _owned_marker.texture.get_height() * 0.5
	var dondolo := roundf(sin(_bob_time * TAU / OWNED_MARKER_PERIOD) * OWNED_MARKER_BOB)
	# A pixel interi: il resto della città è pixel art, e un triangolo che
	# galleggia fra un pixel e l'altro tremolerebbe invece di dondolare.
	_owned_marker.position = Vector2(
		roundf(tetto.get_center().x),
		roundf(tetto.position.y - OWNED_MARKER_GAP - alto) + dondolo)

func _process(delta: float) -> void:
	_bob_time += delta
	_place_owned_marker()

## Quale segnalino ha questo edificio, o `null` se non ne ha uno.
##
## Si ricava da quello che l'edificio SA FARE, non da un elenco di id scritto a
## parte: un interno libero è casa tua, un interno da comprare è tuo solo quando
## l'hai comprato, una finestra è uno sportello. Aggiungendo un edificio nuovo
## il segnalino viene da sé.
func marker_texture() -> Texture2D:
	if needs_ownership:
		return OWNED_MARKER if is_unlocked() else null
	if not interior_scene.is_empty():
		return OWNED_MARKER
	if not window_scene.is_empty():
		return WINDOW_MARKER if is_unlocked() else null
	return null

## Chiamata da `atmosphere.gd` quando la luce è cambiata abbastanza da vedersi.
func on_light_changed() -> void:
	_update_owned_marker()
