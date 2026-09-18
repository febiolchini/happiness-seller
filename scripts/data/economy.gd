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
		"seed_price": 35,
		"grow_hours": 20.0,
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
## Quanti vasi ci stanno in tutto, cantina e garage insieme: sei sotto casa e
## dodici sui due banconi del garage. La ripartizione fra i due posti la dice
## `GrowSites`, che e' anche l'unico a sapere quale indice sta dove.
##
## Il numero non e' piu' "quanti ce ne stanno in cantina" ma "quanti ce ne
## stanno in tutto", e sale comprando una proprieta': era il gancio previsto per
## la progressione del gestionale, ed e' il garage ad averlo tirato.
const MAX_PLOTS := 18
## Costo per sbloccare il vaso di indice N (0-based). I primi tre sono già lì.
##
## Dal settimo in poi sono i banconi del garage, e ricominciano da un gradino
## piu' alto: ci si arriva con la cantina piena e trentacinquemila dollari di
## proprieta' gia' spesi, quindi il problema non e' piu' racimolare duecento
## dollari. La salita resta dolce all'inizio del bancone e ripida in fondo, cosi'
## riempire il garage e' un traguardo lungo e non una spesa sola.
const PLOT_COSTS := [
	0, 0, 0, 210, 560, 1260,
	1500, 1800, 2200, 2600, 3100, 3700,
	4400, 5200, 6100, 7100, 8200, 9400,
]

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
	# Il tempo di domani si tira qui insieme al prezzo, e per lo stesso motivo:
	# sono le due cose che rendono domani diverso da oggi, e il giocatore le
	# scopre insieme aprendo gli occhi il mattino dopo.
	data.weather = Weather.roll(data.weather)

# --- Prezzi correnti -------------------------------------------------------

## Prezzo all'ingrosso: quello che si prende piazzando la merce dal PC, senza
## uscire di casa e senza farsi vedere da nessuno.
static func wholesale_price(data: SaveData) -> int:
	return maxi(1, data.market_price)

## Quanto si paga la merce in un quartiere, rispetto alla strada qualunque.
##
## In collina la stessa roba si paga il dieci per cento in più: lassù nessuno
## sta a contare i centesimi. È la prima ragione per **attraversare la città
## invece di vendere sotto casa** — finora un cliente valeva l'altro, e la mappa
## larga cinquemila pixel era solo una distanza da percorrere.
##
## Le chiavi sono i nomi dei quartieri in `CityMap.DISTRICTS`. Il conto sta qui e
## non lì perché è bilanciamento e non geografia, ed è `Economy` il posto in cui
## si girano i numeri; che le due tabelle siano d'accordo lo verifica un
## controllo automatico, altrimenti un nome scritto male passerebbe come "nessun
## aumento" senza dire niente a nessuno.
##
## Più avanti qui ci andrà anche il rovescio della medaglia: in collina la
## polizia è più attenta, e quel dieci per cento si pagherà in attenzione.
const DISTRICT_PRICE := {
	"HILLSIDE": 1.10,
}

## Il moltiplicatore di un quartiere, 1.0 se non ne ha uno suo.
static func district_price(district: String) -> float:
	return float(DISTRICT_PRICE.get(district, 1.0))

## Prezzo al dettaglio: si vende a mano, in strada, e si prende di più.
##
## `district` è il quartiere in cui sta avvenendo la vendita — vuoto vuol dire
## "da nessuna parte in particolare", e si paga il prezzo base. Vedi
## `DISTRICT_PRICE`.
static func retail_price(data: SaveData, district := "") -> int:
	var price := float(wholesale_price(data)) * RETAIL_MULTIPLIER * district_price(district)
	return maxi(1, int(roundf(price)))

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

