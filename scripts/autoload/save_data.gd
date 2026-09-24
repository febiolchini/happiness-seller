class_name SaveData
extends Resource

## Stato completo di una partita in singolo: tutto ciò che serve per riprendere
## la campagna esattamente dov'era. Qui dentro ci sono SOLO DATI, mai nodi:
## la scena viene ricostruita leggendo questi valori, non salvata così com'è.
##
## Aggiungere roba in futuro è la norma, quindi il formato è pensato per reggere:
## `from_dict()` legge ogni campo con un default, così un salvataggio vecchio a
## cui manca una chiave nuova si carica lo stesso invece di rompersi.

## Va alzata SOLO quando cambia la *struttura* del salvataggio in modo che i
## vecchi file non siano più interpretabili così com'è (es. un campo cambia
## significato o tipo). Aggiungere un campo nuovo non richiede di alzarla.
const CURRENT_VERSION := 1

## Fazioni con cui il giocatore ha una reputazione. Aggiungerne una qui è
## sufficiente: i salvataggi vecchi la vedranno semplicemente a 0.
const FACTIONS := ["strada", "polizia", "vicinato"]

# --- Identità del salvataggio ---------------------------------------------
@export var version := CURRENT_VERSION
@export var display_name := ""
@export var created_at := 0
## Istante dell'ultimo salvataggio. È un float e non un intero: serve la
## precisione sotto il secondo per sapere quale sia davvero l'ultima partita
## quando se ne salvano due di fila.
@export var saved_at := 0.0
## Secondi di gioco effettivo, per mostrarli nella gestione salvataggi.
@export var play_time := 0.0

# --- Storia ----------------------------------------------------------------
## Capitolo/tappa corrente della storyline.
@export var chapter := "prologo"
## Flag liberi della storia: "ha_conosciuto_x" -> true, "scelta_y" -> "opzione_b".
## Dizionario apposta, così aggiungere un evento non richiede di toccare questa classe.
@export var story_flags: Dictionary = {}
## Id dei dialoghi già visti, per non ripeterli.
@export var dialogues_seen: Array = []

# --- Economia --------------------------------------------------------------
@export var cash := 0
@export var debt := 0
## Merce in mano: "id_prodotto" -> quantità. Grammi per l'erba (`Economy.PRODUCT`),
## pezzi per i semi ("seed_regular").
@export var inventory: Dictionary = {}
## Prezzo al grammo di oggi. Lo tira `Economy.roll_new_day()` a ogni mezzanotte:
## è salvato e non ricalcolato, altrimenti ricaricando la partita il mercato
## cambierebbe sotto il naso al giocatore.
@export var market_price := 10

# --- Coltivazione ----------------------------------------------------------
## I vasi del seminterrato, uno per elemento. Un vaso vuoto è un dizionario
## vuoto; i campi di uno piantato sono documentati in `Grow`.
##
## Volutamente `Array` di `Dictionary` e non una classe: la crescita è una
## funzione pura del tempo (vedi `Grow`), quindi qui basta salvare i timestamp.
@export var plots: Array = []
## Quanti vasi sono sbloccati. Il valore di partenza vero lo mette
## `Economy.setup_new_game()`; questo è solo la rete per i salvataggi vecchi,
## che non avevano il campo.
@export var plot_slots := 3

# --- Negozio online --------------------------------------------------------
## Attrezzatura comprata dal PC: "id" -> quanti pezzi. Il catalogo e gli effetti
## stanno in `Shop`, qui c'è solo il conto. Una partita di prima del negozio si
## carica con il dizionario vuoto, cioè senza niente addosso.
@export var upgrades: Dictionary = {}

