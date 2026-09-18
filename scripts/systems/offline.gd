class_name Offline
extends RefCounted

## Quello che è successo mentre il gioco era chiuso.
##
## ## Non c'è niente da simulare
##
## Coltivazione (`Grow`), lavoro del personale (`Staff`) e appuntamento con
## Brian (`SeedDeal`) **erano già funzioni del tempo**: nessuno tiene un conto
## frame per frame, si guarda che ore sono e si fa quello che nel frattempo
## andava fatto. L'unica cosa che si ferma chiudendo il gioco è l'orologio.
##
## Quindi questo file non è un simulatore: è un pezzo che sposta avanti
## l'orologio della partita di quanto è passato nel mondo vero, e lascia che i
## sistemi che c'erano già facciano il loro mestiere. È il motivo per cui costa
## un file solo.
##
## ## Perché a passi e non in un salto
##
## Portare l'orologio da 8:00 a 56:00 in un colpo e chiamare `Staff.work()` una
## volta darebbe un risultato sbagliato in due modi:
##
## 1. Un coltivatore raccoglie e ripianta **una volta per chiamata**. In due
##    giorni di gioco un vaso completa un ciclo e mezzo: con una chiamata sola
##    se ne perderebbe metà, e chi ha lasciato il gioco aperto avrebbe raccolto
##    di più di chi l'ha chiuso per lo stesso tempo.
## 2. I dealer venderebbero tutto il magazzino al prezzo di **oggi**, mentre il
##    prezzo cambia a ogni mezzanotte. Due giorni di merce piazzata al prezzo di
##    un giorno solo è una scommessa che il giocatore non ha fatto.
##
## Quindi il recupero avanza a mezz'ore di gioco, spezzando il passo esatto sulla
## mezzanotte perché paghe, prezzo del giorno e meteo cadano al momento giusto.
## Sono un centinaio di giri per una notte intera: non si sente.
##
## ## Tutta l'assenza, ma a metà resa
##
## Non c'è più un tetto. Si conta **tutto** il tempo passato fuori: chi torna
## dopo una settimana trova una settimana di lavoro, non le quarantotto ore che
## si contavano prima.
##
## Quello che c'è al posto del tetto è la resa: a gioco spento **tutto rende la
## metà**. Se in quel tempo si sarebbero piazzati cinquanta grammi, se ne
## trovano venticinque; le piante fanno metà dei cicli, e metà sono anche le
## paghe e le bollette, perché è tutto il mondo ad andare a metà velocità e non
## solo la parte che frutta.
##
## Come: `catch_up()` accredita metà delle ore, e da lì in poi non cambia
## niente: i sistemi che c'erano già lavorano su quelle. È solo un conto —
## il gioco era spento, non c'era niente da vedere — ed è il modo più onesto di
## farlo, perché non c'è nessun punto in cui una cosa rende e un'altra no.
##
## **Perché a metà e non per intero.** L'orologio della partita corre
## duecentoquaranta volte più veloce del nostro: a `GAME_MINUTES_PER_SECOND` = 4
## una giornata di gioco dura sei minuti veri, e una notte di sonno vale due
## mesi di gioco. Contarla tutta per intero vorrebbe dire che il modo migliore
## di giocare è non aprire il gioco. A metà resta conveniente **esserci** — chi
## gioca produce il doppio di chi aspetta — e chi torna dopo una settimana
## trova comunque una settimana di roba, che è quello che uno si aspetta.
##
## ## Cosa NON succede a gioco chiuso
##
## Solo il personale lavora. Il giocatore no: non annaffia i vasi che i
## coltivatori non seguono, non vende in strada a mano, e soprattutto **non
## compra semi** — quelli si prendono solo da Brian, di persona. Finiti i semi i
## vasi restano vuoti e la produzione si ferma da sola: è il vero limite di una
## lunga assenza, e non lo mette un numero.

## Quanto rende un'ora passata a gioco spento. Vedi il commento qui sopra.
##
## È l'unico numero da girare per rendere il ritorno più o meno ricco: tutto il
## resto viene da sé, perché tutto il recupero è fatto delle ore che questo
## moltiplicatore decide.
const CLOSED_RATE := 0.5

## Quanti passi al massimo, per non piantare il gioco all'avvio.
##
## Il passo è di mezz'ora di gioco, e per un'assenza normale i passi sono
## qualche centinaio. Ma senza tetto l'assenza non ha più un massimo: un mese
## via sarebbe un quarto di milione di giri, cioè una manciata di secondi di
## schermo fermo all'apertura. Oltre questo numero il passo si allarga da solo.
##
## Allargandolo si perde qualcosa — un coltivatore raccoglie **una volta per
## chiamata**, quindi con passi larghi qualche ciclo non viene contato — e va
## bene che sia così: l'errore è sempre in difetto, mai a favore, e comincia a
## esistere dopo mesi di assenza, quando i semi sono finiti da un pezzo e non
## c'è più niente da raccogliere comunque.
const MAX_STEPS := 6000

