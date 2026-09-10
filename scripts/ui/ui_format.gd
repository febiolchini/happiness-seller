class_name UiFormat
extends RefCounted

## Come si scrivono a schermo soldi, orari e durate.
##
## Sta in un file suo perché gli stessi numeri compaiono nell'HUD, nel
## gestionale del PC, nei vasi e nella gestione salvataggi: la prima volta che
## se ne scrive una copia in più, prima o poi le due versioni si allontanano e
## lo stesso valore compare scritto in due modi diversi nella stessa schermata.
##
## Nota sul font: tutto quello che c'è qui contiene cifre, e `alphabet.fnt` ha
## solo lettere e spazio. Le Label che mostrano queste stringhe devono usare il
## font di sistema, non quello del gioco.

## 1250 -> "1.250 $", col punto delle migliaia come si scrive in italiano.
static func money(amount: int) -> String:
	return "%s $" % number(amount)

static func number(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += "."
		grouped += digits[i]
	return ("-" if amount < 0 else "") + grouped

## Ore in formato 0.0-24.0 -> "08:30".
static func clock(time_of_day: float) -> String:
	var total_minutes := int(time_of_day * 60.0) % 1440
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]

## Durata in ore di gioco -> "18H" oppure "35M". In un gestionale interessa
## l'ordine di grandezza, non il decimale.
static func duration(hours: float) -> String:
	if hours <= 0.0:
		return "NOW"
	if hours >= 1.0:
		return "%dH" % int(roundf(hours))
	return "%dM" % maxi(1, int(roundf(hours * 60.0)))

## Secondi di gioco effettivo -> "2h 14m", per la gestione salvataggi.
static func play_time(seconds: float) -> String:
	var total_minutes := int(seconds) / 60
	if total_minutes < 60:
		return "%dm" % total_minutes
	return "%dh %02dm" % [total_minutes / 60, total_minutes % 60]