## Vendita all'ingrosso: nessuno ti vede, si guadagna meno.
##
## Non è più un bottone del PC: il giocatore ci arriva col furgone
## (`Delivery`), il personale attraverso i suoi canali. Quello che resta qui è
## il prezzo — e il fatto che il canale sia aperto o no lo dice `Delivery`.
static func sell_wholesale(data: SaveData, grams: int) -> int:
	return sell(data, grams, wholesale_price(data))

## Vendita a un cliente in strada: paga meglio, ma lascia tracce.
##
## `district` è dove sta il cliente: lo passa chi vende, perché è l'unico a
## saperlo. Il personale non lo passa — un dealer assunto non ha una posizione
## sulla mappa, quindi prende il prezzo base. È una differenza voluta: andare di
## persona in collina è l'unica cosa che quel dieci per cento lo porta a casa.
##
## Restituisce l'incasso; 0 se il cliente per oggi è a posto o la scorta è finita.
static func sell_street(data: SaveData, npc_id: String, grams: int, district := "") -> int:
	var sold := mini(mini(grams, street_demand_left(data, npc_id)), stock(data))
	if sold <= 0:
		return 0
	var revenue := sell(data, sold, retail_price(data, district), street_heat(data))
	if revenue > 0:
		_mark_street_sale(data, npc_id, sold)
	return revenue

## Quanto vuole comprare oggi un cliente. Non è salvato: si ricava da id e
## giorno, così il salvataggio non si gonfia di una riga per ogni NPC e la
## domanda resta identica se si ricarica la partita.
##
## Il tempo che fa è l'unica cosa che la sposta, e la sposta di parecchio: sotto
## la pioggia un cliente prende un terzo di quello che prenderebbe con il sole.
## È quello che dà un motivo per guardare fuori dalla finestra prima di uscire
## con la merce addosso — e per usare il PC nei giorni brutti.
static func street_demand(npc_id: String, day: int, weather_id := Weather.DEFAULT) -> int:
	var spread := STREET_DEMAND.y - STREET_DEMAND.x + 1
	var base := STREET_DEMAND.x + absi(hash("%s|%d" % [npc_id, day])) % spread
	# Almeno un grammo: un tempo così brutto da azzerare la domanda di tutti
	# renderebbe la giornata un muro invece di una giornata storta.
	return maxi(1, int(roundf(float(base) * Weather.demand_mod(weather_id))))

## Quanto gli resta da comprare oggi, tolto quello che ha già preso.
static func street_demand_left(data: SaveData, npc_id: String) -> int:
	var state: Dictionary = data.npc_state.get(npc_id, {})
	var bought := 0
	if int(state.get("day", -1)) == data.day:
		bought = int(state.get("bought", 0))
	return maxi(0, street_demand(npc_id, data.day, Weather.of(data)) - bought)

static func _mark_street_sale(data: SaveData, npc_id: String, grams: int) -> void:
	var state: Dictionary = data.npc_state.get(npc_id, {})
	if int(state.get("day", -1)) != data.day:
		state = {"day": data.day, "bought": 0}
	state["bought"] = int(state.get("bought", 0)) + grams
	data.npc_state[npc_id] = state

# --- Attenzione ------------------------------------------------------------

# --- Bollette --------------------------------------------------------------

## Ogni quanti giorni di gioco arriva la bolletta della luce.
##
## Trenta giorni sono un mese, che al ritmo attuale dell'orologio sono circa tre
## ore vere di gioco: è una spesa che si vede arrivare da lontano e si prepara,
## al contrario delle paghe che mordono ogni notte. Sono due tempi diversi
## apposta — un gestionale ha bisogno di tutti e due.
const BILL_DAYS := 30
## Quota fissa: il contatore c'è anche a cantina spenta. È la casa di partenza,
## che non si compra e quindi non ha una riga in `RealEstate`.
const POWER_BASE := 100
## Quanto costa tenere accesa una lampada in più per un mese.
const POWER_PER_LAMP := 10