## Sotto a questi secondi non è successo niente che valga la pena raccontare.
##
## Serve soprattutto a chi riapre il gioco subito dopo averlo chiuso — o ci
## rientra dal menu — perché non si becchi un riquadro a tutto schermo per
## dirgli che sono passati venti secondi.
const MIN_REAL_SECONDS := 60.0

## Passo del recupero, in ore di gioco. Vedi "Perché a passi e non in un salto".
const STEP_HOURS := 0.5

## Un resoconto vuoto. Le chiavi ci sono **sempre**, anche a zero, così chi lo
## legge non deve difendersi da un dizionario che cambia forma — è la stessa
## regola di `Staff.work()`.
static func empty_report() -> Dictionary:
	return {
		# Se il recupero è stato fatto davvero.
		"ran": false,
		# Secondi veri passati: si contano tutti, non c'è più un tetto.
		"away_seconds": 0.0,
		# Quanto ha rendito quel tempo, 0-1. Vedi `CLOSED_RATE`.
		"rate": 1.0,
		# Ore di gioco recuperate, e da dove si partiva.
		"game_hours": 0.0,
		"from_day": 0,
		"from_time": 0.0,
		# Il lavoro del personale, sommato su tutti i passi.
		"planted": 0,
		"watered": 0,
		"harvested": 0,
		"grams": 0,
		"sold": 0,
		# Lordo, quota trattenuta dai dealer, e quello che è arrivato in cassa:
		# il resoconto mostra il conto per esteso, perché "piazzato per 294 e in
		# cassa 280" senza la riga di mezzo si legge come un errore.
		"gross": 0,
		"commission": 0,
		"revenue": 0,
		# Le paghe scalate alle mezzanotti attraversate, e chi se n'è andato.
		"wages": 0,
		"quit": "",
		# Le bollette della luce scadute nel frattempo.
		"power": 0,
		# Le tasse sulla proprieta' scadute nel frattempo.
		"tax": 0,
		# Vasi seguiti dal personale rimasti vuoti per mancanza di semi.
		"idle": 0,
		# Vasi che adesso hanno bisogno d'acqua.
		"thirsty": 0,
		# Che fine ha fatto l'appuntamento: "ready", "gone", oppure "".
		"deal": "",
		"place": "",
	}

## Da quanti secondi veri è chiusa questa partita.
##
## Un salvataggio nel futuro — l'orologio del sistema spostato indietro, un file
## copiato da un'altra macchina — dà zero e non un numero negativo: il tempo non
## torna indietro, e un conto negativo farebbe camminare l'orologio della partita
## all'incontrario.
static func away_seconds(data: SaveData, now_unix: float) -> float:
	if data == null or data.saved_at <= 0.0:
		return 0.0
	return maxf(0.0, now_unix - data.saved_at)

## Vero se nel resoconto c'è qualcosa che valga la pena mostrare.
static func happened(report: Dictionary) -> bool:
	return bool(report.get("ran", false))

## Porta la partita avanti di `real_seconds` di mondo vero e restituisce il
## resoconto.
##
## `minutes_per_second` è il ritmo dell'orologio di gioco: lo passa chi chiama
## (`GameState.GAME_MINUTES_PER_SECOND`) invece di essere letto da qui, così
## questa classe resta una funzione sui dati e i controlli automatici possono
## farla girare con il ritmo che vogliono.
static func catch_up(data: SaveData, real_seconds: float, minutes_per_second: float) -> Dictionary:
	var report := empty_report()
	if data == null or real_seconds < MIN_REAL_SECONDS or minutes_per_second <= 0.0:
		return report

	# Le ore che l'assenza varrebbe, e quelle che valgono davvero: a gioco
	# spento tutto rende la metà, e il modo di dirlo è accreditare metà delle
	# ore. Da qui in avanti nessuno sa più niente dello sconto — i sistemi
	# lavorano sulle ore che si trovano, come hanno sempre fatto.
	var real_hours := real_seconds * minutes_per_second / 60.0
	var hours := real_hours * CLOSED_RATE
	if hours <= 0.0:
		return report

	report["ran"] = true
	report["away_seconds"] = real_seconds
	report["rate"] = CLOSED_RATE
	report["game_hours"] = hours
	report["from_day"] = data.day
	report["from_time"] = data.time_of_day

	# Il passo si allarga solo per le assenze lunghissime: vedi `MAX_STEPS`.
	var step := maxf(STEP_HOURS, hours / float(MAX_STEPS))
	var left := hours
	while left > 0.0:
		left -= _one_step(data, minf(step, left), report)

	# I vasi che il personale non segue nessuno li ha annaffiati: dirlo è la
	# differenza fra "il gioco mi ha rovinato le piante" e "le piante avevano
	# sete, e adesso lo so".
	report["thirsty"] = Grow.count_thirsty(data.plots, _now(data))
	# Se i semi sono finiti mentre il gioco era chiuso, lo dice il resoconto
	# (`AWAY_IDLE`): segnare il flag qui evita che il telefono lo ripeta un
	# frame dopo, come se fosse una notizia appena arrivata.
	if int(report["idle"]) > 0:
		Staff.seedless_alert(data, int(report["idle"]))
	return report

