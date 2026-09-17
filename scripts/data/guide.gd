class_name Guide
extends RefCounted

## La guida che si apre dal telefono: come funziona il giro, scritto da Brian.
##
## ## Perché una guida e non un tutorial
##
## Questo è un gestionale, e un gestionale si gioca su dei numeri che il
## giocatore non può indovinare: che una pianta ci metta venti ore, che la sete
## tolga due terzi del raccolto, che una lampada valga per **un** vaso solo e
## non per tutti. Senza queste cose scritte da qualche parte, i primi giorni di
## partita sono lenti e sembrano rotti — si pianta, si aspetta, si raccoglie
## meno del previsto, e non c'è modo di capire perché.
##
## Un tutorial le direbbe una volta, all'inizio, quando non servono ancora e
## infatti non le legge nessuno. La guida invece **sta sempre lì**, in fondo
## alla rubrica, e si apre quando ci si impantana: è il momento in cui uno ha
## una domanda, che è l'unico momento in cui una risposta si legge davvero.
##
## È anche il motivo per cui il messaggio d'apertura di Brian
## (`MSG_INTRO_BODY`) la nomina: "all inizio cresce piano non mollare, nel
## telefono ti ho messo una guida". Il messaggio dice che la lentezza è
## normale; la guida dice cosa farci.
##
## ## Solo chiavi
##
## Come la chat, qui dentro ci sono **chiavi di `Strings`** e nessuna frase: il
## testo vero, nelle tre lingue, sta là. Per la guida però c'è una ragione in
## più delle altre tabelle — è l'unico posto del gioco in cui si scrivono dei
## **numeri** (154$, il 15%, dodici ore), e quei numeri devono restare
## allineati a `Economy`, `Shop`, `Grow` e `Staff`. Tenerli in `Strings`
## significa che si correggono in un posto, in tre lingue, senza toccare
## nessuno schermo.
##
## Quando si ritocca il bilanciamento, questa è la tabella da rileggere: una
## guida che dice il falso è peggio di nessuna guida.

## Le sezioni, nell'ordine in cui si leggono.
##
## L'ordine non è alfabetico ed è scelto: si parte da quello che si sta già
## facendo (le piante), si passa a quello che serve per farlo (i semi), e solo
## dopo si arriva a quello che si può comprare. La sezione che il messaggio
## d'apertura promette — "come andare più forte" — è la terza, cioè la prima
## che uno non conosce già.
const SECTIONS := [
	{"title": "GUIDE_PLANTS", "body": "GUIDE_PLANTS_BODY"},
	{"title": "GUIDE_SEEDS", "body": "GUIDE_SEEDS_BODY"},
	{"title": "GUIDE_FASTER", "body": "GUIDE_FASTER_BODY"},
	{"title": "GUIDE_STAFF", "body": "GUIDE_STAFF_BODY"},
	{"title": "GUIDE_WHOLESALE", "body": "GUIDE_WHOLESALE_BODY"},
	{"title": "GUIDE_HEAT", "body": "GUIDE_HEAT_BODY"},
]

## La riga in cima, sopra alla prima sezione: dice di chi sono gli appunti.
const LEAD := "GUIDE_LEAD"

## Tutte le chiavi che la guida usa, per il controllo automatico.
##
## Una chiave che non c'è non rompe niente: `tr()` restituisce la chiave, e a
## schermo compare `GUIDE_HEAT_BODY` al posto di un paragrafo. È il tipo di
## errore che si scopre tardi e per caso, ed è il motivo per cui questa
## funzione esiste.
static func keys() -> Array:
	var found: Array = [LEAD]
	for section: Dictionary in SECTIONS:
		found.append(str(section["title"]))
		found.append(str(section["body"]))
	return found
