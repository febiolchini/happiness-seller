class_name UiTheme
extends RefCounted

## La pelle dell'interfaccia: colori, font e riquadri, in un posto solo.
##
## Prima ogni schermata si dipingeva da sé — l'HUD aveva le sue costanti, il
## gestionale le sue, i bottoni un colore scritto a mano dentro `_make_button()`
## — e il risultato era che lo stesso verde di "va bene" era tre verdi diversi.
## Da qui in poi una tinta si cambia in un posto e cambia dappertutto.
##
## ## Perché chiaro
##
## Il gestionale è il computer di chi manda avanti un'attività: è l'unica
## schermata in cui non si sta guardando la strada, e farla chiara la stacca dal
## mondo invece di essere un altro rettangolo scuro sopra a una città scura.
## La tavolozza è di carta calda, non di bianco d'ufficio — inchiostro marrone e
## non nero, terracotta invece che blu di sistema: la stessa roba sbiadita del
## quartiere, ma pulita.
##
## ## I due font, e perché sono due
##
## - `display()` è `alphabet.fnt`, il font disegnato a mano del gioco. Ha
##   **solo lettere** (niente cifre, niente punteggiatura) e l'ombra già dentro
##   al disegno: va bene per un titolo, non per una riga di dati. È l'identità
##   del gioco e resta dov'è sempre il caso.
## - `body()` è Nunito (OFL, in `assets/fonts/`), che le cifre ce le ha. È
##   arrotondato e caldo: accanto al pixel art non stona come stonerebbe un
##   font da interfaccia di sistema, ed è leggibile a undici pixel, che è la
##   misura a cui vive metà di questa schermata.
##
## Nunito è **variabile**: un file solo, e il peso si chiede a `body(600)`.
## Volendone un altro basta metterlo in `assets/fonts/` e cambiare `BODY_FILE`.
##
## ## Il terzo: il pennello dei menu
##
## `menu()` è `brush.fnt`, l'alfabeto scritto a pennello ricavato da una foto
## da `scripts_tools/import_brush_font.py`. Vale **solo per i menu** — quello
## principale, impostazioni, salvataggi e il menu a tre righe in partita — non
## per il telefono né per le finestre. Come `alphabet.fnt` ha solo lettere (le
## minuscole sono le stesse maiuscole) e l'ombra cotta dentro, quindi le voci
## che ci finiscono sopra sono PIXEL in `strings.gd`.
##
## Va messo con `dress_menu_text()` e non a mano: il glifo è disegnato a 56 px
## e a schermo ne esce un terzo, e rimpicciolito col filtro "nearest" del
## progetto — giusto per il pixel art — il pennello diventa una sgranatura. Il
## filtro lineare lo tiene pulito.

const BODY_FILE := preload("res://assets/fonts/Nunito-Variable.ttf")
const DISPLAY_FILE := preload("res://assets/sprites/ui/alphabet.fnt")
const MENU_FILE := preload("res://assets/sprites/ui/brush.fnt")
## Lo stesso pennello **senza ombra**, per le finestre di carta (PC, agenzia,
## grossista, guida...): lì la lettera si scrive scura sul chiaro, e l'ombra
## scura cotta dentro a `brush.fnt` la farebbe sembrare sbavata.
const WINDOW_FILE := preload("res://assets/sprites/ui/brush_ink.fnt")

## Le misure del pennello nelle finestre.
const WIN_TITLE := 24    ## il titolo della finestra
const WIN_TAB := 17      ## le voci della colonna (schede del PC, sezioni della guida)
const WIN_LABEL := 15    ## le etichette fisse delle righe
const WIN_BUTTON := 16   ## bottoni di sole parole, "chiudi"

## Quello che il pennello sa scrivere: lettere e spazio. Stessa regola PIXEL di
## `strings.gd`, ma controllata sul testo vero, a schermo.
const BRUSH_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz "

## Le misure del pennello. Più grandi di quelle dell'alfabeto di prima: il
## pennello è più sottile e più mosso, e a sedici pixel le setole si impastano.
const MENU_BIG := 22     ## le voci del menu principale
const MENU_ITEM := 18    ## le voci delle impostazioni
const MENU_SMALL := 15   ## "indietro", carica/cancella, le righe del menu in partita
const MENU_TITLE := 26   ## il titolo di una schermata

