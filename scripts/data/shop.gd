class_name Shop
extends RefCounted

## Il negozio online, aperto dal PC in cantina: l'attrezzatura che si compra una
## volta e resta.
##
## Come `Economy`, è solo costanti e funzioni statiche, e per lo stesso motivo:
## i prezzi e gli effetti degli oggetti sono manopole di bilanciamento, e vanno
## tenute in un posto solo invece che sparse fra i bottoni della UI.
##
## Quello che il giocatore possiede sta in `SaveData.upgrades`: "id" -> quanti
## ne ha. Un id che non c'è vale zero, quindi un salvataggio di prima del
## negozio si carica senza niente addosso e funziona.
##
## **Nessun riferimento a `Economy` qui dentro.** È `Economy` che chiede al
## negozio gli sconti sull'attenzione, e le funzioni che servono a `Grow` si
## fanno passare i valori base della varietà invece di andarseli a prendere:
## una dipendenza in un verso solo, senza il rischio di un ciclo fra i due.

# --- Catalogo --------------------------------------------------------------

## Chiavi di `ITEMS`:
## - `name`   CHIAVE del nome mostrato a scaffale (vedi `Strings`)
## - `price`  costo di UN pezzo
## - `max`    quanti se ne possono avere (0 = si usa `max_owned()`, che lo
##            calcola sulla partita)
## - `note`   CHIAVE della riga che spiega cosa fa, mostrata sotto al bottone
##
## Nome e spiegazione sono chiavi e non frasi: il testo vero, nelle tre lingue,
## sta in `Strings`. Qui resta il bilanciamento, che è quello per cui si apre
## questo file.
const ITEMS := {
	"toolkit": {
		"name": "SHOP_TOOLKIT",
		"price": 154,
		"max": 1,
		"note": "SHOP_TOOLKIT_NOTE",
	},
	"lamps": {
		"name": "SHOP_LAMPS",
		"price": 315,
		# Una per vaso, su TUTTI i vasi: cantina e garage.
		#
		# Prima il tetto erano i sei della cantina, per una ragione di disegno —
		# in cantina non c'e' finestra e le lampade sono il sole che manca,
		# mentre il garage la luce ce l'ha, quindi quello che offriva era il
		# POSTO (dodici vasi contro sei) e non la velocita'. Federico ha chiesto
		# di poterle comprare anche per il garage, e la differenza fra i due
		# posti resta comunque nel numero di vasi e nel prezzo del garage.
		#
		# Il tetto e' il numero massimo di vasi del gioco, e non un numero a
		# parte: una lampada per vaso, ovunque sia il vaso. La bolletta cresce
		# per ognuna (`Economy.power_bill()`), quindi riempire il garage di
		# lampade resta una spesa fissa che va coperta.
		"max": Economy.MAX_PLOTS,
		"note": "SHOP_LAMPS_NOTE",
	},
	"filter": {
		"name": "SHOP_FILTER",
		"price": 420,
		"max": 1,
		"note": "SHOP_FILTER_NOTE",
	},
	# Il furgone: senza, l'ingrosso non si può fare. Sta nel negozio come tutto
	# il resto che si compra una volta e resta, ma il bottone compare anche
	# nella scheda MARKET — è lì che ci si accorge di averne bisogno. Vedi
	# `Delivery`.
	"van": {
		"name": "SHOP_VAN",
		"price": 5000,
		"max": 1,
		"note": "SHOP_VAN_NOTE",
	},
}

## Ordine a scaffale. Un dizionario in GDScript conserva l'ordine di scrittura,
## ma appoggiarcisi vuol dire che riordinare il catalogo diventa una modifica
## rischiosa: meglio dirlo qui, esplicito.
const ORDER := ["toolkit", "lamps", "filter", "van"]

# --- Effetti (le manopole vere) --------------------------------------------

