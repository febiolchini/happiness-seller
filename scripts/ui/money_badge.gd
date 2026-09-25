extends Control

## La cassa, in cima allo schermo, scritta in rilievo.
##
## ## Perché è l'unica cosa al centro
##
## Tutto il resto dell'HUD sta negli angoli: la sveglia a destra, il menu a
## sinistra, i messaggini che scorrono sotto. Il centro in alto è il posto che
## l'occhio trova senza cercarlo, e in un gestionale c'è **un** numero che
## merita quel posto.
##
## Per un giro la cassa era finita dentro al menu insieme alla scorta, ed era
## troppo: la scorta è una cosa che si va a controllare, i soldi sono la cosa
## che dice se quello che stai facendo sta funzionando. Sono tornati fuori, ma
## non dove stavano prima — in un angolo, accanto ad altri quattro numeri,
## diventavano arredamento.
##
## ## Il rilievo non è decorazione
##
## Questo numero sta sopra alla città, senza fondo, e sotto ci passa di tutto:
## un muro chiaro, l'asfalto, il cielo, un lampione acceso. Una scritta piatta
## con un'ombra sola su certi fondali si legge male e su altri sparisce.
##
## L'estrusione risolve proprio quello, ma **non da sola**: il primo tentativo
## disegnava i fianchi e poi la faccia, e senza niente in mezzo i fianchi si
## leggevano come un'ombra sfocata invece che come lo spessore della lettera.
##
## Quello che serve è una **sagoma scura** che copra il blocco intero — fianchi
## e faccia insieme — allargata di un pixel in tutte le direzioni. Sopra ci
## vanno i fianchi, e sopra ancora la faccia. Così il numero non tocca mai il
## fondale, e fra la faccia chiara e il fianco scuro c'è sempre un filo nero che
## tiene separate le due superfici. È la differenza fra una scritta con l'ombra
## e una scritta di plastica.
##
## La sagoma si fa a mano, ripetendo la scritta sui nove intorni di ogni
## posizione, e non con `draw_string_outline()`: quello traccia il contorno di
## **una** passata, quindi seguirebbe la faccia e lascerebbe i fianchi fuori.

## Il corpo del numero. Più grande di qualunque altra cosa a schermo: è il posto
## e la taglia a dire che questo è il numero che conta, non il colore.
##
## Diciannove e non ventidue: a ventidue "1.250.000 $" arrivava a un terzo della
## larghezza dello schermo, e un numero che si allunga così smette di essere una
## cosa che si guarda e diventa una scritta appesa in mezzo alla città.
const SIZE := 19
## Quanto sono spesse le lettere.
##
## Due e non tre. A tre il rilievo si vedeva prima del numero — a corpo
## diciannove sono quasi un sesto dell'altezza della cifra, e le lettere
## diventavano oggetti invece che scritte. Uno solo però non basta: a un pixel
## il fianco si confonde col filo nero della sagoma e resta solo una scritta col
## bordo.
const DEPTH := 2

## Quanto sta staccato dal bordo di sopra.
const TOP := 5.0

const FACE := Color(0.97, 0.98, 0.72)
## I fianchi: la faccia scurita, non nera. Un'ombra nera si legge come un'ombra
## portata, il colore scurito si legge come lo spessore della stessa lettera.
const SIDE := Color(0.45, 0.42, 0.17)
## La sagoma sotto a tutto. Nera piena e non semitrasparente: deve funzionare
## anche sopra a un muro chiaro in pieno sole.
const EDGE := Color(0.04, 0.04, 0.03)

var _text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Il pennello rimpicciolito col "nearest" del progetto si sgrana: vedi
	# `UiTheme.dress_menu_text()`.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(_delta: float) -> void:
	var data := GameState.current
	var wanted := UiFormat.money(data.cash) if data != null else ""
	if wanted == _text:
		return
	_text = wanted
	queue_redraw()

func _draw() -> void:
	if _text.is_empty():
		return
	# Il pennello senza ombra: la sagoma e i fianchi qui sotto sono gia'
	# un'ombra, e quella cotta dentro a `brush.fnt` ci farebbe una macchia.
	var font := UiTheme.WINDOW_FILE
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	# La base è la riga su cui poggiano le lettere, non il loro bordo di sopra:
	# `draw_string()` disegna da lì, ed è il motivo per cui ci va sommato
	# l'ascendente invece di partire dall'angolo.
	var base := Vector2(roundf((size.x - width) * 0.5), TOP + font.get_ascent(SIZE))

	# 1. La sagoma: il blocco intero — faccia e fianchi — allargato di un pixel
	#    in tutte le direzioni. È quello che stacca il numero dal fondale e che
	#    mette un filo nero fra la faccia e il fianco.
	for step in range(DEPTH, -1, -1):
		var at := base + Vector2(step, step)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				_write(font, at + Vector2(dx, dy), EDGE)
	# 2. I fianchi, dal più lontano al più vicino: disegnati al contrario si
	#    coprirebbero fra loro e il rilievo verrebbe alto un pixel.
	for step in range(DEPTH, 0, -1):
		_write(font, base + Vector2(step, step), SIDE)
	# 3. La faccia.
	_write(font, base, FACE)

func _write(font: Font, at: Vector2, color: Color) -> void:
	font.draw_string(get_canvas_item(), at, _text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, SIZE, color)
