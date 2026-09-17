extends Control

## La sveglia digitale dell'HUD: che ore sono e che giorno è.
##
## ## Perché una sveglia e non due parole
##
## Prima erano un pezzo della riga in alto: "GIORNO 6  15:36", stesso font e
## stesso colore di tutto il resto. Funzionava e non diceva niente — due numeri
## in mezzo ad altri numeri, che il giocatore smette di vedere dopo dieci
## minuti. In un gestionale dove **il tempo è la risorsa** (le piante crescono a
## ore di gioco, Brian aspetta a ore di gioco, le paghe scattano a mezzanotte)
## l'orologio merita di essere un oggetto, non una voce di elenco.
##
## Quindi è una sveglia da comodino, disegnata, con le cifre accese dentro.
##
## ## Le cifre sono disegnate, non scritte
##
## A sette segmenti, una per una (`_draw_glyph()`), e non con un font. Tre
## motivi, in ordine di peso:
##
## 1. **È il display che rende la sveglia una sveglia.** Un font di sistema
##    dentro a quel buco nero resta un font di sistema dentro a un buco nero.
## 2. **I segmenti spenti.** Su un display vero si intravedono anche quando non
##    sono accesi, ed è il dettaglio che fa leggere l'oggetto come acceso invece
##    che come un'immagine dell'oggetto. Con un font non si possono disegnare:
##    non esistono come glifo.
## 3. Nessun file da aggiungere, e le cifre restano nitide a qualunque taglia
##    perché sono rettangoli.
##
## ## Il vetro è storto, e le cifre pure
##
## La sveglia è disegnata di tre quarti: il display non è un rettangolo ma un
## parallelogramma che scende verso destra. Una riga di cifre orizzontale
## dentro a quel buco si legge subito come un adesivo appiccicato sopra. Quindi
## tutto quello che finisce nel display passa da una trasformazione inclinata di
## `SHEAR` (vedi `_draw()`), e le cifre scendono col vetro.
##
## `GLASS` e `SHEAR` non sono presi a occhio: li misura
## `scripts_tools/import_clock_art.py` sul disegno, mentre lo riduce alla taglia
## del gioco. Se la sveglia viene ridisegnata si rilancia quello e si ricopiano
## qui i tre numeri che stampa.

## Quanto è grande la sveglia, dov'è il vetro dentro la scocca, e quanto pende.
##
## Il rettangolo del vetro è già espresso **nel sistema inclinato**: si applica
## `SHEAR` e ci si disegna dentro dritti, senza altri conti.
const SIZE := Vector2(78.0, 52.0)
const GLASS := Rect2(3.0, 11.4, 56.0, 16.9)
const SHEAR := 0.194

## L'orario, a sinistra del vetro.
##
## Le misure non sono scalabili a piacere. La regola è che **altezza meno tratto
## dev'essere pari**: è quello che tiene il segmento di mezzo centrato su un
## pixel intero (metà di 16-2 fa 7), e sbagliandola cadrebbe a metà pixel e
## sfocherebbe. In larghezza otto lascia barre da quattro col tratto da due.
##
## Sedici su diciassette di vetro: le cifre lo riempiono quasi tutto, ed è
## voluto. Una versione ne usava tredici e il display sembrava acceso a metà —
## su una sveglia le cifre arrivano al bordo, è il vetro a essere della misura
## delle cifre e non il contrario.
##
## **Il tratto è due e non uno**, che a schermo è la differenza fra cifre
## disegnate e cifre accese: con un pixel i segmenti sono dei fili e il display
## si legge come una scritta, con due sono barre e si legge come un apparecchio.
## Costa tre pixel di larghezza in più per cifra, ed è il motivo per cui il
## blocco del giorno ha dovuto stringersi (vedi `DAY_DIGIT`).
const TIME_DIGIT := Vector2(8.0, 16.0)
const TIME_STROKE := 2.0
const TIME_GAP := 1.0
## I due punti. Più larghi del tratto apposta: a misura di tratto sarebbero due
## granelli, e a metà lampeggio l'orario si leggerebbe come "15 40".
const COLON_DOT := 3.0
## Il giorno, piccolo, incolonnato a destra: la scritta sopra e il numero sotto.
## È dove sta il display secondario di una sveglia vera, ed è anche l'unico modo
## di usare la larghezza del vetro invece di lasciarne mezzo vuoto.
const DAY_LETTER := Vector2(3.0, 5.0)
## Alto nove per la regola dell'orario (metà di 9-1 fa 4), e largo **quattro**:
## è la cifra più stretta che si possa scrivere a sette segmenti, con le barre
## orizzontali lunghe due.
##
## Stretta così perché è lì che si paga il tratto doppio dell'orario. Il vetro è
## largo cinquantasei: l'orario ne prende trentotto, i margini due, e quello che
## resta deve bastare al giorno **anche a tre cifre** — che a cinque di
## larghezza farebbero diciassette e andrebbero a toccare l'orario. A quattro ne
## fanno quattordici e restano due pixel di distacco, che a schermo si vedono.
const DAY_DIGIT := Vector2(4.0, 9.0)
## Il pixel della scritta DAY. Vedi `LEGEND`.
const LEGEND_PIXEL := 1.0
const SMALL_STROKE := 1.0
const SMALL_GAP := 1.0
## Aria fra la scritta DAY e il numero sotto.
const DAY_SPLIT := 1.0
## Quanto il blocco del giorno sta lontano dal bordo destro del vetro, e quanto
## l'orario sta lontano da quello sinistro.
##
## Un pixel per parte, che sembra tirato e lo è: il vetro è largo
## cinquantacinque, l'orario ne prende trentatré e il blocco del giorno
## **diciassette** quando il giorno arriva a tre cifre. Quello che resta è il
## distacco fra i due, e tre pixel sono il minimo perché l'ultima cifra
## dell'orario e la prima del giorno non si leggano come un numero solo. Al
## giorno 128 era successo.
const DAY_MARGIN := 1.0
const TIME_MARGIN := 1.0

