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
const PHONE_NOTICE_SCENE := "res://scenes/ui/PhoneNotice.tscn"
const VAN_CUTSCENE_SCENE := "res://scenes/ui/VanCutscene.tscn"
const GUIDE_SCENE := "res://scenes/ui/GuideBook.tscn"
const DEFAULT_SAVE_DIR := "user://saves"
const EXTENSION := ".json"

## Ogni quanti secondi reali la partita si salva da sola mentre si gioca.
##
## Serve perché un gestionale si gioca a sessioni lunghe con poche uscite
## volontarie: si pianta qualcosa, si va in giro, si torna. Senza salvataggio
## automatico, chiudere il gioco in modo brusco butta via tutto quello che si è
## fatto dall'avvio, e il giocatore non ha modo di saperlo prima.
const AUTOSAVE_SECONDS := 45.0

## La freccia fra l'ora di chiusura e quella di riapertura nel resoconto.
## Non passa dalle traduzioni: è un segno, non una parola, e tradotto
## diventerebbe una frase diversa in ogni lingua per dire la stessa cosa.
const AWAY_ARROW := "->"

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
## A 4.0 le 29 ore di gioco di una pianta sono circa 7 minuti reali.
const GAME_MINUTES_PER_SECOND := 4.0

signal game_started(data: SaveData)
signal game_saved(slot_id: String)
## Emesso quando scocca la mezzanotte e comincia un giorno nuovo: è il gancio
## per affitti, consegne, ricarico della merce e simili.
signal day_started(day: int)
## Messaggio breve da mostrare al giocatore ("+20 G HARVESTED"). L'HUD li
## impila in un angolo; chi lo emette non deve sapere come vengono mostrati.
signal notice(text: String)
## Un messaggio **da qualcuno**, che arriva sul telefono in basso a sinistra.
##
## Diverso da `notice`: quello è il gioco che segna un fatto con la coda
## dell'occhio, questo è una persona che scrive e ha un mittente. E diverso da
## `message()`, che ferma tutto con un riquadro a tutto schermo per le cose che
## non si possono perdere. Vedi `scripts/ui/phone.gd`.
signal phone_message(sender: String, body: String)
## Il furgone è appena partito per una consegna, o è appena rientrato.
## Ci si aggancia `city.gd` per farlo attraversare la strada; chi non è in
## strada in quel momento si perde l'animazione e legge il messaggino, che è
## quanto basta.
signal van_left(grams: int)
signal van_back(revenue: int)

## Il furgone è partito per il grossista dei semi, e ne è rientrato coi semi.
## Servono alla City per far muovere il mezzo: sono due segnali a parte e non
## `van_left`/`van_back` perché quelli portano grammi e incassi, e chi li
## ascolta li usa per dire cosa è successo.
signal seed_run_left(seeds: int)
signal seed_run_back(seeds: int)
## Il furgone è partito per il contatto fuori stato di Kevin, e ne è rientrato
## coi semi. Stessa ragione di `seed_run_left`/`seed_run_back`: è lo stesso
## mezzo, un altro fornitore. Vedi `BusImport`.
signal bus_order_left(seeds: int)
signal bus_order_back(seeds: int)
## Brian ha mandato la posizione: da qui in poi c'è un appuntamento sulla mappa.
## Ci si aggancia `city.gd` per tirarlo su dove aspetta.
signal seed_spot_ready(spot: Vector2, place: String)
## L'appuntamento è chiuso — comprato tutto, oppure Brian si è stancato di
## aspettare e se n'è andato. La mappa toglie il personaggio.
signal seed_deal_closed()
## Il prologo è finito: da qui in poi il PC ha la scheda del personale.
## Ci si può agganciare la storia, quando ci sarà.
signal chapter_changed(chapter: String)