## Un passo del recupero. Restituisce quante ore ha davvero consumato, che sono
## meno di quelle chieste quando il passo viene tagliato sulla mezzanotte.
static func _one_step(data: SaveData, wanted: float, report: Dictionary) -> float:
	# Il passo non scavalca mai la mezzanotte: si ferma lì, si fa quello che
	# c'era da fare in quel pezzo di giornata, e il giorno nuovo comincia dopo.
	var to_midnight := 24.0 - data.time_of_day
	var step := wanted
	var midnight := false
	if step >= to_midnight:
		step = to_midnight
		midnight = true

	data.time_of_day += step
	if midnight:
		data.time_of_day = 0.0
		data.day += 1

	var now := _now(data)
	_tick_deal(data, report, now)
	_tick_staff(data, report, now)
	# Il giorno nuovo scatta DOPO il lavoro del pezzo di giornata appena
	# passato: la merce piazzata prima di mezzanotte va venduta al prezzo di
	# ieri, non a quello che esce stanotte.
	if midnight:
		_new_day(data, report)
	return step

## Fa lavorare il personale per questo passo e somma quello che ha fatto.
static func _tick_staff(data: SaveData, report: Dictionary, now: float) -> void:
	if Staff.total(data) <= 0:
		# Senza nessuno assunto il segnaposto va portato avanti lo stesso,
		# altrimenti il primo assunto si troverebbe addosso tutte le ore in cui
		# il gioco era chiuso. È la stessa ragione che c'è dentro `Staff.work()`.
		data.staff_checked_at = now
		return
	var strain := Economy.strain(Economy.DEFAULT_STRAIN)
	# Di listino, non gia' scontati: vedi il commento su `Staff.work()`.
	var base := {"hours": strain["grow_hours"], "grams": strain["grams"]}
	var done := Staff.work(data, now, base)
	for key in ["planted", "watered", "harvested", "grams", "sold", "gross", "commission", "revenue"]:
		report[key] = int(report[key]) + int(done[key])
	# `idle` non si somma: è una fotografia di adesso — quanti vasi seguiti dal
	# personale sono fermi perché i semi sono finiti. Sommandolo si conterebbe
	# lo stesso vaso a ogni passo.
	report["idle"] = int(done["idle"])

## La mezzanotte: prezzo del giorno, meteo e paghe.
##
## È lo stesso giro di `GameState._on_day_started()`, senza le notifiche e senza
## il salvataggio: qui le mezzanotti possono essere due o tre di fila, e il
## giocatore non c'era. Quello che è successo glielo dice il resoconto, una volta
## sola, quando rientra.
static func _new_day(data: SaveData, report: Dictionary) -> void:
	Economy.roll_new_day(data)
	# La bolletta non guarda in faccia a nessuno: scade anche se non c'è
	# personale, perché il contatore gira lo stesso.
	report["power"] = int(report["power"]) + int(Economy.charge_power(data)["paid"])
	# Le tasse sulla proprieta' nemmeno: l'anniversario cade anche se il gioco
	# era spento, e chi resta via un anno lo ritrova scalato dalla cassa.
	report["tax"] = int(report.get("tax", 0)) + int(Economy.charge_property_tax(data)["paid"])
	if Staff.total(data) <= 0:
		return
	var result := Staff.pay_wages(data)
	report["wages"] = int(report["wages"]) + int(result["paid"])
	var quit_role: String = result["quit"]
	if not quit_role.is_empty():
		report["quit"] = quit_role

## Porta avanti l'appuntamento con Brian.
##
## L'attesa e la finestra dell'incontro scorrono anche a gioco chiuso, come
## tutto il resto: chiedere i semi e poi chiudere non è un modo di mettere in
## pausa Brian. Se scade, il giocatore lo legge nel resoconto invece di uscire di
## casa e non trovare nessuno senza sapere perché — che è l'unica cosa che
## rendeva la scadenza un problema.
static func _tick_deal(data: SaveData, report: Dictionary, now: float) -> void:
	match SeedDeal.tick(data, now):
		SeedDeal.STATE_READY:
			report["deal"] = "ready"
			report["place"] = SeedDeal.place(data)
		"gone":
			report["deal"] = "gone"

static func _now(data: SaveData) -> float:
	return float(data.day - 1) * 24.0 + data.time_of_day
