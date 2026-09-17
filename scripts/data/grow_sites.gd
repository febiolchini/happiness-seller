class_name GrowSites
extends RefCounted

## I posti in cui si coltiva: la cantina di casa e, comprandolo, il garage.
##
## È una tabella di DATI come `CityMap` e `RealEstate`, e per lo stesso motivo:
## dove si coltiva è contenuto, non logica. Aggiungere una terza serra vuol dire
## aggiungere una riga qui.
##
## ## I vasi restano un array solo
##
## `SaveData.plots` è sempre un elenco piatto, e un posto è una **fetta** di quel
## elenco: la cantina sono i vasi 0-5, il garage i 6-17. Non c'è un array di
## vasi per stanza, e non deve esserci — i vasi sono già salvati, già cresciuti e
## già contati da `Grow` e da `Staff` senza sapere dove stanno, e spezzarli in
## due elenchi vorrebbe dire rifare tutto quel giro per guadagnarci niente.
##
## Ne segue anche l'ordine in cui si comprano: `SaveData.plot_slots` è un
## contatore unico, quindi si riempie prima la cantina e poi il garage. È il
## verso giusto — il garage costa trentacinquemila dollari, e chi lo compra ha
## già la cantina piena.
##
## ## Un posto chiuso non esiste
##
## `id` è l'id dell'edificio in `CityMap.BUILDINGS`, cioè la stessa chiave con
## cui l'agenzia vende e con cui la partita segna il posseduto: un posto è
## aperto quando quell'edificio è tuo. La cantina ha `id` vuoto perché la casa
## non si compra, te l'ha lasciata il vecchio.
##
## Finché il garage non è tuo, i suoi dodici vasi non si possono nemmeno
## comprare (`Economy.next_plot_cost()`), non compaiono al PC e non ci si può
## mandare nessuno a lavorare.

## - `key`    come si chiama il posto nel salvataggio (`SaveData.grower_sites`)
## - `id`     id dell'edificio da possedere, "" se è roba tua da sempre
## - `name`   CHIAVE del nome mostrato (il testo vero sta in `Strings`)
## - `from`   indice del primo vaso in `SaveData.plots`
## - `count`  quanti vasi ci stanno
const SITES := [
	{"key": "basement", "id": "", "name": "SITE_BASEMENT", "from": 0, "count": 6},
	{"key": "garage", "id": "Garage", "name": "SITE_GARAGE", "from": 6, "count": 12},
]

## Vasi che un coltivatore riesce a seguire. Sta qui e non in `Staff` perché è
## una misura del posto — quanti vasi copre una persona — e perché è il numero
## che decide quanti coltivatori ha senso mandare in ciascuna proprietà.
const POTS_PER_GROWER := 6

static func all() -> Array:
	return SITES

## Il posto con quella chiave, `{}` se non esiste.
static func find(key: String) -> Dictionary:
	for site: Dictionary in SITES:
		if str(site["key"]) == key:
			return site
	return {}

## Il posto a cui appartiene un vaso, `{}` se l'indice è fuori da tutti.
static func site_of(index: int) -> Dictionary:
	for site: Dictionary in SITES:
		var from := int(site["from"])
		if index >= from and index < from + int(site["count"]):
			return site
	return {}

## Il posto è tuo?
static func is_open(data: SaveData, site: Dictionary) -> bool:
	if data == null or site.is_empty():
		return false
	var id := str(site.get("id", ""))
	return id.is_empty() or data.owns(id)

## I posti aperti, nell'ordine della tabella.
static func open_sites(data: SaveData) -> Array:
	var found: Array = []
	for site: Dictionary in SITES:
		if is_open(data, site):
			found.append(site)
	return found

## Quanti vasi di questo posto sono già stati aperti.
##
## `plot_slots` è un contatore unico su tutto l'elenco, quindi qui si taglia la
## fetta che tocca a questo posto: con dieci vasi comprati la cantina ne ha sei
## (è piena) e il garage quattro.
static func slots_in(data: SaveData, site: Dictionary) -> int:
	if data == null or site.is_empty():
		return 0
	var from := int(site["from"])
	return clampi(data.plot_slots - from, 0, int(site["count"]))

## Quanti coltivatori ha senso tenere qui: uno ogni `POTS_PER_GROWER` vasi
## aperti. Ricavato e non scritto a mano, così comprando vasi il tetto sale da
## solo e non resta indietro.
static func capacity(data: SaveData, site: Dictionary) -> int:
	return ceili(float(slots_in(data, site)) / float(POTS_PER_GROWER))

## Quanti vasi si possono aprire in tutto **con le proprietà che si hanno
## adesso**: i sei della cantina, più i dodici del garage se è tuo.
##
## Non è `Economy.MAX_PLOTS`, che sono tutti e diciotto: quello è il tetto del
## gioco, questo è il tetto di questa partita. Al PC va mostrato il secondo, o il
## negozio promette dodici vasi che non si possono comprare.
static func reachable_slots(data: SaveData) -> int:
	var total := 0
	for site: Dictionary in open_sites(data):
		total += int(site["count"])
	return total

## C'è un posto chiuso che, comprandolo, darebbe altri vasi?
##
## È la differenza fra "non ci sta altro" e "non ci sta altro QUI": la prima è
## la fine della strada, la seconda è un invito ad andare in agenzia.
static func has_locked_room(data: SaveData) -> bool:
	for site: Dictionary in SITES:
		if not is_open(data, site):
			return true
	return false

## Nome del posto, già tradotto.
static func site_name(site: Dictionary) -> String:
	return TranslationServer.translate(str(site.get("name", "")))
