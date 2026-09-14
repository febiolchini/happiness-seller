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
## - `cut`   quota di quello che incassa, trattenuta sul posto
## - `note`  CHIAVE della riga che spiega cosa fa
##
## ## Due modi di pagare, e sono due mestieri diversi
##
## Il **coltivatore** prende una paga fissa: il suo lavoro non produce soldi da
## solo, produce piante. Pagarlo a percentuale vorrebbe dire legarlo a una
## vendita che non fa lui, e lasciarlo a bocca asciutta per i tre giorni in cui
## una pianta cresce.
##
## Il **dealer** non prende paga: trattiene una quota di quello che piazza. È il
## modo in cui si paga davvero chi vende, e in partita cambia di più di quanto
## sembri — un dealer senza merce da piazzare non costa niente, mentre un
## coltivatore senza semi costa lo stesso ogni notte. Il costo di assunzione
## resta per tutti e due: è il rischio che ci si prende in anticipo.
const ROLES := {
	"grower": {
		"name": "STAFF_GROWER",
		"hire": 420,
		"wage": 81,
		"cut": 0.0,
		"note": "STAFF_GROWER_NOTE",
	},
	"dealer": {
		"name": "STAFF_DEALER",
		"hire": 560,
		"wage": 0,
		"cut": 0.05,
		"note": "STAFF_DEALER_NOTE",
	},
}

const ORDER := ["grower", "dealer"]

## Quanti dealer si possono avere. Un tetto basso di proposito: il personale è
## un moltiplicatore, non un sostituto del giocatore.
const MAX_DEALERS := 3

## Vasi che un coltivatore riesce a seguire: tutto il seminterrato.
##
## Quanti coltivatori servono lo dice quindi il **posto che c'è**, non un numero
## scritto qui: finché la coltivazione sta in cantina e i vasi sono sei, uno
## basta e avanza, e il gioco lo dice invece di lasciare che il giocatore spenda
## quattrocentoventi dollari per uno che sta a guardare. Quando ci sarà una
## seconda proprietà il tetto salirà da solo. Vedi `max_for()`.
const POTS_PER_GROWER := 6
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

## Quota di quello che incassa che il ruolo si tiene, 0-1.
static func cut(role: String) -> float:
	return float(ROLES.get(role, {}).get("cut", 0.0))

## Quanti se ne possono avere di questo ruolo, adesso.
##
## Per i coltivatori è il posto che c'è in cantina: un coltivatore segue
## `POTS_PER_GROWER` vasi, quindi con sei vasi ne basta uno. È ricavato e non
## scritto a mano perché il numero di vasi cresce (`Economy.PLOT_COSTS`, e un
## domani una seconda proprietà), e un tetto fisso resterebbe indietro senza che
## nessuno se ne accorga.
static func max_for(data: SaveData, role: String) -> int:
	if role != "grower":
		return MAX_DEALERS
	var slots := Economy.MAX_PLOTS if data == null else maxi(data.plot_slots, data.plots.size())
	return maxi(1, ceili(float(slots) / float(POTS_PER_GROWER)))

## Quanto costa al giorno il ruolo, già scritto per essere mostrato: una paga
## per il coltivatore, una percentuale per il dealer.
##
## Sta qui e non nell'interfaccia perché è una proprietà del ruolo: il PC deve
## poter mostrare una riga sola senza sapere che i due si pagano in modi diversi,
## e un ruolo nuovo non deve richiedere di toccare la schermata.
static func pay_label(role: String) -> String:
	var share := cut(role)
	if share > 0.0:
		return TranslationServer.translate("PC_STAFF_PAY_CUT") % int(roundf(share * 100.0))
	return TranslationServer.translate("PC_WAGES_VALUE") % UiFormat.money(wage(role))

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
	return count(data, role) < max_for(data, role) and data.cash >= hire_cost(role)

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
##
## I dealer non hanno paga, quindi non entrano mai in questo conto e non se ne
## vanno mai per soldi: uno che si tiene una quota di quello che vende non ha
## niente da riscuotere nelle notti in cui non ha venduto niente. A restare
## senza lavoro sono i coltivatori, che è anche il verso giusto — sono loro il
## costo fisso che affonda una partita.
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

# --- Quando il personale si fa vivo ----------------------------------------

## Flag della partita: il personale ha già detto che i semi sono finiti.
##
## Sta nel salvataggio e non in memoria perché l'avviso deve valere una volta
## sola: senza, riaprire il gioco a magazzino semi vuoto lo farebbe ripartire
## da capo ogni volta.
const SEEDLESS_FLAG := "seeds_out_told"

