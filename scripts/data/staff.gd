class_name Staff
extends RefCounted

## Il personale: la gente che si assume dal PC perché faccia da sola il giro che
## fino a lì si faceva a mano.
##
## Due ruoli, e sono i due lati del gioco:
## - **GROWER** sta in cantina: pianta, annaffia, raccoglie.
## - **DEALER** piazza la merce **in strada**, e solo quella che il giocatore gli
##   lascia: vedi "La riserva dell'ingrosso" qui sotto.
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
	# L'autista: paga fissa come il coltivatore, e per lo stesso motivo — il suo
	# lavoro non produce soldi, produce viaggi risparmiati. Costa meno degli
	# altri due perche' quello che fa e' comodita', non produzione: chi lo
	# assume compra il non doversi fare la strada fino in centro ogni volta che
	# finiscono i semi.
	"driver": {
		"name": "STAFF_DRIVER",
		"hire": 380,
		"wage": 54,
		"cut": 0.0,
		"note": "STAFF_DRIVER_NOTE",
	},
}

const ORDER := ["grower", "dealer", "driver"]

## Quanti dealer si possono avere con la sola casa. Un tetto basso di proposito:
## il personale è un moltiplicatore, non un sostituto del giocatore.
const MAX_DEALERS := 3
## Quanti se ne aggiungono per ogni proprietà comprata.
##
## Il tetto non è una proprietà della città ma di quanto si è grossi, e quello
## che dice di quanto si è grossi sono le proprietà: col garage si passa da tre
## a cinque, e ogni proprietà che si aggiungerà ne porta altri due senza che
## nessuno debba tornare qui a cambiare un numero. Il conto delle proprietà lo
## tiene già `SaveData.property_count()`.
const DEALERS_PER_PROPERTY := 2

## Quanti dealer si possono avere adesso.
static func max_dealers(data: SaveData) -> int:
	if data == null:
		return MAX_DEALERS
	return MAX_DEALERS + DEALERS_PER_PROPERTY * data.property_count()

## Quanti autisti: uno, e solo col furgone in casa.
##
## Uno perche' i furgoni sono uno: un secondo autista non avrebbe niente da
## guidare. Zero senza furgone, e non e' un caso limite — e' il modo in cui il
## ruolo resta nascosto finche' non ha senso, visto che `roles_for()` salta i
## ruoli che non si possono assumere.
static func max_drivers(data: SaveData) -> int:
	return 1 if data != null and Delivery.has_van(data) else 0

## Vasi che un coltivatore riesce a seguire.
##
## Il numero vero sta in `GrowSites`, perché è una misura del posto e non della
## persona: qui resta il rimando, così chi legge `Staff` non deve sapere dove
## cercarlo. Quanti coltivatori servono lo dice quindi **il posto che c'è**, e
## comprando vasi o proprieta' il tetto sale da solo. Vedi `max_for()`.
const POTS_PER_GROWER := GrowSites.POTS_PER_GROWER
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

## I ruoli che ha senso mostrare adesso, nell'ordine.
##
## Salta quelli che non si possono avere: l'autista senza furgone sarebbe una
## riga "0 su 0" con due bottoni spenti, che non dice al giocatore "non ancora",
## dice "rotto". E' la stessa regola della ripartizione delle vendite e dei
## posti dei coltivatori nel PC — una sezione compare quando c'e' davvero
## qualcosa da decidere.
static func roles_for(data: SaveData) -> Array:
	var list: Array = []
	for role in ORDER:
		if max_for(data, role) > 0:
			list.append(role)
	return list

## C'è un autista in organico? Da questo dipendono due cose: i semi ordinabili
## dal PC, e il contatto in rubrica sul telefono (`Chat.contacts()`).
static func has_driver(data: SaveData) -> bool:
	return count(data, "driver") > 0

## Il flag che ricorda che l'autista si è già presentato.
const DRIVER_HELLO_FLAG := "driver_said_hello"

