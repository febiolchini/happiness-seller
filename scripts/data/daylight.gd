class_name Daylight
extends RefCounted

## Che luce c'è a una data ora, e tutto quello che ne consegue: il colore
## dell'aria, la direzione delle ombre, quando si accendono i lampioni, quante
## finestre sono illuminate.
##
## È una tabella di dati come `CityMap` e `Economy`, per lo stesso motivo: la
## luce di un gioco è bilanciamento, non logica. Qui ci sono i colori di dieci
## momenti della giornata e delle funzioni pure che li interpolano; chi disegna
## chiede "che luce c'è adesso" e non sa niente di come ci si è arrivati.
##
## ## Perché nessuno tiene lo stato della luce
##
## Come la crescita delle piante e il lavoro del personale, la luce **non è
## simulata**: non c'è un nodo che porta avanti un colore un frame per volta e
## se lo salva. Si guarda che ore sono e si ricava il colore, sempre. Così
## ricaricare una partita alle 19:40 la ritrova esattamente nella luce del
## tramonto in cui era, senza che il salvataggio contenga un solo colore.
##
## ## Come arriva a schermo
##
## `atmosphere.gd` prende `light()` e lo mette nel `CanvasModulate` della City,
## che moltiplica tutto quello che sta sulla tela del mondo — terreno, edifici,
## persone, auto. Le cose che devono restare ACCESE dentro a quel buio
## (lampioni, finestre, fari, insegne) si disegnano con `emissive()`, che
## pre-divide il colore per la luce dell'ambiente: moltiplicato dal
## `CanvasModulate` torna quello che si voleva. È verificato sul motore che i
## colori sopra a 1.0 sopravvivano alla moltiplicazione, ed è quello che rende
## inutile una seconda tela solo per le luci.

## Chi deve ridisegnarsi quando la luce cambia si mette in questo gruppo e
## implementa `on_light_changed()`. Lo chiama `atmosphere.gd`, che è l'unico a
## sapere quando la luce è cambiata abbastanza da vedersi.
##
## Il nome sta qui e non in `atmosphere.gd` perché quello è uno script di scena
## senza `class_name`: i componenti non potrebbero nominarlo. Questa invece è
## già la classe che tutti quanti interrogano per sapere che luce c'è.
const LIGHT_GROUP := "skywatch"

## Ora mostrata quando non c'è nessuna partita: la città dietro al menu, o una
## scena aperta dall'editor. Sera presto — lampioni accesi e cielo ancora caldo,
## che è il momento in cui una città fatta di segnaposto si legge meglio.
const MENU_HOUR := 20.4

## Il colore dell'aria in dieci momenti della giornata, compresi i due estremi
## che chiudono il giro a mezzanotte.
##
## `air` moltiplica tutto il mondo, e **non scende mai vicino allo zero**: un
## gestionale si gioca anche di notte, e una notte a 0.1 è una schermata nera
## con dentro dei soldi da contare. La notte qui è blu e scura quanto basta per
## cambiare umore restando leggibile; a rendere la differenza fra giorno e notte
## sono i lampioni accesi e le finestre, non il buio.
##
## `void_color` è il fondale oltre ai bordi del mondo: segue l'aria ma molto più
## cupo, perché è cielo e non terreno illuminato.
const KEYFRAMES := [
	{"hour": 0.0, "air": Color(0.30, 0.33, 0.55), "void_color": Color(0.05, 0.06, 0.12)},
	{"hour": 5.0, "air": Color(0.31, 0.34, 0.55), "void_color": Color(0.06, 0.07, 0.13)},
	{"hour": 6.6, "air": Color(0.66, 0.52, 0.55), "void_color": Color(0.24, 0.17, 0.22)},
	{"hour": 7.8, "air": Color(0.94, 0.84, 0.76), "void_color": Color(0.36, 0.34, 0.36)},
	{"hour": 10.0, "air": Color(1.00, 0.99, 0.95), "void_color": Color(0.30, 0.40, 0.47)},
	{"hour": 13.0, "air": Color(1.00, 1.00, 0.99), "void_color": Color(0.32, 0.43, 0.50)},
	{"hour": 17.0, "air": Color(1.00, 0.95, 0.86), "void_color": Color(0.31, 0.39, 0.45)},
	{"hour": 19.1, "air": Color(0.98, 0.73, 0.56), "void_color": Color(0.35, 0.23, 0.22)},
	{"hour": 20.4, "air": Color(0.63, 0.53, 0.63), "void_color": Color(0.17, 0.14, 0.22)},
	{"hour": 21.6, "air": Color(0.34, 0.37, 0.57), "void_color": Color(0.07, 0.08, 0.14)},
	{"hour": 24.0, "air": Color(0.30, 0.33, 0.55), "void_color": Color(0.05, 0.06, 0.12)},
]

## Fra queste due ore il sole è sopra l'orizzonte: fuori ci sono ombre portate e
## i lampioni sono spenti.
const SUNRISE := 6.4
const SUNSET := 19.6

