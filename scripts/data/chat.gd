class_name Chat
extends RefCounted

## La rubrica del telefono e i fili di messaggi che ci stanno dentro.
##
## ## Due tipi di riga, ed è tutto il punto di questo file
##
## - **Quelle che restano** (`kept()`). I messaggi dei traguardi: l'apertura, la
##   fine del prologo ai mille, il consiglio di allargarsi, il chilo, il
##   grossista della clinica. Sono pezzi di storia, si rileggono a distanza di
##   giorni, e stanno nel salvataggio (`SaveData.chat_log`).
## - **Quelle che non restano** (`live()`). Il giro della richiesta di semi:
##   "servono semi" — "ci penso io" — "ti aspetto in MAIN STREET" — "me ne
##   vado". Finito l'appuntamento non vogliono più dire niente, e tenerle
##   vorrebbe dire che dopo dieci chiamate la chat con Brian è una fila di
##   richieste identiche in cui i cinque messaggi che contano non si trovano
##   più.
##
## ## Quelle che non restano non sono salvate da nessuna parte: si ricavano
##
## L'appuntamento è già tutto scritto dentro a `SaveData.seed_deal` — quando è
## partita la richiesta, quando arriva la posizione, dove, se Brian ha già
## avvisato che sta per andarsene. Da lì il filo si riscrive ogni volta che si
## apre la chat, e **non c'è niente da cancellare**: chiuso l'appuntamento
## `seed_deal` si svuota (`SeedDeal.clear()`) e quei messaggi se ne vanno da
## soli. Nessuna lista che qualcuno si può dimenticare di ripulire, e nessun
## modo di ritrovarsi mezzo giro di messaggi di un appuntamento finito ieri.
##
## È lo stesso trucco delle piante, dell'appuntamento e del lavoro del
## personale: lo stato è una funzione di quello che c'è scritto nel
## salvataggio, non una cosa tenuta in vita a parte. Qui in più fa da sé il
## lavoro di cancellare.
##
## ## Dentro ci sono chiavi, non frasi
##
## Una riga è `{"contact", "from", "key", "arg", "at"}`, e `key` è una chiave di
## `Strings`. Il testo lo tira fuori `body()` al momento di mostrarlo: una
## cronologia di frasi già scritte resterebbe nella lingua in cui la partita è
## cominciata anche cambiando lingua dalle impostazioni, e sarebbe l'unico posto
## del gioco a farlo.

## Chi ha scritto una riga.
const THEM := "them"
const YOU := "you"

## I contatti in rubrica.
##
## **La rubrica c'era già quando il contatto era uno solo**, ed è esattamente
## per questo giorno: aprire il telefono dritto sulla chat di Brian avrebbe
## voluto dire che il telefono *è* quella chat, e il secondo contatto avrebbe
## costretto a rifare la schermata e a insegnare al giocatore un posto nuovo.
## Il secondo contatto è arrivato, ed è stata una riga in `contacts()`.
const BRIAN := "brian"
## L'autista, da quando lo si assume. Vedi `contacts()`.
const DRIVER := "driver"
## Il grossista di Kevin, da quando manda il messaggio del contatto fuori
## stato. Vedi `contacts()` e `BusImport`.
const KEVIN := "kevin"

## Come si chiama ognuno in rubrica: la CHIAVE del nome, non il nome.
const CONTACT_NAMES := {
	BRIAN: "MSG_COUSIN_SPEAKER",
	DRIVER: "MSG_DRIVER_SPEAKER",
	KEVIN: "MSG_KEVIN_SPEAKER",
}

## Quanto ci mette Brian a rispondere alla richiesta di semi, in ore di gioco.
##
## Serve solo a **far vedere la risposta arrivare**: senza, premendo il bottone
## comparirebbero due righe insieme e non si leggerebbe come una conversazione
## ma come un blocco di testo che si accende. Al ritmo dell'orologio
## (`GameState.GAME_MINUTES_PER_SECOND`) sono un paio di secondi veri.
##
## È un'ora di gioco e non un timer per la stessa ragione di tutto il resto: il
## filo si ricava, e un timer vorrebbe dire tenere in vita qualcosa che invece
## si legge dall'appuntamento.
const REPLY_GAP := 0.15

## Quante righe di cronologia si tengono al massimo.
##
## I traguardi sono cinque e non cresceranno a decine, quindi questo tetto non
## si tocca mai: c'è perché una lista dentro a un salvataggio che può solo
## crescere è il tipo di cosa che va bene finché un giorno qualcuno aggancia i
## messaggi a un evento che si ripete.
const MAX_KEPT := 60

## La rubrica di **questa** partita. `name_key` e non il nome già scritto perché
## il mittente è una voce di `Strings` come tutto il resto (vedi
## `MSG_COUSIN_SPEAKER`), e il telefono deve poterlo rileggere quando cambia
## lingua.
##
## Dipende dal salvataggio perché l'autista in rubrica **non c'è finché non lo
## si assume**: uno che non lavora per te non ha motivo di stare nel tuo
## telefono, e una chat che non risponde mai è peggio di un contatto che non
## c'è. Senza salvataggio — il menu principale — resta il solo Brian.
static func contacts(data: SaveData = null) -> Array:
	var list: Array = [{"id": BRIAN, "name_key": str(CONTACT_NAMES[BRIAN])}]
	if Staff.has_driver(data):
		list.append({"id": DRIVER, "name_key": str(CONTACT_NAMES[DRIVER])})
	if BusImport.is_unlocked(data):
		list.append({"id": KEVIN, "name_key": str(CONTACT_NAMES[KEVIN])})
	return list