## Una proprietà è stata comprata dall'agenzia.
##
## Serve ai segnalini sopra agli edifici (`enterable_building.gd`): un edificio
## appena comprato passa da "non è tuo" a "è tuo" e deve cambiare colore subito,
## non alla prossima volta che si entra in città. Il segnale porta l'id perché
## chi ascolta possa saltare il ridisegno se non lo riguarda.
signal property_bought(id: String)
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

## L'ultimo messaggio arrivato sul telefono: `{"sender": ..., "body": ...}`.
##
## Vive qui e non dentro al telefono perché il telefono è per scena — ce n'è uno
## in strada e uno in ogni stanza — e un messaggio arrivato in cantina deve
## potersi rileggere uscendo di casa. Non finisce nel salvataggio: è quello che
## è appena successo, non un pezzo di partita.
var last_text: Dictionary = {}

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
	_tick_seed_deal()
	_tick_staff()
	_tick_van()
	_tick_seed_run()
	_tick_bus_order()
	_check_intro()
	_check_prologue()
	_check_milestones()

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

## Manda un messaggio sul telefono, da parte di qualcuno.
##
## Se in scena non c'è nessun telefono — il menu principale — non succede
## niente, e va bene così: il messaggio resta in `last_text` e si legge appena
## si rientra in partita.
func text_message(sender: String, body: String, contact := "") -> void:
	last_text = {"sender": sender, "body": body, "contact": contact}
	phone_message.emit(sender, body)

## Un messaggio da qualcuno che sta in rubrica: arriva sul telefono come tutti
## gli altri, **e resta nella sua chat**.
##
## È la differenza fra i due modi di scrivere al giocatore, e non è una
## sfumatura: `text_message()` è un avviso e basta — lo si legge quando arriva e
## poi è andato — mentre quello che passa di qui si rilegge aprendo il telefono
## anche tre giorni dopo. Ci vanno **i traguardi**: l'apertura, la fine del
## prologo, il consiglio di allargarsi, il chilo, il grossista. Sono le cose che
## dicono al giocatore cos'è cambiato nel gioco, ed è esattamente la roba che
## uno vuole poter riguardare.
##
## Non ci vanno invece i messaggi dell'appuntamento coi semi, che pure sono di
## Brian: quelli nella chat ci compaiono lo stesso, ma ricavati
## dall'appuntamento (`Chat.live()`), e spariscono quando l'appuntamento si
## chiude. Vedi `Chat`.
##
## Si passa la **chiave** e non la frase: la cronologia è fatta di chiavi, così
## cambiando lingua cambiano anche i messaggi vecchi.
func contact_message(contact: String, key: String, arg := "") -> void:
	if current == null:
		return
	var row := {"contact": contact, "from": Chat.THEM, "key": key, "arg": arg}
	Chat.keep(current, contact, key, arg, total_hours())
	text_message(tr(Chat.name_key(contact)), Chat.body(row), contact)

## Porta avanti l'appuntamento con Brian e avvisa quando cambia qualcosa.
##
## Sta agganciato all'orologio e non a un timer suo: l'attesa è misurata in ore
## di gioco, quindi deve scorrere quando scorre quello — dentro alle stanze e
## col gestionale aperto sì, nei menu no. Come per la coltivazione, il conto non
## è simulato: `SeedDeal.tick()` guarda che ore sono adesso.
func _tick_seed_deal() -> void:
	match SeedDeal.tick(current, total_hours()):
		SeedDeal.STATE_READY:
			var place := SeedDeal.place(current)
			notify(tr("NOTE_BRIAN_SPOT") % place)
			text_message(tr("MSG_COUSIN_SPEAKER"), tr("PHONE_BRIAN_READY") % place,
				Chat.BRIAN)
			seed_spot_ready.emit(SeedDeal.spot(current), place)
			# Un appuntamento fissato è roba che il giocatore ricorda: se il
			# gioco si chiude male, riaprirlo deve ritrovarlo, non farglielo
			# richiedere da capo.
			save_game()
		SeedDeal.EVENT_LEAVING:
			# Sul telefono e non fra i messaggini: è una cosa che qualcuno dice,
			# e soprattutto non deve sparire dopo due secondi e mezzo mentre si
			# sta guardando altrove. Vedi `scripts/ui/phone.gd`.
			text_message(tr("MSG_COUSIN_SPEAKER"), tr("PHONE_BRIAN_LEAVING"), Chat.BRIAN)
		SeedDeal.EVENT_GONE:
			notify(tr("NOTE_BRIAN_LEFT"))
			seed_deal_closed.emit()