# --- Tavolozza --------------------------------------------------------------
# Bianco e nero come base, il colore solo dove serve dire qualcosa: un bottone
# da premere, un valore che va bene, uno che non va. Su un fondo neutro tre
# tinte accese bastano e si vedono; su un fondo gia' colorato ne servirebbero
# di piu' forti e la schermata diventa un semaforo.

## Fondo della finestra: un grigio chiarissimo, non bianco pieno. Serve solo a
## far staccare i riquadri, che invece sono bianchi: con tutto dello stesso
## bianco i gruppi sparirebbero e si tornerebbe a una lista piatta.
const PAPER := Color(0.961, 0.965, 0.973)
## Il riquadro che raggruppa le righe. Questo sì, bianco pieno.
const CARD := Color(1.0, 1.0, 1.0)
## Riquadro incassato: righe alternate, campi spenti.
const SUNKEN := Color(0.925, 0.933, 0.945)
## Fascia dell'intestazione.
const HEADER := Color(1.0, 1.0, 1.0)

## Testo principale. Quasi nero e non nero pieno: il nero assoluto su bianco
## puro vibra, e questa è una schermata da leggere a lungo.
const INK := Color(0.090, 0.098, 0.114)
## Etichette, didascalie.
const INK_SOFT := Color(0.337, 0.361, 0.400)
## Note, spiegazioni, roba che si legge solo se la si cerca.
const INK_FAINT := Color(0.541, 0.565, 0.600)
## Filetti e bordi.
const LINE := Color(0.882, 0.894, 0.914)

## Arancio: il colore delle cose su cui si clicca. È l'unico acceso che non
## vuol dire "bene" o "male" — quelli sono il verde e il rosso qui sotto — e
## quindi è libero di voler dire solo "premimi".
const ACCENT := Color(0.937, 0.424, 0.239)
const ACCENT_DARK := Color(0.788, 0.322, 0.165)
const ACCENT_SOFT := Color(0.992, 0.918, 0.886)

## Verde: va bene, è pronto, è guadagnato.
const GOOD := Color(0.184, 0.627, 0.353)
## Giallo: attenzione, sta per finire. Tirato sul giallo e non sull'ambra per
## non confonderlo con l'arancio dei bottoni.
const WARN := Color(0.851, 0.643, 0.255)
## Rosso: non ce la fai, è rotto, è in perdita.
const BAD := Color(0.839, 0.271, 0.271)
## Blu: informazioni neutre (il tempo che fa, i posti).
const INFO := Color(0.239, 0.510, 0.780)

## Il velo che scurisce il gioco dietro a una finestra modale.
const DIMMER := Color(0.0, 0.0, 0.0, 0.5)

# --- Scala tipografica ------------------------------------------------------
# Sei misure e non una per occasione: con una scala aperta ogni schermata
# inventa il suo corpo e due etichette uguali finiscono scritte diverse.

const SIZE_TITLE := 18   ## titolo di finestra (display)
const SIZE_BIG := 17     ## il numero che conta (la cassa)
const SIZE_TAB := 12     ## voci di menu
const SIZE_VALUE := 12   ## valori nelle righe
const SIZE_LABEL := 11   ## etichette
const SIZE_NOTE := 10    ## note e spiegazioni

const W_REGULAR := 400
const W_MEDIUM := 500
const W_BOLD := 700

static var _body_cache: Dictionary = {}
static var _weight_tag := 0

## Nunito al peso chiesto. Il risultato è in cache: un `FontVariation` nuovo per
## ogni Label vorrebbe dire un atlante di glifi nuovo per ognuna.
static func body(weight: int = W_REGULAR) -> FontVariation:
	if _body_cache.has(weight):
		return _body_cache[weight]
	if _weight_tag == 0:
		_weight_tag = TextServerManager.get_primary_interface().name_to_tag("weight")
	var variation := FontVariation.new()
	variation.base_font = BODY_FILE
	variation.variation_opentype = {_weight_tag: weight}
	_body_cache[weight] = variation
	return variation

static func display() -> Font:
	return DISPLAY_FILE

static func menu() -> Font:
	return MENU_FILE

