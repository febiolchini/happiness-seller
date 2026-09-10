class_name SeedDeal
extends RefCounted

## L'appuntamento con Brian: come si comprano i semi.
##
## Brian è il cugino del protagonista e lavora alla clinica, dove l'erba la
## danno ai malati. I semi escono da lì, e non si comprano in un negozio: si
## chiede dal PC in cantina, si aspetta, e dopo un po' arriva un messaggio con
## un posto in cui vedersi a uno o due isolati da casa.
##
## ## Perché non è un negozio
##
## Un venditore fermo a un indirizzo è un distributore automatico: sai dov'è,
## ci vai quando ti serve, e la cosa smette di esistere come scelta. Un
## appuntamento invece occupa un pezzo di giornata — chiedi adesso, ti muovi
## dopo — e obbliga a decidere quando chiamare, non solo quanto comprare.
##
## ## Il tempo, come per la coltivazione
##
## Non c'è nessun timer che gira: l'appuntamento salva l'ora di gioco in cui la
## posizione arriva e quella in cui Brian se ne va, e lo stato è una funzione di
## che ore sono adesso (vedi `Grow`, che fa lo stesso con le piante). Quindi
## l'attesa scorre anche col gioco chiuso e ricaricare un salvataggio non
## azzera e non salta niente.
##
## L'unico pezzo che va "spinto avanti" è il passaggio da attesa ad
## appuntamento fissato, perché è lì che si sceglie il posto e si avvisa il
## giocatore: se ne occupa `tick()`, che `GameState` chiama mentre l'orologio
## gira.
##
## Campi di un appuntamento (dentro a `SaveData.seed_deal`, vuoto = nessuno):
## - `state`       `STATE_WAITING` finché la posizione non arriva, poi `STATE_READY`
## - `asked_at`    ora di gioco assoluta della richiesta dal PC
## - `ready_at`    ora in cui Brian manda la posizione
## - `expires_at`  ora in cui si stanca e se ne va
## - `spot_x/y`    dove aspetta (scelto solo quando si passa a `STATE_READY`)
## - `place`       come si chiama quel posto, già scritto ("MAIN STREET BY THE...")
## - `seeds`       quanti semi ha portato e non ha ancora venduto

const STATE_WAITING := "waiting"
const STATE_READY := "ready"

## Id e nome del personaggio. Sta qui e non nel roster perché Brian non è uno
## che gira per strada a orari fissi: esiste solo quando c'è un appuntamento, e
## `city.gd` lo tira su leggendo questo.
const NPC_ID := "brian"
const NPC_NAME := "BRIAN"
const NPC_COLOR := Color(0.847, 0.878, 0.898)
const NPC_ACCENT := Color(0.298, 0.478, 0.545)

## Quanto ci mette a rispondere, in ore di gioco. Al ritmo attuale
## (`GameState.GAME_MINUTES_PER_SECOND` a 4.0, una giornata in 6 minuti reali)
## sono circa 30-60 secondi veri: il tempo di annaffiare, vendere qualcosa o
## incamminarsi, non abbastanza da mettere via il gioco.
const WAIT_HOURS := Vector2(2.0, 4.0)

## Quanto resta ad aspettare prima di andarsene. Serve che sia generoso: un
## appuntamento perso perché si era dall'altra parte della città è una punizione
## per aver giocato, non una scelta sbagliata. Dieci ore di gioco bastano ad
## attraversare la mappa più volte.
const MEET_HOURS := 10.0

## Quanti semi porta a ogni consegna. Il limite è quello che tiene in piedi il
## meccanismo: senza, una chiamata sola basterebbe per sempre e chiamare Brian
## diventerebbe qualcosa che si fa una volta e poi si dimentica.
const SEEDS_PER_RUN := 6

# --- Lettura dello stato ---------------------------------------------------

static func state(data: SaveData) -> String:
	return str(data.seed_deal.get("state", ""))

static func is_active(data: SaveData) -> bool:
	return not data.seed_deal.is_empty()

## Vero mentre si aspetta che Brian faccia sapere qualcosa.
static func is_waiting(data: SaveData) -> bool:
	return state(data) == STATE_WAITING

## Vero quando la posizione è arrivata e Brian è sulla mappa.
static func is_ready(data: SaveData) -> bool:
	return state(data) == STATE_READY

## Si può chiedere solo se non c'è già un appuntamento in ballo: due Brian in
## due posti diversi non vogliono dire niente.
static func can_ask(data: SaveData) -> bool:
	return not is_active(data)

static func spot(data: SaveData) -> Vector2:
	return Vector2(
		float(data.seed_deal.get("spot_x", 0.0)),
		float(data.seed_deal.get("spot_y", 0.0)))

static func place(data: SaveData) -> String:
	return str(data.seed_deal.get("place", ""))

static func seeds_left(data: SaveData) -> int:
	return int(data.seed_deal.get("seeds", 0))

