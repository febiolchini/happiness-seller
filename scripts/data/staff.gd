class_name Staff
extends RefCounted

## Il personale: la gente che si assume dal PC perché faccia da sola il giro che
## fino a lì si faceva a mano.
##
## Due ruoli, e sono i due lati del gioco:
## - **GROWER** sta in cantina: pianta, annaffia, raccoglie.
## - **DEALER** piazza la merce, in parte all'ingrosso e in parte in strada,
##   nella proporzione decisa dal giocatore (`SaveData.wholesale_share`).
##
## ## Il lavoro non è simulato
##
## Come la coltivazione (vedi `Grow`), nessuno tiene il conto frame per frame.
## `work()` guarda che ore sono adesso, confronta con `SaveData.staff_checked_at`
## e fa quello che nel frattempo andava fatto. Quindi il personale lavora anche
## mentre il giocatore è dall'altra parte della città, ed è idempotente:
## chiamarla spesso o di rado dà lo stesso risultato.
##
## Si sblocca alla fine del prologo — vedi `GameState._check_prologue()`.

# --- Ruoli -----------------------------------------------------------------

## - `name`  CHIAVE del nome del ruolo (il testo vero sta in `Strings`)
## - `hire`  una tantum all'assunzione
## - `wage`  paga giornaliera, scalata a mezzanotte
## - `note`  CHIAVE della riga che spiega cosa fa
const ROLES := {
	"grower": {
		"name": "STAFF_GROWER",
		"hire": 420,
		"wage": 81,
		"note": "STAFF_GROWER_NOTE",
	},
	"dealer": {
		"name": "STAFF_DEALER",
		"hire": 560,
		"wage": 108,
		"note": "STAFF_DEALER_NOTE",
	},
}

const ORDER := ["grower", "dealer"]

## Quanti se ne possono avere per ruolo. Un tetto basso di proposito: il
## personale è un moltiplicatore, non un sostituto del giocatore.
const MAX_PER_ROLE := 3

## Vasi che un coltivatore riesce a seguire.
const POTS_PER_GROWER := 2
## Grammi all'ora di gioco che un dealer riesce a piazzare.
const GRAMS_PER_DEALER_HOUR := 2.0
## Sotto a questi grammi il dealer non esce: aspetta di averne abbastanza.
##
## Non è bilanciamento, è rumore. `work()` gira a ogni frame, e senza una soglia
## il primo grammo intero verrebbe piazzato appena maturato — un messaggino ogni
## sette secondi reali, da un giro in cantina alla fine della partita. Sopra a
## una manciata di grammi diventa una consegna ogni mezzo minuto, che è quello
## che si vuole leggere.
const MIN_BATCH_GRAMS := 5
## Di quanto si sposta la quota all'ingrosso a ogni click sui bottoni del PC.
const SHARE_STEP := 10

# --- Organico --------------------------------------------------------------

static func count(data: SaveData, role: String) -> int:
	if data == null:
		return 0
	return int(data.staff.get(role, 0))

static func total(data: SaveData) -> int:
	var sum := 0
	for role in ORDER:
		sum += count(data, role)
	return sum

static func hire_cost(role: String) -> int:
	return int(ROLES.get(role, {}).get("hire", 0))

static func wage(role: String) -> int:
	return int(ROLES.get(role, {}).get("wage", 0))

## Nome del ruolo, già tradotto.
static func role_name(role: String) -> String:
	return TranslationServer.translate(str(ROLES.get(role, {}).get("name", role.to_upper())))

## Spiegazione sotto ai bottoni, già tradotta.
static func note(role: String) -> String:
	var key := str(ROLES.get(role, {}).get("note", ""))
	return "" if key.is_empty() else TranslationServer.translate(key)

## Il conto delle paghe di una giornata.
static func daily_wages(data: SaveData) -> int:
	var sum := 0
	for role in ORDER:
		sum += count(data, role) * wage(role)
	return sum

static func can_hire(data: SaveData, role: String) -> bool:
	if data == null or not ROLES.has(role):
		return false
	return count(data, role) < MAX_PER_ROLE and data.cash >= hire_cost(role)

static func hire(data: SaveData, role: String, now: float) -> bool:
	if not can_hire(data, role):
		return false
	data.cash -= hire_cost(role)
	data.staff[role] = count(data, role) + 1
	# Il primo assunto non deve trovarsi addosso le ore passate da quando la
	# partita è cominciata: il conto del lavoro riparte da adesso.
	if total(data) == 1:
		data.staff_checked_at = now
	return true

static func fire(data: SaveData, role: String) -> bool:
	if data == null or count(data, role) <= 0:
		return false
	data.staff[role] = count(data, role) - 1
	if int(data.staff[role]) <= 0:
		data.staff.erase(role)
	return true

# --- Ripartizione delle vendite --------------------------------------------

## Quota della merce che i dealer piazzano all'ingrosso, 0-100. Il resto va in
## strada.
static func wholesale_share(data: SaveData) -> int:
	if data == null:
		return 100
	return clampi(data.wholesale_share, 0, 100)

