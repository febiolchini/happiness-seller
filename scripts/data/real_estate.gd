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
const LISTINGS := [
	{
		"id": "Garage",
		"titolo": "RE_GARAGE_NAME",
		"riga": "RE_GARAGE_DESC",
		"prezzo": 35000,
	},
]

static func all() -> Array:
	return LISTINGS

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
	}
	# Se la proprieta' e' anche un posto in cui si coltiva, da adesso ci si puo'
	# mandare gente: chi era in panchina ci va da solo. Vedi `GrowSites`.
	Staff.sync_sites(data)
	return true
