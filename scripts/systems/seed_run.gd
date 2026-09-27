class_name SeedRun
extends RefCounted

## Il grossista dei semi: si comprano a cassette, al banco, e arrivano subito.
##
## ## Perché esiste, accanto a Brian
##
## Brian porta una manciata di semi per volta, quando riesce a staccare dalla
## clinica (`SeedDeal`). Il grossista vende a cassette, e il prezzo al seme
## scende con la quantità.
##
## ## Al banco, non in viaggio
##
## Era un ordine: si mandava il furgone e si aspettavano due ore, e per non
## farsi la strada fino in centro si assumeva un autista. Adesso il gioco è un
## gestionale senza protagonista, e un edificio si clicca e si usa: i semi si
## pagano e sono in magazzino. Il furgone e l'autista restano per l'ingrosso
## della merce, che è l'unico viaggio vero.
##
## `seed_run` nel salvataggio resta solo per le partite salvate con un ordine
## in viaggio: `tick()` lo consegna all'ora prevista, e nessuno ne apre più.

## Quanto ci metteva il furgone, andata e ritorno: resta per leggere gli
## ordini dei salvataggi vecchi.
const TRIP_HOURS := 2.0

## I tagli ordinabili: quanti semi, e quanto si paga l'uno.
##
## Il prezzo al seme **scende** con la quantità, ed è il punto di tutto:
## comprare poco costa di più al seme, comprare tanto immobilizza la cassa. Lo
## sconto è sul listino di `Economy.seed_price()`, quindi cambiando quello
## questi restano coerenti da soli invece di diventare tre numeri da riallineare
## a mano.
const PACKS := [
	{"seeds": 10, "discount": 0.10},
	{"seeds": 25, "discount": 0.20},
	{"seeds": 60, "discount": 0.30},
]

# --- Sbloccato? -------------------------------------------------------------

## Il grossista è aperto sempre: è il fornitore dello zio, e fa parte
## dell'attività che si eredita. Resta una funzione perché chi mostra i semi
## non deve sapere se un giorno tornerà a dipendere da qualcosa.
static func is_unlocked(_data: SaveData) -> bool:
	return true

# --- Il viaggio -------------------------------------------------------------

static func is_running(data: SaveData) -> bool:
	return data != null and not data.seed_run.is_empty()

## Quanti semi sta andando a prendere, 0 se è fermo.
static func load_seeds(data: SaveData) -> int:
	return int(data.seed_run.get("seeds", 0)) if is_running(data) else 0

## Quanto manca al rientro, in ore di gioco. 0 se è fermo o se è già ora.
static func hours_left(data: SaveData, now: float) -> float:
	if not is_running(data):
		return 0.0
	return maxf(0.0, float(data.seed_run.get("back_at", now)) - now)

## Quanto costa un taglio, in totale.
static func pack_price(pack: Dictionary, strain_id := Economy.DEFAULT_STRAIN) -> int:
	var seeds := int(pack["seeds"])
	var unit := float(Economy.seed_price(strain_id)) * (1.0 - float(pack["discount"]))
	return maxi(1, int(roundf(unit * float(seeds))))

## Si può comprare? Basta avere i soldi.
static func can_order(data: SaveData, pack: Dictionary,
		strain_id := Economy.DEFAULT_STRAIN) -> bool:
	return data != null and data.cash >= pack_price(pack, strain_id)

## Compra un taglio: si paga e i semi vanno subito in magazzino. Restituisce i
## semi comprati, 0 se non si poteva.
##
## `now` non serve più a niente — i semi non viaggiano — ma resta nella firma:
## è la stessa di `BusImport.order()`, e chi chiama non deve sapere quale dei
## due banchi sta usando.
static func order(data: SaveData, pack: Dictionary, _now: float,
		strain_id := Economy.DEFAULT_STRAIN) -> int:
	if not can_order(data, pack, strain_id):
		return 0
	var seeds := int(pack["seeds"])
	data.cash -= pack_price(pack, strain_id)
	data.add_item(Economy.seed_item(strain_id), seeds)
	return seeds

## Consegna un ordine rimasto in viaggio in un salvataggio vecchio, quando è
## ora. Restituisce i semi arrivati, 0 se non c'era niente o non è ancora ora.
static func tick(data: SaveData, now: float) -> int:
	if not is_running(data) or now < float(data.seed_run.get("back_at", now)):
		return 0
	var seeds := int(data.seed_run.get("seeds", 0))
	var strain := str(data.seed_run.get("strain", Economy.DEFAULT_STRAIN))
	data.seed_run = {}
	data.add_item(Economy.seed_item(strain), seeds)
	return seeds