## Quanto è lunga l'ombra rispetto a quello che la proietta, col sole allo zenit
## e col sole radente. Le due cose che fanno leggere l'ora a colpo d'occhio
## senza guardare l'orologio sono la lunghezza dell'ombra e il colore della
## luce, in quest'ordine.
const SHADOW_SHORT := 0.45
const SHADOW_LONG := 2.30
## Quanto è marcata l'ombra col sole alto. Col sole basso si allunga ma sbiadisce.
const SHADOW_STRONG := 0.30
const SHADOW_WEAK := 0.13
## Di notte resta un velo sotto alle cose. Non è un'ombra portata, è il contatto
## con il terreno: senza, di notte tutto sembra staccato da terra e galleggia.
const SHADOW_NIGHT := 0.16

## Oltre questo valore `emissive()` non spinge. Senza un tetto, una notte molto
## scura farebbe schizzare i numeri e il primo lampione acceso diventerebbe una
## macchia bianca piatta senza più colore dentro.
const EMISSIVE_CEILING := 5.0

# --- L'ora ------------------------------------------------------------------

## Che ore sono nella partita in corso. Senza partita — la città dietro al menu,
## una scena aperta dall'editor, i controlli automatici — vale l'ora del menu
## invece di schiantare su un `current` che non c'è.
static func hour_of(data: SaveData) -> float:
	if data == null:
		return MENU_HOUR
	return data.time_of_day

# --- Il colore dell'aria ----------------------------------------------------

## Il colore del sole a quell'ora, senza meteo: è la tabella qui sopra,
## interpolata.
static func air(hour: float) -> Color:
	return _sample(hour, "air")

## Il fondale oltre ai bordi del mondo.
static func void_color(hour: float) -> Color:
	return _sample(hour, "void_color")

## La luce che c'è davvero adesso: l'ora, e sopra il meteo del giorno.
##
## È questo il valore che finisce nel `CanvasModulate`, ed è quello da passare a
## `emissive()`. Usare `air()` e basta vorrebbe dire una giornata di pioggia
## identica a una di sole, che è il modo più veloce di ridurre il meteo a una
## decorazione appiccicata sopra.
static func light(data: SaveData) -> Color:
	var tint := Weather.tint(Weather.of(data))
	var value := air(hour_of(data))
	return Color(value.r * tint.r, value.g * tint.g, value.b * tint.b, 1.0)

## Quanto è illuminata la scena, 0 (notte fonda) - 1 (mezzogiorno sereno).
## Serve a chi deve decidere qualcosa in base alla luce senza mettersi a
## ragionare sui singoli canali di un colore.
static func brightness(data: SaveData) -> float:
	var value := light(data)
	return clampf((value.r + value.g + value.b) / 3.0, 0.0, 1.0)

# --- Il sole ----------------------------------------------------------------

## Quanto è alto il sole: 0 sotto l'orizzonte, 1 a mezzogiorno.
##
## È una campana e non una retta perché il sole resta alto per mezza giornata e
## sale e scende in fretta agli estremi, ed è lì che le ombre si allungano.
static func sun_height(hour: float) -> float:
	if hour <= SUNRISE or hour >= SUNSET:
		return 0.0
	return sin((hour - SUNRISE) / (SUNSET - SUNRISE) * PI)

## L'ombra che c'è adesso: da che parte cade, quanto è lunga, quanto è marcata.
##
## La direzione punta sempre un po' verso il basso, anche a mezzogiorno: la
## vista è obliqua, e un'ombra che a mezzogiorno sparisce sotto ai piedi toglie
## il contatto con il terreno proprio nell'ora in cui dovrebbe essere più netto.
##
## Il meteo conta quanto l'ora: col cielo coperto la luce arriva da tutte le
## parti e le ombre portate non esistono. È il dettaglio che fa capire che il
## tempo è cambiato anche senza guardare la pioggia.
static func shadow(data: SaveData) -> Dictionary:
	var hour := hour_of(data)
	var height := sun_height(hour)
	var sharp := float(Weather.entry(Weather.of(data))["shadows"])

	if height <= 0.0:
		# Di notte non c'è nessuna ombra portata: resta solo il contatto con il
		# terreno, che è il motivo per cui la lunghezza qui è quasi zero e non
		# `SHADOW_SHORT`. Con quella, ogni edificio della città si porterebbe
		# dietro una macchia scura verso il basso anche a mezzanotte.
		return {"direction": Vector2(0.0, 1.0), "length": 0.12, "alpha": SHADOW_NIGHT}

	# Il sole nasce a est e tramonta a ovest: l'ombra parte lunga verso ovest,
	# si accorcia passando sotto, e riparte allungandosi verso est.
	var across := cos((hour - SUNRISE) / (SUNSET - SUNRISE) * PI)
	return {
		"direction": Vector2(-across, 0.45 + 0.35 * height).normalized(),
		"length": lerpf(SHADOW_LONG, SHADOW_SHORT, height),
		# Sotto le nuvole l'ombra portata non sparisce del tutto: resta il velo
		# di contatto, lo stesso che c'è di notte.
		"alpha": maxf(SHADOW_NIGHT * sharp, lerpf(SHADOW_WEAK, SHADOW_STRONG, height) * sharp),
	}

# --- Le luci artificiali ----------------------------------------------------