## Veste un testo dei menu col pennello: font, misura e il filtro lineare (vedi
## sopra). Vale per Label e Button, e per qualunque altro Control con un font.
static func dress_menu_text(node: Control, size := MENU_ITEM) -> void:
	node.add_theme_font_override("font", MENU_FILE)
	node.add_theme_font_size_override("font_size", size)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

## Si può scrivere col pennello? Solo se ogni carattere è una lettera o uno
## spazio. Un "VASO 3" o un "$120" no: col pennello la cifra non si disegna e
## resterebbe un buco nella parola.
##
## Si guarda il testo **tradotto**: molti nodi hanno per testo la chiave
## ("PC_CLOSE") e la traduzione la fa Godot a schermo, e la chiave col suo
## trattino basso non passerebbe mai.
static func can_brush(text: String) -> bool:
	var shown := String(TranslationServer.translate(text))
	if shown.strip_edges().is_empty():
		return false
	for letter in shown:
		if not BRUSH_CHARS.contains(letter):
			return false
	return true

## Veste un testo di una finestra: col pennello senza ombra se il testo lo
## permette, altrimenti con Nunito al peso dato — **e lo decide sul testo che
## c'è adesso**. Le righe del PC cambiano scritta mentre si gioca, quindi chi
## riscrive il testo di un bottone o di un'etichetta la richiama.
##
## Il pennello esce un filo più grande di Nunito alla stessa misura dichiarata
## ma più sottile, quindi le due misure si passano separate.
static func dress_window_text(node: Control, text: String, brush_size: int,
		body_size: int, weight := W_MEDIUM) -> void:
	if can_brush(text):
		node.add_theme_font_override("font", WINDOW_FILE)
		node.add_theme_font_size_override("font_size", brush_size)
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Niente ombra: i titoli dell'agenzia e del grossista ne hanno una nel
		# `.tscn` (serviva al vecchio font), e sotto al pennello sulla carta
		# faceva sembrare la scritta sbavata.
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	else:
		node.add_theme_font_override("font", body(weight))
		node.add_theme_font_size_override("font_size", body_size)
		node.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE

## Una Label di finestra: pennello se il testo è di sole parole, Nunito se no.
## È `label()` con in più la scelta del font.
static func window_label(text: String, brush_size: int, body_size: int,
		color: Color, weight := W_MEDIUM) -> Label:
	var node := label(text, body_size, color, weight)
	dress_window_text(node, text, brush_size, body_size, weight)
	return node

# --- Riquadri ---------------------------------------------------------------

