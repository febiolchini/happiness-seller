class_name Weather
extends RefCounted

## Che tempo fa, quanto dura e cosa cambia.
##
## Tabella di dati come `Daylight` e `Economy`. Ogni voce dice due cose insieme:
## come si vede (tinta dell'aria, pioggia, nebbia, vento, nuvole) e cosa cambia
## in partita (quanta gente c'è in giro a comprare, quanto ci si fa notare).
##
## ## Il meteo deve pesare, altrimenti è carta da parati
##
## Una pioggia che si limita a scorrere davanti allo schermo è un filtro. Qui un
## giorno di pioggia ha meno clienti per strada ma anche meno occhi addosso, e
## un giorno sereno il contrario: il giocatore che guarda fuori dalla finestra
## sta già decidendo se oggi conviene uscire a vendere o piazzare tutto
## all'ingrosso dal PC. È lo stesso motivo per cui il prezzo del giorno cambia a
## mezzanotte — dare una ragione per cui domani non è uguale a oggi.
##
## ## Perché è salvato e non ricalcolato
##
## Come `market_price`, il tempo del giorno viene tirato a mezzanotte e scritto
## nel salvataggio. Ricavarlo da giorno e seme sarebbe più compatto, ma
## basterebbe ritoccare la tabella perché tutte le partite salvate cambiassero
## tempo sotto il naso al giocatore, e perché "il giorno che pioveva" diventasse
## un altro giorno.

## Il tempo di ripiego: è anche quello che vede chi apre una scena dall'editor e
## quello che risponde a un salvataggio di prima che il meteo esistesse.
const DEFAULT := "clear"

## chiave -> com'è fatto.
##
## `tint`     moltiplica la luce dell'ora: il grigio del coperto, il blu della
##            pioggia. Non scurisce e basta, sposta anche il colore, perché una
##            giornata coperta non è una giornata di sole abbassata.
## `dark`     se le luci artificiali si accendono anche di giorno.
## `shadows`  quanto restano marcate le ombre portate, 0 = luce diffusa.
## `rain`     densità della pioggia, 0-1.
## `fog`      quanto è densa la foschia, 0-1.
## `clouds`   quante ombre di nuvole passano sul terreno, 0-1.
## `wind`     quanto spingono di lato pioggia e cartacce, -1/+1.
## `thunder`  secondi medi fra un lampo e l'altro, 0 = niente temporale.
## `demand`   moltiplicatore sulla voglia di comprare dei clienti in strada.
## `heat`     moltiplicatore sull'attenzione che si prende vendendo in strada.
## `name`     chiave di traduzione mostrata nell'HUD.
const TYPES := {
	"clear": {
		"tint": Color(1.00, 1.00, 1.00), "dark": false, "shadows": 1.00,
		"rain": 0.0, "fog": 0.0, "clouds": 0.08, "wind": 0.10, "thunder": 0.0,
		"demand": 1.15, "heat": 1.10, "name": "WEATHER_CLEAR",
	},
	"clouds": {
		"tint": Color(0.93, 0.94, 0.97), "dark": false, "shadows": 0.55,
		"rain": 0.0, "fog": 0.05, "clouds": 0.55, "wind": 0.30, "thunder": 0.0,
		"demand": 1.00, "heat": 1.00, "name": "WEATHER_CLOUDS",
	},
	"overcast": {
		"tint": Color(0.78, 0.80, 0.86), "dark": false, "shadows": 0.15,
		"rain": 0.0, "fog": 0.18, "clouds": 0.85, "wind": 0.40, "thunder": 0.0,
		"demand": 0.90, "heat": 0.92, "name": "WEATHER_OVERCAST",
	},
	"rain": {
		"tint": Color(0.63, 0.68, 0.80), "dark": true, "shadows": 0.05,
		"rain": 0.62, "fog": 0.22, "clouds": 0.70, "wind": 0.45, "thunder": 0.0,
		"demand": 0.62, "heat": 0.70, "name": "WEATHER_RAIN",
	},
	"storm": {
		"tint": Color(0.48, 0.53, 0.68), "dark": true, "shadows": 0.0,
		"rain": 1.00, "fog": 0.30, "clouds": 0.95, "wind": 0.85, "thunder": 9.0,
		"demand": 0.38, "heat": 0.55, "name": "WEATHER_STORM",
	},
	"fog": {
		"tint": Color(0.74, 0.76, 0.79), "dark": true, "shadows": 0.10,
		"rain": 0.0, "fog": 0.80, "clouds": 0.20, "wind": 0.05, "thunder": 0.0,
		"demand": 0.78, "heat": 0.58, "name": "WEATHER_FOG",
	},
}

