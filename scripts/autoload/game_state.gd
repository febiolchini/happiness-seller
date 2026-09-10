extends Node

## Autoload: unica fonte di verità sulla partita in corso, e gestore dei file
## di salvataggio su disco.
##
## Le scene non leggono/scrivono mai file: parlano con `GameState.current` e
## chiamano `save_game()`. Salvare diventa quindi solo "riversa su disco lo
## stato del singleton", senza andare a caccia di dati sparsi nell'albero.

## I salvataggi vanno in `user://`, la cartella dati dell'utente: `res://` in un
## gioco esportato è di sola lettura, quindi lì non si può scrivere.
const CITY_SCENE := "res://scenes/levels/City.tscn"
const DEFAULT_SAVE_DIR := "user://saves"
const EXTENSION := ".json"

## Ogni quanti secondi reali la partita si salva da sola mentre si gioca.
##
## Serve perché un gestionale si gioca a sessioni lunghe con poche uscite
## volontarie: si pianta qualcosa, si va in giro, si torna. Senza salvataggio
## automatico, chiudere il gioco in modo brusco butta via tutto quello che si è
## fatto dall'avvio, e il giocatore non ha modo di saperlo prima.
const AUTOSAVE_SECONDS := 45.0

## Cartella dei salvataggi.
##
## È una variabile e non una costante perché i controlli automatici devono
## poter scrivere altrove: girando sulla cartella vera riempirebbero l'elenco di
## partite finte e "riprendi" ne caricherebbe una di quelle invece della partita
## del giocatore.
var save_dir := DEFAULT_SAVE_DIR:
	set(value):
		save_dir = value
		DirAccess.make_dir_recursive_absolute(value)

## Minuti di gioco che passano per ogni secondo reale: a 4.0 una giornata dura
## 6 minuti veri. È il numero da girare per tarare il ritmo del gestionale, e va
## letto insieme a `Economy.STRAINS.grow_hours`: sono i due che insieme decidono
## quanto dura un ciclo di coltivazione in minuti di orologio da parete.
## A 4.0 le 30 ore di gioco di una pianta sono circa 7 minuti e mezzo reali.
const GAME_MINUTES_PER_SECOND := 4.0

signal game_started(data: SaveData)
signal game_saved(slot_id: String)
## Emesso quando scocca la mezzanotte e comincia un giorno nuovo: è il gancio
## per affitti, consegne, ricarico della merce e simili.
signal day_started(day: int)
## Messaggio breve da mostrare al giocatore ("+20 G HARVESTED"). L'HUD li
## impila in un angolo; chi lo emette non deve sapere come vengono mostrati.
signal notice(text: String)
## Emesso subito prima di scrivere su disco.
##
## Chi tiene in scena uno stato che non è ancora dentro a `current` lo riversa
## qui: la mappa, per esempio, sa dove sta il protagonista mentre `SaveData` no.
## Senza questo gancio un salvataggio automatico scriverebbe una posizione
## vecchia, e riprendendo la partita il protagonista ricomparirebbe dove stava
## qualche minuto prima.
signal saving()

## Partita attualmente in memoria, `null` quando siamo nei menu senza aver
## ancora caricato niente.
var current: SaveData = null
## Nome file (senza estensione) della partita in corso.
var current_slot := ""
## Mentre è true scorrono sia l'orologio di gioco sia il contatore delle ore
## giocate. La City lo accende entrando e lo spegne uscendo, così nei menu il
## tempo resta fermo.
var clock_running := false

## Secondi reali dall'ultimo salvataggio, per il salvataggio automatico.
var _since_autosave := 0.0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	day_started.connect(_on_day_started)

func _process(delta: float) -> void:
	if not clock_running or current == null:
		return
	current.play_time += delta
	_advance_clock(delta)

	# L'orologio gira solo mentre si gioca davvero (non nei menu), quindi
	# agganciare qui il salvataggio automatico vuol dire salvare solo quando
	# c'è qualcosa di nuovo da salvare.
	_since_autosave += delta
	if _since_autosave >= AUTOSAVE_SECONDS:
		save_game()