## Se lampioni, fari e insegne sono accesi.
##
## Non dipende solo dall'ora: sotto un temporale o nella nebbia si accendono
## anche di giorno, che è quello che succede davvero ed è anche il modo più
## diretto di far vedere che il tempo è brutto.
static func lamps_on(data: SaveData) -> bool:
	var hour := hour_of(data)
	# Un'ora prima del tramonto e un'ora dopo l'alba: è quando si accendono
	# davvero, e serve anche a non lasciare un buco fra il momento in cui la
	# gente accende le luci in casa e quello in cui si accende la strada.
	if hour < SUNRISE + 0.9 or hour > SUNSET - 1.2:
		return true
	return bool(Weather.entry(Weather.of(data))["dark"])

## Quanto sono accese, 0-1.
##
## Sul far della sera salgono insieme al buio invece di scattare da spente a
## piene: uno stacco secco all'ora esatta si legge come un interruttore, non
## come una città che accende le luci.
static func lamp_strength(data: SaveData) -> float:
	if not lamps_on(data):
		return 0.0
	var hour := hour_of(data)
	var fade := 1.0
	if hour > SUNSET - 2.0 and hour < SUNSET + 1.0:
		fade = clampf((hour - (SUNSET - 2.0)) / 3.0, 0.0, 1.0)
	elif hour > SUNRISE - 1.0 and hour < SUNRISE + 2.0:
		fade = clampf(((SUNRISE + 2.0) - hour) / 3.0, 0.0, 1.0)
	# Col brutto tempo restano accese comunque, anche in pieno giorno.
	if bool(Weather.entry(Weather.of(data))["dark"]):
		fade = maxf(fade, 0.7)
	return fade

## Che quota di finestre è accesa a quest'ora, 0-1.
##
## La curva è quella di un palazzo vero e non una sinusoide: si accendono presto
## la mattina, si spengono quasi tutte di giorno, sono al massimo dopo cena e
## calano piano fino alle ore piccole. È quello che rende una fila di edifici
## una città abitata invece di una fila di scatole con dei buchi gialli.
static func window_lit_ratio(hour: float) -> float:
	const CURVE := [
		[0.0, 0.10], [3.0, 0.04], [5.5, 0.10], [7.0, 0.34], [8.5, 0.16],
		[11.0, 0.06], [16.5, 0.10], [18.5, 0.45], [21.0, 0.62], [23.0, 0.38],
		[24.0, 0.10],
	]
	var wrapped := fposmod(hour, 24.0)
	for i in range(CURVE.size() - 1):
		var from: Array = CURVE[i]
		var to: Array = CURVE[i + 1]
		if wrapped >= float(from[0]) and wrapped <= float(to[0]):
			var span := float(to[0]) - float(from[0])
			var t := 0.0 if span <= 0.0 else (wrapped - float(from[0])) / span
			return lerpf(float(from[1]), float(to[1]), t)
	return 0.10

# --- Disegnare cose accese --------------------------------------------------

## Il colore da passare a `draw_*` perché una cosa ACCESA resti accesa dentro al
## buio della sera.
##
## Il `CanvasModulate` della City moltiplica tutto per la luce dell'ambiente:
## una finestra gialla, disegnata gialla, alle nove di sera viene fuori marrone.
## Qui il colore viene pre-diviso per quella stessa luce, così la
## moltiplicazione lo riporta dov'era.
##
## L'opacità non si tocca: il `CanvasModulate` non la moltiplica, e dividerla
## renderebbe opaco ogni alone.
static func emissive(color: Color, ambient: Color) -> Color:
	return Color(
		minf(color.r / maxf(ambient.r, 0.04), EMISSIVE_CEILING),
		minf(color.g / maxf(ambient.g, 0.04), EMISSIVE_CEILING),
		minf(color.b / maxf(ambient.b, 0.04), EMISSIVE_CEILING),
		color.a)

# --- Interpolazione ---------------------------------------------------------

## Il valore di un campo della tabella all'ora data.
##
## La tabella ha sia l'ora 0 sia l'ora 24 con lo stesso colore, quindi il giro
## si chiude da solo a mezzanotte senza un caso a parte: è lo stesso motivo per
## cui `time_of_day` torna a zero invece di crescere all'infinito.
static func _sample(hour: float, field: String) -> Color:
	var wrapped := fposmod(hour, 24.0)
	for i in range(KEYFRAMES.size() - 1):
		var from: Dictionary = KEYFRAMES[i]
		var to: Dictionary = KEYFRAMES[i + 1]
		if wrapped >= float(from["hour"]) and wrapped <= float(to["hour"]):
			var span := float(to["hour"]) - float(from["hour"])
			var t := 0.0 if span <= 0.0 else (wrapped - float(from["hour"])) / span
			# `smoothstep` e non lineare: fra un keyframe e l'altro il colore
			# parte e arriva piano, e il passaggio non ha spigoli proprio
			# all'alba e al tramonto, che sono le due ore in cui si guarda.
			return (from[field] as Color).lerp(to[field] as Color, smoothstep(0.0, 1.0, t))
	return KEYFRAMES[0][field]