## Fa lavorare il personale assunto.
##
## Come l'appuntamento con Brian, sta agganciato all'orologio e non a un timer
## suo: il lavoro è misurato in ore di gioco, quindi deve scorrere quando scorre
## quello. Il conto non è simulato — `Staff.work()` guarda che ore sono adesso.
func _tick_staff() -> void:
	if Staff.total(current) <= 0:
		# Anche senza nessuno assunto il segnaposto del tempo va portato avanti,
		# altrimenti il primo assunto si troverebbe addosso tutte le ore passate
		# dall'inizio della partita.
		current.staff_checked_at = total_hours()
		return
	var strain := Economy.strain(Economy.DEFAULT_STRAIN)
	# Di listino, non gia' scontati: la lampada e' un effetto per vaso, e
	# `Staff._growers_work()` la calcola vaso per vaso perche' ogni coltivatore
	# ne segue piu' d'uno. Vedi `Staff.work()`.
	var base := {"hours": strain["grow_hours"], "grams": strain["grams"]}
	var report := Staff.work(current, total_hours(), base)
	if Staff.seedless_alert(current, int(report["idle"])):
		text_message(tr("MSG_STAFF_SPEAKER"), tr("PHONE_SEEDS_OUT"))
	if int(report["grams"]) > 0:
		notify(tr("NOTE_STAFF_HARVESTED") % int(report["grams"]))
	if int(report["revenue"]) > 0:
		notify(tr("NOTE_STAFF_SOLD") % [UiFormat.money(int(report["revenue"])), int(report["sold"])])

## La prima volta che si arriva a `Economy.PROLOGUE_CASH` il prologo si chiude:
## il cugino si fa vivo e nel PC compare la scheda del personale.
##
## Il controllo sta qui e non dentro alla vendita perché i soldi entrano da
## troppe parti — il PC, i clienti in strada, un domani gli affitti — e
## ricordarsi di chiamarlo da ognuna vorrebbe dire dimenticarselo da qualcuna.
## Attaccato all'orologio scatta comunque, qualunque sia la strada che ha fatto
## arrivare i soldi.
func _check_prologue() -> void:
	if current.chapter != "prologo" or current.cash < Economy.PROLOGUE_CASH:
		return
	current.chapter = "capitolo_uno"
	current.set_flag("staff_unlocked", true)
	chapter_changed.emit(current.chapter)
	contact_message(Chat.BRIAN, "MSG_COUSIN_BODY")
	save_game()

## Soldi che sbloccano il consiglio di allargarsi, e flag che ricorda di averlo
## già dato. Come la fine del prologo, è un traguardo che scatta una volta sola
## e resta scritto nel salvataggio.
const EXPAND_CASH := 10000
const EXPAND_FLAG := "expand_advised"
## Brian ha chiesto il nome dell'organizzazione (al primo assunto).
const ORG_NAME_FLAG := "org_name_asked"
## Flag del messaggio d'apertura, quello che racconta da dove viene la casa.
const INTRO_FLAG := "intro_seen"