static func set_wholesale_share(data: SaveData, value: int) -> void:
	if data == null:
		return
	data.wholesale_share = clampi(value, 0, 100)

# --- Le paghe --------------------------------------------------------------

## Scala le paghe di una giornata. Restituisce quanto è stato pagato.
##
## Se i soldi non bastano se ne va uno — e per primo quello che costa di più:
## lasciare il giocatore in rosso con l'organico intatto vorrebbe dire un buco
## che si allarga da solo ogni notte, senza niente che lo fermi.
static func pay_wages(data: SaveData) -> Dictionary:
	var due := daily_wages(data)
	if due <= 0:
		return {"paid": 0, "quit": ""}
	if data.cash >= due:
		data.cash -= due
		return {"paid": due, "quit": ""}
	var paid := data.cash
	data.cash = 0
	var quit_role := ""
	for role in ORDER:
		if count(data, role) > 0 and (quit_role.is_empty() or wage(role) > wage(quit_role)):
			quit_role = role
	if not quit_role.is_empty():
		fire(data, quit_role)
	return {"paid": paid, "quit": quit_role}

# --- Il lavoro -------------------------------------------------------------

## Fa fare al personale quello che andava fatto da `staff_checked_at` a `now`.
##
## `mods` è la fotografia dell'attrezzatura per le piante nuove, la stessa che
## userebbe il giocatore piantando a mano: vedi `Shop.grow_mods()`.
##
## Restituisce un resoconto di cosa è successo — chi chiama decide se mostrarlo.
## Le chiavi ci sono sempre, anche a zero, così chi legge non deve difendersi.
static func work(data: SaveData, now: float, mods: Dictionary = {}) -> Dictionary:
	var report := {"planted": 0, "watered": 0, "harvested": 0, "grams": 0, "sold": 0, "revenue": 0}
	if data == null or total(data) <= 0:
		# Senza nessuno assunto il tempo scorre lo stesso: altrimenti il primo
		# assunto si troverebbe addosso tutte le ore della partita e piazzerebbe
		# un magazzino intero al primo giro.
		if data != null:
			data.staff_checked_at = now
		return report

	var elapsed := maxf(0.0, now - data.staff_checked_at)
	_growers_work(data, now, mods, report)
	var consumed := _dealers_work(data, elapsed, report)
	# L'orologio del personale avanza solo per le ore davvero consumate: i grammi
	# sono interi, e un dealer che in mezz'ora non arriva a un grammo intero deve
	# ritrovarsi quella mezz'ora al giro dopo invece di perderla.
	data.staff_checked_at = now - (elapsed - consumed)
	return report

static func _growers_work(data: SaveData, now: float, mods: Dictionary, report: Dictionary) -> void:
	var pots := count(data, "grower") * POTS_PER_GROWER
	if pots <= 0:
		return
	var seed_item := Economy.seed_item(Economy.DEFAULT_STRAIN)
	for index in mini(pots, data.plots.size()):
		var plot: Dictionary = data.plots[index]
		Grow.sync(plot, now)
		if Grow.is_ready(plot, now):
			var grams := Grow.harvest(plot, now)
			if grams > 0:
				data.add_item(Economy.PRODUCT, grams)
				data.bump_stat(Economy.STAT_GRAMS_HARVESTED, grams)
				data.bump_stat(Economy.STAT_PLANTS_GROWN)
				report["harvested"] = int(report["harvested"]) + 1
				report["grams"] = int(report["grams"]) + grams
		if Grow.is_empty(plot):
			if data.get_item(seed_item) > 0:
				data.add_item(seed_item, -1)
				Grow.plant(plot, Economy.DEFAULT_STRAIN, now, mods)
				report["planted"] = int(report["planted"]) + 1
		elif Grow.is_thirsty(plot, now):
			Grow.water(plot, now)
			report["watered"] = int(report["watered"]) + 1

## Piazza la merce e restituisce le ore di lavoro davvero consumate.
static func _dealers_work(data: SaveData, elapsed: float, report: Dictionary) -> float:
	var dealers := count(data, "dealer")
	if dealers <= 0 or elapsed <= 0.0:
		return elapsed
	var per_hour := float(dealers) * GRAMS_PER_DEALER_HOUR
	var stock := Economy.stock(data)
	var budget := mini(int(floorf(per_hour * elapsed)), stock)
	if budget <= 0:
		# Niente da vendere: le ore non vanno tenute da parte, si sono perse.
		return elapsed if stock <= 0 else 0.0
	# `budget >= stock` è il caso del fondo di magazzino: meno della soglia ma
	# non ne arriverà altra, quindi va piazzato lo stesso invece di restare lì.
	if budget < MIN_BATCH_GRAMS and budget < stock:
		return 0.0

	var share := wholesale_share(data)
	var bulk := int(roundf(float(budget) * float(share) / 100.0))
	var street := budget - bulk
	var revenue := 0
	if bulk > 0:
		revenue += Economy.sell_wholesale(data, bulk)
	if street > 0:
		revenue += Economy.sell(data, street, Economy.retail_price(data), Economy.street_heat(data))
	report["sold"] = budget
	report["revenue"] = revenue
	return float(budget) / per_hour
