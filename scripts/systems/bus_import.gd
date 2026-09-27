class_name BusImport
extends RefCounted

## Il contatto fuori stato che Kevin gira al giocatore: casse molto più
## grandi di quelle del grossista in centro, ma bisogna prima essersi fatti
## un nome.
##
## ## Perché esiste, accanto a `SeedRun`
##
## Il grossista di Kevin (`SeedRun`) arriva a sessanta semi a cassetta: va bene
## per riempire cantina e garage in un colpo o due, ma un'attività che gira sul
## personale a pieno organico li brucia in fretta. Il contatto fuori stato è il
## passo dopo: fino a duecentocinquanta semi, con lo sconto più alto del
## gioco, ma un traguardo in soldi prima di poterci parlare.
##
## ## Al banco della stazione, come da Kevin
##
## Era un ordine: il furgone andava a ritirare il pacco alla stazione e ci
## metteva sei ore, e un secondo autista serviva a non tenere fermo il mezzo di
## casa. Adesso, come dal grossista in centro, si clicca la stazione, si paga e
## i semi sono in magazzino. Il furgone serve solo all'ingrosso della merce.
##
## `bus_run` nel salvataggio resta solo per le partite salvate con un ritiro in
## corso: `tick()` lo consegna all'ora prevista, e nessuno ne apre più.

## Quanto cash serve per sbloccare il contatto. La prima volta che ci si
## arriva, Kevin manda il messaggio e lo sportello della stazione degli
## autobus si apre: vedi `GameState._check_milestones()`.
const UNLOCK_CASH := 100000
const UNLOCK_FLAG := "bus_station_unlocked"

## Quanto ci metteva il ritiro alla stazione: resta per leggere i viaggi dei
## salvataggi vecchi.
const TRIP_HOURS := 6.0

## I tagli: quanti semi, e quanto si paga l'uno.
##
## Continuano la scala di `SeedRun.PACKS` (10/25/60, sconto 10/20/30%): stessa
## idea, un gradino più su. Lo sconto è sempre sul listino di
## `Economy.seed_price()`.
const PACKS := [
	{"seeds": 100, "discount": 0.35},
	{"seeds": 150, "discount": 0.40},
	{"seeds": 250, "discount": 0.45},
]

# --- Sbloccato? -------------------------------------------------------------

static func is_unlocked(data: SaveData) -> bool:
	return data != null and bool(data.get_flag(UNLOCK_FLAG, false))

## Il contatto si apre arrivando a `UNLOCK_CASH`. Restituisce true **solo il
## giro in cui scatta**, così chi chiama manda il messaggio di Kevin una volta
## sola.
static func check_unlock(data: SaveData) -> bool:
	if data == null or is_unlocked(data):
		return false
	if data.cash < UNLOCK_CASH:
		return false
	data.set_flag(UNLOCK_FLAG, true)
	return true

# --- Comprare ---------------------------------------------------------------

## C'è ancora in viaggio un ritiro di un salvataggio vecchio?
static func is_running(data: SaveData) -> bool:
	return data != null and not data.bus_run.is_empty()

## Quanto costa un taglio, in totale.
static func pack_price(pack: Dictionary, strain_id := Economy.DEFAULT_STRAIN) -> int:
	var seeds := int(pack["seeds"])
	var unit := float(Economy.seed_price(strain_id)) * (1.0 - float(pack["discount"]))
	return maxi(1, int(roundf(unit * float(seeds))))

## Si può comprare? Serve il contatto e servono i soldi.
static func can_order(data: SaveData, pack: Dictionary,
		strain_id := Economy.DEFAULT_STRAIN) -> bool:
	if data == null or not is_unlocked(data):
		return false
	return data.cash >= pack_price(pack, strain_id)

## Compra un taglio: si paga e i semi vanno subito in magazzino. Restituisce i
## semi comprati, 0 se non si poteva. Stessa firma di `SeedRun.order()`.
static func order(data: SaveData, pack: Dictionary, _now: float,
		strain_id := Economy.DEFAULT_STRAIN) -> int:
	if not can_order(data, pack, strain_id):
		return 0
	var seeds := int(pack["seeds"])
	data.cash -= pack_price(pack, strain_id)
	data.add_item(Economy.seed_item(strain_id), seeds)
	return seeds

## Consegna un ritiro rimasto in viaggio in un salvataggio vecchio, quando è
## ora. Restituisce i semi arrivati, 0 se non c'era niente o non è ancora ora.
static func tick(data: SaveData, now: float) -> int:
	if not is_running(data) or now < float(data.bus_run.get("back_at", now)):
		return 0
	var seeds := int(data.bus_run.get("seeds", 0))
	var strain := str(data.bus_run.get("strain", Economy.DEFAULT_STRAIN))
	data.bus_run = {}
	data.add_item(Economy.seed_item(strain), seeds)
	return seeds