## I traguardi che non sono la fine del prologo: il consiglio di allargarsi ai
## diecimila, e il chilo di merce che apre l'ingrosso.
##
## Stanno tutti agganciati all'orologio e non al punto in cui cambiano i numeri,
## per lo stesso motivo di `_check_prologue()`: i soldi e la merce entrano da
## troppe parti — il PC, la strada, il personale, il furgone che rientra — e
## ricordarsi di chiamare il controllo da ognuna vuol dire dimenticarselo da
## qualcuna.
func _check_milestones() -> void:
	if current.cash >= EXPAND_CASH and not bool(current.get_flag(EXPAND_FLAG, false)):
		current.set_flag(EXPAND_FLAG, true)
		contact_message(Chat.BRIAN, "MSG_EXPAND_BODY")
		save_game()
	if Delivery.check_unlock(current):
		contact_message(Chat.BRIAN, "MSG_KILO_BODY")
		save_game()
	# Comprato il furgone, Brian presenta il grossista della clinica: da lì in
	# poi i semi si comprano a cassette invece che due alla volta da lui.
	if SeedRun.check_unlock(current):
		contact_message(Chat.BRIAN, "MSG_SEED_WHOLESALE_BODY")
		save_game()
	# Fatto il primo giro di persona, Brian dice che c'è un modo di non farlo
	# più: l'autista. È il consiglio giusto nel momento giusto — arriva quando
	# si è appena camminato fino in centro, non prima, quando sarebbe stato un
	# ruolo in più in una lista di ruoli.
	if SeedRun.check_driver_hint(current):
		contact_message(Chat.BRIAN, "MSG_DRIVER_BODY")
		save_game()
	# Il primo assunto, chiunque sia: non si è più soli, è un'attività vera, e
	# Brian dice che serve un nome. La finestra per darlo la apre l'HUD
	# (`hud.gd::_check_org_name()`), che c'è sia in città sia nelle stanze.
	if Staff.total(current) > 0 and not bool(current.get_flag(ORG_NAME_FLAG, false)):
		current.set_flag(ORG_NAME_FLAG, true)
		contact_message(Chat.BRIAN, "MSG_ORG_NAME_BODY")
		save_game()
	# Assunto l'autista, si presenta lui: è il messaggio che porta il giocatore
	# nella sua chat, che è il posto da cui lo si manda a prendere i semi.
	if Staff.check_driver_hello(current):
		contact_message(Chat.DRIVER, "MSG_DRIVER_HELLO")
		save_game()
	# Ai centomila dollari Kevin gira il contatto fuori stato: da qui in poi la
	# stazione degli autobus compare in COMMERCIAL DISTRICT (vedi `unlock_flag`
	# in `CityMap.BUILDINGS`) e il messaggio mette Kevin in rubrica.
	if BusImport.check_unlock(current):
		contact_message(Chat.KEVIN, "MSG_KEVIN_BUS_STATION_BODY")
		save_game()

## Il messaggio d'apertura: da dove viene la casa, e cosa ci si fa.
##
## Non sta in `new_game()` ma qui, agganciato all'orologio, perché `new_game()`
## gira anche dal menu — e un fumetto che compare dietro ai bottoni del menu
## principale, prima ancora di vedere la città, non lo legge nessuno.
func _check_intro() -> void:
	if bool(current.get_flag(INTRO_FLAG, false)):
		return
	current.set_flag(INTRO_FLAG, true)
	contact_message(Chat.BRIAN, "MSG_INTRO_BODY")
	save_game()

## Fa rientrare il furgone dal grossista quando è ora, e scarica i semi.
func _tick_seed_run() -> void:
	var seeds := SeedRun.tick(current, total_hours())
	if seeds <= 0:
		return
	notify(tr("NOTE_SEEDS_IN") % seeds)
	seed_run_back.emit(seeds)
	# Semi arrivati è roba che il giocatore ricorda: non deve dipendere dal
	# prossimo salvataggio automatico.
	save_game()

## Fa rientrare il furgone dal contatto fuori stato di Kevin quando è ora, e
## scarica i semi. Stessa forma di `_tick_seed_run()`, altro fornitore.
func _tick_bus_order() -> void:
	var seeds := BusImport.tick(current, total_hours())
	if seeds <= 0:
		return
	notify(tr("NOTE_SEEDS_IN") % seeds)
	bus_order_back.emit(seeds)
	save_game()

