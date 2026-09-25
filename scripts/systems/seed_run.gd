class_name SeedRun
extends RefCounted

## Il viaggio dal grossista: si ordinano semi a cassette e il furgone va a
## prenderli.
##
## ## Perché esiste, accanto a Brian
##
## Brian porta due o tre semi per volta, quando riesce a staccare dalla clinica
## (`SeedDeal`). Va benissimo per sei vasi in cantina; con dodici vasi in garage
## e l'ingrosso da rifornire diventa il collo di bottiglia dell'intera attività
## — si vende più in fretta di quanto si riesca a piantare.
##
## Il grossista è la risposta: quantità grosse, prezzo per seme più basso, ma
## **non è immediato**. È la stessa forma dell'ingrosso della merce
## (`Delivery`): si manda il furgone e si aspetta.
##
## ## Perché si aspetta invece di avere i semi subito
##
## Senza l'attesa questo non sarebbe un ordine, sarebbe un negozio: si
## comprerebbero i semi nell'istante in cui servono e la scorta non sarebbe mai
## una decisione. Due ore di gioco bastano a obbligare a ordinare **prima** di
## restare a secco, che è tutto quello che serve perché la scorta di semi
## diventi una cosa a cui pensare.
##
## ## Come è fatto, e perché come `Delivery`
##
## Non c'è nessun timer: si scrive l'ora di rientro dentro al salvataggio e si
## guarda che ore sono adesso. È lo stesso schema di `Delivery` e `SeedDeal`, ed
## è quello che fa funzionare l'attesa anche a gioco chiuso — chi ordina e
## spegne ritrova i semi arrivati, invece di ritrovare un conto alla rovescia
## fermo dove l'aveva lasciato.

## Il flag che ricorda che il grossista si è fatto vivo. Lo accende
## `GameState._check_milestones()` quando entra in casa il furgone: senza mezzo
## non c'è nessuno che vada a ritirare.
const UNLOCK_FLAG := "seed_wholesale_unlocked"

## Ricorda che dal grossista ci si e' andati almeno una volta, e che il consiglio
## di prendere un autista e' gia' arrivato.
##
## Sono due flag e non uno perche' dicono due cose diverse: la prima e' una cosa
## che il giocatore ha fatto, la seconda una cosa che il gioco gli ha detto. Il
## consiglio parte al primo ordine, ma il posto in cui si mandano i messaggi e'
## `GameState._check_milestones()`, non qui — questo file non sa niente di
## telefoni e di traduzioni, e non deve cominciare adesso.
const BOUGHT_FLAG := "seed_wholesale_bought"
const DRIVER_HINT_FLAG := "seed_driver_hinted"

## Quanto ci mette il furgone, andata e ritorno. Due ore di gioco.
const TRIP_HOURS := 2.0

## I tagli ordinabili: quanti semi, e quanto si paga l'uno.
##
## Il prezzo al seme **scende** con la quantità, ed è il punto di tutto:
## comprare da Brian è comodo e caro, comprare qui è scomodo e conveniente. Lo
## sconto è sul listino di `Economy.seed_price()`, quindi cambiando quello
## questi restano coerenti da soli invece di diventare tre numeri da riallineare
## a mano.
const PACKS := [
	{"seeds": 10, "discount": 0.10},
	{"seeds": 25, "discount": 0.20},
	{"seeds": 60, "discount": 0.30},
]

# --- Sbloccato? -------------------------------------------------------------

static func is_unlocked(data: SaveData) -> bool:
	return data != null and bool(data.get_flag(UNLOCK_FLAG, false))

## Il grossista si apre quando in casa c'è un furgone: è il mezzo a rendere
## possibile il ritiro, e la stessa spesa che apre l'ingrosso della merce apre
## anche questo. Restituisce true **solo il giro in cui scatta**, così chi
## chiama può mandare il messaggio una volta sola.
static func check_unlock(data: SaveData) -> bool:
	if data == null or is_unlocked(data):
		return false
	if not Delivery.has_van(data):
		return false
	data.set_flag(UNLOCK_FLAG, true)
	return true

## Il consiglio dell'autista: vero **solo il giro in cui scatta**, come
## `check_unlock()`, cosi' chi chiama manda il messaggio una volta sola.
##
## Arriva al primo ordine e non al primo rientro: quello che stanca e' la strada
## fino in centro, e quella e' gia' stata fatta nel momento in cui si ordina.
static func check_driver_hint(data: SaveData) -> bool:
	if data == null or not bool(data.get_flag(BOUGHT_FLAG, false)):
		return false
	if bool(data.get_flag(DRIVER_HINT_FLAG, false)):
		return false
	data.set_flag(DRIVER_HINT_FLAG, true)
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

## Si può ordinare? No se il grossista non si è ancora fatto vivo, se il furgone
## è già in giro (per i semi, per la merce, o per il contatto fuori stato di
## Kevin: è sempre lo stesso mezzo), o se i soldi non bastano.
static func can_order(data: SaveData, pack: Dictionary,
		strain_id := Economy.DEFAULT_STRAIN) -> bool:
	if data == null or not is_unlocked(data) or is_running(data):
		return false
	if Delivery.is_running(data) or BusImport.is_running(data):
		return false
	return data.cash >= pack_price(pack, strain_id)

## Manda il furgone. Restituisce i semi ordinati, 0 se non si poteva.
##
## I soldi si pagano **adesso**, non al ritorno: è un ordine, e un ordine si
## paga quando lo si fa. Serve anche a evitare il giochino di ordinare a
## credito e spendere la cassa nel frattempo.
static func order(data: SaveData, pack: Dictionary, now: float,
		strain_id := Economy.DEFAULT_STRAIN) -> int:
	if not can_order(data, pack, strain_id):
		return 0
	var seeds := int(pack["seeds"])
	data.cash -= pack_price(pack, strain_id)
	# Il primo ordine e' un traguardo: da li' Brian consiglia l'autista.
	data.set_flag(BOUGHT_FLAG, true)
	data.seed_run = {
		"seeds": seeds,
		"strain": strain_id,
		"left_at": now,
		"back_at": now + TRIP_HOURS,
	}
	return seeds

## Fa rientrare il furgone se è ora, e scarica i semi. Restituisce quanti ne ha
## portati, 0 se non è ancora rientrato o se non era partito.
##
## Come `Delivery.tick()`: è l'unico pezzo che va spinto avanti, perché al
## ritorno succede qualcosa e qualcuno deve accorgersene.
static func tick(data: SaveData, now: float) -> int:
	if not is_running(data) or now < float(data.seed_run.get("back_at", now)):
		return 0
	var seeds := int(data.seed_run.get("seeds", 0))
	var strain := str(data.seed_run.get("strain", Economy.DEFAULT_STRAIN))
	data.seed_run = {}
	data.add_item(Economy.seed_item(strain), seeds)
	return seeds