## Verde, come i display a fluorescenza degli anni ottanta.
##
## Era ambra finché la scocca era verde oliva: lì l'ambra era il complementare e
## il verde sarebbe sparito dentro al suo stesso colore. Adesso che la sveglia è
## **rossa** vale l'opposto — l'ambra le stava addosso, nella stessa famiglia
## calda, e a un metro di distanza il display si perdeva nella scocca; il verde
## è il complementare del rosso e le cifre saltano fuori dal vetro.
##
## È anche il motivo per cui questa costante esiste invece di essere scritta
## dentro alle funzioni di disegno: il colore della luce dipende dal disegno
## della scocca, e i disegni cambiano.
const LIT := Color(0.45, 0.94, 0.55)
## Il segmento spento. Quasi invisibile ed è il punto: si vede solo se lo si
## cerca, come su un display vero.
const DIM := Color(0.45, 0.94, 0.55, 0.10)
## Il giorno è informazione di contorno: stessa luce, un filo più bassa.
const LIT_SOFT := Color(0.45, 0.94, 0.55, 0.72)

## Il colore dei due punti quando sono spenti.
##
## Spenti sul serio (`DIM`) sarebbe più fedele a una sveglia vera, ed è come era
## la prima versione: a schermo però i due punti sono due quadratini di due
## pixel, e metà del tempo l'orario diventava "15 40" con un buco in mezzo, che
## si legge come un display rotto invece che come un lampeggio. Bassi ma visibili
## è il compromesso che si legge.
const COLON_OFF := Color(0.45, 0.94, 0.55, 0.30)

## Quanto dura un lampeggio dei due punti, in secondi veri.
##
## Un secondo esatto, come una sveglia da comodino, e **non** un secondo di
## gioco: l'orologio del gioco corre quattro minuti al secondo, e due punti che
## lampeggiano a quel ritmo sembrano un guasto. È l'unica cosa di questo nodo
## che segue il tempo vero, ed è giusto così — è il battito dell'oggetto, non
## della partita.
const BLINK := 1.0

## I sette segmenti accesi per ogni carattere che sappiamo disegnare, nell'ordine
## `a b c d e f g`: sopra, destra-alto, destra-basso, sotto, sinistra-basso,
## sinistra-alto, mezzo.
##
## Solo cifre: le lettere di "DAY" sono stampate, non a segmenti (vedi
## `LEGEND`). Una chiave che non c'è esce vuota invece di rompere, ma resta un
## buco nel display: se qui dentro dovesse finire altro, va aggiunto prima.
const GLYPHS := {
	"0": [true, true, true, true, true, true, false],
	"1": [false, true, true, false, false, false, false],
	"2": [true, true, false, true, true, false, true],
	"3": [true, true, true, true, false, false, true],
	"4": [false, true, true, false, false, true, true],
	"5": [true, false, true, true, false, true, true],
	"6": [true, false, true, true, true, true, true],
	"7": [true, true, true, false, false, false, false],
	"8": [true, true, true, true, true, true, true],
	"9": [true, true, true, true, false, true, true],
	" ": [false, false, false, false, false, false, false],
}