func _advance_clock(delta: float) -> void:
	current.time_of_day += delta * GAME_MINUTES_PER_SECOND / 60.0
	# `while` e non `if`: con un frame lungo (o un ritmo di gioco accelerato)
	# si può scavallare più di una mezzanotte in un colpo solo.
	while current.time_of_day >= 24.0:
		current.time_of_day -= 24.0
		current.day += 1
		day_started.emit(current.day)

## Ora di gioco assoluta dall'inizio della partita, in ore.
##
## È il tempo con cui ragiona la coltivazione: un vaso salva l'ora in cui è
## stato piantato e da quella si ricava lo stadio, quindi serve un numero che
## cresce sempre e non riparte da zero ogni mezzanotte come `time_of_day`.
func total_hours() -> float:
	if current == null:
		return 0.0
	return float(current.day - 1) * 24.0 + current.time_of_day

## Manda un messaggio breve all'HUD. Chi chiama non deve sapere se e come
## verrà mostrato: se un giorno i toast diventassero un log, cambia solo l'HUD.
func notify(text: String) -> void:
	notice.emit(text)

## La mezzanotte: prezzo del giorno nuovo e attenzione che si raffredda.
## La logica sta in `Economy`, qui c'è solo il collegamento — così il singleton
## dei salvataggi non si mette a sapere quanto costa un grammo.
func _on_day_started(_day: int) -> void:
	if current == null:
		return
	Economy.roll_new_day(current)
	# Il cambio di giorno è un punto di controllo naturale: è il momento in cui
	# cambiano prezzi e attenzione, ed è quello che il giocatore ricorda.
	save_game()

# --- Ciclo di vita della partita -------------------------------------------

## Inizia una campagna nuova e la salva subito, così compare fra i salvataggi
## anche se il giocatore chiude il gioco un secondo dopo.
func new_game() -> SaveData:
	var index := _next_campaign_index()
	current = SaveData.create_new("partita %d" % index)
	# I valori di partenza del gestionale (soldi, vasi, primi semi) li mette
	# `Economy`: `SaveData` è solo il formato, il bilanciamento sta altrove.
	Economy.setup_new_game(current)
	current_slot = _make_slot_id()
	save_game()
	game_started.emit(current)
	return current

## Riprende il salvataggio più recente presente sul dispositivo.
## Restituisce false se non ce n'è nessuno.
func continue_last() -> bool:
	var saves := list_saves()
	if saves.is_empty():
		return false
	return load_slot(saves[0]["slot_id"])

func load_slot(slot_id: String) -> bool:
	var raw := _read_save(_path_for(slot_id))
	if raw.is_empty():
		return false
	current = SaveData.from_dict(raw)
	current_slot = slot_id
	game_started.emit(current)
	return true

func save_game() -> bool:
	if current == null:
		push_warning("save_game() chiamato senza nessuna partita in corso.")
		return false
	if current_slot.is_empty():
		current_slot = _make_slot_id()
	# Prima di scrivere, chi ha dello stato vivo in scena lo riversa in `current`.
	saving.emit()
	current.saved_at = Time.get_unix_time_from_system()
	_since_autosave = 0.0
	var text := JSON.stringify(current.to_dict(), "\t")
	if not _write_atomic(_path_for(current_slot), text):
		push_error("Salvataggio fallito su %s" % _path_for(current_slot))
		return false
	game_saved.emit(current_slot)
	return true

func delete_slot(slot_id: String) -> bool:
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return false
	if dir.remove(slot_id + EXTENSION) != OK:
		return false
	# Se il giocatore cancella la partita che sta giocando, il singleton non
	# deve restare agganciato a uno slot che non esiste più.
	if slot_id == current_slot:
		current = null
		current_slot = ""
	return true