## Resa in piu' per ogni GROW TOOLKIT.
const TOOLKIT_YIELD := 0.15
## Tempo di crescita in meno per il vaso che ha la sua lampada accesa.
##
## **Non si somma.** Una lampada sta sopra a UN vaso (vedi
## `scenes/components/GrowLamp.tscn`, `lamp_set` == indice del vaso): il vaso 0
## e' piu' veloce se e' accesa la lampada 0, il vaso 3 se e' accesa la lampada
## 3, e comprarne sei non rende nessuno dei due l'8% x 6. E' rimasto un bug per
## un giro: quando il tetto delle lampade e' salito da tre a sei,
## `grow_mods()` continuava a moltiplicare per il TOTALE posseduto invece che
## per "questo vaso ha la sua lampada, si o no" — con sei lampade ogni pianta,
## in qualunque vaso, si vedeva tagliare il 48% invece dell'8% del solo vaso
## coperto.
const LAMP_SPEEDUP := 0.08
## Quanta attenzione toglie il filtro a carbone.
const FILTER_HEAT_CUT := 0.40

# --- Lettura del catalogo --------------------------------------------------

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

## Nome a scaffale, già tradotto.
static func item_name(id: String) -> String:
	return TranslationServer.translate(str(item(id).get("name", id.to_upper())))

static func price(id: String) -> int:
	return int(item(id).get("price", 0))

## Spiegazione sotto al bottone, già tradotta.
static func note(id: String) -> String:
	var key := str(item(id).get("note", ""))
	return "" if key.is_empty() else TranslationServer.translate(key)

static func owned(data: SaveData, id: String) -> int:
	if data == null:
		return 0
	return int(data.upgrades.get(id, 0))

## Quanti pezzi di `id` si possono avere.
static func max_owned(id: String) -> int:
	return maxi(1, int(item(id).get("max", 1)))

static func can_buy(data: SaveData, id: String) -> bool:
	if data == null or not ITEMS.has(id):
		return false
	return owned(data, id) < max_owned(id) and data.cash >= price(id)

## Compra un pezzo. False (e niente scalato) se il negozio è esaurito per quella
## voce o i soldi non bastano, così chi chiama può dirlo invece di far comparire
## roba dal nulla.
static func buy(data: SaveData, id: String) -> bool:
	if not can_buy(data, id):
		return false
	data.cash -= price(id)
	data.upgrades[id] = owned(data, id) + 1
	# Il furgone arriva col pieno fatto: far comprare un mezzo da cinquemila
	# dollari e poi dire "adesso però mettici la benzina" è un secondo bottone
	# per la stessa decisione.
	if id == "van":
		data.van_fuel = Delivery.TANK_RUNS
	return true

# --- Cosa cambia in partita ------------------------------------------------

## Quanto pesa sull'attenzione un grammo venduto in strada, in frazione del
## valore base. Lo chiede `Economy.street_heat()`.
static func heat_factor(data: SaveData) -> float:
	return maxf(0.0, 1.0 - FILTER_HEAT_CUT * float(owned(data, "filter")))

## Le modifiche alla coltivazione da appiccicare a una pianta che si sta
## seminando adesso: vedi `Grow.plant()`.
##
## Sono una **fotografia** presa al momento della semina, e restano attaccate a
## quella pianta. Serve a tenere la crescita una funzione pura dei timestamp del
## vaso: se l'effetto si leggesse dall'attrezzatura posseduta adesso, comprare
## le lampade a metà ciclo cambierebbe la durata di una pianta già a due terzi
## del percorso, e il conto alla rovescia mostrato salterebbe all'indietro.
##
## `plot_index` e' IL VASO che sta ricevendo il seme: la lampada e' un effetto
## per vaso (vedi `LAMP_SPEEDUP`), quindi senza sapere quale vaso e' non si puo'
## dire se questo seme ha una lampada sopra. Il ripiego (-1, il default) e' "non
## lo so": niente sconto, mai un bonus regalato a un vaso che magari non ha
## nessuna lampada. Chi conosce il vaso — `GrowPlot`, `Staff._growers_work()` —
## lo passa; chi non lo conosce ancora — un'anteprima nel PC prima di scegliere
## dove piantare — lo lascia com'e'.
static func grow_mods(data: SaveData, base_hours: float, base_grams: int, plot_index := -1) -> Dictionary:
	var has_lamp := plot_index >= 0 and owned(data, "lamps") > plot_index
	var hours := base_hours * (1.0 - LAMP_SPEEDUP) if has_lamp else base_hours
	var grams := int(roundf(float(base_grams) * (1.0 + TOOLKIT_YIELD * float(owned(data, "toolkit")))))
	return {"hours": maxf(1.0, hours), "grams": maxi(1, grams)}