## Assunto l'autista, il primo messaggio lo manda lui: vero **solo il giro in
## cui scatta**, come gli altri traguardi.
##
## È quel messaggio a mettere il contatto in rubrica sotto agli occhi del
## giocatore. La rubrica ce l'avrebbe comunque — `Chat.contacts()` guarda
## l'organico — ma un contatto che compare in silenzio dentro a una schermata
## che si apre solo se la si cerca non lo trova nessuno.
static func check_driver_hello(data: SaveData) -> bool:
	if data == null or not has_driver(data):
		return false
	if bool(data.get_flag(DRIVER_HELLO_FLAG, false)):
		return false
	data.set_flag(DRIVER_HELLO_FLAG, true)
	return true

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
	if role == "dealer":
		return max_dealers(data)
	if role == "driver":
		return max_drivers(data)
	if role != "grower":
		return max_dealers(data)
	if data == null:
		return maxi(1, ceili(float(Economy.MAX_PLOTS) / float(POTS_PER_GROWER)))
	# Somma delle capienze dei posti aperti, e non un conto sul totale dei vasi:
	# sei vasi in cantina e uno solo aperto in garage fanno due coltivatori (uno
	# per posto) e non uno, perche' nessuno lavora in due stanze insieme.
	var room := 0
	for site: Dictionary in GrowSites.open_sites(data):
		room += GrowSites.capacity(data, site)
	return maxi(1, room)

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
	# Un coltivatore appena assunto va **subito** in un posto che ha spazio, e
	# non resta in panchina aspettando che qualcuno lo assegni: si paga ogni
	# notte, e uno pagato per non fare niente si legge come un bug. Dove sta lo
	# si cambia quando si vuole, dalla scheda del personale.
	if role == "grower":
		sync_sites(data)
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
	if role == "grower":
		sync_sites(data)
	return true

# --- Chi lavora dove -------------------------------------------------------

## ## I coltivatori si assegnano, i dealer no
##
## Un coltivatore sta in **una** stanza e segue i vasi di quella: mandarne due in
## cantina mentre il garage ha dodici piante da annaffiare e' una scelta
## sbagliata che il gioco deve permettere, non impedire. La strada invece e' una
## sola, quindi i dealer non hanno niente da assegnare.
##
## `SaveData.grower_sites` tiene "chiave del posto" -> quanti. Due invarianti,
## e le rimette a posto `sync_sites()`:
##
## 1. la somma non supera mai i coltivatori assunti;
## 2. nessun posto ne ha piu' di quanti ne regge (`GrowSites.capacity()`).
##
## Servono perche' l'organico e i vasi cambiano sotto: si licenzia, si vende una
## proprieta', si compra un vaso. Invece di difendersi in ogni punto che legge,
## si rimette in riga in un posto solo.

## Quanti coltivatori stanno in questo posto.
static func growers_on(data: SaveData, key: String) -> int:
	if data == null:
		return 0
	return int(data.grower_sites.get(key, 0))

## Quanti coltivatori assunti non sono ancora da nessuna parte.
##
## A regime e' zero — `sync_sites()` li piazza — ma non e' un errore: puo'
## valere piu' di zero quando i posti sono tutti pieni, cioe' quando si ha piu'
## gente che vasi.
static func idle_growers(data: SaveData) -> int:
	if data == null:
		return 0
	var placed := 0
	for site: Dictionary in GrowSites.all():
		placed += growers_on(data, str(site["key"]))
	return maxi(0, count(data, "grower") - placed)

## Ne aggiunge (o toglie) uno a questo posto. Torna false se non si poteva:
## niente spazio nel posto, o nessuno libero da mandarci.
static func assign(data: SaveData, key: String, amount: int) -> bool:
	if data == null or amount == 0:
		return false
	var site := GrowSites.find(key)
	if site.is_empty() or not GrowSites.is_open(data, site):
		return false
	var here := growers_on(data, key)
	var wanted := here + amount
	if wanted < 0:
		return false
	if amount > 0 and (wanted > GrowSites.capacity(data, site) or idle_growers(data) < amount):
		return false
	_set_growers_on(data, key, wanted)
	return true

## Rimette in riga le assegnazioni dopo che qualcosa e' cambiato sotto.
##
## Prima toglie il di piu' — posti chiusi, capienze scese, gente licenziata —
## poi piazza chi e' rimasto libero nel primo posto che ha spazio. L'ordine
## conta: piazzare prima di tagliare vorrebbe dire mandare qualcuno in un posto
## che sta per chiudere.
static func sync_sites(data: SaveData) -> void:
	if data == null:
		return
	for key: String in data.grower_sites.keys():
		if GrowSites.find(key).is_empty():
			data.grower_sites.erase(key)
	for site: Dictionary in GrowSites.all():
		var key := str(site["key"])
		var room := GrowSites.capacity(data, site) if GrowSites.is_open(data, site) else 0
		if growers_on(data, key) > room:
			_set_growers_on(data, key, room)
	# Piu' gente che posti: si taglia dall'ultimo posto all'indietro, cosi' a
	# restare coperta e' la cantina, che e' quella che c'e' sempre.
	var over := -idle_growers_raw(data)
	var sites := GrowSites.all()
	for i in range(sites.size() - 1, -1, -1):
		if over <= 0:
			break
		var key := str((sites[i] as Dictionary)["key"])
		var take := mini(over, growers_on(data, key))
		if take > 0:
			_set_growers_on(data, key, growers_on(data, key) - take)
			over -= take
	# E chi e' rimasto libero va nel primo posto che lo regge.
	for site: Dictionary in GrowSites.all():
		var free := idle_growers(data)
		if free <= 0:
			break
		if not GrowSites.is_open(data, site):
			continue
		var key := str(site["key"])
		var room := GrowSites.capacity(data, site) - growers_on(data, key)
		if room > 0:
			_set_growers_on(data, key, growers_on(data, key) + mini(room, free))

