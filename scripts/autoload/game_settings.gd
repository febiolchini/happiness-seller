extends Node

## Autoload: le preferenze che valgono per tutto il gioco e non per una partita
## sola. Per ora c'è solo la lingua.
##
## Stanno **fuori** dai salvataggi di proposito: la lingua è una proprietà di
## chi gioca, non della partita. Metterla dentro a `SaveData` vorrebbe dire che
## caricare un salvataggio vecchio rimette il gioco nella lingua in cui era
## stato iniziato, e che una partita nuova non sa in che lingua leggevi un
## minuto prima. Vanno quindi in un file loro, `user://settings.cfg`.
##
## È anche il posto da cui le traduzioni entrano nel motore: vedi
## `_install_translations()`.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "game"

## Emesso quando la lingua cambia. Ci si aggancia chi ha del testo già scritto a
## schermo e costruito dal codice: le Label dei `Control` le ritraduce Godot da
## sola, ma una stringa composta con `%` — "12 g", "GIORNO 3 08:40" — è stata
## messa lì da noi e va rifatta.
signal locale_changed(locale: String)

var locale := Strings.LOCALES[0]:
	set(value):
		var wanted := value if value in Strings.LOCALES else Strings.LOCALES[0]
		if wanted == locale and TranslationServer.get_locale() == wanted:
			return
		locale = wanted
		TranslationServer.set_locale(wanted)
		locale_changed.emit(wanted)

func _ready() -> void:
	_install_translations()
	_load()

## Riversa `Strings.TEXT` nel `TranslationServer`, una `Translation` per lingua.
##
## Costruite qui e non importate da un CSV: in questo progetto i dati stanno in
## tabelle GDScript (`city_map.gd`, `npc_roster.gd`, `economy.gd`), e un CSV
## sarebbe l'unico file di contenuto che non si legge insieme al codice che lo
## usa. In cambio non c'è nessun passaggio di importazione da ricordarsi: si
## aggiunge una riga alla tabella e al riavvio c'è.
func _install_translations() -> void:
	for i in Strings.LOCALES.size():
		var translation := Translation.new()
		translation.locale = Strings.LOCALES[i]
		for key in Strings.TEXT:
			var row: Array = Strings.TEXT[key]
			if i < row.size():
				translation.add_message(key, str(row[i]))
		TranslationServer.add_translation(translation)

# --- Il file ----------------------------------------------------------------

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		# Primo avvio: si parte dalla lingua del sistema, se è una di quelle che
		# il gioco parla. Chiedere la lingua a chi apre il gioco per la prima
		# volta quando il sistema l'ha già detta è una schermata in più per
		# niente.
		locale = _system_locale()
		save()
		return
	locale = str(config.get_value(SECTION, "locale", _system_locale()))

func save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "locale", locale)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Impossibile scrivere le impostazioni in %s" % SETTINGS_PATH)

## La lingua del sistema, se il gioco la parla; altrimenti la prima dell'elenco.
## `OS.get_locale()` torna roba tipo "it_IT", quindi si guarda solo la parte
## prima dell'underscore.
func _system_locale() -> String:
	var system := OS.get_locale().split("_")[0]
	return system if system in Strings.LOCALES else Strings.LOCALES[0]
