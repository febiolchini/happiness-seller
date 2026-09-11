class_name Economy
extends RefCounted

## Tutte le manopole del gestionale in un posto solo: prezzi, tempi, costi di
## ampliamento, quanto scalda le acque una vendita in strada.
##
## Stanno qui perché tarare un tycoon vuol dire cambiare venti volte gli stessi
## dieci numeri: se sono sparsi dentro alle scene non si ritrovano più. Le scene
## non scrivono mai un prezzo a mano, lo chiedono a questa classe.
##
## Solo costanti e funzioni statiche: non va istanziata. Le funzioni che muovono
## soldi o merce prendono la `SaveData` e la modificano, così la contabilità sta
## in un posto solo invece che sparsa fra i bottoni della UI.

# --- Merce -----------------------------------------------------------------

## Chiave dell'erba pronta dentro a `SaveData.inventory`. L'unità è il GRAMMO.
const PRODUCT := "weed"
## I semi stanno nello stesso inventario, con questo prefisso: "seed_regular".
const SEED_PREFIX := "seed_"

## Varietà coltivabili. Per ora ce n'è una sola, ma la tabella esiste già:
## aggiungerne una vuol dire una riga qui e nient'altro.
##
## - `seed_price`  quanto la fa pagare l'amico della clinica
## - `grow_hours`  ore DI GIOCO dal seme al raccolto
## - `grams`       resa di una pianta curata bene
## - `base_price`  prezzo di riferimento al grammo, prima delle oscillazioni
const STRAINS := {
	"regular": {
		"name": "REGULAR",
		"seed_price": 40,
		"grow_hours": 29.0,
		"grams": 20,
		"base_price": 10,
	},
}

const DEFAULT_STRAIN := "regular"

# --- Come si parte ---------------------------------------------------------

## Soldi che chiudono il prologo. La prima volta che si arriva qui il cugino
## si fa vivo e si sblocca il personale: vedi `GameState._check_prologue()`.
const PROLOGUE_CASH := 1000

const STARTING_CASH := 120
const STARTING_SEEDS := 2
## Vasi disponibili all'inizio: "poche piante", il resto si compra.
const START_PLOTS := 3
## Quanti vasi ci stanno nel seminterrato. Per andare oltre servirà un'altra
## proprietà, ed è il primo gancio per la progressione del gestionale.
const MAX_PLOTS := 6
## Costo per sbloccare il vaso di indice N (0-based). I primi tre sono già lì.
const PLOT_COSTS := [0, 0, 0, 210, 560, 1260]

# --- Mercato ---------------------------------------------------------------

## Oscillazione massima del prezzo del giorno, in frazione del prezzo base.
const PRICE_SWING := 0.25
## Vendere in strada rende di più che piazzare la merce all'ingrosso dal PC,
## ma si fa un cliente alla volta e si dà da pensare al quartiere.
const RETAIL_MULTIPLIER := 1.4
## Grammi che un cliente di strada compra in un giorno: minimo e massimo.
const STREET_DEMAND := Vector2i(8, 22)

# --- Attenzione della polizia ----------------------------------------------

const HEAT_MAX := 100.0
## Quanto si raffredda ogni notte: senza questo il primo giorno di vendite
## resterebbe addosso per sempre.
const HEAT_DECAY_PER_DAY := 9.0
const HEAT_PER_STREET_GRAM := 0.12

# --- Statistiche (chiavi di SaveData.stats) --------------------------------

const STAT_GRAMS_HARVESTED := "grams_harvested"
const STAT_GRAMS_SOLD := "grams_sold"
const STAT_EARNED := "earned"
const STAT_PLANTS_GROWN := "plants_grown"

# --- Lettura della tabella varietà -----------------------------------------

static func strain(strain_id: String) -> Dictionary:
	return STRAINS.get(strain_id, STRAINS[DEFAULT_STRAIN])

static func strain_name(strain_id: String) -> String:
	return str(strain(strain_id)["name"])

static func seed_item(strain_id: String) -> String:
	return SEED_PREFIX + strain_id

static func seed_price(strain_id: String) -> int:
	return int(strain(strain_id)["seed_price"])

static func base_price(strain_id: String) -> int:
	return int(strain(strain_id)["base_price"])

# --- Ciclo di vita della partita -------------------------------------------

## Mette in una partita appena creata i valori di partenza del gestionale.
##
## Sta qui e non in `SaveData` di proposito: `SaveData` contiene solo dati e non
## deve sapere niente di bilanciamento, altrimenti ogni ritocco al prezzo dei
## semi finirebbe per toccare il formato dei salvataggi.
static func setup_new_game(data: SaveData) -> void:
	data.cash = STARTING_CASH
	data.plot_slots = START_PLOTS
	data.ensure_plots()
	data.market_price = base_price(DEFAULT_STRAIN)
	data.add_item(seed_item(DEFAULT_STRAIN), STARTING_SEEDS)

## Quello che succede a mezzanotte: il prezzo del giorno nuovo e il
## raffreddamento dell'attenzione addosso al giocatore.
static func roll_new_day(data: SaveData) -> void:
	var base := float(base_price(DEFAULT_STRAIN))
	data.market_price = int(roundf(base * randf_range(1.0 - PRICE_SWING, 1.0 + PRICE_SWING)))
	data.heat = maxf(0.0, data.heat - HEAT_DECAY_PER_DAY)

# --- Prezzi correnti -------------------------------------------------------

## Prezzo all'ingrosso: quello che si prende piazzando la merce dal PC, senza
## uscire di casa e senza farsi vedere da nessuno.
static func wholesale_price(data: SaveData) -> int:
	return maxi(1, data.market_price)