## Fa rientrare il furgone quando è ora, e paga.
func _tick_van() -> void:
	var revenue := Delivery.tick(current, total_hours())
	if revenue <= 0:
		return
	notify(tr("NOTE_VAN_BACK") % UiFormat.money(revenue))
	van_back.emit(revenue)
	# Un carico rientrato è roba che il giocatore ricorda: non deve dipendere
	# dal prossimo salvataggio automatico.
	save_game()

## Un riquadro che ferma tutto finché non lo si chiude.
##
## È per le cose che vanno lette prima di continuare e che **non ha scritto
## nessuno**: la società elettrica, il personale che se ne va, il resoconto di
## quello che è successo a gioco chiuso. Quando invece a scrivere è una persona
## — Brian — il posto è il telefono (`text_message()`), non questo.
##
## Il riquadro viene appeso a questo singleton, non alla scena corrente: è un
## autoload, quindi sta sopra alla scena, e il messaggio compare uguale in
## strada e dentro a una stanza. Vedi `scripts/ui/phone_notice.gd`.
func message(speaker: String, body: String) -> Node:
	var notice_scene: PackedScene = load(PHONE_NOTICE_SCENE)
	if notice_scene == null:
		push_warning("Manca la scena del messaggio: %s" % PHONE_NOTICE_SCENE)
		notify("%s: %s" % [speaker, body])
		return null
	var popup := notice_scene.instantiate()
	popup.setup(speaker, body)
	add_child(popup)
	return popup

## La guida, aperta dal tasto in fondo alla rubrica del telefono.
##
## Appesa a questo singleton e non alla scena corrente, per il motivo di sempre:
## è un autoload, quindi sta sopra alla scena, e la guida si apre uguale in
## strada e dentro a una stanza. Vedi `scripts/ui/guide_book.gd`.
##
## Una sola per volta: il tasto resta premibile sotto alla finestra solo se
## qualcosa va storto, e due guide sovrapposte sono due Esc per chiuderle.
func open_guide() -> Node:
	for open: Node in get_tree().get_nodes_in_group("modal"):
		if open.scene_file_path == GUIDE_SCENE:
			return open
	var guide_scene: PackedScene = load(GUIDE_SCENE)
	if guide_scene == null:
		push_warning("Manca la scena della guida: %s" % GUIDE_SCENE)
		return null
	var book := guide_scene.instantiate()
	add_child(book)
	return book

## Il filmato della partenza del furgone. Sta qui e non nella City per il
## motivo di sempre: l'ingrosso si ordina dal PC in cantina, dove la City non
## c'e'. Appeso a questo singleton si vede da qualunque stanza.
##
## Se la scena manca non succede niente: la consegna e' gia' partita nei dati,
## e il filmato e' la ciliegina. Vedi `scripts/ui/van_cutscene.gd`.
func van_cutscene(grams: int) -> Node:
	var scene: PackedScene = load(VAN_CUTSCENE_SCENE)
	if scene == null:
		push_warning("Manca la scena del filmato: %s" % VAN_CUTSCENE_SCENE)
		return null
	var movie := scene.instantiate()
	movie.setup(tr("CUT_VAN_OUT"))
	add_child(movie)
	return movie

## La mezzanotte: prezzo del giorno nuovo e attenzione che si raffredda.
## La logica sta in `Economy`, qui c'è solo il collegamento — così il singleton
## dei salvataggi non si mette a sapere quanto costa un grammo.
func _on_day_started(_day: int) -> void:
	if current == null:
		return
	Economy.roll_new_day(current)
	_pay_staff()
	_pay_power()
	_pay_property_tax()
	# Il cambio di giorno è un punto di controllo naturale: è il momento in cui
	# cambiano prezzi e attenzione, ed è quello che il giocatore ricorda.
	save_game()