func has_any_save() -> bool:
	return not list_saves().is_empty()

## Riepilogo di ogni salvataggio presente, dal più recente al più vecchio.
## Serve alla schermata di gestione salvataggi.
func list_saves() -> Array:
	var saves: Array = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return saves
	for file_name in dir.get_files():
		if not file_name.ends_with(EXTENSION):
			continue
		var raw := _read_save(save_dir.path_join(file_name))
		if raw.is_empty():
			continue
		var data := SaveData.from_dict(raw)
		saves.append({
			"slot_id": file_name.trim_suffix(EXTENSION),
			"display_name": data.display_name,
			"chapter": data.chapter,
			"day": data.day,
			"cash": data.cash,
			"properties": data.property_count(),
			"play_time": data.play_time,
			"saved_at": data.saved_at,
		})
	# A parità di istante decide il nome dello slot, che contiene data e ora ed
	# è unico. Senza il secondo criterio "l'ultima partita" dipenderebbe
	# dall'ordine in cui il sistema elenca i file, e due salvataggi scritti
	# nello stesso secondo si scambierebbero di posto fra un avvio e l'altro.
	saves.sort_custom(func(a, b):
		if not is_equal_approx(a["saved_at"], b["saved_at"]):
			return a["saved_at"] > b["saved_at"]
		return a["slot_id"] > b["slot_id"])
	return saves

## Scena da aprire per riprendere la partita: la stanza in cui si era, oppure
## la strada. Se il salvataggio punta a una stanza che nel frattempo è stata
## rinominata o cancellata si torna fuori invece di schiantarsi.
func scene_for_current_state() -> String:
	if current != null and not current.current_room.is_empty():
		if ResourceLoader.exists(current.current_room):
			return current.current_room
		push_warning("La stanza salvata non esiste più: %s" % current.current_room)
	return CITY_SCENE

# --- Economia ---------------------------------------------------------------

func add_cash(amount: int) -> void:
	if current == null:
		return
	current.cash += amount

func can_afford(cost: int) -> bool:
	return current != null and current.cash >= cost

## Scala il costo solo se i soldi bastano. Restituisce false se non bastavano,
## così chi chiama può mostrare un messaggio invece di mandare il conto in rosso.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	current.cash -= cost
	return true

# --- File -------------------------------------------------------------------

func _path_for(slot_id: String) -> String:
	return save_dir.path_join(slot_id + EXTENSION)

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Impossibile aprire %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Salvataggio illeggibile: %s" % path)
		return {}
	return parsed

## Scrive prima su un file temporaneo e solo dopo sostituisce quello buono: se
## il gioco crasha o va via la corrente a metà scrittura, la partita precedente
## resta intatta invece di diventare un file troncato e illeggibile.
func _write_atomic(path: String, text: String) -> bool:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Impossibile scrivere %s" % tmp_path)
		return false
	file.store_string(text)
	file.close()

	var dir := DirAccess.open(save_dir)
	if dir == null:
		return false
	var final_name := path.get_file()
	var tmp_name := tmp_path.get_file()
	if dir.file_exists(final_name) and dir.remove(final_name) != OK:
		return false
	return dir.rename(tmp_name, final_name) == OK

## Id univoco e ordinabile, con data e ora: "partita_20260907_114400".
## Niente ':' nel nome, altrimenti su Windows il file non si può creare.
func _make_slot_id() -> String:
	var now := Time.get_datetime_dict_from_system()
	var base := "partita_%04d%02d%02d_%02d%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
	var slot_id := base
	var suffix := 2
	while FileAccess.file_exists(_path_for(slot_id)):
		slot_id = "%s_%d" % [base, suffix]
		suffix += 1
	return slot_id

## Numero progressivo per il nome mostrato ("partita 1", "partita 2", ...).
func _next_campaign_index() -> int:
	return list_saves().size() + 1