## Che tempo può venire dopo quello di oggi, e con che peso.
##
## Una tabella di passaggi e non un dado piatto su sei voci, perché il tempo
## vero ha una direzione: si annuvola prima di piovere e si schiarisce dopo. Coi
## pesi piatti si passerebbe da sereno a temporale e di nuovo a sereno in tre
## giorni, e il meteo si leggerebbe come rumore invece che come stagione.
##
## Ogni riga somma a 100 per rendere leggibili le percentuali a occhio.
##
## **La pioggia deve restare rara.** La prima tabella pioveva un giorno su
## quattro (distribuzione stazionaria della catena: `rain` + `storm` al 23%) —
## Federico l'ha giocata e ha chiesto un giorno su sette. Non si abbassa il solo
## "rain" di `TRANSITIONS["overcast"]`: la pioggia arriva anche di rimbalzo, da
## `clouds` e da `storm` che torna giù passando da `rain`, quindi il conto che
## conta è quello di TUTTA la catena, non di una riga sola. Questa versione
## pesca acqua (`rain` + `storm`) il 14,5% delle volte — un giorno su 6,9 — e
## ci si arriva così: `clear` e `clouds` restano appiccicosi (tornarci è più
## probabile che lasciarli), `overcast` è il vero bivio fra tornare al coperto
## e cominciare a piovere, e uno `storm` si spegne per gradi passando da
## `rain`/`overcast` invece di schiarirsi di colpo — è l'unica cosa che un
## controllo automatico verifica (`storm.clear` deve restare più basso di
## `clouds.clear`, vedi `_test_weather()`).
const TRANSITIONS := {
	"clear": {"clear": 52, "clouds": 32, "overcast": 6, "fog": 10},
	"clouds": {"clear": 36, "clouds": 32, "overcast": 21, "rain": 8, "fog": 3},
	"overcast": {"clouds": 36, "overcast": 24, "rain": 27, "storm": 8, "fog": 5},
	"rain": {"overcast": 38, "rain": 24, "storm": 10, "clouds": 25, "clear": 3},
	"storm": {"rain": 35, "overcast": 35, "clouds": 20, "clear": 10},
	"fog": {"fog": 20, "clear": 25, "clouds": 30, "overcast": 25},
}

# --- Consultare la tabella --------------------------------------------------

## La riga di un tipo di tempo. Una chiave sconosciuta — un salvataggio scritto
## con una tabella diversa — ricade sul sereno invece di schiantare.
static func entry(weather_id: String) -> Dictionary:
	return TYPES.get(weather_id, TYPES[DEFAULT])

## Il tempo che fa nella partita in corso, col ripiego per quando non c'è
## nessuna partita (menu, scena aperta dall'editor).
static func of(data: SaveData) -> String:
	if data == null or not TYPES.has(data.weather):
		return DEFAULT
	return data.weather

static func tint(weather_id: String) -> Color:
	return entry(weather_id)["tint"]

static func name_key(weather_id: String) -> String:
	return str(entry(weather_id)["name"])