## Se il personale deve avvisare ADESSO che è rimasto senza semi.
##
## Restituisce true una volta sola per ogni "fine dei semi": chi chiama manda il
## messaggio e non deve tenere il conto di niente. Il permesso torna da solo
## appena arrivano altri semi, così la volta dopo si viene avvisati di nuovo.
##
## `idle` è quanti vasi seguiti dal personale sono fermi per mancanza di semi —
## lo dice il resoconto di `work()`. Senza quel numero non basterebbe guardare
## il magazzino: a semi zero ma vasi tutti pieni non c'è niente di cui
## avvisare, il lavoro sta andando avanti.
static func seedless_alert(data: SaveData, idle: int) -> bool:
	if data == null:
		return false
	if Economy.seeds_owned(data) > 0:
		# Semi tornati: la prossima volta che finiscono si riavvisa.
		data.set_flag(SEEDLESS_FLAG, false)
		return false
	if idle <= 0 or bool(data.get_flag(SEEDLESS_FLAG, false)):
		return false
	data.set_flag(SEEDLESS_FLAG, true)
	return true

# --- Il lavoro -------------------------------------------------------------

## Fa fare al personale quello che andava fatto da `staff_checked_at` a `now`.
##
## `strain_base` e' `{"hours": ..., "grams": ...}` DI LISTINO — i valori grezzi
## della varieta', prima di qualunque negozio. Non e' gia' la fotografia
## dell'attrezzatura: quella (`Shop.grow_mods()`) dipende dal VASO, perche' la
## lampada e' un effetto per vaso e non per il totale posseduto (vedi
## `Shop.LAMP_SPEEDUP`). Un coltivatore segue piu' vasi, e ognuno puo' avere o
## non avere la sua lampada sopra: calcolarla una volta sola fuori dal ciclo,
## come succedeva prima, vuol dire dare lo stesso sconto a un vaso coperto e a
## uno scoperto. `_growers_work()` la ricalcola per ogni vaso, dentro al ciclo
## che gia' ne conosce l'indice.
##
## Restituisce un resoconto di cosa è successo — chi chiama decide se mostrarlo.
## Le chiavi ci sono sempre, anche a zero, così chi legge non deve difendersi.
static func work(data: SaveData, now: float, strain_base: Dictionary = {}) -> Dictionary:
	var report := {
		"planted": 0, "watered": 0, "harvested": 0, "grams": 0, "sold": 0,
		# `gross` è quello che la merce ha fatto, `commission` la quota trattenuta
		# dai dealer, `revenue` quello che è arrivato davvero in cassa. Servono
		# tutti e tre: il messaggino in partita mostra quello che la cassa ha
		# visto, il resoconto di quando si rientra mostra il conto per esteso.
		"gross": 0, "commission": 0, "revenue": 0,
		# Vasi seguiti dal personale rimasti vuoti perché i semi sono finiti.
		# Non è un errore, è la fine della catena: i semi li compra solo il
		# giocatore, di persona, da Brian. A gioco aperto non serve dirlo — il
		# vaso vuoto si vede — ma a gioco chiuso è l'unica spiegazione del
		# perché la produzione si è fermata. Vedi `Offline`.
		"idle": 0,
	}
	if data == null or total(data) <= 0:
		# Senza nessuno assunto il tempo scorre lo stesso: altrimenti il primo
		# assunto si troverebbe addosso tutte le ore della partita e piazzerebbe
		# un magazzino intero al primo giro.
		if data != null:
			data.staff_checked_at = now
		return report

	var elapsed := maxf(0.0, now - data.staff_checked_at)
	_growers_work(data, now, strain_base, report)
	var consumed := _dealers_work(data, elapsed, report)
	# L'orologio del personale avanza solo per le ore davvero consumate: i grammi
	# sono interi, e un dealer che in mezz'ora non arriva a un grammo intero deve
	# ritrovarsi quella mezz'ora al giro dopo invece di perderla.
	data.staff_checked_at = now - (elapsed - consumed)
	return report

static func _growers_work(data: SaveData, now: float, strain_base: Dictionary, report: Dictionary) -> void:
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
				# Vuoto se non e' stata data una varieta' di base: e' cosi' che
				# i controlli automatici che chiamano `work()` senza pensare
				# all'attrezzatura si ritrovano il comportamento di sempre —
				# nessun bonus, valori di listino puri.
				var mods := {}
				if not strain_base.is_empty():
					mods = Shop.grow_mods(
						data, float(strain_base.get("hours", 0.0)),
						int(strain_base.get("grams", 0)), index)
				Grow.plant(plot, Economy.DEFAULT_STRAIN, now, mods)
				report["planted"] = int(report["planted"]) + 1
			else:
				report["idle"] = int(report["idle"]) + 1
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
	var gross := 0
	if bulk > 0:
		gross += Economy.sell_wholesale(data, bulk)
	if street > 0:
		gross += Economy.sell(data, street, Economy.retail_price(data), Economy.street_heat(data))

	# La quota se la tengono sul posto, prima di consegnare: è il motivo per cui
	# si scala dalla cassa qui e non a mezzanotte come le paghe. Non dipende da
	# quanti sono — la merce piazzata è la stessa, divisa fra loro — quindi
	# assumerne un altro aumenta quanto si riesce a piazzare, non la percentuale.
	var commission := int(roundf(float(gross) * cut("dealer")))
	if commission > 0:
		data.cash -= commission
	report["sold"] = budget
	report["gross"] = gross
	report["commission"] = commission
	report["revenue"] = gross - commission
	return float(budget) / per_hour
