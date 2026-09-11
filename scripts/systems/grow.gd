class_name Grow
extends RefCounted

## La coltivazione: un vaso del seminterrato, dal seme al raccolto.
##
## **La crescita non viene simulata frame per frame.** Un vaso salva l'ora di
## gioco in cui è stato piantato e lo stadio è una funzione pura di quanto tempo
## è passato da allora. Questo è il punto centrale del sistema: le piante
## crescono anche mentre il giocatore è in giro per la città o ha il gioco
## chiuso, senza che nessuno debba tenere il conto, e ricaricare un salvataggio
## non azzera niente.
##
## Un vaso è un semplice `Dictionary` dentro a `SaveData.plots`, e un vaso vuoto
## è un dizionario vuoto: così `SaveData` non ha bisogno di conoscere questa
## classe e non si crea un giro di dipendenze fra i due.
##
## Campi di un vaso piantato:
## - `strain`      id della varietà (vedi `Economy.STRAINS`)
## - `planted_at`  ora di gioco assoluta della semina
## - `watered_at`  ora dell'ultima annaffiatura
## - `checked_at`  fin dove è già stata contata la sete (vedi `sync()`)
## - `dry_hours`   ore di sete accumulate: è quello che rovina la resa
## - `hours`       durata del ciclo per QUESTA pianta
## - `grams`       resa piena di QUESTA pianta
##
## Gli ultimi due sono la fotografia dell'attrezzatura presa al momento della
## semina (vedi `Shop.grow_mods()`): stanno sul vaso e non si rileggono dal
## negozio, altrimenti comprare le lampade a metà ciclo cambierebbe la durata di
## una pianta già a due terzi del percorso e il conto alla rovescia salterebbe
## all'indietro. Mancano nei vasi piantati prima del negozio, e lì si ricade sui
## valori della varietà.

enum Stage { EMPTY, SEEDLING, VEGETATIVE, FLOWERING, READY }

## Chiavi dei nomi mostrati a schermo, nell'ordine dell'enum. Le tre versioni
## stanno in `Strings`; qui ci sono solo le chiavi, perché questa classe non
## deve sapere in che lingua sta girando il gioco.
const STAGE_KEYS := ["GROW_EMPTY", "GROW_SEEDLING", "GROW_VEGETATIVE", "GROW_FLOWERING", "GROW_READY"]

## Inizio di ogni stadio in frazione del ciclo completo. L'ultimo è il raccolto.
const STAGE_STARTS := [0.0, 0.20, 0.55, 1.0]

## Ogni quante ore di gioco la pianta ha di nuovo sete.
##
## Va letta insieme a `grow_hours` della varietà (29) e a
## `GameState.GAME_MINUTES_PER_SECOND`: a 12 servono due annaffiature per
## ciclo, una ogni tre minuti reali circa. Abbassarla vuol dire trasformare la
## coltivazione in una guardia a vista, che non è il gioco che si vuole.
const WATER_HOURS := 12.0
## Sete accumulata che porta la resa al minimo.
const MAX_DRY_HOURS := 40.0
## Anche una pianta trascurata dà qualcosa: sotto questa frazione non si scende.
const MIN_QUALITY := 0.35

# --- Stato del vaso --------------------------------------------------------

static func is_empty(plot: Dictionary) -> bool:
	return plot.is_empty()

## Mette un seme nel vaso. Modifica il dizionario **sul posto** invece di
## restituirne uno nuovo, così chi lo tiene in un array non deve reinserirlo.
## `mods` è la fotografia dell'attrezzatura, con le chiavi `hours` e `grams`
## (vedi `Shop.grow_mods()`). Vuoto vuol dire "a mani nude": si usano i valori
## della varietà.
static func plant(plot: Dictionary, strain_id: String, now: float, mods: Dictionary = {}) -> void:
	plot.clear()
	plot["strain"] = strain_id
	plot["planted_at"] = now
	plot["watered_at"] = now
	plot["checked_at"] = now
	plot["dry_hours"] = 0.0
	plot["hours"] = float(mods.get("hours", Economy.strain(strain_id)["grow_hours"]))
	plot["grams"] = int(mods.get("grams", Economy.strain(strain_id)["grams"]))

static func strain_of(plot: Dictionary) -> String:
	return str(plot.get("strain", Economy.DEFAULT_STRAIN))

static func grow_hours(plot: Dictionary) -> float:
	return maxf(1.0, float(plot.get("hours", Economy.strain(strain_of(plot))["grow_hours"])))

## Resa piena di questa pianta, prima che la sete ci metta le mani.
static func full_grams(plot: Dictionary) -> int:
	return maxi(1, int(plot.get("grams", Economy.strain(strain_of(plot))["grams"])))