## Quanto verrà la prossima bolletta.
##
## Tre addendi, e sono tre cose diverse: la casa (`POWER_BASE`), i **muri in
## più** che si sono comprati, e le lampade accese.
##
## Le proprietà pesano perché un posto consuma anche vuoto — saracinesca,
## ventilazione, il contatore che gira — ed è quello che rende il garage una
## spesa fissa e non solo dodici vasi in regalo: chi lo compra se ne accorge
## alla prima bolletta anche prima di averci piantato niente. Quanto pesa
## ognuna lo dice `RealEstate` (`corrente`), accanto al prezzo, perché è
## l'altra metà di quanto costa avere quel posto.
##
## Le lampade si pagano **accese**, non per vaso: un vaso al buio non consuma
## niente. È anche il motivo per cui ogni lampada in più è una scelta e non un
## acquisto ovvio — accorcia la crescita e allunga la bolletta.
static func power_bill(data: SaveData) -> int:
	if data == null:
		return POWER_BASE
	var bill := POWER_BASE + POWER_PER_LAMP * Shop.owned(data, "lamps")
	for id: String in data.properties:
		bill += RealEstate.power_draw(id)
	return bill

## Fra quanti giorni di gioco arriva.
static func days_to_bill(data: SaveData) -> int:
	if data == null:
		return BILL_DAYS
	return maxi(0, BILL_DAYS - (data.day - data.power_billed_day))

## Scala la bolletta se è il giorno. Restituisce quanto è stato pagato e quanto
## era dovuto: chi chiama decide se e come dirlo.
##
## Si paga quel che c'è, come le paghe del personale: restare senza corrente è
## una conseguenza che va scritta quando ci sarà qualcosa da spegnere, e per ora
## un buco che si allarga in silenzio sarebbe peggio di un conto pagato a metà.
static func charge_power(data: SaveData) -> Dictionary:
	var result := {"due": 0, "paid": 0}
	if data == null or data.day - data.power_billed_day < BILL_DAYS:
		return result
	# Il giorno da cui riparte il conto è quello in cui sarebbe SCADUTA la
	# bolletta, non oggi: attraversando più mesi in un colpo solo (il recupero
	# del tempo a gioco chiuso) non se ne salta nessuno e non se ne accavallano.
	data.power_billed_day += BILL_DAYS
	var due := power_bill(data)
	var paid := mini(due, data.cash)
	data.cash -= paid
	result["due"] = due
	result["paid"] = paid
	return result

# --- Tasse sulla proprietà --------------------------------------------------

## Ogni quanti giorni di gioco torna la tassa sulla proprietà.
##
## Un anno, perché è quello che è: una patrimoniale non è una bolletta, e
## contarla in mesi la farebbe sembrare l'ennesima spesa corrente. Al ritmo
## dell'orologio sono un paio di giornate vere di gioco — abbastanza lontano da
## dimenticarsene, ed è il punto: chi compra il secondo capannone lo compra
## guardando quanto rende, e la tassa gli ricorda che possedere costa anche
## quando non produce.
const TAX_DAYS := 365
## Quanto si paga ogni anno, sul prezzo di acquisto.
const TAX_RATE := 0.01

## Quanto verrebbe la tassa di **una** proprietà: l'1% di quello che è costata.
##
## Sul prezzo di listino e non su un valore che si muove: il valore di mercato
## non esiste ancora in questo gioco, e inventarne uno solo per tassarlo
## vorrebbe dire due verità su quanto vale un edificio.
static func property_tax(id: String) -> int:
	return int(roundf(float(RealEstate.price(id)) * TAX_RATE))

## Quanto si paga in tutto ogni anno, con le proprietà di adesso. Serve al PC:
## è il numero che si guarda prima di comprare.
static func yearly_tax(data: SaveData) -> int:
	if data == null:
		return 0
	var total := 0
	for id: String in data.properties:
		total += property_tax(id)
	return total

