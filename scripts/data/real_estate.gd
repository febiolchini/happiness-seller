class_name RealEstate
extends RefCounted

## Quello che l'agenzia immobiliare ha in vendita.
##
## È una tabella di DATI, come `CityMap`: l'agenzia non decide niente, mostra
## questo elenco e chiede a `GameState` se ci sono i soldi.
##
## ## Perché l'id è quello dell'edificio
##
## `id` non è il nome dell'annuncio, è l'**id della voce in `CityMap.BUILDINGS`**:
## è lo stesso con cui `SaveData.properties` segna quello che si possiede
## (`owns()`), e lo stesso con cui i nodi si chiamano dentro `City.tscn`. Tenerne
## uno solo vuol dire che comprare un annuncio e possedere un edificio sono la
## stessa cosa scritta una volta: al garage sono bastati un `interior` e un
## `"owned": true` nella pianta perche' chi l'ha comprato se lo trovi aperto, e
## qui non e' cambiato niente. Vale per ogni proprieta' che verra' dopo.
##
## Un annuncio con un id che nella pianta non esiste è un errore di dati e non
## una proprietà "astratta": si comprerebbe qualcosa che in città non si vede.
## `game_tests.gd` lo controlla.
##
## ## Come si aggiunge una proprietà
##
## Una voce qui e una voce in `CityMap.BUILDINGS` con lo stesso `id`. Il prezzo
## sta qui e non nella pianta perché la pianta dice **dov'è** un edificio, non
## quanto costa: sono due cose che cambiano per motivi diversi, e il giorno che
## i prezzi si muovono con la partita è questa tabella a diventare dinamica.

## `id` → id dell'edificio in `CityMap.BUILDINGS`
## `titolo`/`riga` → chiavi di traduzione (vedi `strings.gd`)
## `prezzo` → dollari, interi
## `corrente` → quanto aggiunge alla bolletta mensile, a locale vuoto
##
## `agenzia` → quale sportello lo vende: "flats" (quella accanto a casa) o
## "downtown" (PRIME REALTY, a DOWNTOWN). Senza, e' "flats". Ogni agenzia
## mostra solo i suoi annunci: vedi `for_agency()` e `real_estate_window.gd`.
## `edificio` → per le proprieta' che sono un PEZZO di un edificio (un
## appartamento in un grattacielo): l'id dell'edificio in `CityMap.BUILDINGS`.
## In quel caso `id` e' l'appartamento, e l'edificio e' quello che si vede in
## citta'. Senza, l'id e' l'edificio stesso, come per il garage.
##
## `corrente` sta qui insieme al prezzo perche' e' l'altra meta' dello stesso
## discorso: un posto non si paga solo il giorno che si compra, e un capannone
## grande costa piu' di un box anche a luci spente. Sono i muri a consumare —
## saracinesca, ventilazione, il contatore che gira — mentre quello che ci si
## mette dentro lo paga per conto suo: ogni lampada rossa ha il suo costo in
## `Economy.POWER_PER_LAMP`, e la bolletta e' la somma delle due cose.
const LISTINGS := [
	{
		"id": "Garage",
		"titolo": "RE_GARAGE_NAME",
		"riga": "RE_GARAGE_DESC",
		"prezzo": 35000,
		"corrente": 120,
	},
	# I due appartamenti nella MERIDIAN TOWER, il grattacielo piu' alto: li
	# vende l'agenzia di DOWNTOWN. Per ora si comprano e basta — dentro non si
	# entra ancora, quindi non hanno `interior` e la torre resta com'e'.
	{
		"id": "MeridianApt5",
		"edificio": "MeridianTower",
		"agenzia": "downtown",
		"titolo": "RE_MERIDIAN_5_NAME",
		"riga": "RE_MERIDIAN_5_DESC",
		"prezzo": 300000,
		"corrente": 60,
	},
	{
		"id": "MeridianApt21",
		"edificio": "MeridianTower",
		"agenzia": "downtown",
		"titolo": "RE_MERIDIAN_21_NAME",
		"riga": "RE_MERIDIAN_21_DESC",
		"prezzo": 1000000,
		"corrente": 90,
	},
]

static func all() -> Array:
	return LISTINGS

## Gli annunci di un'agenzia sola ("flats" o "downtown").
static func for_agency(agency: String) -> Array:
	var out: Array = []
	for listing in LISTINGS:
		if str(listing.get("agenzia", "flats")) == agency:
			out.append(listing)
	return out

## L'id dell'edificio in citta' in cui sta la proprieta'.
static func building_of(listing: Dictionary) -> String:
	return str(listing.get("edificio", listing["id"]))

## Quanto aggiunge alla bolletta mensile la proprieta' con quell'id.
##
## Zero per un id sconosciuto, e zero per la casa di partenza: quella non e' un
## annuncio, e la sua corrente e' gia' dentro a `Economy.POWER_BASE`.
static func power_draw(id: String) -> int:
	return int(find(id).get("corrente", 0))

## Il prezzo di listino, su cui si calcola anche la tassa annuale. Zero se
## l'annuncio non c'e' piu': una tabella che cambia non deve far pagare tasse su
## un valore inventato.
static func price(id: String) -> int:
	return int(find(id).get("prezzo", 0))

## L'annuncio con quell'id, o un dizionario vuoto.
static func find(id: String) -> Dictionary:
	for listing in LISTINGS:
		if str(listing["id"]) == id:
			return listing
	return {}

## Comprare: toglie i soldi e segna la proprietà.
##
## Torna `false` senza fare niente se l'annuncio non esiste, se è già di
## proprietà o se i soldi non bastano. Il controllo sui soldi lo fa `spend()`,
## che è l'unico posto dove il contante cala: farlo anche qui vorrebbe dire due
## verità sullo stesso portafoglio.
static func buy(id: String) -> bool:
	var listing := find(id)
	if listing.is_empty():
		return false
	var data := GameState.current
	if data == null or data.owns(id):
		return false
	if not GameState.spend(int(listing["prezzo"])):
		return false
	data.properties[id] = {
		"livello": 1,
		"acquisito_il": data.day,
		# Il conto per la tassa sulla proprieta' parte dal rogito: vedi
		# `Economy.charge_property_tax()`. Se ne tiene uno per proprieta' e non
		# uno solo per la partita perche' ognuna si compra il suo giorno, e la
		# scadenza e' il suo anniversario.
		"tassato_il": data.day,
	}
	# Se la proprieta' e' anche un posto in cui si coltiva, da adesso ci si puo'
	# mandare gente: chi era in panchina ci va da solo. Vedi `GrowSites`.
	Staff.sync_sites(data)
	return true
