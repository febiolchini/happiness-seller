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
## personale a pieno organico li brucia più in fretta di quanto convenga
## rifare la strada fino in centro ogni volta. Il contatto fuori stato è il
## passo dopo: fino a duecentocinquanta semi, con lo sconto più alto del
## gioco, ma un traguardo in soldi prima di poterci parlare.
##
## ## Come è fatto, e perché come `SeedRun`
##
## Stessa forma, stesso schema: niente timer, si scrive l'ora di rientro e lo
## stato è una funzione di che ore sono adesso. Il furgone è lo stesso di
## `Delivery` e `SeedRun` — uno solo, un viaggio alla volta — e le tre classi
## si escludono a vicenda: vedi `can_order()`.

## Quanto cash serve per sbloccare il contatto. La prima volta che ci si
## arriva, Kevin manda il messaggio e la stazione degli autobus compare in
## COMMERCIAL DISTRICT: vedi `GameState._check_milestones()`.
const UNLOCK_CASH := 100000
const UNLOCK_FLAG := "bus_station_unlocked"

## Il viaggio è più lungo di quello dal grossista in centro (`SeedRun.TRIP_HOURS`,
## due ore): il pacco arriva fuori stato in autobus e il furgone lo va a
## prendere alla stazione. Sei ore di gioco, circa un minuto e mezzo reale.
const TRIP_HOURS := 6.0

## I tagli ordinabili: quanti semi, e quanto si paga l'uno.
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

# --- Il viaggio -------------------------------------------------------------

static func is_running(data: SaveData) -> bool:
	return data != null and not data.bus_run.is_empty()

## Col secondo autista (`Staff.max_drivers()`, che si apre con la stazione) il
## ritiro alla stazione lo fa lui, e il furgone di casa resta libero per
## l'ingrosso e per il grossista in centro. Con uno solo e' tutto come prima:
## un furgone, un viaggio alla volta.
static func has_own_driver(data: SaveData) -> bool:
	return Staff.count(data, "driver") >= 2

## Il viaggio alla stazione sta tenendo fermo il furgone di casa? E' la domanda
## che si fanno gli altri viaggi prima di partire.
static func holds_van(data: SaveData) -> bool:
	return is_running(data) and not has_own_driver(data)

## Quanti semi sta andando a prendere, 0 se è fermo.
static func load_seeds(data: SaveData) -> int:
	return int(data.bus_run.get("seeds", 0)) if is_running(data) else 0

## Quanto manca al rientro, in ore di gioco. 0 se è fermo o se è già ora.
static func hours_left(data: SaveData, now: float) -> float:
	if not is_running(data):
		return 0.0
	return maxf(0.0, float(data.bus_run.get("back_at", now)) - now)

## Quanto costa un taglio, in totale.
static func pack_price(pack: Dictionary, strain_id := Economy.DEFAULT_STRAIN) -> int:
	var seeds := int(pack["seeds"])
	var unit := float(Economy.seed_price(strain_id)) * (1.0 - float(pack["discount"]))
	return maxi(1, int(roundf(unit * float(seeds))))

## Si può ordinare? No se il contatto non si è ancora sbloccato, se questo
## viaggio è già in corso, se il furgone è in giro per la merce o per il
## grossista di Kevin e non c'è un secondo autista a cui darlo, o se i soldi non
## bastano.
static func can_order(data: SaveData, pack: Dictionary,
		strain_id := Economy.DEFAULT_STRAIN) -> bool:
	if data == null or not is_unlocked(data) or is_running(data):
		return false
	if not has_own_driver(data) and (Delivery.is_running(data) or SeedRun.is_running(data)):
		return false
	return data.cash >= pack_price(pack, strain_id)

## Manda il furgone. Restituisce i semi ordinati, 0 se non si poteva.
##
## I soldi si pagano subito, come da Kevin: è un ordine, e un ordine si paga
## quando lo si fa.
static func order(data: SaveData, pack: Dictionary, now: float,
		strain_id := Economy.DEFAULT_STRAIN) -> int:
	if not can_order(data, pack, strain_id):
		return 0
	var seeds := int(pack["seeds"])
	data.cash -= pack_price(pack, strain_id)
	data.bus_run = {
		"seeds": seeds,
		"strain": strain_id,
		"left_at": now,
		"back_at": now + TRIP_HOURS,
	}
	return seeds

## Fa rientrare il furgone se è ora, e scarica i semi. Restituisce quanti ne ha
## portati, 0 se non è ancora rientrato o se non era partito.
static func tick(data: SaveData, now: float) -> int:
	if not is_running(data) or now < float(data.bus_run.get("back_at", now)):
		return 0
	var seeds := int(data.bus_run.get("seeds", 0))
	var strain := str(data.bus_run.get("strain", Economy.DEFAULT_STRAIN))
	data.bus_run = {}
	data.add_item(Economy.seed_item(strain), seeds)
	return seeds