## Il nome di un contatto qualunque, anche di uno che adesso non è in rubrica:
## serve a rileggere una chat vecchia senza dover sapere chi lavora per te
## adesso.
static func name_key(contact: String) -> String:
	return str(CONTACT_NAMES.get(contact, ""))

# --- Il testo di una riga ---------------------------------------------------

## La frase di una riga, nella lingua di adesso.
##
## `TranslationServer.translate()` e non `tr()`: quello è un metodo di `Object`,
## e qui dentro sono tutte funzioni statiche su dei dati — non c'è nessun nodo
## a cui chiederlo. Fanno la stessa cosa.
static func body(row: Dictionary) -> String:
	var text := str(TranslationServer.translate(str(row.get("key", ""))))
	var arg := str(row.get("arg", ""))
	return text % arg if not arg.is_empty() else text

static func is_mine(row: Dictionary) -> bool:
	return str(row.get("from", THEM)) == YOU

# --- Le righe che restano ---------------------------------------------------

## Aggiunge un messaggio alla cronologia.
##
## Non si chiama da fuori: ci si passa da `GameState.contact_message()`, che è
## anche il punto in cui il messaggio diventa un avviso sul telefono. Un
## messaggio che finisce in cronologia senza far suonare il telefono è un
## messaggio che il giocatore non legge mai.
static func keep(data: SaveData, contact: String, key: String, arg: String,
		at: float) -> void:
	if data == null or key.is_empty():
		return
	data.chat_log.append({
		"contact": contact, "from": THEM, "key": key, "arg": arg, "at": at,
	})
	while data.chat_log.size() > MAX_KEPT:
		data.chat_log.pop_front()

static func kept(data: SaveData, contact: String) -> Array:
	var rows: Array = []
	if data == null:
		return rows
	for row in data.chat_log:
		if str((row as Dictionary).get("contact", "")) == contact:
			rows.append(row)
	return rows

# --- Le righe che non restano ----------------------------------------------

## Il giro della richiesta di semi, riscritto dall'appuntamento in corso.
##
## Vuoto quando non c'è nessun appuntamento, ed è così che questi messaggi si
## cancellano: non li cancella nessuno, semplicemente smettono di esistere
## quando `seed_deal` si svuota.
##
## Le ore servono a metterle in fila insieme a quelle della cronologia, ma non
## solo: la risposta di Brian compare `REPLY_GAP` dopo la richiesta, quindi
## premendo il bottone si vede partire il messaggio e poi arrivare la risposta,
## invece di vederli comparire insieme.
static func live(data: SaveData, now: float) -> Array:
	if data == null or not SeedDeal.is_active(data):
		return []
	var deal: Dictionary = data.seed_deal
	var asked := float(deal.get("asked_at", 0.0))
	var rows: Array = [_row(YOU, "CHAT_ASK_SEEDS", "", asked)]
	if now >= asked + REPLY_GAP:
		rows.append(_row(THEM, "CHAT_BRIAN_ON_IT", "", asked + REPLY_GAP))
	if SeedDeal.is_ready(data):
		rows.append(_row(THEM, "PHONE_BRIAN_READY", SeedDeal.place(data),
			float(deal.get("ready_at", asked))))
	if bool(deal.get("warned", false)):
		rows.append(_row(THEM, "PHONE_BRIAN_LEAVING", "",
			float(deal.get("expires_at", asked)) - SeedDeal.LEAVING_HOURS))
	return rows

## Il giro dell'autista, riscritto dal viaggio in corso.
##
## Stessa forma di `live()` e per lo stesso motivo: le due righe — "vai a
## prendere i semi" e "vado" — non vogliono più dire niente quando il furgone è
## tornato, e spariscono da sole quando `seed_run` si svuota. Nessuna lista da
## ripulire, e nessun modo di ritrovarsi in chat l'ordine di ieri.
static func driver_live(data: SaveData, now: float) -> Array:
	if data == null or not SeedRun.is_running(data):
		return []
	var run: Dictionary = data.seed_run
	var left := float(run.get("left_at", 0.0))
	var rows: Array = [
		_row_for(DRIVER, YOU, "CHAT_SEND_DRIVER", str(int(run.get("seeds", 0))), left),
	]
	if now >= left + REPLY_GAP:
		rows.append(_row_for(DRIVER, THEM, "CHAT_DRIVER_ON_IT", "", left + REPLY_GAP))
	return rows

static func _row(from: String, key: String, arg: String, at: float) -> Dictionary:
	return _row_for(BRIAN, from, key, arg, at)

static func _row_for(contact: String, from: String, key: String, arg: String,
		at: float) -> Dictionary:
	return {"contact": contact, "from": from, "key": key, "arg": arg, "at": at}

# --- Il filo intero ---------------------------------------------------------

## Tutti i messaggi con un contatto, in ordine di quando sono arrivati.
##
## L'ordine si fa sull'ora di gioco e non sull'ordine in cui stanno nei due
## elenchi: un traguardo può scattare in mezzo a un appuntamento aperto, e
## appiccicare la cronologia prima e il giro dei semi dopo lo metterebbe nel
## posto sbagliato.
static func thread(data: SaveData, contact: String, now: float) -> Array:
	var rows := kept(data, contact)
	if contact == BRIAN:
		rows.append_array(live(data, now))
	elif contact == DRIVER:
		rows.append_array(driver_live(data, now))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("at", 0.0)) < float(b.get("at", 0.0)))
	return rows