## Prezzo al dettaglio: si vende a mano, in strada, e si prende di più.
static func retail_price(data: SaveData) -> int:
	return maxi(1, int(roundf(float(wholesale_price(data)) * RETAIL_MULTIPLIER)))

# --- Semi ------------------------------------------------------------------

static func seeds_owned(data: SaveData, strain_id := DEFAULT_STRAIN) -> int:
	return data.get_item(seed_item(strain_id))

static func buy_seeds(data: SaveData, count: int, strain_id := DEFAULT_STRAIN) -> bool:
	var cost := seed_price(strain_id) * count
	if count <= 0 or data.cash < cost:
		return false
	data.cash -= cost
	data.add_item(seed_item(strain_id), count)
	return true

# --- Vendita ---------------------------------------------------------------

static func stock(data: SaveData) -> int:
	return data.get_item(PRODUCT)

## Vende `grams` al prezzo indicato e restituisce l'incasso, 0 se non c'era
## niente da vendere: chi chiama può mostrare un messaggio invece di far
## comparire soldi dal nulla.
static func sell(data: SaveData, grams: int, price_per_gram: int, heat_per_gram := 0.0) -> int:
	var available := stock(data)
	if grams <= 0 or available <= 0:
		return 0
	var sold := mini(grams, available)
	var revenue := sold * price_per_gram
	data.add_item(PRODUCT, -sold)
	data.cash += revenue
	data.bump_stat(STAT_GRAMS_SOLD, sold)
	data.bump_stat(STAT_EARNED, revenue)
	add_heat(data, float(sold) * heat_per_gram)
	return revenue

## Vendita all'ingrosso dal PC: nessuno ti vede, si guadagna meno.
static func sell_wholesale(data: SaveData, grams: int) -> int:
	return sell(data, grams, wholesale_price(data))

## Vendita a un cliente in strada: paga meglio, ma lascia tracce.
## Restituisce l'incasso; 0 se il cliente per oggi è a posto o la scorta è finita.
static func sell_street(data: SaveData, npc_id: String, grams: int) -> int:
	var sold := mini(mini(grams, street_demand_left(data, npc_id)), stock(data))
	if sold <= 0:
		return 0
	var revenue := sell(data, sold, retail_price(data), street_heat(data))
	if revenue > 0:
		_mark_street_sale(data, npc_id, sold)
	return revenue

## Quanto vuole comprare oggi un cliente. Non è salvato: si ricava da id e
## giorno, così il salvataggio non si gonfia di una riga per ogni NPC e la
## domanda resta identica se si ricarica la partita.
static func street_demand(npc_id: String, day: int) -> int:
	var spread := STREET_DEMAND.y - STREET_DEMAND.x + 1
	return STREET_DEMAND.x + absi(hash("%s|%d" % [npc_id, day])) % spread

## Quanto gli resta da comprare oggi, tolto quello che ha già preso.
static func street_demand_left(data: SaveData, npc_id: String) -> int:
	var state: Dictionary = data.npc_state.get(npc_id, {})
	var bought := 0
	if int(state.get("day", -1)) == data.day:
		bought = int(state.get("bought", 0))
	return maxi(0, street_demand(npc_id, data.day) - bought)

static func _mark_street_sale(data: SaveData, npc_id: String, grams: int) -> void:
	var state: Dictionary = data.npc_state.get(npc_id, {})
	if int(state.get("day", -1)) != data.day:
		state = {"day": data.day, "bought": 0}
	state["bought"] = int(state.get("bought", 0)) + grams
	data.npc_state[npc_id] = state

# --- Attenzione ------------------------------------------------------------

## Attenzione per grammo venduto in strada, col filtro a carbone del negozio
## già scontato. Passa da qui chiunque venda al dettaglio — il giocatore in
## prima persona e i dealer assunti — così l'acquisto vale per tutti e due.
static func street_heat(data: SaveData) -> float:
	return HEAT_PER_STREET_GRAM * Shop.heat_factor(data)

static func add_heat(data: SaveData, amount: float) -> void:
	data.heat = clampf(data.heat + amount, 0.0, HEAT_MAX)

## Etichetta leggibile dell'attenzione addosso al giocatore, per HUD e PC.
## Già tradotta: chi la mostra la scrive e basta.
##
## `TranslationServer.translate()` e non `tr()`: questa è una funzione statica di
## una classe che non è un `Node`, e `tr()` è un metodo di `Node`.
static func heat_label(heat: float) -> String:
	if heat < 15.0:
		return TranslationServer.translate("HEAT_QUIET")
	if heat < 35.0:
		return TranslationServer.translate("HEAT_NOTICED")
	if heat < 60.0:
		return TranslationServer.translate("HEAT_WATCHED")
	if heat < 85.0:
		return TranslationServer.translate("HEAT_HUNTED")
	return TranslationServer.translate("HEAT_RAID_SOON")

# --- Vasi ------------------------------------------------------------------

## Costo del prossimo vaso, -1 se il seminterrato è pieno.
static func next_plot_cost(data: SaveData) -> int:
	var index := data.plot_slots
	if index >= MAX_PLOTS or index >= PLOT_COSTS.size():
		return -1
	return int(PLOT_COSTS[index])

static func buy_plot(data: SaveData) -> bool:
	var cost := next_plot_cost(data)
	if cost < 0 or data.cash < cost:
		return false
	data.cash -= cost
	data.plot_slots += 1
	data.ensure_plots()
	return true