## Come si chiama, nella lingua scelta. Passa dal `TranslationServer` e non da
## `tr()` perché questa è una funzione statica e `tr()` è un metodo di `Object`:
## è lo stesso giro che fanno `Shop.item_name()` e `Staff.role_name()`.
static func display_name(weather_id: String) -> String:
	return TranslationServer.translate(name_key(weather_id))

## Se c'è acqua per strada. La usano le stanze per mettere la pioggia sui vetri
## e la città per il luccichio sull'asfalto.
static func is_wet(weather_id: String) -> bool:
	return float(entry(weather_id)["rain"]) > 0.0

## Se vale la pena disegnare un temporale: lampi e tuoni.
static func has_thunder(weather_id: String) -> bool:
	return float(entry(weather_id)["thunder"]) > 0.0

# --- Quanto pesa in partita -------------------------------------------------

## Quanto compra oggi la gente per strada, rispetto a una giornata normale.
static func demand_mod(weather_id: String) -> float:
	return float(entry(weather_id)["demand"])

## Quanto ci si fa notare vendendo in strada, rispetto a una giornata normale.
## Sotto la pioggia la gente cammina a testa bassa e le pattuglie stanno in
## macchina: si vende meno, ma quel poco si vende più tranquilli.
static func heat_mod(weather_id: String) -> float:
	return float(entry(weather_id)["heat"])

# --- Il giorno nuovo --------------------------------------------------------

## Che tempo fa domani, visto che tempo fa oggi.
##
## Il tiro passa da `randf()` e non da un seme fisso: come il prezzo del giorno,
## il tempo di domani non deve essere prevedibile da chi ha già visto la
## tabella. A tenerlo stabile fra un caricamento e l'altro è il salvataggio, non
## il determinismo.
static func roll(previous: String) -> String:
	var row: Dictionary = TRANSITIONS.get(previous, TRANSITIONS[DEFAULT])
	var total := 0
	for key in row:
		total += int(row[key])
	if total <= 0:
		return DEFAULT
	var pick := randi() % total
	for key in row:
		pick -= int(row[key])
		if pick < 0:
			return str(key)
	return DEFAULT

## Quanti secondi veri mancano al prossimo fulmine, -1 se non c'è temporale.
##
## L'intervallo della tabella è la media, e intorno c'è mezzo scarto: fulmini a
## cadenza fissa si contano, e una volta contati smettono di far paura.
##
## Sta qui e non in `atmosphere.gd` perché il temporale lo sentono in due — la
## città e le stanze — e sono due scene diverse che non si vedono mai. L'unica
## cosa che hanno in comune è questa tabella.
static func next_bolt_delay(weather_id: String) -> float:
	var mean := float(entry(weather_id)["thunder"])
	if mean <= 0.0:
		return -1.0
	return mean * randf_range(0.5, 1.6)

## Le righe che non tornano, come testo leggibile. Vuoto vuol dire tutto a
## posto. La usa il controllo automatico, come `Strings.problems()`: una tabella
## dei passaggi con dentro un tipo che non esiste manderebbe il meteo su un
## default silenzioso, che è il tipo di errore che non si vede mai.
static func problems() -> Array:
	var found: Array = []
	const FIELDS := [
		"tint", "dark", "shadows", "rain", "fog", "clouds", "wind", "thunder",
		"demand", "heat", "name",
	]
	for key in TYPES:
		for field in FIELDS:
			if not (TYPES[key] as Dictionary).has(field):
				found.append("al tempo %s manca il campo %s" % [key, field])
		if not TRANSITIONS.has(key):
			found.append("il tempo %s non ha una riga nei passaggi" % key)
	for key in TRANSITIONS:
		if not TYPES.has(key):
			found.append("i passaggi partono da %s, che non e' un tempo" % key)
		for target in TRANSITIONS[key]:
			if not TYPES.has(target):
				found.append("da %s si puo' andare a %s, che non e' un tempo" % [key, target])
	return found