## Avanza il conto della sete fino a `now`.
##
## È l'unico pezzo che ha bisogno di essere "spinto avanti", perché la sete si
## accumula e non si può ricavare dai soli timestamp: annaffiare due volte non
## deve cancellare la sete di ieri. Si chiama pigramente, ogni volta che un
## vaso viene letto — è idempotente e monotona, quindi chiamarla spesso o di
## rado dà lo stesso risultato.
static func sync(plot: Dictionary, now: float) -> void:
	if plot.is_empty():
		return
	var checked := float(plot.get("checked_at", now))
	if now <= checked:
		return
	# La sete inizia a contare solo dopo `WATER_HOURS` dall'ultima annaffiatura.
	var thirsty_from := float(plot.get("watered_at", now)) + WATER_HOURS
	var from := maxf(checked, thirsty_from)
	if now > from:
		plot["dry_hours"] = float(plot.get("dry_hours", 0.0)) + (now - from)
	plot["checked_at"] = now

static func water(plot: Dictionary, now: float) -> void:
	if plot.is_empty():
		return
	sync(plot, now)
	plot["watered_at"] = now

# --- Crescita --------------------------------------------------------------

## Avanzamento del ciclo, 0.0 = appena piantato, 1.0 = pronto. Può superare 1
## (una pianta pronta lasciata lì non peggiora, aspetta).
static func progress(plot: Dictionary, now: float) -> float:
	if plot.is_empty():
		return 0.0
	return maxf(0.0, (now - float(plot.get("planted_at", now))) / grow_hours(plot))

static func stage(plot: Dictionary, now: float) -> Stage:
	if plot.is_empty():
		return Stage.EMPTY
	var p := progress(plot, now)
	if p >= STAGE_STARTS[3]:
		return Stage.READY
	if p >= STAGE_STARTS[2]:
		return Stage.FLOWERING
	if p >= STAGE_STARTS[1]:
		return Stage.VEGETATIVE
	return Stage.SEEDLING

## Il nome dello stadio, già tradotto.
static func stage_name(plot: Dictionary, now: float) -> String:
	return TranslationServer.translate(STAGE_KEYS[stage(plot, now)])

static func is_ready(plot: Dictionary, now: float) -> bool:
	return stage(plot, now) == Stage.READY

## Ore di gioco che mancano al raccolto, 0 se è già pronto.
static func hours_left(plot: Dictionary, now: float) -> float:
	if plot.is_empty():
		return 0.0
	return maxf(0.0, float(plot.get("planted_at", now)) + grow_hours(plot) - now)

# --- Sete ------------------------------------------------------------------

static func is_thirsty(plot: Dictionary, now: float) -> bool:
	if plot.is_empty():
		return false
	return now - float(plot.get("watered_at", now)) >= WATER_HOURS

# --- Resa ------------------------------------------------------------------

## Qualità della pianta, 0-1: parte da 1 e scende con la sete accumulata.
## Va letta DOPO `sync()`, altrimenti non tiene conto del tempo appena passato.
static func quality(plot: Dictionary) -> float:
	if plot.is_empty():
		return 0.0
	var dry := float(plot.get("dry_hours", 0.0))
	return clampf(1.0 - dry / MAX_DRY_HOURS, MIN_QUALITY, 1.0)

## Grammi che darebbe il raccolto adesso.
static func yield_grams(plot: Dictionary) -> int:
	if plot.is_empty():
		return 0
	return maxi(1, int(roundf(float(full_grams(plot)) * quality(plot))))

## Raccoglie e svuota il vaso. Restituisce i grammi, 0 se non era pronto.
static func harvest(plot: Dictionary, now: float) -> int:
	sync(plot, now)
	if not is_ready(plot, now):
		return 0
	var grams := yield_grams(plot)
	plot.clear()
	return grams

# --- Comodità su tutto il seminterrato -------------------------------------

## Annaffia tutti i vasi che avevano sete. Restituisce quanti ne ha bagnati.
static func water_all(plots: Array, now: float) -> int:
	var count := 0
	for plot in plots:
		if is_empty(plot) or not is_thirsty(plot, now):
			continue
		water(plot, now)
		count += 1
	return count

## Raccoglie tutte le piante pronte. Restituisce i grammi totali.
static func harvest_all(plots: Array, now: float) -> int:
	var grams := 0
	for plot in plots:
		grams += harvest(plot, now)
	return grams

static func count_ready(plots: Array, now: float) -> int:
	var count := 0
	for plot in plots:
		if is_ready(plot, now):
			count += 1
	return count

static func count_thirsty(plots: Array, now: float) -> int:
	var count := 0
	for plot in plots:
		if is_thirsty(plot, now):
			count += 1
	return count