## Fra quanti giorni scade la prossima, `-1` se non si possiede niente.
static func days_to_tax(data: SaveData) -> int:
	if data == null:
		return -1
	var soonest := -1
	for id: String in data.properties:
		var left := maxi(0, TAX_DAYS - (data.day - _taxed_day(data, id)))
		if soonest < 0 or left < soonest:
			soonest = left
	return soonest

## Scala le tasse scadute. Stessa forma di `charge_power()`, e per gli stessi
## motivi: torna quanto era dovuto e quanto si è riusciti a pagare, e chi chiama
## decide se dirlo.
##
## Ogni proprietà ha il suo anniversario — si contano i giorni dal rogito, non
## dal capodanno — e il `while` serve perché il tempo a gioco chiuso può far
## passare più di un anno in un colpo solo: come per la bolletta, il giorno da
## cui riparte il conto è quello in cui la tassa è SCADUTA e non oggi, così non
## se ne salta nessuna.
static func charge_property_tax(data: SaveData) -> Dictionary:
	var result := {"due": 0, "paid": 0}
	if data == null:
		return result
	for id: String in data.properties:
		var entry: Dictionary = data.properties[id]
		var last := _taxed_day(data, id)
		while data.day - last >= TAX_DAYS:
			last += TAX_DAYS
			result["due"] = int(result["due"]) + property_tax(id)
		entry["tassato_il"] = last
	var paid := mini(int(result["due"]), data.cash)
	data.cash -= paid
	result["paid"] = paid
	return result

## Da che giorno si conta l'anno di questa proprietà.
##
## I salvataggi di prima delle tasse hanno solo `acquisito_il`, e va benissimo:
## è esattamente il giorno da cui l'anno andrebbe contato. Chi rientra in una
## partita vecchia non si trova un arretrato inventato né un anno regalato.
static func _taxed_day(data: SaveData, id: String) -> int:
	var entry: Dictionary = data.properties.get(id, {})
	return int(entry.get("tassato_il", entry.get("acquisito_il", data.day)))

# --- Attenzione ------------------------------------------------------------

## Attenzione per grammo venduto in strada, col filtro a carbone del negozio
## già scontato. Passa da qui chiunque venda al dettaglio — il giocatore in
## prima persona e i dealer assunti — così l'acquisto vale per tutti e due.
## Ci rientra anche il tempo che fa: sotto la pioggia la gente cammina a testa
## bassa e le pattuglie restano in macchina, quindi si vende meno ma quel poco
## si vende più tranquilli. È il contrappeso che rende una giornata brutta una
## scelta e non solo un danno.
static func street_heat(data: SaveData) -> float:
	return HEAT_PER_STREET_GRAM * Shop.heat_factor(data) * Weather.heat_mod(Weather.of(data))

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

## Costo del prossimo vaso, -1 se non ce n'e' un prossimo da comprare.
##
## Due motivi per non averlo: sono finiti tutti, oppure il prossimo sta in un
## posto che non e' ancora tuo. Il secondo e' quello che tiene in piedi il
## garage come traguardo: finita la cantina non si compra piu' niente finche'
## non si compra il garage, e allora si riapre la fila di dodici.
static func next_plot_cost(data: SaveData) -> int:
	if data == null:
		return -1
	var index := data.plot_slots
	if index >= MAX_PLOTS or index >= PLOT_COSTS.size():
		return -1
	if not GrowSites.is_open(data, GrowSites.site_of(index)):
		return -1
	return int(PLOT_COSTS[index])

static func buy_plot(data: SaveData) -> bool:
	var cost := next_plot_cost(data)
	if cost < 0 or data.cash < cost:
		return false
	data.cash -= cost
	data.plot_slots += 1
	data.ensure_plots()
	# Un vaso in piu' puo' voler dire un posto di lavoro in piu': se c'era un
	# coltivatore in panchina, adesso ha dove stare. Vedi `Staff.sync_sites()`.
	Staff.sync_sites(data)
	return true