# --- Personale -------------------------------------------------------------
## Organico assunto: "ruolo" -> quanti. I ruoli sono in `Staff.ROLES`.
@export var staff: Dictionary = {}
## Dove lavorano i coltivatori: "chiave del posto" -> quanti. Le chiavi sono in
## `GrowSites.SITES`, e la somma non puo' superare i coltivatori assunti.
##
## Sta a parte da `staff` e non dentro, perche' sono due domande diverse: quanti
## ne paghi e dove li mandi. I dealer non compaiono qui — la strada e' una sola.
@export var grower_sites: Dictionary = {}
## Quota del raccolto messa da parte per l'ingrosso, 0-100. Il resto è quello
## che i dealer possono piazzare in strada. Vedi `Staff.wholesale_share()`.
@export var wholesale_share := 100
## Grammi della scorta messi da parte per l'ingrosso: i dealer non li toccano,
## li muove solo il giocatore col furgone.
##
## È un numero e non una percentuale ricalcolata al volo, e deve esserlo: una
## quota ricalcolata sulla scorta si ridurrebbe a ogni vendita dei dealer — il
## 30% di quel che resta, poi il 30% di quel che resta ancora — e la riserva si
## svuoterebbe da sola fino a zero. Cresce a ogni raccolto e cala solo quando
## parte un carico. Vedi `Staff.reserved()`.
@export var wholesale_reserve := 0
## Fin dove è già stato contato il lavoro del personale, in ore di gioco
## assolute. Come i vasi, il lavoro non è simulato: si guarda che ore sono
## adesso e si fa quello che nel frattempo andava fatto (vedi `Staff.work()`).
@export var staff_checked_at := 0.0

# --- Semi ------------------------------------------------------------------
## L'appuntamento con Brian per comprare i semi, vuoto quando non ce n'è uno in
## ballo. I campi sono documentati in `SeedDeal`, che è anche l'unico posto da
## cui questo dizionario va toccato.
##
## Come i vasi, dentro ci sono ore di gioco e coordinate: è salvato con i cast
## espliciti (`_deal_from_dict()`) e non passa da `_restore_ints()`, che
## arrotonderebbe un `ready_at` di 26.5 perdendo la mezz'ora.
@export var seed_deal: Dictionary = {}

# --- Ingrosso --------------------------------------------------------------
## Il viaggio del furgone in corso, vuoto quando è fermo. I campi sono
## documentati in `Delivery`, che è anche l'unico posto da cui va toccato.
##
## Come i vasi e l'appuntamento con Brian, dentro ci sono ore di gioco: è
## salvato con i cast espliciti (`_run_from_dict()`) e non passa da
## `_restore_ints()`, che arrotonderebbe un `back_at` di 26.5 perdendo la
## mezz'ora.
@export var van_run: Dictionary = {}
## Consegne che restano nel serbatoio. Si riempie comprando il furgone e
## facendo il pieno: vedi `Delivery.TANK_RUNS`.
@export var van_fuel := 0

## Il viaggio dal grossista dei semi, vuoto quando il furgone è fermo. Stesso
## mezzo e stessa forma di `van_run`, altro carico: i campi li documenta
## `SeedRun`, che è l'unico posto da cui va toccato.
##
## È un campo a parte e non lo stesso `van_run` perché i due viaggi portano cose
## diverse e finiscono in modo diverso — uno torna con i soldi, l'altro con i
## semi. Che non possano essere in corso tutti e due insieme è una regola del
## gioco (`SeedRun.can_order()`), non un vincolo della struttura dati.
@export var seed_run: Dictionary = {}

# --- Messaggi --------------------------------------------------------------
## La cronologia della chat del telefono: i messaggi dei traguardi, quelli che
## il giocatore deve poter rileggere a distanza di giorni.
##
## **Dentro ci sono chiavi di traduzione, non frasi.** Una riga e'
## `{"contact": "brian", "key": "MSG_KILO_BODY", "arg": "", "at": 53.5}`: il
## testo lo tira fuori `Chat.body()` al momento di mostrarlo. Salvare la frase
## gia' scritta vorrebbe dire che una partita cominciata in italiano resta in
## italiano anche cambiando lingua dalle impostazioni, e la cronologia sarebbe
## l'unico posto del gioco a farlo.
##
## Quello che NON ci finisce e' il giro della richiesta di semi: quello si
## ricava dall'appuntamento (`Chat.live()`), e per questo si cancella da solo.
## Vedi `Chat`, che e' anche l'unico posto da cui questo array va toccato.
@export var chat_log: Array = []

