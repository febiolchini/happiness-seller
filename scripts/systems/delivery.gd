class_name Delivery
extends RefCounted

## L'ingrosso: il furgone che porta la merce fuori città a chili.
##
## ## Perché non si può fare dall'inizio
##
## Prima l'ingrosso era un bottone sempre acceso nel PC: dieci grammi, cinquanta,
## tutto. Comodo, e per questo sbagliato — c'era un modo di vendere che non
## chiedeva niente a nessuno, e la strada (che paga il 40% in più, ma un cliente
## alla volta e alzando l'attenzione) diventava la scelta strana.
##
## Adesso l'ingrosso è una **fase** della partita e va aperta in due passi:
##
## 1. avere avuto in mano **un chilo** almeno una volta (`UNLOCK_GRAMS`): è il
##    punto in cui la merce non ci sta più nelle tasche;
## 2. comprare il **furgone** (`Shop`, voce `van`): un chilo non si porta in giro
##    a piedi.
##
## Il primo è un traguardo, il secondo una spesa. Il traguardo si raggiunge
## producendo, quindi l'ingrosso arriva quando serve e non prima.
##
## ## Il viaggio non è simulato
##
## Come tutto il resto (vedi `Grow`, `Staff`, `SeedDeal`): la consegna salva
## l'ora di gioco in cui il furgone torna, e lo stato è una funzione di che ore
## sono adesso. Niente timer, quindi il viaggio va avanti anche in cantina, in
## un'altra stanza, e col gioco chiuso.
##
## **La merce parte subito, i soldi arrivano al ritorno.** È la differenza fra
## un bottone e un viaggio: per qualche ora il magazzino è vuoto e il denaro non
## c'è ancora, ed è lì che l'ingrosso costa qualcosa oltre al margine più basso.

# --- Le regole -------------------------------------------------------------

## Quanta merce bisogna aver avuto in mano, una volta sola, perché l'ingrosso si
## apra. Mille grammi: un chilo.
const UNLOCK_GRAMS := 1000
## Flag della partita che ricorda il traguardo raggiunto.
const UNLOCK_FLAG := "wholesale_unlocked"

## Id della voce del negozio che è il furgone.
const VAN_ITEM := "van"

## I tagli che si possono spedire, in grammi. Un furgone non esce per cinquanta
## grammi: l'ingrosso è per i carichi, e i tagli sono quello che glielo dice.
const LOADS := [1000, 2000, 5000, 10000]

## Quanto dura un viaggio, in ore di gioco. Cresce col carico, ma non in
## proporzione: caricare il doppio non vuol dire guidare il doppio.
const TRIP_BASE_HOURS := 3.0
const TRIP_HOURS_PER_KG := 0.6

## Quante consegne fa un pieno, e quanto costa riempirlo.
##
## Il carburante è di proposito **una spesa piccola**: non è lì per pesare sul
## bilancio — un carico da un chilo vale cento volte un pieno — ma perché un
## furgone che non consuma niente non è un furgone. Quello che fa davvero è
## costringere a passare dal PC ogni tanto.
const TANK_RUNS := 10
const TANK_PRICE := 180

# --- Lo sblocco ------------------------------------------------------------

## Il traguardo del chilo è stato raggiunto?
static func is_unlocked(data: SaveData) -> bool:
	return data != null and bool(data.get_flag(UNLOCK_FLAG, false))

## Segna il traguardo se la scorta ci è appena arrivata. Restituisce true la
## volta in cui scatta, così chi chiama può mostrare il messaggio una volta sola.
##
## Guarda la scorta di **adesso** e non un totale accumulato: il traguardo è
## "ti sei trovato un chilo in mano", non "ne hai prodotto un chilo in tutto".
static func check_unlock(data: SaveData) -> bool:
	if data == null or is_unlocked(data):
		return false
	if Economy.stock(data) < UNLOCK_GRAMS:
		return false
	data.set_flag(UNLOCK_FLAG, true)
	# Il canale si apre con un chilo gia' in magazzino, e da questo istante la
	# quota scelta al PC vuol dire qualcosa: senza ritarare adesso, i dealer si
	# piazzerebbero quel chilo prima che il giocatore possa metterne da parte un
	# grammo. Vedi `Staff.retarget_reserve()`.
	Staff.retarget_reserve(data)
	return true