## Come `idle_growers()` ma senza il pavimento a zero: negativo vuol dire che
## nei posti c'e' scritta piu' gente di quanta ne sia assunta, ed e' proprio il
## caso che `sync_sites()` deve raddrizzare.
static func idle_growers_raw(data: SaveData) -> int:
	var placed := 0
	for site: Dictionary in GrowSites.all():
		placed += growers_on(data, str(site["key"]))
	return count(data, "grower") - placed

static func _set_growers_on(data: SaveData, key: String, value: int) -> void:
	if value <= 0:
		data.grower_sites.erase(key)
	else:
		data.grower_sites[key] = value

# --- La riserva dell'ingrosso ----------------------------------------------

## ## Come si divide la merce
##
## La percentuale scelta al PC **non dice ai dealer dove vendere**: dice quanta
## roba mettere da parte perché non la vendano loro. I dealer lavorano la strada
## e basta; quello che è da parte lo muove solo il giocatore, col furgone. Trenta
## e settanta vuol dire: di cento grammi raccolti, settanta i dealer li possono
## piazzare e trenta restano in magazzino ad aspettare un carico.
##
## Prima la stessa percentuale voleva dire "i dealer piazzano il 30% del loro
## giro all'ingrosso", ed era un'altra cosa: il canale dell'ingrosso passava
## anche a loro, il furgone non serviva a niente, e la scelta si riduceva a quale
## dei due prezzi preferire. Adesso è una scelta fra **incassare subito** (la
## strada, che però paga il dealer e alza l'attenzione) e **tenere da parte per
## il carico grosso** (l'ingrosso, che però bisogna guidarcelo).
##
## ## Perché la riserva è un numero e non una percentuale
##
## Una quota ricalcolata sulla scorta si svuoterebbe da sola: i dealer piazzano
## il 70%, sulla rimanenza il 30% è un terzo di quel che era, loro ne piazzano
## di nuovo il 70%, e via così fino a zero. La riserva è quindi un totale di
## grammi (`SaveData.wholesale_reserve`): **cresce a ogni raccolto** e cala solo
## quando parte un carico.

## Quota del raccolto che si mette da parte per l'ingrosso, 0-100.
##
## Finché l'ingrosso non è aperto (vedi `Delivery.UNLOCK_GRAMS`) è **zero
## qualunque cosa dica il salvataggio**: il canale non esiste ancora per nessuno,
## e mettere da parte merce per un furgone che non c'è vorrebbe dire bloccare il
## magazzino senza motivo. Il numero scelto dal giocatore non si perde — resta
## scritto, e torna valido appena il chilo arriva.
static func wholesale_share(data: SaveData) -> int:
	if data == null:
		return 100
	if not Delivery.is_unlocked(data):
		return 0
	return clampi(data.wholesale_share, 0, 100)

## Cambia la quota e rimette subito d'accordo la riserva con la scorta di adesso.
##
## Il ritocco vale nei due versi: alzando la quota si mette da parte altra roba
## fra quella che c'è già, abbassandola se ne libera. Senza, la quota nuova
## varrebbe solo dal raccolto dopo, e chi abbassa la percentuale apposta per far
## vendere i dealer si ritroverebbe il magazzino bloccato come prima.
static func set_wholesale_share(data: SaveData, value: int) -> void:
	if data == null:
		return
	data.wholesale_share = clampi(value, 0, 100)
	retarget_reserve(data)

## Rifà la riserva sulla scorta di adesso, alla quota di adesso.
##
## Si chiama quando cambia la quota e quando l'ingrosso si apre: in quel secondo
## momento in magazzino c'è già un chilo, e senza questo i dealer se lo
## piazzerebbero tutto prima che la percentuale appena comparsa al PC voglia dire
## qualcosa.
static func retarget_reserve(data: SaveData) -> void:
	if data == null:
		return
	var stock := Economy.stock(data)
	data.wholesale_reserve = clampi(
		int(roundf(float(stock) * float(wholesale_share(data)) / 100.0)), 0, stock)

## Grammi che i dealer non devono toccare.
##
## Limitata alla scorta a ogni lettura invece di essere riscritta: vendendo di
## persona fino a scendere sotto la riserva, quella che resta è quella che c'è.
## Ne segue che le vendite del giocatore intaccano la riserva **per ultima**, ed
## è il verso giusto: la roba da parte è sua, non se la porta via da solo
## finché ha dell'altro da vendere.
static func reserved(data: SaveData) -> int:
	if data == null:
		return 0
	return clampi(data.wholesale_reserve, 0, Economy.stock(data))

