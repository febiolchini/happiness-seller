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
		"price": 220,
		"max": 1,
		"note": "SHOP_TOOLKIT_NOTE",
	},
	"lamps": {
		"name": "SHOP_LAMPS",
		"price": 450,
		"max": 3,
		"note": "SHOP_LAMPS_NOTE",
	},
	"auto_water": {
		"name": "SHOP_AUTO_WATER",
		"price": 700,
		"max": 0,
		"note": "SHOP_AUTO_WATER_NOTE",
	},
	"filter": {
		"name": "SHOP_FILTER",
		"price": 600,
		"max": 1,
		"note": "SHOP_FILTER_NOTE",
	},
}

## Ordine a scaffale. Un dizionario in GDScript conserva l'ordine di scrittura,
## ma appoggiarcisi vuol dire che riordinare il catalogo diventa una modifica
## rischiosa: meglio dirlo qui, esplicito.
const ORDER := ["toolkit", "lamps", "auto_water", "filter"]

# --- Effetti (le manopole vere) --------------------------------------------

## Resa in piu' per ogni GROW TOOLKIT.
const TOOLKIT_YIELD := 0.15
## Tempo di crescita in meno per ogni set di lampade.
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

## Quanti pezzi di `id` si possono avere in questa partita.
##
## I vasi autoinnaffianti non hanno un tetto fisso: si equipaggiano i vasi che
## ci sono, quindi il tetto cresce comprando vasi nuovi. Gli altri oggetti hanno
## il loro `max` scritto nel catalogo.
static func max_owned(data: SaveData, id: String) -> int:
	var cap := int(item(id).get("max", 1))
	if cap > 0:
		return cap
	if id == "auto_water" and data != null:
		return data.plot_slots
	return 1

static func can_buy(data: SaveData, id: String) -> bool:
	if data == null or not ITEMS.has(id):
		return false
	return owned(data, id) < max_owned(data, id) and data.cash >= price(id)

## Compra un pezzo. False (e niente scalato) se il negozio è esaurito per quella
## voce o i soldi non bastano, così chi chiama può dirlo invece di far comparire
## roba dal nulla.
static func buy(data: SaveData, id: String) -> bool:
	if not can_buy(data, id):
		return false
	data.cash -= price(id)
	data.upgrades[id] = owned(data, id) + 1
	return true

# --- Cosa cambia in partita ------------------------------------------------

## Quanti vasi, partendo dal primo, si annaffiano da soli.
static func auto_pots(data: SaveData) -> int:
	return mini(owned(data, "auto_water"), data.plot_slots if data != null else 0)

## Il vaso `index` si annaffia da solo?
static func is_auto_pot(data: SaveData, index: int) -> bool:
	return index >= 0 and index < auto_pots(data)

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
static func grow_mods(data: SaveData, base_hours: float, base_grams: int) -> Dictionary:
	var hours := base_hours * maxf(0.2, 1.0 - LAMP_SPEEDUP * float(owned(data, "lamps")))
	var grams := int(roundf(float(base_grams) * (1.0 + TOOLKIT_YIELD * float(owned(data, "toolkit")))))
	return {"hours": maxf(1.0, hours), "grams": maxi(1, grams)}