## Le paghe del personale, scalate a mezzanotte. Se i soldi non bastano se ne
## va uno: vedi `Staff.pay_wages()`.
func _pay_staff() -> void:
	if Staff.total(current) <= 0:
		return
	var result := Staff.pay_wages(current)
	if int(result["paid"]) > 0:
		notify(tr("NOTE_WAGES") % UiFormat.money(int(result["paid"])))
	var quit_role: String = result["quit"]
	if not quit_role.is_empty():
		message(tr("MSG_STAFF_SPEAKER"), tr("MSG_STAFF_QUIT") % Staff.role_name(quit_role))

## La bolletta della luce, quando scade. A differenza delle paghe non arriva
## ogni notte: vedi `Economy.BILL_DAYS`.
func _pay_power() -> void:
	var bill := Economy.charge_power(current)
	if int(bill["due"]) <= 0:
		return
	notify(tr("NOTE_POWER_BILL") % UiFormat.money(int(bill["paid"])))
	# Pagata a metà è una cosa che il giocatore deve sapere: è il primo segno
	# che la cantina costa più di quanto renda.
	if int(bill["paid"]) < int(bill["due"]):
		message(tr("MSG_POWER_SPEAKER"), tr("MSG_POWER_SHORT") % [
			UiFormat.money(int(bill["due"])), UiFormat.money(int(bill["paid"]))])

## La tassa sulla proprieta', una volta l'anno per ogni edificio comprato.
## Vedi `Economy.charge_property_tax()`: qui c'e' solo come la si racconta.
func _pay_property_tax() -> void:
	var tax := Economy.charge_property_tax(current)
	if int(tax["due"]) <= 0:
		return
	notify(tr("NOTE_PROPERTY_TAX") % UiFormat.money(int(tax["paid"])))
	if int(tax["paid"]) < int(tax["due"]):
		message(tr("MSG_TAX_SPEAKER"), tr("MSG_TAX_SHORT") % [
			UiFormat.money(int(tax["due"])), UiFormat.money(int(tax["paid"]))])

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
	# Prima di dire a chiunque che la partita è cominciata: chi si aggancia a
	# `game_started` costruisce la scena dallo stato, e lo stato deve essere già
	# quello recuperato. Altrimenti la mappa nascerebbe all'ora di ieri sera e
	# salterebbe avanti un attimo dopo.
	_catch_up_offline()
	game_started.emit(current)
	return true

## Recupera il tempo passato mentre il gioco era chiuso.
##
## Il lavoro vero lo fa `Offline`, che sposta l'orologio e lascia lavorare i
## sistemi che c'erano già — vedi il commento in cima a `offline.gd`. Qui c'è
## solo il collegamento: da dove arriva il ritmo dell'orologio, e come si
## racconta al giocatore quello che è successo.
func _catch_up_offline() -> void:
	# Chi ha spento il mondo a gioco chiuso riapre dove aveva lasciato: stessa
	# ora, stesse piante, stessa cassa. Basta non chiamare il recupero, perché
	# `saved_at` viene riscritto al primo salvataggio e il tempo saltato non si
	# accumula per la volta dopo. Vedi `GameSettings.offline_progress`.
	if not GameSettings.offline_progress:
		return
	var away := Offline.away_seconds(current, Time.get_unix_time_from_system())
	var report := Offline.catch_up(current, away, GAME_MINUTES_PER_SECOND)
	if not Offline.happened(report):
		return
	# Si scrive subito su disco. Il recupero è già stato speso: se il giocatore
	# chiudesse il gioco senza salvare, riaprendolo si ritroverebbe il resoconto
	# di prima e nient'altro, e un raccolto che aveva già letto non ci sarebbe più.
	save_game()
	message(tr("MSG_AWAY_SPEAKER"), _away_body(report))