static func _box(bg: Color, radius: int, border := 0, border_color := LINE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	if border > 0:
		box.set_border_width_all(border)
		box.border_color = border_color
	return box

## La finestra: carta con un bordo caldo e un'ombra larga e morbida sotto, che
## è quello che la stacca dal gioco senza doverci mettere un contorno spesso.
static func window_box() -> StyleBoxFlat:
	var box := _box(PAPER, 6, 1, Color(0.800, 0.816, 0.843))
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	return box

## La fascia in cima alla finestra. È bianca come i riquadri, quindi a
## staccarla dal corpo della finestra c'è solo il filetto sotto.
##
## Angoli tondi solo sopra: sotto continua il corpo della finestra, e
## arrotondarli lì lascerebbe due tacche di fondo che si vedono.
static func header_box() -> StyleBoxFlat:
	var box := _box(HEADER, 0)
	box.corner_radius_top_left = 5
	box.corner_radius_top_right = 5
	box.border_width_bottom = 1
	box.border_color = LINE
	box.content_margin_left = 12
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

## Il riquadro che raggruppa un pugno di righe.
static func card_box() -> StyleBoxFlat:
	var box := _box(CARD, 4, 1, LINE)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 5
	return box

## Il pannellino chiaro dell'HUD, che sta sopra al gioco e non dentro a una
## finestra: più trasparente, e con l'ombra, perché sotto ci può passare di
## tutto.
static func hud_box() -> StyleBoxFlat:
	var box := _box(Color(1.0, 1.0, 1.0, 0.92), 5, 1,
		Color(0.604, 0.631, 0.675, 0.80))
	box.shadow_color = Color(0, 0, 0, 0.28)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

# --- Bottoni ----------------------------------------------------------------

## L'azione principale: terracotta piena, testo di carta.
static func primary_boxes() -> Dictionary:
	var normal := _box(ACCENT, 4)
	var hover := _box(ACCENT.lightened(0.10), 4)
	var pressed := _box(ACCENT_DARK, 4)
	var disabled := _box(Color(0.886, 0.898, 0.914), 4)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 4
		box.content_margin_bottom = 5
	pressed.content_margin_top = 5
	pressed.content_margin_bottom = 4
	return {"normal": normal, "hover": hover, "pressed": pressed,
		"disabled": disabled}

## L'azione secondaria: solo contorno, si accende passandoci sopra.
static func ghost_boxes() -> Dictionary:
	var normal := _box(Color(1, 1, 1, 0), 4, 1, LINE)
	var hover := _box(ACCENT_SOFT, 4, 1, ACCENT)
	var pressed := _box(ACCENT_SOFT.darkened(0.06), 4, 1, ACCENT_DARK)
	var disabled := _box(Color(1, 1, 1, 0), 4, 1, Color(0.918, 0.925, 0.937))
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 4
		box.content_margin_bottom = 5
	return {"normal": normal, "hover": hover, "pressed": pressed,
		"disabled": disabled}

## La voce del menu laterale. Da spenta non ha sfondo: una colonna di riquadri
## tutti uguali non direbbe quale è quello aperto.
static func rail_boxes() -> Dictionary:
	var normal := _box(Color(1, 1, 1, 0), 4)
	var hover := _box(Color(1.0, 1.0, 1.0, 0.80), 4)
	var active := _box(CARD, 4, 1, LINE)
	# Contorno di terracotta attorno alla voce aperta, piu' spesso sul fianco.
	# Il riquadro di carta da solo dice "sono qui", ma resta dello stesso colore
	# di tutto il resto: e' il colore a far trovare il punto in cui si e' senza
	# doverlo cercare. Di lato e' piu' spesso perche' la colonna si legge da
	# sinistra. (`StyleBoxFlat` ha un colore di bordo solo, quindi il contorno
	# si accende tutto insieme: non si puo' colorare il solo fianco.)
	active.border_width_left = 3
	for box: StyleBoxFlat in [normal, hover, active]:
		box.content_margin_left = 9
		box.content_margin_right = 6
		box.content_margin_top = 4
		box.content_margin_bottom = 5
	active.border_color = ACCENT
	# Il bordo mangia spazio al testo: senza questo, la voce aperta si sposta di
	# tre pixel rispetto alle altre e la colonna balla a ogni click.
	active.content_margin_left = 6
	return {"normal": normal, "hover": hover, "active": active}

# --- Aiuti ------------------------------------------------------------------

## Una Label già vestita. Serve perché l'interfaccia di questo gioco si scrive
## in codice, e senza questa scorciatoia ogni Label sono quattro righe di
## `add_theme_*_override` copiate dalla Label di sopra.
static func label(text: String, size: int, color: Color,
		weight := W_REGULAR) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", body(weight))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## Veste la barra di scorrimento di un contenitore, che altrimenti resta quella
## grigio-scura di serie: su una finestra di carta e' l'unico pezzo che tradisce
## che sotto c'e' un'interfaccia di sistema.
static func dress_scrollbar(bar: ScrollBar) -> void:
	var fondo := _box(Color(0.925, 0.933, 0.945), 3)
	var cursore := _box(Color(0.741, 0.765, 0.800), 3)
	var acceso := _box(ACCENT, 3)
	bar.add_theme_stylebox_override("scroll", fondo)
	bar.add_theme_stylebox_override("grabber", cursore)
	bar.add_theme_stylebox_override("grabber_highlight", acceso)
	bar.add_theme_stylebox_override("grabber_pressed", acceso)

## Veste un bottone già esistente con uno dei set qui sopra.
static func dress_button(button: Button, boxes: Dictionary, color: Color,
		size := SIZE_VALUE, weight := W_MEDIUM) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		if boxes.has(state):
			button.add_theme_stylebox_override(state, boxes[state])
	button.add_theme_stylebox_override("focus", _box(Color(1, 1, 1, 0), 4))
	button.add_theme_font_override("font", body(weight))
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", INK_FAINT)
