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
		"heat": heat,
		"properties": properties,
		"reputation": reputation,
		"npc_state": npc_state,
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
	data.heat = float(source.get("heat", 0.0))
	data.properties = _restore_ints(source.get("properties", {}))
	data.reputation = _restore_ints(source.get("reputation", {}))
	data.npc_state = _restore_ints(source.get("npc_state", {}))
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
		result.append({
			"strain": str(plot.get("strain", "regular")),
			"planted_at": float(plot.get("planted_at", 0.0)),
			"watered_at": float(plot.get("watered_at", 0.0)),
			"checked_at": float(plot.get("checked_at", 0.0)),
			"dry_hours": float(plot.get("dry_hours", 0.0)),
		})
	return result

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