## Il resoconto di quello che è successo mentre il gioco era chiuso.
##
## Le righe compaiono solo quando hanno qualcosa da dire, come i segmenti
## dell'HUD: una partita senza personale legge due righe, una con la cantina
## avviata ne legge sei. Le prime due ci sono sempre, e servono a spiegare il
## salto dell'orologio: senza, si riaprirebbe il gioco al giorno 5 ricordandosi
## di averlo chiuso al giorno 3.
func _away_body(report: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append(tr("AWAY_HEADER") % UiFormat.play_time(float(report["away_seconds"])))
	lines.append("%s %d %s  %s  %s %d %s" % [
		tr("HUD_DAY"), int(report["from_day"]), UiFormat.clock(float(report["from_time"])),
		AWAY_ARROW,
		tr("HUD_DAY"), current.day, UiFormat.clock(current.time_of_day)])
	# Il tetto va detto, o il conto non torna: chi è stato via un mese e trova
	# una settimana di lavoro deve sapere perché, altrimenti sembra che il gioco
	# si sia perso qualcosa per strada. Quando l'assenza ci sta dentro non se ne
	# parla nemmeno: non c'è niente da spiegare.
	if bool(report.get("capped", false)):
		lines.append(tr("AWAY_CAPPED") % Offline.MAX_GAME_DAYS)

	var facts := PackedStringArray()
	if int(report["grams"]) > 0:
		facts.append(tr("AWAY_HARVEST") % int(report["grams"]))
	if int(report["sold"]) > 0:
		facts.append(tr("AWAY_SOLD") % [int(report["sold"]), UiFormat.money(int(report["gross"]))])
	if int(report["commission"]) > 0:
		facts.append(tr("AWAY_CUT") % UiFormat.money(int(report["commission"])))
	if int(report["wages"]) > 0:
		facts.append(tr("AWAY_WAGES") % UiFormat.money(int(report["wages"])))
	if int(report["power"]) > 0:
		facts.append(tr("AWAY_POWER") % UiFormat.money(int(report["power"])))
	if int(report.get("tax", 0)) > 0:
		facts.append(tr("AWAY_TAX") % UiFormat.money(int(report["tax"])))
	var quit_role: String = report["quit"]
	if not quit_role.is_empty():
		facts.append(tr("AWAY_QUIT") % Staff.role_name(quit_role))
	if int(report["idle"]) > 0:
		facts.append(tr("AWAY_IDLE"))
	if int(report["thirsty"]) > 0:
		facts.append(tr("AWAY_THIRSTY") % int(report["thirsty"]))
	match str(report["deal"]):
		"ready":
			facts.append(tr("AWAY_DEAL_READY") % str(report["place"]))
		"gone":
			facts.append(tr("AWAY_DEAL_GONE"))
	if facts.is_empty():
		facts.append(tr("AWAY_NO_STAFF") if Staff.total(current) <= 0 else tr("AWAY_QUIET"))

	return "\n".join(lines) + "\n\n" + "\n".join(facts)

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
	# A parità esatta di istante decide il nome dello slot, che contiene data e
	# ora ed è unico. Senza il secondo criterio "l'ultima partita" dipenderebbe
	# dall'ordine in cui il sistema elenca i file, e due salvataggi scritti
	# nello stesso millesimo di secondo si scambierebbero di posto fra un avvio
	# e l'altro.
	#
	# **`!=` e non `is_equal_approx()`**, che è quello che c'era e che rompeva il
	# tasto play. `saved_at` è un tempo UNIX: un miliardo e settecento milioni di
	# secondi. `is_equal_approx()` ha una tolleranza RELATIVA — un centomillesimo
	# del valore — che su numeri di quella taglia vale **cinque ore**. Due
	# partite salvate a meno di cinque ore l'una dall'altra risultavano quindi
	# "salvate nello stesso istante", il confronto cadeva sul nome dello slot, e
	# il nome dello slot è la data in cui la partita è stata **creata**: play
	# riprendeva la campagna iniziata più di recente invece di quella giocata più
	# di recente. Due istanti si confrontano per quello che sono, non a meno di
	# un epsilon: qui l'approssimazione non serviva a niente e mangiava mezza
	# giornata.
	saves.sort_custom(func(a, b):
		if a["saved_at"] != b["saved_at"]:
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