# --- Bollette --------------------------------------------------------------
## Giorno in cui è stata pagata l'ultima bolletta della luce. La prossima scade
## `Economy.BILL_DAYS` giorni dopo. Si salva il giorno e non un conto alla
## rovescia per lo stesso motivo di tutto il resto: un traguardo si ritrova
## intatto ricaricando, un contatore va tenuto in vita da qualcuno.
@export var power_billed_day := 1

# --- L'organizzazione -----------------------------------------------------
## Il nome dell'attività. Vuoto finché Brian non lo chiede, al primo assunto:
## è lì che da uno che vende si diventa un'organizzazione. Vedi `Prestige`.
@export var org_name := ""
## I punti prestigio. Come si guadagnano non è ancora deciso: vedi `Prestige`.
@export var prestige := 0

# --- Attenzione della polizia ---------------------------------------------
## 0-100. Sale vendendo in strada, scende ogni notte. Vedi `Economy`.
@export var heat := 0.0

# --- Proprietà -------------------------------------------------------------
## "id_edificio" -> { "livello": int, "acquisito_il": int, ... }.
## Le chiavi corrispondono ai nomi dei nodi in City.tscn (TrailerCamp, Condo, ...).
@export var properties: Dictionary = {}

# --- Reputazione -----------------------------------------------------------
## "fazione" -> valore. Vedi FACTIONS.
@export var reputation: Dictionary = {}

# --- NPC -------------------------------------------------------------------
## Stato minimo dei personaggi di strada: "id" -> { "day": int, "bought": int }.
## Ci finisce solo quello che NON si può ricavare: quanto ha già comprato oggi
## un cliente. La domanda del giorno invece è deterministica e non si salva
## (vedi `Economy.street_demand()`).
@export var npc_state: Dictionary = {}

# --- Mondo e giocatore -----------------------------------------------------
## Che tempo fa oggi. Lo tira `Economy.roll_new_day()` a ogni mezzanotte, come
## il prezzo: è salvato e non ricalcolato, altrimenti un ritocco alla tabella
## del meteo cambierebbe il tempo di tutte le partite già salvate, e "il giorno
## che pioveva" diventerebbe un altro giorno. Le chiavi sono in `Weather.TYPES`.
@export var weather := Weather.DEFAULT
@export var day := 1
## Ora del giorno in formato 0.0 - 24.0.
@export var time_of_day := 8.0
@export var player_position := Vector2(320, 264)
## Scena della stanza in cui si è, "" quando si è fuori in strada. Serve a
## riprendere la partita esattamente dove la si era lasciata, anche dentro casa.
@export var current_room := ""

## Contatori liberi per statistiche e achievement futuri.
@export var stats: Dictionary = {}

## Partita nuova di zecca.
static func create_new(name: String) -> SaveData:
	var data := SaveData.new()
	var now := int(Time.get_unix_time_from_system())
	data.display_name = name
	data.created_at = now
	data.saved_at = now
	for faction in FACTIONS:
		data.reputation[faction] = 0
	return data

# --- Comodità ---------------------------------------------------------------

func get_flag(flag: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag, default_value)

func set_flag(flag: String, value: Variant = true) -> void:
	story_flags[flag] = value

func has_seen_dialogue(id: String) -> bool:
	return id in dialogues_seen

func mark_dialogue_seen(id: String) -> void:
	if not has_seen_dialogue(id):
		dialogues_seen.append(id)

func get_reputation(faction: String) -> int:
	return int(reputation.get(faction, 0))

func change_reputation(faction: String, amount: int) -> void:
	reputation[faction] = get_reputation(faction) + amount