## La scritta DAY, disegnata a pixel invece che a sette segmenti.
##
## Non è un'incoerenza, è come sono fatti gli apparecchi veri: le **cifre** sono
## a segmenti perché devono cambiare, la **parola** è stampata sul vetro e non
## cambia mai. Ed è anche l'unica che si legga: una "A" a sette segmenti alta
## cinque pixel viene fuori come tre macchie, e questo si è visto solo mettendola
## a schermo.
const LEGEND := {
	"D": ["110", "101", "101", "101", "110"],
	"A": ["010", "101", "111", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"],
}

var _time := 0.0

func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var data := GameState.current
	if data == null:
		return
	# Da qui in poi si disegna storto: tutto quello che segue scende insieme al
	# vetro. Va rimesso a posto alla fine, perché la trasformazione resta
	# attaccata al nodo e il prossimo `_draw()` la troverebbe già applicata.
	draw_set_transform_matrix(Transform2D(Vector2(1.0, SHEAR), Vector2(0.0, 1.0), Vector2.ZERO))
	_draw_time(data)
	_draw_day(data)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## L'orario, a sinistra del vetro, coi due punti che lampeggiano.
func _draw_time(data: SaveData) -> void:
	var clock := UiFormat.clock(data.time_of_day)
	var y := GLASS.position.y + (GLASS.size.y - TIME_DIGIT.y) * 0.5
	var x := GLASS.position.x + TIME_MARGIN
	for i in clock.length():
		var letter := clock[i]
		if letter == ":":
			_draw_colon(Vector2(x, y))
			# Un pixel per parte come fra due cifre: i due punti sono un carattere
			# come gli altri, e dargli più aria spezzava l'orario in due metà.
			x += COLON_DOT + TIME_GAP
			continue
		_draw_glyph(letter, Vector2(x, y), TIME_DIGIT, TIME_STROKE, LIT)
		x += TIME_DIGIT.x + TIME_GAP

## I due punti. Quadrati e non tondi: sono due segmenti come tutti gli altri, e
## un cerchio in mezzo a dei rettangoli si vedrebbe che viene da un altro
## disegno.
func _draw_colon(at: Vector2) -> void:
	var on := fmod(_time, BLINK * 2.0) < BLINK
	var color := LIT if on else COLON_OFF
	# A un terzo e a due terzi dell'altezza della cifra, centrati: è dove stanno
	# sui display veri, ed è anche l'unico modo di non farli sembrare appoggiati
	# sul segmento di mezzo delle cifre accanto.
	var half := COLON_DOT * 0.5
	draw_rect(Rect2(at.x, at.y + TIME_DIGIT.y * 0.3 - half, COLON_DOT, COLON_DOT), color, true)
	draw_rect(Rect2(at.x, at.y + TIME_DIGIT.y * 0.7 - half, COLON_DOT, COLON_DOT), color, true)

## Il giorno: la scritta DAY sopra, il numero sotto, incolonnati a destra.
##
## **"DAY" non passa dalle traduzioni, ed è voluto.** È una scritta stampata su
## un apparecchio, come le lettere sul quadrante di un orologio: non si traduce
## per lo stesso motivo per cui non si traducono i nomi delle strade. Il giorno
## scritto a parole c'è già, tradotto, nel gestionale del PC (`HUD_DAY`).
func _draw_day(data: SaveData) -> void:
	var number := str(data.day)
	var word_width := DAY_LETTER.x * 3.0 + SMALL_GAP * 2.0
	var number_width := DAY_DIGIT.x * number.length() + SMALL_GAP * (number.length() - 1)
	var block := maxf(word_width, number_width)
	var right := GLASS.end.x - DAY_MARGIN
	var tall := DAY_LETTER.y + DAY_SPLIT + DAY_DIGIT.y
	var top := GLASS.position.y + (GLASS.size.y - tall) * 0.5

	var x := right - block + (block - word_width) * 0.5
	for letter in "DAY":
		_draw_legend(letter, Vector2(x, top))
		x += DAY_LETTER.x + SMALL_GAP

	x = right - block + (block - number_width) * 0.5
	var y := top + DAY_LETTER.y + DAY_SPLIT
	for i in number.length():
		_draw_glyph(number[i], Vector2(x, y), DAY_DIGIT, SMALL_STROKE, LIT)
		x += DAY_DIGIT.x + SMALL_GAP

## Una lettera della scritta DAY, pixel per pixel. Vedi `LEGEND`.
func _draw_legend(letter: String, at: Vector2) -> void:
	var rows: Array = LEGEND.get(letter, [])
	for row in rows.size():
		var line: String = rows[row]
		for column in line.length():
			if line[column] != "1":
				continue
			draw_rect(Rect2(
				at.x + float(column) * LEGEND_PIXEL,
				at.y + float(row) * LEGEND_PIXEL,
				LEGEND_PIXEL, LEGEND_PIXEL), LIT_SOFT, true)

## Un carattere a sette segmenti. Disegna **anche quelli spenti**, sbiaditi: è
## quello che distingue un display da una scritta.
func _draw_glyph(letter: String, at: Vector2, glyph: Vector2, stroke: float,
		color: Color) -> void:
	var on: Array = GLYPHS.get(letter.to_upper(), GLYPHS[" "])
	var middle := (glyph.y - stroke) * 0.5
	var side := middle - stroke
	var rects := [
		Rect2(at.x + stroke, at.y, glyph.x - stroke * 2.0, stroke),                       # a
		Rect2(at.x + glyph.x - stroke, at.y + stroke, stroke, side),                      # b
		Rect2(at.x + glyph.x - stroke, at.y + middle + stroke, stroke, side),             # c
		Rect2(at.x + stroke, at.y + glyph.y - stroke, glyph.x - stroke * 2.0, stroke),    # d
		Rect2(at.x, at.y + middle + stroke, stroke, side),                                # e
		Rect2(at.x, at.y + stroke, stroke, side),                                         # f
		Rect2(at.x + stroke, at.y + middle, glyph.x - stroke * 2.0, stroke),              # g
	]
	for i in rects.size():
		draw_rect(rects[i], color if on[i] else DIM, true)