## Se il giocatore ha il furgone.
static func has_van(data: SaveData) -> bool:
	return Shop.owned(data, VAN_ITEM) > 0

## Se si può spedire: serve il traguardo, il furgone, benzina nel serbatoio e
## nessun viaggio già in corso.
static func can_dispatch(data: SaveData) -> bool:
	return (
		is_unlocked(data) and has_van(data)
		and fuel(data) > 0 and not is_running(data))

# --- Il carburante ---------------------------------------------------------

## Quante consegne restano nel serbatoio.
static func fuel(data: SaveData) -> int:
	return 0 if data == null else clampi(data.van_fuel, 0, TANK_RUNS)

static func needs_fuel(data: SaveData) -> bool:
	return has_van(data) and fuel(data) <= 0

## Fa il pieno. False se non serve o se i soldi non bastano.
static func refuel(data: SaveData) -> bool:
	if data == null or not has_van(data) or fuel(data) >= TANK_RUNS:
		return false
	if data.cash < TANK_PRICE:
		return false
	data.cash -= TANK_PRICE
	data.van_fuel = TANK_RUNS
	return true

# --- Il viaggio ------------------------------------------------------------

static func is_running(data: SaveData) -> bool:
	return data != null and not data.van_run.is_empty()

## Grammi che il furgone sta portando adesso, 0 se è fermo.
static func load_grams(data: SaveData) -> int:
	return 0 if not is_running(data) else int(data.van_run.get("grams", 0))

## Quanto incasserà al ritorno.
static func load_value(data: SaveData) -> int:
	return 0 if not is_running(data) else int(data.van_run.get("value", 0))

## Ore di gioco che mancano al ritorno, 0 se è già rientrato o fermo.
static func hours_left(data: SaveData, now: float) -> float:
	if not is_running(data):
		return 0.0
	return maxf(0.0, float(data.van_run.get("back_at", now)) - now)

## Quanto dura il viaggio per questo carico.
static func trip_hours(grams: int) -> float:
	return TRIP_BASE_HOURS + TRIP_HOURS_PER_KG * (float(grams) / 1000.0)

## Manda il furgone. Restituisce i grammi partiti, 0 se non si poteva.
##
## Il prezzo si fissa **alla partenza** e non al ritorno: è l'accordo preso con
## chi compra, e un prezzo che cambia mentre il furgone è in viaggio sarebbe una
## scommessa che il giocatore non ha fatto — lo stesso motivo per cui il prezzo
## del giorno si salva invece di ricalcolarlo.
static func dispatch(data: SaveData, grams: int, now: float) -> int:
	if not can_dispatch(data) or grams <= 0 or Economy.stock(data) < grams:
		return 0
	data.add_item(Economy.PRODUCT, -grams)
	# Il carico e' esattamente quello per cui la merce era stata messa da parte:
	# partendo, la riserva si libera. Vedi `Staff.reserved()`.
	Staff.release_reserved(data, grams)
	data.van_fuel = fuel(data) - 1
	data.van_run = {
		"grams": grams,
		"value": grams * Economy.wholesale_price(data),
		"left_at": now,
		"back_at": now + trip_hours(grams),
	}
	return grams

## Fa tornare il furgone se è ora. Restituisce l'incasso, 0 se non è ancora
## rientrato o se non era partito.
##
## Come `SeedDeal.tick()`: è l'unico pezzo che va "spinto avanti", perché al
## ritorno succede qualcosa — i soldi entrano — e qualcuno deve accorgersene.
static func tick(data: SaveData, now: float) -> int:
	if not is_running(data) or now < float(data.van_run.get("back_at", now)):
		return 0
	var revenue := load_value(data)
	var grams := load_grams(data)
	data.van_run = {}
	data.cash += revenue
	data.bump_stat(Economy.STAT_GRAMS_SOLD, grams)
	data.bump_stat(Economy.STAT_EARNED, revenue)
	return revenue

## I tagli spedibili con la scorta di adesso, dal più piccolo al più grande.
## Vuoto quando non ce n'è abbastanza nemmeno per il taglio minimo.
static func loads_for(data: SaveData) -> Array:
	var out: Array = []
	var have := Economy.stock(data)
	for amount in LOADS:
		if have >= int(amount):
			out.append(int(amount))
	return out