func get_item(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func add_item(item_id: String, amount: int) -> void:
	var total := get_item(item_id) + amount
	if total <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = total

func owns(building_id: String) -> bool:
	return properties.has(building_id)

func property_count() -> int:
	return properties.size()

func bump_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount

func get_stat(key: String) -> int:
	return int(stats.get(key, 0))

## Allinea l'array dei vasi al numero di vasi sbloccati.
##
## Solo in aggiunta, mai in sottrazione: se un salvataggio arriva con più vasi
## di quanti ne risultino sbloccati (un ritocco al bilanciamento, una partita
## di una versione diversa) le piante che ci stanno dentro non si buttano via.
func ensure_plots() -> void:
	while plots.size() < plot_slots:
		plots.append({})
	if plots.size() > plot_slots:
		plot_slots = plots.size()

## Il vaso all'indice dato, `{}` se l'indice è fuori dai vasi sbloccati.
## Il dizionario è quello vero, non una copia: modificarlo modifica la partita.
func plot(index: int) -> Dictionary:
	if index < 0 or index >= plots.size():
		return {}
	return plots[index]

# --- Serializzazione --------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": version,
		"display_name": display_name,
		"created_at": created_at,
		"saved_at": saved_at,
		"play_time": play_time,
		"chapter": chapter,
		"story_flags": story_flags,
		"dialogues_seen": dialogues_seen,
		"cash": cash,
		"debt": debt,
		"inventory": inventory,
		"market_price": market_price,
		"plots": plots,
		"plot_slots": plot_slots,
		"upgrades": upgrades,
		"staff": staff,
		"grower_sites": grower_sites,
		"wholesale_share": wholesale_share,
		"wholesale_reserve": wholesale_reserve,
		"staff_checked_at": staff_checked_at,
		"seed_deal": seed_deal,
		"van_run": van_run,
		"van_fuel": van_fuel,
		"seed_run": seed_run,
		"chat_log": chat_log,
		"power_billed_day": power_billed_day,
		"heat": heat,
		"org_name": org_name,
		"prestige": prestige,
		"properties": properties,
		"reputation": reputation,
		"npc_state": npc_state,
		"weather": weather,
		"day": day,
		"time_of_day": time_of_day,
		# Il JSON non conosce Vector2: lo salviamo come coppia di numeri.
		"player_position": [player_position.x, player_position.y],
		"current_room": current_room,
		"stats": stats,
	}