## Grammi che i dealer possono piazzare in strada.
static func sellable(data: SaveData) -> int:
	if data == null:
		return 0
	return maxi(0, Economy.stock(data) - reserved(data))

## Mette da parte la quota di un raccolto appena entrato in magazzino.
##
## Va chiamata DOPO aver aggiunto i grammi alla scorta, perché la riserva non
## può superarla. Ci passano tutti e tre i modi di raccogliere — il vaso in
## cantina, "raccogli tutto" dal PC, il coltivatore assunto — perché mettere da
## parte è una proprietà del raccolto, non di chi ha impugnato le forbici.
static func reserve_harvest(data: SaveData, grams: int) -> void:
	if data == null or grams <= 0:
		return
	var share := wholesale_share(data)
	if share <= 0:
		return
	var put_aside := int(roundf(float(grams) * float(share) / 100.0))
	data.wholesale_reserve = clampi(
		data.wholesale_reserve + put_aside, 0, Economy.stock(data))

## Toglie dalla riserva la merce appena partita col furgone: è esattamente
## quello per cui era stata messa da parte.
static func release_reserved(data: SaveData, grams: int) -> void:
	if data == null or grams <= 0:
		return
	data.wholesale_reserve = maxi(0, data.wholesale_reserve - grams)

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
## senza lavoro sono quelli a paga fissa, e se ne va per primo chi costa di più
## — il coltivatore prima dell'autista — che è anche il verso giusto: è il costo
## fisso più alto quello che affonda una partita.
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

## Il lavoro dei coltivatori, posto per posto.
##
## Prima era un ciclo solo sui primi `coltivatori x 6` vasi dell'elenco, e con
## una stanza sola voleva dire la stessa cosa. Con due non piu': due assunti
## entrambi in cantina coprivano i vasi 0-11, cioe' anche i primi sei del
## garage, dove non c'era nessuno. Adesso ogni posto copre **la sua fetta**
## dell'elenco, e chi non ha nessuno assegnato non viene toccato.
static func _growers_work(data: SaveData, now: float, strain_base: Dictionary, report: Dictionary) -> void:
	if count(data, "grower") <= 0:
		return
	for site: Dictionary in GrowSites.all():
		if not GrowSites.is_open(data, site):
			continue
		var hands := growers_on(data, str(site["key"]))
		if hands <= 0:
			continue
		var from := int(site["from"])
		var covered := mini(hands * POTS_PER_GROWER, int(site["count"]))
		_work_pots(data, now, strain_base, report, from, from + covered)

static func _work_pots(
		data: SaveData, now: float, strain_base: Dictionary, report: Dictionary,
		from: int, to: int) -> void:
	var seed_item := Economy.seed_item(Economy.DEFAULT_STRAIN)
	for index in range(from, mini(to, data.plots.size())):
		var plot: Dictionary = data.plots[index]
		Grow.sync(plot, now)
		if Grow.is_ready(plot, now):
			var grams := Grow.harvest(plot, now)
			if grams > 0:
				data.add_item(Economy.PRODUCT, grams)
				reserve_harvest(data, grams)
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

## Piazza la merce in strada e restituisce le ore di lavoro davvero consumate.
##
## Solo in strada: l'ingrosso è il furgone, e il furgone è del giocatore. Quello
## che è messo da parte per un carico (`reserved()`) qui non si tocca, ed è tutta
## la differenza che fa la percentuale scelta al PC.
static func _dealers_work(data: SaveData, elapsed: float, report: Dictionary) -> float:
	var dealers := count(data, "dealer")
	if dealers <= 0 or elapsed <= 0.0:
		return elapsed
	var per_hour := float(dealers) * GRAMS_PER_DEALER_HOUR
	var free := sellable(data)
	var budget := mini(int(floorf(per_hour * elapsed)), free)
	if budget <= 0:
		# Niente che possano vendere: le ore non vanno tenute da parte, si sono
		# perse. Vale anche a magazzino pieno ma tutto da parte: quella merce non
		# è loro, e tenere le ore vorrebbe dire accumularle per una consegna che
		# non faranno mai.
		return elapsed if free <= 0 else 0.0
	# `budget >= free` è il caso del fondo di magazzino: meno della soglia ma non
	# ne arriverà altra, quindi va piazzato lo stesso invece di restare lì.
	if budget < MIN_BATCH_GRAMS and budget < free:
		return 0.0

	var gross := Economy.sell(
		data, budget, Economy.retail_price(data), Economy.street_heat(data))

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