## Ore di gioco che mancano al prossimo passaggio: alla posizione se si sta
## aspettando, alla partenza di Brian se l'appuntamento è già fissato.
static func hours_left(data: SaveData, now: float) -> float:
	if not is_active(data):
		return 0.0
	var deadline := float(data.seed_deal.get(
		"ready_at" if is_waiting(data) else "expires_at", now))
	return maxf(0.0, deadline - now)

# --- Il giro dell'appuntamento ---------------------------------------------

## Chiede semi a Brian dal PC. Restituisce false se c'è già un appuntamento
## aperto, così chi chiama può dirlo invece di far finta di aver fatto qualcosa.
static func ask(data: SaveData, now: float) -> bool:
	if not can_ask(data):
		return false
	data.seed_deal = {
		"state": STATE_WAITING,
		"asked_at": now,
		"ready_at": now + randf_range(WAIT_HOURS.x, WAIT_HOURS.y),
		"expires_at": 0.0,
		"spot_x": 0.0,
		"spot_y": 0.0,
		"place": "",
		"seeds": SEEDS_PER_RUN,
	}
	return true

## Porta l'appuntamento avanti fino a `now` e dice cosa è appena successo:
## `STATE_READY` quando arriva la posizione, "gone" quando Brian si stanca e se
## ne va, "" quando non è cambiato niente.
##
## Restituisce l'evento invece di emettere un segnale suo perché è una funzione
## statica su dei dati: chi la chiama sa già come avvisare il giocatore, e i
## controlli automatici possono farla girare senza tirarsi dietro l'albero della
## scena.
static func tick(data: SaveData, now: float) -> String:
	if not is_active(data):
		return ""
	if is_waiting(data):
		if now < float(data.seed_deal.get("ready_at", now)):
			return ""
		_set_spot(data, now)
		return STATE_READY
	if now >= float(data.seed_deal.get("expires_at", now)):
		clear(data)
		return "gone"
	return ""

## Sceglie dove aspetta e fa scattare la finestra dell'appuntamento.
static func _set_spot(data: SaveData, now: float) -> void:
	var spots := CityMap.meet_spots()
	# Il ripiego non dovrebbe servire mai — il reticolo di posti buoni intorno
	# a casa è largo — ma un appuntamento senza posto lascerebbe la partita con
	# un Brian che non esiste da nessuna parte e nessun modo di chiudere il
	# giro. Meglio il marciapiede di casa che un vicolo cieco.
	var point: Vector2 = spots[randi() % spots.size()] if not spots.is_empty() else CityMap.home_doorstep()
	data.seed_deal["state"] = STATE_READY
	data.seed_deal["spot_x"] = point.x
	data.seed_deal["spot_y"] = point.y
	data.seed_deal["place"] = CityMap.place_name(point)
	data.seed_deal["expires_at"] = now + MEET_HOURS

## Compra `count` semi da Brian. Restituisce quanti ne ha davvero dati: meno di
## quelli chiesti se non ne ha più abbastanza o se i soldi non bastano, 0 se non
## se ne fa niente.
##
## Chiude l'appuntamento quando Brian resta a mani vuote: restare fermo lì con
## niente da vendere lo farebbe sembrare rotto.
static func buy(data: SaveData, count: int, strain_id := Economy.DEFAULT_STRAIN) -> int:
	if not is_ready(data):
		return 0
	var wanted := mini(count, seeds_left(data))
	var affordable := data.cash / maxi(1, Economy.seed_price(strain_id))
	var sold := mini(wanted, affordable)
	if sold <= 0 or not Economy.buy_seeds(data, sold, strain_id):
		return 0
	data.seed_deal["seeds"] = seeds_left(data) - sold
	if seeds_left(data) <= 0:
		clear(data)
	return sold

## Chiude l'appuntamento: Brian sparisce dalla mappa e se ne può chiedere un
## altro.
static func clear(data: SaveData) -> void:
	data.seed_deal = {}

# --- La voce per lo spawn --------------------------------------------------

## La riga che `city.gd` passa a `Npc.setup()` per tirare su Brian dove aspetta.
##
## Ha la stessa forma di una voce di `NpcRoster`, così l'NPC non deve sapere se
## viene dal roster o da un appuntamento. Il percorso è un punto solo — sta
## fermo, sta aspettando qualcuno — e la fascia oraria copre tutta la giornata:
## a decidere se c'è o no è l'appuntamento, non l'orologio.
static func npc_entry(data: SaveData) -> Dictionary:
	return {
		"id": NPC_ID,
		"name": NPC_NAME,
		"role": NpcRoster.ROLE_SEEDS,
		"route": [spot(data)],
		"speed": 0.0,
		"pause": 1.0,
		"hours": Vector2(0, 24),
		"color": NPC_COLOR,
		"accent": NPC_ACCENT,
	}