## Ricostruisce una partita da un dizionario letto da JSON.
##
## Attenzione ai cast a int: il parser JSON restituisce *sempre* numeri float,
## quindi senza `int()` i soldi diventerebbero 1250.0 e stamperebbero male.
static func from_dict(raw: Dictionary) -> SaveData:
	var source := _migrate(raw)
	var data := SaveData.new()
	data.version = int(source.get("version", CURRENT_VERSION))
	data.display_name = str(source.get("display_name", ""))
	data.created_at = int(source.get("created_at", 0))
	data.saved_at = float(source.get("saved_at", 0.0))
	data.play_time = float(source.get("play_time", 0.0))
	data.chapter = str(source.get("chapter", "prologo"))
	data.story_flags = _restore_ints(source.get("story_flags", {}))
	data.dialogues_seen = source.get("dialogues_seen", [])
	data.cash = int(source.get("cash", 0))
	data.debt = int(source.get("debt", 0))
	data.inventory = _restore_ints(source.get("inventory", {}))
	data.market_price = int(source.get("market_price", 10))
	# I vasi NON passano da `_restore_ints()`: dentro ci sono ore di gioco, e un
	# `planted_at` di 48.0 tornerebbe intero perdendo i minuti. Hanno una loro
	# conversione con i cast espliciti.
	data.plots = _plots_from_array(source.get("plots", []))
	data.plot_slots = int(source.get("plot_slots", 3))
	data.upgrades = _restore_ints(source.get("upgrades", {}))
	data.staff = _restore_ints(source.get("staff", {}))
	data.grower_sites = _restore_ints(source.get("grower_sites", {}))
	data.wholesale_share = clampi(int(source.get("wholesale_share", 100)), 0, 100)
	data.wholesale_reserve = maxi(0, int(source.get("wholesale_reserve", 0)))
	# Ore di gioco, quindi float esplicito e non `_restore_ints()`: un
	# `staff_checked_at` di 26.5 tornerebbe intero perdendo la mezz'ora.
	data.staff_checked_at = float(source.get("staff_checked_at", 0.0))
	data.seed_deal = _deal_from_dict(source.get("seed_deal", {}))
	# Un salvataggio di prima delle bollette parte dal giorno in cui si trova,
	# non dal giorno 1: altrimenti si beccherebbe un mese arretrato di colpo.
	data.van_run = _run_from_dict(source.get("van_run", {}))
	data.van_fuel = int(source.get("van_fuel", 0))
	data.seed_run = _seed_run_from_dict(source.get("seed_run", {}))
	data.chat_log = _chat_from_array(source.get("chat_log", []))
	data.power_billed_day = int(source.get("power_billed_day", source.get("day", 1)))
	data.heat = float(source.get("heat", 0.0))
	data.org_name = str(source.get("org_name", ""))
	data.prestige = int(source.get("prestige", 0))
	data.properties = _restore_ints(source.get("properties", {}))
	data.reputation = _restore_ints(source.get("reputation", {}))
	data.npc_state = _restore_ints(source.get("npc_state", {}))
	# Un salvataggio di prima del meteo non ha il campo: parte da sereno invece
	# che da una stringa vuota, che non sarebbe un tempo.
	data.weather = str(source.get("weather", Weather.DEFAULT))
	data.day = int(source.get("day", 1))
	data.time_of_day = float(source.get("time_of_day", 8.0))
	data.current_room = str(source.get("current_room", ""))
	data.stats = _restore_ints(source.get("stats", {}))

	var pos: Array = source.get("player_position", [320, 264])
	if pos.size() == 2:
		data.player_position = Vector2(float(pos[0]), float(pos[1]))

	# Una fazione aggiunta dopo che la partita era già iniziata parte da 0.
	for faction in FACTIONS:
		if not data.reputation.has(faction):
			data.reputation[faction] = 0
	# Un salvataggio di prima della coltivazione non ha vasi: glieli diamo qui,
	# vuoti, invece di far trovare un array corto a chi legge `plots[2]`.
	data.ensure_plots()
	return data

## Ricostruisce i vasi con i cast espliciti: le ore di gioco sono float e devono
## restare float, i grammi e gli indici interi devono restare interi.
static func _plots_from_array(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY or (item as Dictionary).is_empty():
			result.append({})
			continue
		var plot: Dictionary = item
		var restored := {
			"strain": str(plot.get("strain", "regular")),
			"planted_at": float(plot.get("planted_at", 0.0)),
			"watered_at": float(plot.get("watered_at", 0.0)),
			"checked_at": float(plot.get("checked_at", 0.0)),
			"dry_hours": float(plot.get("dry_hours", 0.0)),
		}
		# Fotografia dell'attrezzatura al momento della semina (vedi `Grow`).
		# Le chiavi si copiano solo se c'erano: una pianta messa prima del
		# negozio non ne ha, e `Grow` ricade da solo sui valori della varietà.
		# Il default NON si mette qui, perché vorrebbe dire far conoscere a
		# `SaveData` la tabella delle varietà.
		if plot.has("hours"):
			restored["hours"] = float(plot["hours"])
		if plot.has("grams"):
			restored["grams"] = int(plot["grams"])
		result.append(restored)
	return result

## Ricostruisce il viaggio del furgone coi cast espliciti, per lo stesso motivo
## dei vasi: le ore di gioco devono restare float, i grammi e i soldi interi.
static func _run_from_dict(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return {}
	var run: Dictionary = raw
	return {
		"grams": int(run.get("grams", 0)),
		"value": int(run.get("value", 0)),
		"left_at": float(run.get("left_at", 0.0)),
		"back_at": float(run.get("back_at", 0.0)),
	}

## Ricostruisce la cronologia della chat coi cast espliciti, per lo stesso
## motivo dei vasi: `at` e' un'ora di gioco e deve restare float, altrimenti
## `_restore_ints()` arrotonderebbe un messaggio arrivato alle 53.5 e due
## messaggi dello stesso pomeriggio finirebbero in ordine sbagliato.
##
## Le righe senza chiave si buttano: una cronologia e' fatta di messaggi, e una
## riga che non sa cosa dire non e' un messaggio.
static func _chat_from_array(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("key", "")).is_empty():
			continue
		result.append({
			"contact": str(row.get("contact", "")),
			"from": str(row.get("from", "them")),
			"key": str(row.get("key", "")),
			"arg": str(row.get("arg", "")),
			"at": float(row.get("at", 0.0)),
		})
	return result

## Come `_run_from_dict()`, per il viaggio dei semi: le ore restano float e i
## semi interi. Un salvataggio di prima che il grossista esistesse non ha il
## campo, e torna vuoto — cioè furgone fermo, che è la cosa giusta.
static func _seed_run_from_dict(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return {}
	var run: Dictionary = raw
	return {
		"seeds": int(run.get("seeds", 0)),
		"strain": str(run.get("strain", Economy.DEFAULT_STRAIN)),
		"left_at": float(run.get("left_at", 0.0)),
		"back_at": float(run.get("back_at", 0.0)),
	}

## Ricostruisce l'appuntamento con Brian coi cast espliciti, per lo stesso
## motivo dei vasi: le ore di gioco e le coordinate devono restare float, i semi
## rimasti interi. Un salvataggio senza appuntamento, o con un dizionario vuoto,
## torna vuoto.
static func _deal_from_dict(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return {}
	var deal: Dictionary = raw
	return {
		"state": str(deal.get("state", "waiting")),
		"asked_at": float(deal.get("asked_at", 0.0)),
		"ready_at": float(deal.get("ready_at", 0.0)),
		"expires_at": float(deal.get("expires_at", 0.0)),
		"spot_x": float(deal.get("spot_x", 0.0)),
		"spot_y": float(deal.get("spot_y", 0.0)),
		"place": str(deal.get("place", "")),
		"warned": bool(deal.get("warned", false)),
		"seeds": int(deal.get("seeds", 0)),
	}

## Il parser JSON restituisce ogni numero come float, anche dentro ai dizionari
## liberi: senza questo passaggio 30 grammi di merce tornerebbero come "30.0" e
## finirebbero stampati così a schermo. Qui i float senza parte decimale tornano
## interi, ricorsivamente.
##
## Nota: se un giorno servirà tenere in questi dizionari un float che vale un
## numero tondo (es. un moltiplicatore 2.0), va messo in un campo tipizzato suo
## invece che qui dentro, altrimenti si ritrova come int 2.
static func _restore_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if is_equal_approx(value, floorf(value)) else value
		TYPE_DICTIONARY:
			var result := {}
			for key in value:
				result[key] = _restore_ints(value[key])
			return result
		TYPE_ARRAY:
			var list := []
			for item in value:
				list.append(_restore_ints(item))
			return list
	return value

## Porta un salvataggio vecchio al formato corrente.
## Per ora c'è solo la versione 1, ma il gancio esiste già: quando servirà una
## migrazione basterà aggiungere un `if version < 2: ...` qui dentro.
static func _migrate(raw: Dictionary) -> Dictionary:
	var version_found := int(raw.get("version", 1))
	if version_found > CURRENT_VERSION:
		push_warning("Salvataggio in versione %d, più recente di quella supportata (%d): potrebbe caricarsi male." % [version_found, CURRENT_VERSION])
	return raw
