class_name Strings
extends RefCounted

## Tutto il testo che il giocatore legge, nelle tre lingue.
##
## È una tabella di dati come `CityMap` e `NpcRoster`, per lo stesso motivo: le
## traduzioni sono contenuto, non logica, e sparse fra le scene non si
## ritrovano più. Qui invece una riga sola tiene le tre versioni della stessa
## frase una sotto l'altra, ed è l'unico posto da guardare per sapere se ne
## manca una.
##
## Le stringhe finiscono nel `TranslationServer` all'avvio
## (`GameSettings._install_translations()`), quindi nel resto del progetto si
## usa `tr("CHIAVE")` e nient'altro. Anche le scene passano da qui: il testo dei
## `Control` scritto nel `.tscn` viene tradotto da Godot da solo, quindi in
## quei campi ci va **la chiave**, non la frase.
##
## ## Le due regole da non rompere
##
## 1. **Una chiave che non c'è viene mostrata così com'è.** `tr()` non avvisa e
##    non torna vuota: restituisce la chiave. Una voce dimenticata si vede a
##    schermo come `PC_TAB_SHOP`, ed è il motivo per cui c'è un controllo
##    automatico che verifica che ogni lingua abbia ogni riga.
##
## 2. **Le chiavi marcate PIXEL possono contenere solo lettere e spazio.**
##    Sono quelle mostrate col font del gioco (`alphabet.fnt`) o col pennello
##    dei menu (`brush.fnt`), che hanno cinquantatré caratteri: A-Z, a-z e lo
##    spazio. Niente cifre, niente
##    accenti, niente apostrofi — una "à" o una "ñ" lì dentro non si disegna e
##    lascia un buco nella parola. Anche per questo lo spagnolo qui dice
##    "ESPANOL" e non "ESPAÑOL". Il controllo automatico verifica anche questo.
##
## Restano volutamente **non tradotti**: i nomi propri (Brian, Tony, gli agenti)
## e le insegne degli edifici in `CityMap`. Sono nomi di posti e di persone di
## una cittadina americana inventata, e tradurli la sposterebbe altrove.

## Le lingue offerte, nell'ordine in cui compaiono nelle impostazioni. Il primo
## è anche quello di ripiego quando una lingua di sistema non è fra queste.
const LOCALES := ["en", "it", "es"]

## Come si chiamano nelle impostazioni. PIXEL: si leggono col font del gioco.
const LOCALE_NAMES := {
	"en": "ENGLISH",
	"it": "ITALIANO",
	"es": "ESPANOL",
}

## chiave -> [inglese, italiano, spagnolo], nell'ordine di `LOCALES`.
##
## Array e non dizionario per riga: sono centocinquanta voci per tre lingue, e
## ripetere `{"en": ..., "it": ...}` ogni volta renderebbe illeggibile proprio
## la cosa che questa tabella deve rendere facile — leggere le tre versioni
## della stessa frase una sotto l'altra.
const TEXT := {
	# --- Menu e impostazioni (PIXEL) ---------------------------------------
	# Le voci del menu principale che prima erano immagini (PLAY, SETTINGS,
	# EXIT, scritte in inglese e basta): adesso sono testo col pennello, e si
	# traducono come le altre.
	"MENU_CONTINUE": ["continue", "continua", "continuar"],
	"MENU_QUIT": ["quit", "esci", "salir"],
	"MENU_NEW_GAME": ["new game", "nuova partita", "partida nueva"],
	"MENU_SAVES": ["saves", "salvataggi", "partidas"],
	"MENU_SETTINGS": ["settings", "impostazioni", "ajustes"],
	"MENU_BACK": ["back", "indietro", "atras"],
	"MENU_VIDEO": ["video", "video", "video"],
	"MENU_AUDIO": ["audio", "audio", "audio"],
	"MENU_COMMANDS": ["commands", "comandi", "controles"],
	"MENU_LANGUAGE": ["language", "lingua", "idioma"],
	# La voce delle impostazioni che decide se il mondo va avanti a gioco
	# chiuso. I due bottoni dicono cosa fa il mondo e non "acceso/spento":
	# la domanda non e' se una voce e' attiva, e' cosa succede mentre non ci
	# sei, e la risposta si legge meglio scritta cosi'.
	"MENU_OFFLINE": ["world offline", "mondo offline", "mundo offline"],
	"MENU_OFFLINE_ON": ["keeps going", "va avanti", "sigue"],
	"MENU_OFFLINE_OFF": ["stays still", "resta fermo", "se detiene"],
	"MENU_LOAD": ["load", "carica", "cargar"],
	"MENU_DELETE": ["delete", "cancella", "borrar"],
	"MENU_SURE": ["sure", "sicuro", "seguro"],

	# --- Gestione salvataggi ----------------------------------------------
	"SAVES_EMPTY": [
		"No saved games on this device.",
		"Nessun salvataggio su questo dispositivo.",
		"No hay partidas guardadas en este dispositivo.",
	],
	## %d giorno, %d soldi, %d proprietà, %s tempo giocato
	"SAVES_LINE": [
		"day %d   %d$   %d properties   %s played",
		"giorno %d   %d$   %d proprietà   %s giocate",
		"dia %d   %d$   %d propiedades   %s jugadas",
	],
	"SAVES_SAVED_ON": ["saved on %s", "salvato il %s", "guardado el %s"],

	# --- HUD ---------------------------------------------------------------
	"HUD_DAY": ["DAY", "GIORNO", "DIA"],

	# --- Che tempo fa ------------------------------------------------------
	# Non sono marcate PIXEL: l'HUD scrive col font di sistema, perché deve
	# mostrare cifre (i soldi, l'orario) che `alphabet.fnt` non ha. Restano
	# comunque di sole lettere, così se un giorno finissero su un cartello o in
	# una schermata scritta col font del gioco non ci sarebbe niente da rifare.
	"WEATHER_CLEAR": ["CLEAR", "SERENO", "DESPEJADO"],
	"WEATHER_CLOUDS": ["CLOUDY", "NUVOLOSO", "NUBLADO"],
	"WEATHER_OVERCAST": ["OVERCAST", "COPERTO", "CUBIERTO"],
	"WEATHER_RAIN": ["RAIN", "PIOGGIA", "LLUVIA"],
	"WEATHER_STORM": ["STORM", "TEMPORALE", "TORMENTA"],
	"WEATHER_FOG": ["FOG", "NEBBIA", "NIEBLA"],

	# --- Stanze (PIXEL) ----------------------------------------------------
	"ROOM_ENTRANCE": ["ENTRANCE", "INGRESSO", "ENTRADA"],
	"ROOM_KITCHEN": ["KITCHEN", "CUCINA", "COCINA"],
	"ROOM_BASEMENT": ["BASEMENT", "CANTINA", "SOTANO"],
	"ROOM_GARAGE": ["GARAGE", "GARAGE", "GARAJE"],
	"ROOM_GENERIC": ["ROOM", "STANZA", "CUARTO"],
	"ROOM_EXIT": ["EXIT", "ESCI", "SALIR"],

	# --- Agenzia immobiliare (PIXEL) ---------------------------------------
	"RE_TITLE": ["PROPERTIES FOR SALE", "PROPRIETA IN VENDITA", "PROPIEDADES EN VENTA"],
	"RE_CLOSE": ["CLOSE", "CHIUDI", "CERRAR"],
	"RE_BUY": ["BUY", "COMPRA", "COMPRAR"],
	"RE_OWNED": ["OWNED", "TUA", "TUYA"],
	"RE_NO_CASH": ["NOT ENOUGH", "SOLDI CORTI", "SIN FONDOS"],
	"RE_CASH": ["CASH", "CONTANTI", "EFECTIVO"],
	"RE_EMPTY": ["NOTHING ON THE BOOKS", "NIENTE IN ELENCO", "NADA EN LISTA"],
	"RE_TITLE_DOWNTOWN": ["DOWNTOWN HOMES", "CASE A DOWNTOWN", "CASAS EN DOWNTOWN"],
	"RE_MERIDIAN_5_NAME": [
		"Meridian Tower, 5th floor", "Meridian Tower, 5 piano", "Meridian Tower, piso 5",
	],
	"RE_MERIDIAN_5_DESC": [
		"Two rooms, city view, doorman downstairs.",
		"Due locali, vista sulla citta', portiere all'ingresso.",
		"Dos ambientes, vista a la ciudad, portero en la entrada.",
	],
	"RE_MERIDIAN_21_NAME": [
		"Meridian Tower, 21st floor", "Meridian Tower, 21 piano", "Meridian Tower, piso 21",
	],
	"RE_MERIDIAN_21_DESC": [
		"Penthouse-level corner flat, glass on two sides.",
		"Attico d'angolo, vetrate su due lati.",
		"Atico en esquina, ventanales en dos lados.",
	],
	"RE_GARAGE_NAME": ["GARAGE ON CROSS STREET", "GARAGE IN CROSS STREET", "GARAJE EN CROSS STREET"],
	## Diceva "NIENTE FINESTRE", e il fondale dell'interno (`rooms/garage.png`) ne
	## ha una rotta a sinistra piu' quelle della serranda: l'annuncio descrive un
	## posto che si va a vedere, e le due cose devono dire la stessa roba. I due
	## banconi sono anche quello che serve sapere, perche' e' li' che ci andranno
	## i vasi.
	"RE_GARAGE_DESC": ["ONE BAY  ROLLER DOOR  TWO BENCHES",
		"UN BOX  SERRANDA  DUE BANCONI",
		"UNA PLAZA  PERSIANA  DOS BANCOS"],

	# --- Il PC: cornice e schede (PIXEL) -----------------------------------
	"PC_TITLE": ["BUSINESS MANAGEMENT", "GESTIONE ATTIVITA", "GESTION DEL NEGOCIO"],
	"PC_CLOSE": ["CLOSE", "CHIUDI", "CERRAR"],
	"PC_TAB_OVERVIEW": ["OVERVIEW", "QUADRO", "RESUMEN"],
	"PC_TAB_GROW": ["GROW", "COLTIVA", "CULTIVO"],
	"PC_TAB_SHOP": ["SHOP", "NEGOZIO", "TIENDA"],
	"PC_TAB_MARKET": ["MARKET", "MERCATO", "MERCADO"],
	"PC_TAB_STAFF": ["STAFF", "PERSONALE", "PERSONAL"],

	# --- Il PC: etichette delle righe (PIXEL) ------------------------------
	"PC_CASH": ["CASH", "CONTANTI", "EFECTIVO"],
	"PC_DAY": ["DAY", "GIORNO", "DIA"],
	"PC_STOCK": ["STOCK", "SCORTA", "EXISTENCIAS"],
	"PC_SEEDS": ["SEEDS", "SEMI", "SEMILLAS"],
	"PC_POTS_IN_USE": ["POTS IN USE", "VASI IN USO", "MACETAS EN USO"],
	"PC_READY_TO_CUT": ["READY TO CUT", "PRONTE DA TAGLIARE", "LISTAS PARA CORTAR"],
	"PC_ATTENTION": ["ATTENTION", "ATTENZIONE", "ATENCION"],
	"PC_GRAMS_HARVESTED": ["GRAMS HARVESTED", "GRAMMI RACCOLTI", "GRAMOS COSECHADOS"],
	"PC_GRAMS_SOLD": ["GRAMS SOLD", "GRAMMI VENDUTI", "GRAMOS VENDIDOS"],
	"PC_TOTAL_EARNED": ["TOTAL EARNED", "TOTALE INCASSATO", "TOTAL GANADO"],
	"PC_STAFF": ["STAFF", "PERSONALE", "PERSONAL"],
	"PC_WAGES": ["WAGES", "PAGHE", "SUELDOS"],
	"PC_SALES_SPLIT": ["SALES SPLIT", "RIPARTIZIONE VENDITE", "REPARTO DE VENTAS"],
	"PC_RESERVED": ["SET ASIDE", "MESSI DA PARTE", "APARTADOS"],
	"PC_GROWER_SITES": ["WHO WORKS WHERE", "CHI LAVORA DOVE", "QUIEN TRABAJA DONDE"],
	"PC_SITE_SPARE": ["NO POSTING", "SENZA POSTO", "SIN PUESTO"],
	"SITE_BASEMENT": ["BASEMENT", "CANTINA", "SOTANO"],
	"SITE_GARAGE": ["GARAGE", "GARAGE", "GARAJE"],
	"PC_WHOLESALE_TODAY": ["WHOLESALE TODAY", "INGROSSO OGGI", "MAYOREO HOY"],
	"PC_STREET_PRICE": ["STREET PRICE", "PREZZO IN STRADA", "PRECIO EN LA CALLE"],
	"PC_STOCK_VALUE": ["STOCK VALUE", "VALORE SCORTA", "VALOR EXISTENCIAS"],
	"PC_VAN": ["VAN", "FURGONE", "FURGONETA"],
	"PC_VAN_TANK": ["TANK", "SERBATOIO", "DEPOSITO"],
	## %d numero del vaso. Font di sistema: contiene una cifra.
	"PC_POT_N": ["POT %d", "VASO %d", "MACETA %d"],
	## %s giorni, %s orario
	"PC_DAY_VALUE": ["%d   %s", "%d   %s", "%d   %s"],

	# --- Il PC: scheda GROW ------------------------------------------------
	"PC_PLOT_EMPTY": ["empty", "vuoto", "vacio"],
	"PC_PLOT_LOCKED": ["locked", "bloccato", "bloqueada"],
	## %s costo
	"PC_PLOT_LOCKED_COST": ["locked  -  %s", "bloccato  -  %s", "bloqueada  -  %s"],
	## %s stadio, %d percentuale, %s tempo che manca
	"PC_PLOT_GROWING": ["%s  %d%%  -  %s", "%s  %d%%  -  %s", "%s  %d%%  -  %s"],
	## %d grammi
	"PC_PLOT_READY": ["READY  -  %d g", "PRONTA  -  %d g", "LISTA  -  %d g"],
	"PC_PLOT_DRY": ["  (dry)", "  (asciutto)", "  (seca)"],
	## %d quanti hanno sete
	"PC_WATER_ALL": [
		"WATER ALL  (%d thirsty)", "ANNAFFIA TUTTO  (%d con sete)", "REGAR TODO  (%d con sed)",
	],
	## %d quante sono pronte
	"PC_HARVEST_ALL": [
		"HARVEST ALL  (%d ready)", "RACCOGLI TUTTO  (%d pronte)", "COSECHAR TODO  (%d listas)",
	],
	## %s costo
	"PC_OPEN_POT": ["OPEN NEW POT  -  %s", "APRI UN VASO  -  %s", "ABRIR MACETA  -  %s"],
	"PC_NO_ROOM_POTS": [
		"NO ROOM FOR MORE POTS", "NON CI STANNO ALTRI VASI", "NO CABEN MAS MACETAS",
	],
	"PC_POTS_NEED_ROOM": [
		"FULL HERE  -  YOU NEED ANOTHER PLACE",
		"QUI E' PIENO  -  SERVE UN ALTRO POSTO",
		"AQUI ESTA LLENO  -  HACE FALTA OTRO SITIO",
	],
	## %d grammi, %s durata
	"PC_YIELD_NOTE": [
		"A plant yields about %d g in %s. Water it or the yield drops.",
		"Una pianta rende circa %d g in %s. Annaffiala o la resa cala.",
		"Una planta da unos %d g en %s. Riegala o el rendimiento baja.",
	],

	# --- Il PC: i semi -----------------------------------------------------
	## %s tempo che manca
	"PC_WAITING_BRIAN": [
		"WAITING ON BRIAN  -  %s", "BRIAN CI STA PENSANDO  -  %s", "ESPERANDO A BRIAN  -  %s",
	],
	## %s posto
	"PC_BRIAN_WAITING": [
		"BRIAN IS WAITING  -  %s", "BRIAN TI ASPETTA  -  %s", "BRIAN TE ESPERA  -  %s",
	],
	"PC_ASK_BRIAN": ["ASK BRIAN FOR SEEDS", "CHIEDI I SEMI A BRIAN", "PEDIR SEMILLAS A BRIAN"],
	## %d grammi che servono per sbloccare l'ingrosso
	"PC_WHOLESALE_LOCKED": [
		"Wholesale is not for the pocket trade. Hold %d g at once and the people who move that kind of weight will be worth talking to.",
		"L'ingrosso non e' roba da tasche. Arriva ad avere %d g tutti insieme, e chi muove quel peso varra' la pena di essere sentito.",
		"El mayoreo no es cosa de bolsillo. Ten %d g de golpe y valdra la pena hablar con quien mueve ese peso.",
	],
	## %s costo del furgone
	"PC_BUY_VAN": ["BUY A VAN  -  %s", "COMPRA UN FURGONE  -  %s", "COMPRA UNA FURGONETA  -  %s"],
	## %d consegne per pieno
	"PC_VAN_NOTE": [
		"A kilo does not travel on foot. Used, high mileage, and it does %d runs on a tank.",
		"Un chilo non viaggia a piedi. Usato, tanti chilometri, e fa %d consegne con un pieno.",
		"Un kilo no viaja a pie. Usada, con muchos kilometros, y hace %d viajes por deposito.",
	],
	## %d quanti nel serbatoio, %d quanti ce ne stanno
	"PC_VAN_FUEL": ["%d / %d runs", "%d / %d consegne", "%d / %d viajes"],
	## %s costo del pieno
	"PC_REFUEL": ["FILL THE TANK  -  %s", "FAI IL PIENO  -  %s", "LLENAR EL DEPOSITO  -  %s"],
	## %d chili, %s incasso
	"PC_SEND_KG": ["SEND %d KG  -  %s", "MANDA %d KG  -  %s", "ENVIAR %d KG  -  %s"],
	## %d chili a bordo, %s incasso atteso, %s tempo che resta
	"PC_VAN_AWAY": [
		"%d kg out  -  %s  -  back in %s",
		"%d kg fuori  -  %s  -  torna fra %s",
		"%d kg fuera  -  %s  -  vuelve en %s",
	],
	"PC_VAN_DRY": [
		"The tank is dry. Nothing leaves the garage until you fill it.",
		"Il serbatoio e' a secco. Dal garage non esce niente finche' non fai il pieno.",
		"El deposito esta seco. Del garaje no sale nada hasta que lo llenes.",
	],
	## %d semi, %s posto, %s tempo che resta
	"PC_BRIAN_NOTE_READY": [
		"Brian brought %d seed(s) and is waiting at %s. He will not hang around forever: about %s left.",
		"Brian ha portato %d seme/i e aspetta a %s. Non ci resta in eterno: gli restano circa %s.",
		"Brian trajo %d semilla(s) y espera en %s. No se quedara para siempre: le quedan unos %s.",
	],
	"PC_BRIAN_NOTE_WAITING": [
		"Brian works at the clinic, where they hand the stuff out to patients. He will text a spot to meet when he can get away.",
		"Brian lavora alla clinica, dove la roba la danno ai pazienti. Manderà un posto dove vedersi appena riesce a staccare.",
		"Brian trabaja en la clinica, donde le dan el material a los pacientes. Mandara un sitio para verse en cuanto pueda escaparse.",
	],
	"PC_BRIAN_NOTE_EMPTY": [
		"Out of seeds. Ask your cousin Brian for more.",
		"Semi finiti. Chiedine altri a tuo cugino Brian.",
		"Sin semillas. Pidele mas a tu primo Brian.",
	],

	# --- Il PC: scheda MARKET ----------------------------------------------
	# I bottoni "vendi N grammi" e "vendi tutto" non ci sono piu': l'ingrosso
	# adesso e' un viaggio del furgone a chili (vedi `Delivery`), e le voci
	# stanno piu' sotto, con i carichi e il serbatoio.
	## %d percentuale in più della strada
	"PC_MARKET_NOTE": [
		"Wholesale is safe and does not raise attention. Selling to people on the street pays %d%% more, but one customer at a time.",
		"L'ingrosso è sicuro e non alza l'attenzione. Vendere alla gente per strada rende il %d%% in più, ma un cliente alla volta.",
		"El mayoreo es seguro y no levanta atencion. Vender a la gente en la calle paga un %d%% mas, pero de uno en uno.",
	],

	# --- Il PC: scheda SHOP ------------------------------------------------
	## %s nome, %d quanti se ne hanno
	"PC_SHOP_OWNED": ["%s  -  OWNED (%d)", "%s  -  GIA' TUO (%d)", "%s  -  YA LO TIENES (%d)"],
	## %s nome, %s prezzo
	"PC_SHOP_BUY": ["%s  -  %s", "%s  -  %s", "%s  -  %s"],
	## %s riga di sopra, %d quanti se ne hanno, %d quanti se ne possono avere
	"PC_SHOP_BUY_MORE": ["%s   (%d / %d)", "%s   (%d / %d)", "%s   (%d / %d)"],
	## %s costo
	"PC_SHOP_EXTRA_POT": ["EXTRA POT  -  %s", "UN VASO IN PIU'  -  %s", "MACETA EXTRA  -  %s"],
	## %d quanti vasi si possono aprire con le proprieta' che si hanno adesso
	"PC_SHOP_POT_NOTE": [
		"One more pot, in the first place with room. With what you own now: up to %d.",
		"Un vaso in più, nel primo posto che ha spazio. Con quello che possiedi adesso: fino a %d.",
		"Una maceta mas, en el primer sitio con espacio. Con lo que tienes ahora: hasta %d.",
	],

	# --- Il PC: scheda STAFF -----------------------------------------------
	## %s paga giornaliera
	"PC_WAGES_VALUE": ["%s / day", "%s / giorno", "%s / dia"],
	## %d quanti, %d massimo, %s quanto costa (gia' scritto: vedi Staff.pay_label)
	"PC_STAFF_COUNT": ["%d / %d   (%s)", "%d / %d   (%s)", "%d / %d   (%s)"],
	## %d percentuale trattenuta sulle vendite
	"PC_STAFF_PAY_CUT": [
		"%d%% of sales", "%d%% sulle vendite", "%d%% de las ventas",
	],
	## %d quanti, %s paga totale
	"PC_STAFF_SUMMARY": [
		"%d  (%s / day)", "%d  (%s / giorno)", "%d  (%s / dia)",
	],
	## %s costo
	"PC_HIRE": ["HIRE  -  %s", "ASSUMI  -  %s", "CONTRATAR  -  %s"],
	"PC_NO_ROOM_STAFF": ["NO ROOM FOR MORE", "NON SERVE NESSUN ALTRO", "NO HACE FALTA NADIE MAS"],
	"PC_LET_GO": ["LET ONE GO", "MANDANE VIA UNO", "DESPEDIR A UNO"],
	## %d quota ingrosso, %d quota strada
	"PC_SPLIT_VALUE": [
		"%d%% wholesale  /  %d%% street",
		"%d%% ingrosso  /  %d%% strada",
		"%d%% mayoreo  /  %d%% calle",
	],
	## %d assegnati, %d che ne stanno, %d vasi aperti, %d vasi in tutto
	"PC_SITE_ROW": [
		"%d of %d   (%d/%d pots)", "%d su %d   (%d/%d vasi)", "%d de %d   (%d/%d macetas)",
	],
	"PC_SITE_SHUT": ["not yours", "non e' tua", "no es tuya"],
	## %d quanti vasi ci sono in questo posto
	"PC_SITE_POTS": ["%d pots", "%d vasi", "%d macetas"],
	## %d coltivatori senza posto
	"PC_SITE_IDLE": ["%d", "%d", "%d"],
	"PC_SEND_HERE": ["SEND ONE HERE", "MANDANE UNO QUI", "MANDA UNO AQUI"],
	"PC_TAKE_AWAY": ["TAKE ONE OFF", "TOGLINE UNO", "QUITA UNO"],
	## %d vasi che un coltivatore riesce a seguire
	"PC_SITES_NOTE": [
		"A grower works one place and tends up to %d pots there, so how many a place takes depends on the pots you have OPENED there, not on the ones it could hold: the garage takes a second one from its seventh pot on. Hire another and he lands wherever there is room; move him from here. One with no posting still draws his wage every night and grows nothing.",
		"Un coltivatore sta in un posto solo e segue fino a %d vasi, quindi quanti ne regge un posto dipende dai vasi che ci hai APERTO, non da quelli che ci starebbero: il garage ne regge un secondo dal settimo vaso in poi. Assumendone un altro finisce dove c'e' spazio, e da qui lo si sposta. Uno senza posto prende la paga ogni notte lo stesso e non coltiva niente.",
		"Un cultivador esta en un solo sitio y atiende hasta %d macetas, asi que cuantos aguanta un sitio depende de las macetas que hayas ABIERTO alli, no de las que cabrian: el garaje aguanta un segundo desde su septima maceta. Si contratas otro va donde haya sitio, y desde aqui lo mueves. Uno sin puesto cobra igual cada noche y no cultiva nada.",
	],

	## %d grammi da parte, %d grammi liberi
	"PC_RESERVED_VALUE": [
		"%d g held  /  %d g to the dealers",
		"%d g fermi  /  %d g ai dealer",
		"%d g guardados  /  %d g a los vendedores",
	],
	"PC_MORE_WHOLESALE": [
		"HOLD MORE  (for the van)", "TIENI DA PARTE  (per il furgone)",
		"GUARDAR MAS  (para la furgoneta)",
	],
	"PC_MORE_STREET": [
		"HOLD LESS  (more to sell)", "TIENI MENO  (piu' da vendere)",
		"GUARDAR MENOS  (mas para vender)",
	],
	## %d percentuale in più della strada
	"PC_SPLIT_NOTE": [
		"This is how much of every harvest you hold back for the van. The dealers only work the street, and they never touch what is held: that part is yours to drive out yourself. The street pays %d%% more than wholesale, but every gram that changes hands out there raises attention.",
		"E' quanto di ogni raccolto tieni da parte per il furgone. I dealer battono solo la strada, e quello che e' da parte non lo toccano: quella roba la porti fuori tu. La strada rende il %d%% in piu' dell'ingrosso, ma ogni grammo che passa di mano la fuori alza l'attenzione.",
		"Es cuanto de cada cosecha guardas para la furgoneta. Los vendedores solo trabajan la calle, y lo guardado no lo tocan: eso lo sacas tu. La calle paga un %d%% mas que el mayoreo, pero cada gramo que cambia de manos ahi fuera levanta atencion.",
	],

	# --- Stadi della pianta (PIXEL, e anche font di sistema) ---------------
	"GROW_EMPTY": ["EMPTY", "VUOTO", "VACIO"],
	"GROW_SEEDLING": ["SEEDLING", "GERMOGLIO", "BROTE"],
	"GROW_VEGETATIVE": ["VEGETATIVE", "VEGETATIVA", "VEGETATIVA"],
	"GROW_FLOWERING": ["FLOWERING", "FIORITURA", "FLORACION"],
	"GROW_READY": ["READY", "PRONTA", "LISTA"],

	# --- Attenzione della polizia (PIXEL) ----------------------------------
	"HEAT_QUIET": ["QUIET", "TRANQUILLO", "TRANQUILO"],
	"HEAT_NOTICED": ["NOTICED", "NOTATO", "FICHADO"],
	"HEAT_WATCHED": ["WATCHED", "SORVEGLIATO", "VIGILADO"],
	"HEAT_HUNTED": ["HUNTED", "BRACCATO", "PERSEGUIDO"],
	"HEAT_RAID_SOON": ["RAID SOON", "RETATA VICINA", "REDADA CERCA"],

	# --- Negozio: nomi (PIXEL) e spiegazioni -------------------------------
	"SHOP_TOOLKIT": ["GROW TOOLKIT", "ATTREZZATURA", "EQUIPO DE CULTIVO"],
	"SHOP_TOOLKIT_NOTE": [
		"Shears, a pH meter, decent soil. Every plant yields 15% more.",
		"Forbici, pH metro, terriccio decente. Ogni pianta rende il 15% in più.",
		"Tijeras, medidor de pH, tierra decente. Cada planta rinde un 15% mas.",
	],
	"SHOP_LAMPS": ["RED GROW LAMPS", "LAMPADE ROSSE", "LAMPARAS ROJAS"],
	"SHOP_LAMPS_NOTE": [
		"Red lamps over the pots, one per pot, anywhere you grow. Each cuts 8% off the growing time and adds 10 $ to the monthly power bill. Applies to plants put in from now on.",
		"Lampade rosse sopra ai vasi, una per vaso, in cantina come in garage. Ognuna taglia l'8% del tempo di crescita e aggiunge 10 $ alla bolletta del mese. Vale per le piante messe da qui in avanti.",
		"Lamparas rojas sobre las macetas, una por maceta, donde sea que cultives. Cada una recorta un 8% del tiempo de cultivo y suma 10 $ a la factura del mes. Vale para las plantas que siembres de ahora en adelante.",
	],
	"SHOP_VAN": ["WORK VAN", "FURGONE", "FURGONETA"],
	## %d chili minimi, %d consegne per pieno — riempiti da `Shop.note()`
	"SHOP_VAN_NOTE": [
		"An old work van, the kind nobody looks at twice. Without it there is no wholesale: a kilo does not travel on foot.",
		"Un vecchio furgone da lavoro, di quelli che nessuno guarda due volte. Senza, l'ingrosso non si fa: un chilo non viaggia a piedi.",
		"Una furgoneta vieja de trabajo, de las que nadie mira dos veces. Sin ella no hay mayoreo: un kilo no viaja a pie.",
	],
	"SHOP_FILTER": ["CARBON FILTER", "FILTRO A CARBONE", "FILTRO DE CARBON"],
	"SHOP_FILTER_NOTE": [
		"The smell stays in the basement: every gram sold on the street weighs 40% less on attention.",
		"L'odore non esce più dalla cantina: ogni grammo venduto in strada pesa il 40% in meno sull'attenzione.",
		"El olor ya no sale del sotano: cada gramo vendido en la calle pesa un 40% menos en la atencion.",
	],

	# --- Personale: nomi (PIXEL) e spiegazioni -----------------------------
	"STAFF_GROWER": ["GROWER", "COLTIVATORE", "CULTIVADOR"],
	"STAFF_GROWER_NOTE": [
		"Plants whatever seeds he finds, waters, harvests. He works one place and tends the pots there, and gets paid whether there are seeds or not.",
		"Pianta i semi che trova, annaffia e raccoglie. Sta in un posto solo e segue i vasi di quello, e la paga la prende che ci siano semi o no.",
		"Siembra las semillas que encuentra, riega y cosecha. Esta en un solo sitio y atiende sus macetas, y cobra haya semillas o no.",
	],
	"STAFF_DRIVER": ["DRIVER", "AUTISTA", "CHOFER"],
	"STAFF_DRIVER_NOTE": [
		"Takes the van to the supplier for you: with him on the payroll you order the seeds from the PC instead of walking downtown. One van, one driver, and he gets paid whether he drives or not.",
		"Porta lui il furgone dal grossista: assunto, i semi si ordinano dal PC invece di farsi la strada fino in centro. Un furgone, un autista, e la paga la prende che guidi o no.",
		"Lleva el la furgoneta al mayorista: contratado, las semillas se piden desde el PC en vez de cruzar la ciudad. Una furgoneta, un chofer, y cobra conduzca o no.",
	],
	"STAFF_DEALER": ["DEALER", "SPACCIATORE", "VENDEDOR"],
	"STAFF_DEALER_NOTE": [
		"Works the street, and only with what you leave him. No wage: he keeps a cut of whatever he sells, so an idle dealer costs nothing. The street pays well and raises attention.",
		"Batte la strada, e solo con quello che gli lasci. Niente paga: si tiene una quota di quello che vende, quindi fermo non costa niente. La strada rende bene e alza l'attenzione.",
		"Trabaja la calle, y solo con lo que le dejas. Sin sueldo: se queda una parte de lo que vende, asi que parado no cuesta nada. La calle paga bien y levanta atencion.",
	],

	## Il bottone che apre il grossista dal PC: c'e' solo con l'autista assunto.
	"PC_SEND_DRIVER": ["SEND THE DRIVER", "MANDA L'AUTISTA", "MANDA AL CHOFER"],
	"PC_DRIVER_NOTE": [
		"The driver does the run. Order from here and the van goes: same crates, same two hours.",
		"Il viaggio lo fa l'autista. Ordini da qui e il furgone parte: stesse casse, stesse due ore.",
		"El viaje lo hace el chofer. Pides desde aqui y la furgoneta sale: mismas cajas, mismas dos horas.",
	],

	# --- Messaggini dell'HUD -----------------------------------------------
	"NOTE_PLANTED": ["PLANTED", "PIANTATO", "SEMBRADA"],
	"NOTE_WATERED": ["WATERED", "ANNAFFIATO", "REGADA"],
	## %d quanti vasi
	"NOTE_WATERED_N": ["WATERED %d POTS", "ANNAFFIATI %d VASI", "REGADAS %d MACETAS"],
	## %d grammi
	"NOTE_HARVESTED": ["+%d G HARVESTED", "+%d G RACCOLTI", "+%d G COSECHADOS"],
	## %d grammi
	"NOTE_STAFF_HARVESTED": [
		"STAFF: +%d G HARVESTED", "PERSONALE: +%d G RACCOLTI", "PERSONAL: +%d G COSECHADOS",
	],
	## %s incasso, %d grammi
	"NOTE_STAFF_SOLD": [
		"STAFF: +%s  (%d G)", "PERSONALE: +%s  (%d G)", "PERSONAL: +%s  (%d G)",
	],
	## %s incasso, %d grammi
	"NOTE_SOLD": ["+%s  (%d G)", "+%s  (%d G)", "+%s  (%d G)"],
	## %d semi
	"NOTE_SEEDS_BOUGHT": ["+%d SEEDS", "+%d SEMI", "+%d SEMILLAS"],
	"NOTE_NO_SEEDS": [
		"NO SEEDS  -  ASK BRIAN", "SEMI FINITI  -  CHIEDI A BRIAN", "SIN SEMILLAS  -  PIDE A BRIAN",
	],
	"NOTE_NO_ROOM": ["NO ROOM LEFT DOWN HERE", "QUI SOTTO NON CI STA ALTRO", "AQUI ABAJO NO CABE MAS"],
	"NOTE_NOT_YOURS": [
		"NOT YOURS  -  BUY IT AT THE AGENCY",
		"NON E' TUA  -  COMPRALA IN AGENZIA",
		"NO ES TUYA  -  COMPRALA EN LA AGENCIA",
	],
	"NOTE_USE_PC": [
		"USE THE PC TO OPEN THIS POT", "APRI QUESTO VASO DAL PC", "ABRE ESTA MACETA DESDE EL PC",
	],
	## %s stadio, %s tempo che manca
	"NOTE_PLOT_STATUS": ["%s  -  %s LEFT", "%s  -  MANCA %s", "%s  -  FALTA %s"],
	"NOTE_ASKED_BRIAN": [
		"ASKED BRIAN FOR SEEDS", "SEMI CHIESTI A BRIAN", "SEMILLAS PEDIDAS A BRIAN",
	],
	## %s posto
	"NOTE_BRIAN_SPOT": ["BRIAN: %s", "BRIAN: %s", "BRIAN: %s"],
	"NOTE_BRIAN_LEFT": ["BRIAN LEFT", "BRIAN SE N'E' ANDATO", "BRIAN SE HA IDO"],
	"NOTE_NEW_POT": ["NEW POT OPENED", "VASO NUOVO APERTO", "MACETA NUEVA ABIERTA"],
	## %s nome dell'oggetto
	"NOTE_BOUGHT": ["BOUGHT  %s", "COMPRATO  %s", "COMPRADO  %s"],
	## %s ruolo
	"NOTE_HIRED": ["HIRED  %s", "ASSUNTO  %s", "CONTRATADO  %s"],
	## %s ruolo
	"NOTE_LET_GO": ["LET GO  %s", "MANDATO VIA  %s", "DESPEDIDO  %s"],
	## %s quanto è stato pagato
	"NOTE_WAGES": ["WAGES  -%s", "PAGHE  -%s", "SUELDOS  -%s"],
	"NOTE_POWER_BILL": ["POWER BILL  -%s", "BOLLETTA  -%s", "LUZ  -%s"],
	## %s quanto e' stato pagato di tasse sulla proprieta'
	"NOTE_PROPERTY_TAX": ["PROPERTY TAX  -%s", "TASSE SULLA CASA  -%s", "IMPUESTOS  -%s"],
	## %d chili partiti
	"NOTE_VAN_LEFT": ["%d KG ON THE ROAD", "%d KG PARTITI", "%d KG EN CAMINO"],
	## %s incasso
	"NOTE_VAN_BACK": ["VAN BACK  +%s", "FURGONE RIENTRATO  +%s", "FURGONETA DE VUELTA  +%s"],
	"NOTE_REFUELLED": ["TANK FULL", "PIENO FATTO", "DEPOSITO LLENO"],
	"NOTE_SEEDS_IN": ["SEEDS IN  +%d", "SEMI ARRIVATI  +%d", "SEMILLAS LLEGADAS  +%d"],

	# --- Il grossista dei semi (PIXEL il titolo) ---------------------------
	"SW_TITLE": ["SEED SUPPLIER", "GROSSISTA SEMI", "MAYORISTA SEMILLAS"],
	"SW_NAME": ["CLINIC SUPPLY", "FORNITURE CLINICA", "SUMINISTROS CLINICA"],
	"SW_PACK": ["%d SEEDS", "%d SEMI", "%d SEMILLAS"],
	## %d = sconto in percentuale sul prezzo di Brian
	"SW_PACK_NOTE": [
		"%d%% off the usual price per seed.",
		"%d%% in meno sul prezzo a seme di Brian.",
		"%d%% menos sobre el precio por semilla.",
	],
	"SW_ORDER": ["ORDER", "ORDINA", "PEDIR"],
	"SW_NO_CASH": ["NOT ENOUGH", "SOLDI CORTI", "FALTA DINERO"],
	"SW_VAN_OUT": ["THE VAN IS OUT", "IL FURGONE E FUORI", "LA FURGONETA ESTA FUERA"],
	## %s = quanto manca
	"SW_ON_THE_WAY": [
		"Van on the way back: %s left.",
		"Furgone in arrivo: mancano %s.",
		"Furgoneta en camino: faltan %s.",
	],
	"SW_NOTE": [
		"Order and the van goes to fetch them. It takes about two hours, and it is the same van that does the wholesale runs: one job at a time.",
		"Si ordina e il furgone va a prenderli. Ci mette un paio d'ore, ed e' lo stesso furgone dell'ingrosso: un viaggio alla volta.",
		"Pides y la furgoneta va a por ellas. Tarda un par de horas, y es la misma furgoneta del mayoreo: un viaje cada vez.",
	],

	# --- Il telefono (PIXEL le voci del menu) ------------------------------
	# I mittenti sono quelli che ci sono gia': `MSG_STAFF_SPEAKER` e
	# `MSG_COUSIN_SPEAKER`. Chi scrive e' la stessa persona, che il messaggio
	# arrivi qui o nel riquadro a tutto schermo.
	#
	# I corpi usano il font di SISTEMA, quindi ci possono stare le cifre; le
	# voci del menu usano quello del gioco, quindi solo lettere e spazio.
	## Le tre facce della voce del menu. Lo schermo del telefono e' largo poco
	## piu' di cento pixel, quindi qui c'e' un tetto vero: oltre i
	## `Strings.PHONE_MENU_CHARS` caratteri il testo viene tagliato a meta'
	## parola, ed e' successo davvero ("BRIAN CI PENS"). Un controllo automatico
	## lo verifica, perche' a leggerle qui sembrano tutte corte uguali.
	"PHONE_CALL_BRIAN": ["CALL BRIAN", "CHIAMA BRIAN", "LLAMA A BRIAN"],
	## Il bottone in fondo alla chat dell'autista, e cosa dice mentre e' fuori.
	"PHONE_SEND_DRIVER": ["GET SEEDS", "PRENDI SEMI", "TRAE SEMILLAS"],
	"PHONE_DRIVER_OUT": ["ON THE WAY", "IN VIAGGIO", "EN CAMINO"],
	## %s quanti semi
	"CHAT_SEND_DRIVER": [
		"Go get %s seeds",
		"Vai a prendere %s semi",
		"Ve a por %s semillas",
	],
	"CHAT_DRIVER_ON_IT": [
		"On my way. Back in a couple of hours.",
		"Vado. Torno fra un paio d'ore.",
		"Voy. Vuelvo en un par de horas.",
	],
	"PHONE_WAITING": ["HE IS ON IT", "CI PENSA LUI", "EL SE ENCARGA"],
	"PHONE_BRIAN_HERE": ["HE IS WAITING", "TI ASPETTA", "TE ESPERA"],
	# --- La chat con Brian --------------------------------------------------
	# Il titolo della rubrica e' PIXEL (font del gioco); i messaggi no, si
	# leggono in nuvoletta col font di sistema come tutti gli altri corpi.
	"CHAT_TITLE": ["MESSAGES", "MESSAGGI", "MENSAJES"],
	## Quando con un contatto non ci si e' ancora scritti niente. Nella chat di
	## Brian si vede solo per il primo minuto di partita, prima che arrivi il
	## messaggio d'apertura: dopo non e' piu' vuota mai.
	"CHAT_EMPTY": [
		"Nothing here yet.",
		"Qui non c'e' ancora niente.",
		"Aqui todavia no hay nada.",
	],
	## La richiesta di semi, cioe' l'unica riga che il giocatore **manda**.
	## Vedi `Chat.live()`: non e' scritta da nessuna parte, si ricava
	## dall'appuntamento aperto.
	"CHAT_ASK_SEEDS": [
		"Need seeds cousin.",
		"Servono semi cugino.",
		"Necesito semillas primo.",
	],
	## La risposta, che arriva un paio di secondi dopo (`Chat.REPLY_GAP`): senza,
	## le due righe comparirebbero insieme e non si leggerebbero come una
	## conversazione.
	"CHAT_BRIAN_ON_IT": [
		"On it. I will let you know where.",
		"Ci penso io. Ti faccio sapere dove.",
		"Yo me encargo. Te digo donde.",
	],
	# --- La guida ------------------------------------------------------------
	# Si apre dalla rubrica, sotto ai contatti, ed e' l'unica schermata del
	# telefono su carta bianca invece che sul vetro scuro: sono appunti, non
	# messaggi, e la differenza si vede prima di leggere.
	#
	# **Qui NIENTE e' PIXEL tranne la voce della rubrica.** Le sezioni si
	# leggono col font di sistema, quindi ci vanno accenti, apostrofi, cifre e
	# valute: sono le uniche pagine del gioco in cui si scrivono dei numeri per
	# esteso, ed e' esattamente il motivo per cui la guida serve.
	## La voce in fondo alla rubrica. Questa si legge col font del gioco: PIXEL.
	"GUIDE_TITLE": ["GUIDE", "GUIDA", "GUIA"],
	"GUIDE_ROW_NOTE": [
		"how the whole thing works",
		"come funziona il giro",
		"como funciona el asunto",
	],
	"GUIDE_LEAD": [
		"Brian's notes. Worth a look when you get stuck.",
		"Gli appunti di Brian. Da guardare quando ti impantani.",
		"Los apuntes de Brian. Para mirar cuando te atascas.",
	],

	"GUIDE_PLANTS": ["THE PLANTS", "LE PIANTE", "LAS PLANTAS"],
	"GUIDE_PLANTS_BODY": [
		"A seed becomes about 20 grams in some twenty game hours. That clock runs while you are out in the street, and it runs while the game is closed.\n\nWater every 12 hours. Thirst does not stop a plant, it ruins the yield: a pot left dry for days comes in at a third of what it should. It is the most expensive mistake in the game, and fixing it costs nothing.",
		"Un seme diventa circa 20 grammi in una ventina di ore di gioco. Quell'orologio gira mentre sei in giro per il quartiere, e gira anche a gioco chiuso.\n\nAnnaffia ogni 12 ore. La sete non ferma la pianta: le rovina la resa, e un vaso lasciato a secco per giorni rende un terzo di quello che dovrebbe. È l'errore che costa di più, e rimediare non costa niente.",
		"Una semilla se convierte en unos 20 gramos en unas veinte horas de juego. Ese reloj corre mientras estás en la calle, y corre también con el juego cerrado.\n\nRiega cada 12 horas. La sed no detiene la planta: le arruina el rendimiento, y una maceta seca durante días da un tercio de lo que debería. Es el error más caro del juego, y arreglarlo no cuesta nada.",
	],

	"GUIDE_SEEDS": ["THE SEEDS", "I SEMI", "LAS SEMILLAS"],
	"GUIDE_SEEDS_BODY": [
		"Seeds come from Brian, out of the clinic. You call him from this phone, he takes a couple of hours, then he waits for you somewhere in the neighbourhood: go where he says and buy before he gets tired of standing there.\n\nEvery call is 6 to 12 seeds, never the same number twice. Call him before you run out, not after: while you wait, the pots sit empty.",
		"I semi li porta Brian, dalla clinica. Lo chiami da questo telefono, ci mette un paio d'ore e poi ti aspetta in un posto del quartiere: vai dove ti dice e compra prima che si stanchi di stare lì.\n\nOgni chiamata sono dai 6 ai 12 semi, mai lo stesso numero. Chiamalo prima che finiscano, non dopo: mentre aspetti, i vasi restano vuoti.",
		"Las semillas las trae Brian, de la clínica. Lo llamas desde este teléfono, tarda un par de horas y luego te espera en algún sitio del barrio: ve donde te diga y compra antes de que se canse de esperar.\n\nCada llamada son de 6 a 12 semillas, nunca el mismo número. Llámalo antes de quedarte sin, no después: mientras esperas, las macetas están vacías.",
	],

	"GUIDE_FASTER": ["GOING FASTER", "ANDARE PIÙ FORTE", "IR MÁS RÁPIDO"],
	"GUIDE_FASTER_BODY": [
		"Three things, in this order.\n\nMORE POTS. They do not make a plant grow faster, they grow more at once. You unlock them from the PC, and the garage adds twelve on top of the six downstairs. Owning it is not free: it adds 120$ to every power bill even empty, and 1% of what you paid for it goes in property tax once a year.\n\nGROW TOOLKIT. 154$ once, and every harvest comes in 15% heavier. It pays for itself in two cuts.\n\nLAMPS. 315$ each, and one lamp sits over ONE pot: it cuts 8% off that pot's time, not off everybody's. Six lamps do not make one pot six times faster, and every one of them shows up on the power bill.",
		"Tre cose, in quest'ordine.\n\nPIÙ VASI. Non fanno crescere una pianta più in fretta, ne fanno crescere di più insieme. Si sbloccano dal PC, e il garage ne aggiunge dodici sopra ai sei di sotto. Averlo non è gratis: aggiunge 120$ a ogni bolletta anche vuoto, e una volta l'anno se ne va l'1% di quanto è costato in tasse sulla proprietà.\n\nGROW TOOLKIT. 154$ una volta sola, e ogni raccolto rende il 15% in più. Si ripaga in due tagli.\n\nLAMPADE. 315$ l'una, e una lampada sta sopra a UN vaso: taglia l'8% del tempo di quel vaso, non di tutti. Sei lampade non rendono un vaso sei volte più veloce, e ognuna si vede sulla bolletta della luce.",
		"Tres cosas, en este orden.\n\nMÁS MACETAS. No hacen crecer una planta más rápido, hacen crecer más a la vez. Se desbloquean desde el PC, y el garaje añade doce sobre las seis de abajo. Tenerlo no es gratis: añade 120$ a cada factura aunque esté vacío, y una vez al año se va el 1% de lo que costó en impuestos.\n\nGROW TOOLKIT. 154$ una sola vez, y cada cosecha rinde un 15% más. Se paga solo en dos cortes.\n\nLÁMPARAS. 315$ cada una, y una lámpara va sobre UNA maceta: le quita el 8% del tiempo a esa maceta, no a todas. Seis lámparas no hacen una maceta seis veces más rápida, y cada una se nota en la factura de la luz.",
	],

	"GUIDE_STAFF": ["HIRING", "IL PERSONALE", "EL PERSONAL"],
	"GUIDE_STAFF_BODY": [
		"At a thousand dollars the STAFF tab opens on the PC.\n\nA grower covers 6 pots: plants, waters and cuts for you, and keeps working while the game is closed. A dealer moves the product on the street and keeps a cut of it. A driver takes the van to the seed supplier: hire him and he turns up in your phone, so you order the crates from his chat or from the PC instead of walking downtown. You can keep 3 dealers, and 2 more for every property you buy.\n\nWages run every day whether there is work or not. Hiring before you have the pots to fill is just an expense.",
		"Ai mille dollari si apre la scheda PERSONALE nel PC.\n\nUn coltivatore segue 6 vasi: pianta, annaffia e raccoglie al posto tuo, e continua a lavorare anche a gioco chiuso. Un dealer piazza la merce in strada e se ne tiene una quota. Un autista porta il furgone dal grossista dei semi: assunto ti compare in rubrica sul telefono, così le casse le ordini dalla sua chat o dal PC invece di farti la strada fino in centro. I dealer che puoi tenere sono 3, più 2 per ogni proprietà che compri.\n\nLe paghe corrono ogni giorno, che ci sia lavoro o no. Assumere prima di avere i vasi da riempire è solo una spesa.",
		"A los mil dólares se abre la pestaña PERSONAL en el PC.\n\nUn cultivador lleva 6 macetas: planta, riega y corta por ti, y sigue trabajando con el juego cerrado. Un camello coloca la mercancía en la calle y se queda una parte. Un chofer lleva la furgoneta al mayorista de semillas: contratado te aparece en la agenda del teléfono, así pides las cajas desde su chat o desde el PC en vez de cruzar la ciudad. Puedes tener 3 camellos, y 2 más por cada propiedad que compres.\n\nLos sueldos corren cada día, haya trabajo o no. Contratar antes de tener macetas que llenar es solo un gasto.",
	],

	"GUIDE_WHOLESALE": ["WHOLESALE", "L'INGROSSO", "EL MAYOREO"],
	"GUIDE_WHOLESALE_BODY": [
		"The first time you put a kilo together, Brian tells you to get a van (5000$). Wholesale pays less per gram but takes the lot in one go: it is what you want once the street cannot keep up with what you grow.\n\nThe van also opens the clinic's seed supplier: whole crates instead of a handful, and no waiting on Brian.",
		"La prima volta che metti insieme un chilo, Brian ti dice di prendere un furgone (5000$). All'ingrosso pagano meno al grammo ma prendono tutto in una volta: è quello che serve quando la strada non sta più dietro a quanto produci.\n\nCol furgone si apre anche il grossista di semi della clinica: casse intere invece di una manciata, e non devi più aspettare Brian.",
		"La primera vez que juntas un kilo, Brian te dice que consigas una furgoneta (5000$). En el mayoreo pagan menos por gramo pero se lo llevan todo de una vez: es lo que hace falta cuando la calle ya no sigue el ritmo de lo que produces.\n\nCon la furgoneta se abre también el proveedor de semillas de la clínica: cajas enteras en vez de un puñado, y sin esperar a Brian.",
	],

	"GUIDE_HEAT": ["THE HEAT", "L'ATTENZIONE", "LA ATENCIÓN"],
	"GUIDE_HEAT_BODY": [
		"Selling on the street raises police attention. It comes down on its own every day, and the carbon filter (420$) makes it climb 40% slower.\n\nIn bad weather you sell less, but what you do sell draws less notice: heads down, patrols in the car.",
		"Vendere in strada alza l'attenzione della polizia. Scende da sola ogni giorno, e il filtro a carbone (420$) la fa salire il 40% in meno.\n\nCol brutto tempo si vende meno, ma quel poco si vende più tranquilli: la gente cammina a testa bassa e le pattuglie stanno in macchina.",
		"Vender en la calle sube la atención de la policía. Baja sola cada día, y el filtro de carbón (420$) hace que suba un 40% menos.\n\nCon mal tiempo vendes menos, pero lo poco que vendes llama menos la atención: la gente va con la cabeza baja y las patrullas se quedan en el coche.",
	],

	"PHONE_SEEDS_OUT": [
		"Out of seeds down here. The pots stay empty until you bring more.",
		"Semi finiti, qui sotto. I vasi restano vuoti finche' non ne porti altri.",
		"Sin semillas aqui abajo. Las macetas siguen vacias hasta que traigas mas.",
	],
	## La riga del filmato della partenza del furgone. PIXEL: si legge col font
	## del gioco. Vedi `scripts/ui/van_cutscene.gd`.
	"CUT_VAN_OUT": [
		"the load leaves the city",
		"il carico lascia la citta",
		"la carga deja la ciudad",
	],

	## L'avviso che manda quando sta per andarsene: vedi `SeedDeal.LEAVING_HOURS`.
	"PHONE_BRIAN_LEAVING": [
		"I cannot stand here all day cousin. Moving soon.",
		"Non ci posso restare tutto il giorno cugino. Fra poco me ne vado.",
		"No puedo quedarme todo el dia primo. Me voy dentro de poco.",
	],
	## %s posto. Il posto va a capo da solo: e' lungo (MILL ROAD NORTH OF MAIN
	## STREET) e attaccato alla frase la mangerebbe tutta.
	"PHONE_BRIAN_READY": [
		"Got them. Waiting for you at:\n%s",
		"Li ho presi. Ti aspetto qui:\n%s",
		"Los tengo. Te espero aqui:\n%s",
	],

	# --- Messaggi sul telefono ---------------------------------------------
	"MSG_COUSIN_SPEAKER": ["BRIAN", "BRIAN", "BRIAN"],
	## L'apertura: da dove viene la casa.
	##
	## PIXEL, come tutte le vignette: si legge col font del gioco, quindi solo
	## lettere e spazio. A mandare a capo e' la riga e non la punteggiatura, e
	## ogni riga sta sotto ai quaranta caratteri — piu' lunga va a capo da sola
	## e il conto delle righe salta.
	"MSG_INTRO_BODY": [
		"The old man left you the house\nYou know what a basement is for\nIt grows slow at first do not quit\nOn your phone you have a guide and me",
		"Il vecchio ti ha lasciato la casa\nLo sai a cosa serve un seminterrato\nAll inizio cresce piano non mollare\nNel telefono trovi una guida e me",
		"El viejo te ha dejado la casa\nYa sabes para que sirve un sotano\nAl principio crece lento no lo dejes\nEn el telefono tienes la guia y a mi",
	],
	## Il chilo raggiunto. Niente cifra dentro: il font del gioco non ha i numeri,
	## quindi il peso si dice a parole.
	"MSG_KILO_BODY": [
		"A kilo in one place cousin\nGet a van and go wholesale\nLess per gram but they take the lot",
		"Un chilo tutto insieme cugino\nServe un furgone e vai all ingrosso\nPagano meno ma prendono tutto",
		"Un kilo de golpe primo\nConsigue una furgoneta y ve al mayoreo\nPagan menos pero se lo llevan todo",
	],
	# Al primo assunto. PIXEL: si legge col font del gioco, solo lettere.
	"MSG_ORG_NAME_BODY": [
		"Cousin you are not alone anymore\nThis is a real business now\nIt needs a name",
		"Cugino ora non sei piu solo\nQuesta e una vera attivita\nLe serve un nome",
		"Primo ya no estas solo\nEsto es un negocio de verdad\nNecesita un nombre",
	],
	"ORG_NAME_TITLE": ["NAME YOUR CREW", "DAI UN NOME ALLA BANDA", "NOMBRA A TU BANDA"],
	"ORG_NAME_HINT": [
		"From now on this is how the street will know you.",
		"Da adesso la strada vi conoscera' con questo nome.",
		"Desde ahora la calle os conocera' con este nombre.",
	],
	"ORG_NAME_PLACEHOLDER": ["Crew name", "Nome della banda", "Nombre de la banda"],
	"ORG_NAME_OK": ["That's the name", "Questo e' il nome", "Ese es el nombre"],
	# Il primo livello di prestigio. PIXEL.
	"PRESTIGE_ROOKIES": ["ROOKIES", "PIVELLI", "NOVATOS"],
	"MSG_EXPAND_BODY": [
		"Look at the numbers cousin\nWalk the streets and look at the old\nplaces for sale or rent",
		"Guarda i numeri cugino\nGira il quartiere e guarda i posti\nvecchi in vendita o in affitto",
		"Mira los numeros primo\nDate una vuelta y mira los sitios\nviejos en venta o alquiler",
	],
	# Il grossista della clinica: arriva comprato il furgone, ed e' il messaggio
	# che apre il magazzino in centro. Vedi `SeedRun`.
	"MSG_SEED_WHOLESALE_BODY": [
		"Saw you got a van cousin
If my seeds are not enough I can send
you straight to the clinic supplier
Big batches down there
You will need them to keep up",
		"Ho visto che ti stai espandendo cugino
Se i miei semi non ti bastano ti mando
dritto dal grossista della clinica
Li compri grandi quantita
Ti serve per stare al passo",
		"He visto que te expandes primo
Si mis semillas no bastan te mando
derecho al mayorista de la clinica
Alli compras grandes cantidades
Te hara falta para seguir el ritmo",
	],
	"MSG_COUSIN_BODY": [
		"You are putting the work in cousin\nYou should get someone to help\nCheck the PC you can hire now",
		"Vedo che ti stai impegnando cugino\nTi conviene assumere qualcuno\nGuarda il PC ora si puo assumere",
		"Veo que te esfuerzas primo\nTe conviene contratar a alguien\nMira el PC ya puedes contratar",
	],
	## Arriva la prima volta che si comprano i semi dal grossista, quando il
	## viaggio fino in centro lo si e' appena fatto a piedi: e' il momento in cui
	## il consiglio si capisce da solo.
	"MSG_DRIVER_BODY": [
		"You went down there\nyourself cousin\nIf the trip wears you out\nput a driver on that van\nHe picks up the seeds\nyou order from home",
		"Ci sei andato di persona\ncugino\nSe il viaggio ti pesa\nmettici un autista\nVa lui a prendere i semi\ne tu li ordini da casa",
		"Fuiste tu mismo primo\nSi el viaje te pesa\nponle un chofer\na la furgoneta\nEl va a por las semillas\ny tu las pides desde casa",
	],
	"MSG_DRIVER_SPEAKER": ["DRIVER", "AUTISTA", "CHOFER"],
	## La prima riga che scrive: arriva quando lo si assume, ed e' anche quella
	## che mette il contatto in rubrica.
	"MSG_DRIVER_HELLO": [
		"I drive the van\nWrite me when the\nseeds run low",
		"Sono io al furgone\nScrivimi quando i\nsemi finiscono",
		"Conduzco yo jefe\nEscribeme cuando\nfalten semillas",
	],
	"MSG_STAFF_SPEAKER": ["STAFF", "PERSONALE", "PERSONAL"],
	"MSG_POWER_SPEAKER": ["POWER COMPANY", "SOCIETA ELETTRICA", "COMPANIA DE LUZ"],
	"MSG_TAX_SPEAKER": ["CITY HALL", "COMUNE", "AYUNTAMIENTO"],
	## %s quanto era dovuto, %s quanto e' stato pagato
	"MSG_TAX_SHORT": [
		"Property tax came to %s and only %s went through. What you own costs you every year, full pots or empty ones.",
		"Le tasse sulla proprieta erano %s e ne sono passati solo %s. Quello che possiedi ti costa ogni anno, che i vasi siano pieni o vuoti.",
		"Los impuestos eran %s y solo han pasado %s. Lo que tienes te cuesta cada ano, esten las macetas llenas o vacias.",
	],
	## %s quanto era dovuto, %s quanto e' stato pagato
	"MSG_POWER_SHORT": [
		"The bill came to %s and only %s went through. Those lamps eat power whether the pots are full or not.",
		"La bolletta era di %s e ne sono passati solo %s. Quelle lampade consumano che i vasi siano pieni o vuoti.",
		"La factura era de %s y solo han pasado %s. Esas lamparas consumen esten las macetas llenas o vacias.",
	],
	## %s ruolo
	"MSG_STAFF_QUIT": [
		"%s walked out: there was not enough in the till to cover the wages.",
		"%s se n'è andato: in cassa non c'era abbastanza per pagare le paghe.",
		"%s se ha largado: no habia bastante en la caja para pagar los sueldos.",
	],
	"MSG_OK": ["OK", "OK", "OK"],

	# --- Il resoconto di quando si rientra ---------------------------------
	# Il corpo del messaggio del telefono usa il font di SISTEMA (solo chi parla
	# e il bottone usano quello del gioco), quindi qui le cifre si possono
	# scrivere. Vedi `phone.gd`.
	#
	# Sono scritte come "etichetta: valore" e non come frasi ("2 vasi sono
	# rimasti a secco") apposta: cosi' non c'e' nessun singolare da sbagliare
	# quando il numero e' 1, in nessuna delle tre lingue, e il riquadro si legge
	# come quello che e' — un rendiconto.
	"MSG_AWAY_SPEAKER": ["WHILE YOU WERE OUT", "MENTRE ERI VIA", "MIENTRAS NO ESTABAS"],
	"AWAY_HEADER": [
		"You were away %s.",
		"Sei stato via %s.",
		"Has estado fuera %s.",
	],
	## %d quanti giorni di gioco al massimo vale un'assenza
	"AWAY_CAPPED": [
		"You were away longer: at most %d game days are counted.",
		"Sei stato via di piu': si contano al massimo %d giorni di gioco.",
		"Estuviste fuera mas tiempo: se cuentan como maximo %d dias de juego.",
	],
	"AWAY_HARVEST": ["Harvested: %d g", "Raccolto: %d g", "Cosechado: %d g"],
	"AWAY_SOLD": ["Moved: %d g for %s", "Piazzato: %d g per %s", "Colocado: %d g por %s"],
	"AWAY_CUT": ["Dealer cut: -%s", "Quota dei dealer: -%s", "Parte de los vendedores: -%s"],
	"AWAY_WAGES": ["Wages: -%s", "Paghe: -%s", "Sueldos: -%s"],
	"AWAY_POWER": ["Power bill: -%s", "Bolletta della luce: -%s", "Factura de la luz: -%s"],
	"AWAY_TAX": ["Property tax: -%s", "Tasse sulla proprieta: -%s", "Impuestos: -%s"],
	"AWAY_QUIT": [
		"%s walked out: there was no money to pay the wages.",
		"%s se n'è andato: non c'erano i soldi per pagarlo.",
		"%s se fue: no habia dinero para pagarle.",
	],
	"AWAY_IDLE": [
		"The seeds ran out: the free pots stayed empty. Only you can get more, from Brian.",
		"I semi sono finiti: i vasi liberi sono rimasti vuoti. Altri li puoi prendere solo tu, da Brian.",
		"Se acabaron las semillas: las macetas libres se quedaron vacias. Mas solo las puedes conseguir tu, de Brian.",
	],
	"AWAY_THIRSTY": [
		"Pots that need water: %d",
		"Vasi da annaffiare: %d",
		"Macetas que necesitan agua: %d",
	],
	"AWAY_DEAL_READY": [
		"Brian sent the spot: %s.",
		"Brian ha mandato la posizione: %s.",
		"Brian ha mandado el sitio: %s.",
	],
	"AWAY_DEAL_GONE": [
		"Brian got tired of waiting and left.",
		"Brian si è stancato di aspettare e se n'è andato.",
		"Brian se canso de esperar y se fue.",
	],
	"AWAY_NO_STAFF": [
		"Nobody works for you yet: only the clock moved.",
		"Non hai ancora nessuno che lavori per te: è passato solo il tempo.",
		"Todavia no tienes a nadie trabajando: solo ha pasado el tiempo.",
	],
	"AWAY_QUIET": [
		"Nothing worth telling happened down there.",
		"Di sotto non è successo niente che valga la pena raccontare.",
		"Abajo no ha pasado nada que merezca la pena contar.",
	],

	# --- Brian all'appuntamento --------------------------------------------
	"NPC_SEEDS_EMPTY": [
		"That was the last of it. Give me a couple of hours and ask again.",
		"Quello era l'ultimo. Dammi un paio d'ore e richiedimelo.",
		"Ese era el ultimo. Dame un par de horas y vuelve a pedirmelo.",
	],
	## %d prezzo, %d quanti ne ha portati, %d quanti ne hai, %d soldi
	## %d prezzo, %d quanti ne ha portati, %d quanti ne ha il giocatore, %d cassa
	##
	## Le due cifre in fondo sono scritte come "etichetta: valore" e non dentro a
	## una frase, per lo stesso motivo del resoconto di quando si rientra: il
	## giocatore puo' averne uno solo, o nessuno, e "hai 1 semi" non si puo'
	## scrivere in nessuna delle tre lingue senza un "(s)" appiccicato.
	"NPC_SEEDS_BODY": [
		"Straight out of the clinic stock, cousin. %d $ a seed, and you never got them from me.\n\nI brought %d.  Seeds on you: %d.  Cash: %d $.",
		"Presi dritti dal magazzino della clinica, cugino. %d $ al seme, e non te li ho dati io.\n\nNe ho portati %d.  Semi che hai: %d.  Cassa: %d $.",
		"Sacados del almacen de la clinica, primo. %d $ la semilla, y yo no te los he dado.\n\nHe traido %d.  Semillas que llevas: %d.  Dinero: %d $.",
	],
	## %d quanti, %d costo
	"NPC_SEEDS_BUY": ["BUY %d  -  %d $", "PRENDINE %d  -  %d $", "COMPRAR %d  -  %d $"],
	"NPC_SEEDS_DONE": ["THAT IS ALL", "BASTA COSI", "NADA MAS"],
	"NPC_SEEDS_CLEANED_OUT": [
		"That is me cleaned out. See you around, cousin.",
		"Io sono a secco. Ci si vede, cugino.",
		"Yo me he quedado sin nada. Nos vemos, primo.",
	],

	# --- Clienti di strada --------------------------------------------------
	"NPC_BUYER_DONE": [
		"I am good for today. Come find me tomorrow.",
		"Per oggi sono a posto. Passa domani.",
		"Por hoy estoy servido. Pasate manana.",
	],
	## %d grammi che vorrebbe
	"NPC_BUYER_EMPTY_HANDED": [
		"You are empty handed. I need %d g, whenever you sort yourself out.",
		"Sei a mani vuote. Mi servono %d g, quando ti organizzi.",
		"Vienes con las manos vacias. Necesito %d g, cuando te organices.",
	],
	## %d grammi, %d prezzo al grammo, %d quanti ne hai
	"NPC_BUYER_BODY": [
		"I can take %d g today, %d $ a gram.\n\nYou are carrying %d g.",
		"Oggi ne prendo %d g, %d $ al grammo.\n\nTu ne hai addosso %d g.",
		"Hoy me llevo %d g, %d $ el gramo.\n\nTu llevas encima %d g.",
	],
	## %d grammi, %d incasso
	"NPC_BUYER_UPTOWN": [
		"Up here nobody counts the pennies. It is worth the walk.",
		"Quassù nessuno sta a contare i centesimi. La strada la vale.",
		"Aqui arriba nadie cuenta los centimos. Vale la caminata.",
	],
	"NPC_BUYER_SELL": ["SELL %d G  -  %d $", "VENDI %d G  -  %d $", "VENDER %d G  -  %d $"],
	"NPC_BUYER_NOT_NOW": ["NOT NOW", "NON ADESSO", "AHORA NO"],

	# --- Pattuglie ----------------------------------------------------------
	"NPC_COP_CALM": ["Move along.", "Circolare.", "Circulen."],
	"NPC_COP_SEEN": [
		"New face. I remember faces.",
		"Faccia nuova. Io le facce me le ricordo.",
		"Cara nueva. Yo las caras me las recuerdo.",
	],
	"NPC_COP_TALK": [
		"Funny. People keep mentioning your name lately.",
		"Strano. Ultimamente il tuo nome salta fuori spesso.",
		"Que curioso. Ultimamente tu nombre sale mucho.",
	],
	"NPC_COP_HUNT": [
		"We know what you are doing down in the Flats. We are just waiting to prove it.",
		"Sappiamo cosa combini giù ai Flats. Aspettiamo solo di poterlo dimostrare.",
		"Sabemos lo que haces alla abajo en los Flats. Solo esperamos poder demostrarlo.",
	],

	# --- Battute dei passanti ----------------------------------------------
	"LINE_FLATS_1_A": [
		"Landlord raised the rent again. On this place. Can you believe it?",
		"Il padrone ha alzato di nuovo l'affitto. Per questo buco. Ci credi?",
		"El casero ha subido otra vez el alquiler. Por este cuchitril. Te lo puedes creer?",
	],
	"LINE_FLATS_1_B": [
		"They say the mall is hiring. They always say the mall is hiring.",
		"Dicono che al centro commerciale assumono. Lo dicono sempre.",
		"Dicen que en el centro comercial contratan. Siempre lo dicen.",
	],
	"LINE_FLATS_1_C": [
		"Keep an eye on your bike. Nothing stays out here for long.",
		"Tieni d'occhio la bici. Qui fuori non resta niente per molto.",
		"No pierdas de vista la bici. Aqui fuera nada dura mucho.",
	],
	"LINE_FLATS_2_A": [
		"Two buses a day down here. Both of them full.",
		"Due autobus al giorno, qui sotto. Pieni tutti e due.",
		"Dos autobuses al dia aqui abajo. Llenos los dos.",
	],
	"LINE_FLATS_2_B": [
		"You walk everywhere too? Figures.",
		"Anche tu vai a piedi dappertutto? Immaginavo.",
		"Tu tambien vas a pie a todas partes? Me lo imaginaba.",
	],
	"LINE_FLATS_2_C": [
		"The projects had heat until March. March.",
		"Alle case popolari il riscaldamento è andato fino a marzo. Marzo.",
		"En las casas baratas hubo calefaccion hasta marzo. Marzo.",
	],
	"LINE_FLATS_3_A": [
		"Been trying to open a shop on this row for six years.",
		"Sono sei anni che provo ad aprire un negozio su questa fila.",
		"Llevo seis anos intentando abrir una tienda en esta calle.",
	],
	"LINE_FLATS_3_B": [
		"Permits go through city hall. City hall goes through nobody.",
		"I permessi passano dal municipio. Il municipio non passa da nessuna parte.",
		"Los permisos pasan por el ayuntamiento. El ayuntamiento no pasa por ningun sitio.",
	],
	"LINE_FLATS_3_C": [
		"Quiet street. Too quiet for business.",
		"Strada tranquilla. Troppo tranquilla per lavorarci.",
		"Calle tranquila. Demasiado tranquila para el negocio.",
	],
	"LINE_FLATS_4_A": [
		"I have lived on this avenue longer than it has had a name.",
		"Abito su questo viale da prima che avesse un nome.",
		"Vivo en esta avenida desde antes de que tuviera nombre.",
	],
	"LINE_FLATS_4_B": [
		"Careful past the tow yard. They take anything that stands still.",
		"Attento dopo il deposito carri. Si portano via tutto quello che sta fermo.",
		"Cuidado pasado el deposito de grua. Se llevan todo lo que este quieto.",
	],
	"LINE_FLATS_4_C": [
		"You look like you are up to something. Good for you.",
		"Hai l'aria di uno che sta combinando qualcosa. Buon per te.",
		"Tienes pinta de estar tramando algo. Me alegro por ti.",
	],
	"LINE_FLATS_5_A": [
		"Cops never come down Mill Road. Just saying.",
		"Su Mill Road gli sbirri non ci vengono mai. Così, per dire.",
		"Por Mill Road la poli no baja nunca. Por decir algo.",
	],
	"LINE_FLATS_5_B": [
		"You got anything? No? Cool. Cool cool cool.",
		"Hai qualcosa? No? Va bene. Va bene va bene.",
		"Llevas algo? No? Vale. Vale vale vale.",
	],
	"LINE_FLATS_5_C": [
		"I have cleared that whole stair set. Twice.",
		"Quella rampa di scale l'ho saltata tutta. Due volte.",
		"Ese tramo de escaleras me lo he saltado entero. Dos veces.",
	],
	"LINE_IND_1_A": [
		"Third shift at the plant. Cough came free with the job.",
		"Terzo turno alla fabbrica. La tosse era compresa nel posto.",
		"Tercer turno en la fabrica. La tos venia incluida con el puesto.",
	],
	"LINE_IND_1_B": [
		"Whole yard is scrap now. Used to be four hundred of us in there.",
		"Adesso il piazzale è tutto ferraglia. Là dentro eravamo in quattrocento.",
		"Ahora el patio es todo chatarra. Ahi dentro eramos cuatrocientos.",
	],
	"LINE_IND_1_C": [
		"You want work, talk to the depot. You want money, do not.",
		"Se cerchi lavoro, prova al deposito. Se cerchi soldi, lascia perdere.",
		"Si buscas trabajo, prueba en el deposito. Si buscas dinero, dejalo.",
	],
	"LINE_IND_2_A": [
		"I walk this street twice a day. Nothing ever changes on it.",
		"Faccio questa strada due volte al giorno. Non ci cambia mai niente.",
		"Hago esta calle dos veces al dia. Aqui no cambia nunca nada.",
	],
	"LINE_IND_2_B": [
		"Dock Street is the line. Flats that side, works this side.",
		"Dock Street è il confine. I Flats di là, le officine di qua.",
		"Dock Street es la linea. Los Flats a ese lado, los talleres a este.",
	],
	"LINE_IND_2_C": [
		"Watch the trucks. They do not watch you.",
		"Occhio ai camion. Loro a te non ci badano.",
		"Ojo con los camiones. Ellos a ti no te miran.",
	],
	"LINE_IND_3_A": [
		"Foreman says one more month. He said that last winter.",
		"Il capo dice ancora un mese. Lo diceva anche l'inverno scorso.",
		"El capataz dice que un mes mas. Eso decia el invierno pasado.",
	],
	"LINE_IND_3_B": [
		"Smell that? That is the tank farm. You get used to it.",
		"Lo senti l'odore? Sono i serbatoi. Ci si fa l'abitudine.",
		"Hueles eso? Son los depositos. Uno se acostumbra.",
	],
	"LINE_IND_3_C": [
		"Everything here runs on somebody owing somebody.",
		"Qui gira tutto sul fatto che qualcuno deve qualcosa a qualcun altro.",
		"Aqui todo funciona porque alguien le debe algo a alguien.",
	],
	"LINE_IND_4_A": [
		"Forty years on the line and they gave me a clock.",
		"Quarant'anni in catena di montaggio e mi hanno regalato un orologio.",
		"Cuarenta anos en la cadena y me regalaron un reloj.",
	],
	"LINE_IND_4_B": [
		"Division Avenue. Good name. Right idea.",
		"Division Avenue. Bel nome. Idea giusta.",
		"Division Avenue. Buen nombre. Idea acertada.",
	],
	"LINE_IND_4_C": [
		"Nothing gets built here any more. Only moved.",
		"Qui non si costruisce più niente. Si sposta e basta.",
		"Aqui ya no se construye nada. Solo se mueve.",
	],
	"LINE_DOWN_1_A": [
		"Rent downtown is a joke. The punchline is me.",
		"Gli affitti in centro sono una barzelletta. La battuta finale sono io.",
		"Los alquileres del centro son un chiste. El remate soy yo.",
	],
	"LINE_DOWN_1_B": [
		"Everyone here is late for something.",
		"Qui sono tutti in ritardo per qualcosa.",
		"Aqui todo el mundo llega tarde a algo.",
	],
	"LINE_DOWN_1_C": [
		"The clinic is the only place in this city that answers the phone.",
		"La clinica è l'unico posto in questa città che risponde al telefono.",
		"La clinica es el unico sitio de esta ciudad que coge el telefono.",
	],
	"LINE_DOWN_2_A": [
		"I know a guy who knows a guy. That is the whole economy.",
		"Conosco uno che conosce uno. L'economia è tutta qui.",
		"Conozco a uno que conoce a otro. Toda la economia es esa.",
	],
	"LINE_DOWN_2_B": [
		"Market square on a weekday. Dead as anything.",
		"La piazza del mercato in un giorno feriale. Morta.",
		"La plaza del mercado entre semana. Muerta del todo.",
	],
	"LINE_DOWN_2_C": [
		"You are not from downtown. It shows.",
		"Tu non sei del centro. Si vede.",
		"Tu no eres del centro. Se te nota.",
	],
	"LINE_CIVIC_1_A": [
		"The fountain has been dry twice this month. Nobody at city hall answers.",
		"La fontana è rimasta a secco due volte questo mese. Al municipio non risponde nessuno.",
		"La fuente se ha quedado seca dos veces este mes. En el ayuntamiento no contesta nadie.",
	],
	"LINE_CIVIC_1_B": [
		"Quiet down here. That is what I pay the taxes for.",
		"Qui è tranquillo. È per quello che pago le tasse.",
		"Aqui hay tranquilidad. Para eso pago los impuestos.",
	],
	"LINE_CIVIC_1_C": [
		"You are a long way from the Flats, friend.",
		"Sei parecchio lontano dai Flats, amico.",
		"Estas bastante lejos de los Flats, amigo.",
	],
	"LINE_CIVIC_2_A": [
		"Third window on the left, and bring two forms of everything.",
		"Terzo sportello a sinistra, e porta due copie di tutto.",
		"Tercera ventanilla a la izquierda, y trae dos copias de todo.",
	],
	"LINE_CIVIC_2_B": [
		"I have been to every office on this avenue. Twice.",
		"Sono passato da tutti gli uffici di questo viale. Due volte.",
		"He pasado por todas las oficinas de esta avenida. Dos veces.",
	],
	"LINE_CIVIC_2_C": [
		"They moved the registry again. Nobody knows where.",
		"Hanno spostato di nuovo l'anagrafe. Nessuno sa dove.",
		"Han vuelto a mover el registro. Nadie sabe adonde.",
	],
	"LINE_CIVIC_3_A": [
		"School board meets Tuesdays. Nobody comes.",
		"Il consiglio di istituto si riunisce il martedì. Non ci va nessuno.",
		"El consejo escolar se reune los martes. No va nadie.",
	],
	"LINE_CIVIC_3_B": [
		"That plaza cost more than the school it faces.",
		"Quella piazza è costata più della scuola che ci sta davanti.",
		"Esa plaza costo mas que el colegio que tiene enfrente.",
	],
	"LINE_CIVIC_3_C": [
		"Careful who sees you down here in the daytime.",
		"Attento a chi ti vede qui sotto di giorno.",
		"Ojo con quien te vea por aqui a plena luz.",
	],
	"LINE_HILL_1_A": [
		"We have a committee about people like you walking up here.",
		"Abbiamo un comitato apposta per la gente come te che sale fin qui.",
		"Tenemos un comite para la gente como tu que sube hasta aqui.",
	],
	"LINE_HILL_1_B": [
		"Lovely day. Do move along.",
		"Bella giornata. Adesso però circola.",
		"Bonito dia. Ahora circule.",
	],
	"LINE_HILL_1_C": [
		"The gardener comes Tuesdays. You are not the gardener.",
		"Il giardiniere viene il martedì. Tu non sei il giardiniere.",
		"El jardinero viene los martes. Tu no eres el jardinero.",
	],
	"LINE_HILL_2_A": [
		"Bought this place before the boulevard went in. Best decision I made.",
		"Ho comprato qui prima che facessero il viale. La mia decisione migliore.",
		"Compre aqui antes de que hicieran el bulevar. La mejor decision de mi vida.",
	],
	"LINE_HILL_2_B": [
		"The club has a waiting list. It has had one since 1974.",
		"Il club ha una lista d'attesa. Ce l'ha dal 1974.",
		"El club tiene lista de espera. La tiene desde 1974.",
	],
	"LINE_HILL_2_C": [
		"You want the Flats. Straight down, then keep going.",
		"Tu cerchi i Flats. Dritto giù, e poi continua.",
		"Tu buscas los Flats. Todo recto para abajo, y sigue.",
	],
	"LINE_HILL_3_A": [
		"Hill Drive is private above the boulevard. Officially.",
		"Hill Drive sopra al viale è privata. Ufficialmente.",
		"Hill Drive por encima del bulevar es privada. Oficialmente.",
	],
	"LINE_HILL_3_B": [
		"I walk this every morning. I have never met a neighbour.",
		"Faccio questa strada ogni mattina. Non ho mai incontrato un vicino.",
		"Hago esta calle cada manana. Nunca me he cruzado con un vecino.",
	],
	"LINE_HILL_3_C": [
		"If you are selling something, the answer is no. Probably.",
		"Se stai vendendo qualcosa, la risposta è no. Probabilmente.",
		"Si vendes algo, la respuesta es no. Probablemente.",
	],
}

# --- Controlli sulla tabella ------------------------------------------------

## Quanto lunghe possono essere le voci del menu del telefono.
##
## Non e' una regola di stile: il vetro del telefono e' largo 116 px (e la
## larghezza della scocca e' scelta apposta perche' ci stiano, vedi `SIZE` in
## `phone.gd`) e il bottone taglia quello che avanza. Tredici caratteri col font
## del gioco a corpo 12 sono quello che ci sta. Vedi `PHONE_CALL_BRIAN`.
const PHONE_MENU_CHARS := 13
## Le voci che devono stare in quella larghezza.
const PHONE_MENU_KEYS := [
	"PHONE_CALL_BRIAN", "PHONE_WAITING", "PHONE_BRIAN_HERE",
	"PHONE_SEND_DRIVER", "PHONE_DRIVER_OUT",
]

## Caratteri che il font del gioco sa disegnare: lettere e spazio, nient'altro.
## Vedi la regola 2 in cima al file.
##
## L'a-capo e' ammesso e non e' un'eccezione alla regola: non e' un carattere
## che il font deve disegnare, e' dove la riga finisce. Nelle vignette fa il
## lavoro che farebbe la punteggiatura, che li' non si puo' scrivere.
const PIXEL_FONT_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 
"

## Le chiavi mostrate col font del gioco, e quindi limitate a lettere e spazio.
## L'elenco è scritto a mano perché è una proprietà di **dove** finisce la
## stringa, non della stringa: la stessa frase in un'altra Label andrebbe bene.
const PIXEL_KEYS := [
	"MENU_CONTINUE", "MENU_QUIT",
	"MENU_NEW_GAME", "MENU_SAVES", "MENU_SETTINGS", "MENU_BACK", "MENU_VIDEO",
	"MENU_AUDIO", "MENU_COMMANDS", "MENU_LANGUAGE", "MENU_LOAD", "MENU_DELETE",
	"MENU_OFFLINE", "MENU_OFFLINE_ON", "MENU_OFFLINE_OFF",
	"MENU_SURE",
	# Le righe del menu a tre righe in partita: si leggono col pennello.
	"STAFF_DEALER", "STAFF_GROWER",
	"ROOM_ENTRANCE", "ROOM_KITCHEN", "ROOM_BASEMENT", "ROOM_GARAGE", "ROOM_GENERIC",
	"ROOM_EXIT",
	"PC_TITLE", "PC_CLOSE",
	"RE_TITLE", "RE_CLOSE", "RE_BUY", "RE_OWNED", "RE_NO_CASH", "RE_CASH",
	"RE_EMPTY", "RE_GARAGE_NAME", "RE_GARAGE_DESC", "RE_TITLE_DOWNTOWN",
	"PC_TAB_OVERVIEW", "PC_TAB_GROW", "PC_TAB_SHOP", "PC_TAB_MARKET", "PC_TAB_STAFF",
	"PC_CASH", "PC_DAY", "PC_STOCK", "PC_SEEDS", "PC_POTS_IN_USE", "PC_READY_TO_CUT",
	"PC_ATTENTION", "PC_GRAMS_HARVESTED", "PC_GRAMS_SOLD", "PC_TOTAL_EARNED",
	"PC_STAFF", "PC_WAGES", "PC_SALES_SPLIT", "PC_RESERVED", "PC_WHOLESALE_TODAY",
	"PC_GROWER_SITES", "PC_SITE_SPARE", "SITE_BASEMENT", "SITE_GARAGE",
	"PC_STREET_PRICE", "PC_STOCK_VALUE",
	"MSG_COUSIN_SPEAKER", "MSG_STAFF_SPEAKER", "MSG_AWAY_SPEAKER", "MSG_POWER_SPEAKER",
	"MSG_TAX_SPEAKER",
	"MSG_OK",
	# I corpi delle vignette: si leggono col font del gioco, non con quello di
	# sistema come gli avvisi. Vedi `phone.gd`.
	"MSG_INTRO_BODY", "MSG_KILO_BODY", "MSG_EXPAND_BODY", "MSG_COUSIN_BODY",
	"MSG_ORG_NAME_BODY", "ORG_NAME_TITLE", "PRESTIGE_ROOKIES",
	"MSG_SEED_WHOLESALE_BODY", "MSG_DRIVER_BODY", "MSG_DRIVER_HELLO", "SW_TITLE",
	"MSG_DRIVER_SPEAKER",
	"PHONE_CALL_BRIAN", "PHONE_WAITING", "PHONE_BRIAN_HERE", "CHAT_TITLE",
	# Della guida solo la voce in rubrica: dentro si legge col font di
	# sistema, e le cifre servono.
	"GUIDE_TITLE",
	"CUT_VAN_OUT",
]

static func locale_name(locale: String) -> String:
	return str(LOCALE_NAMES.get(locale, locale.to_upper()))

## Le righe che non tornano, come testo leggibile. Vuoto vuol dire tutto a
## posto. La usa il controllo automatico: una traduzione dimenticata non rompe
## niente, si limita a mostrare la chiave a schermo, ed è esattamente il tipo di
## errore che si scopre tardi e per caso.
static func problems() -> Array:
	var found: Array = []
	for key in TEXT:
		var row: Array = TEXT[key]
		if row.size() != LOCALES.size():
			found.append("%s ha %d lingue invece di %d" % [key, row.size(), LOCALES.size()])
			continue
		for i in row.size():
			if str(row[i]).is_empty():
				found.append("%s manca in %s" % [key, LOCALES[i]])
		if key in PIXEL_KEYS:
			for i in row.size():
				for letter in str(row[i]):
					if not PIXEL_FONT_CHARS.contains(letter):
						found.append("%s (%s) ha '%s', che il font del gioco non disegna" % [
							key, LOCALES[i], letter])
						break
	for key in PIXEL_KEYS:
		if not TEXT.has(key):
			found.append("%s e' segnata PIXEL ma non esiste" % key)
	# Le voci del menu del telefono hanno anche un tetto di lunghezza: oltre
	# quello il bottone le taglia a meta' parola. Vedi `PHONE_MENU_CHARS`.
	for key in PHONE_MENU_KEYS:
		if not TEXT.has(key):
			found.append("%s e' una voce del telefono ma non esiste" % key)
			continue
		for i in (TEXT[key] as Array).size():
			var line := str(TEXT[key][i])
			if line.length() > PHONE_MENU_CHARS:
				found.append("%s (%s) e' lunga %d: sullo schermo del telefono ce ne stanno %d" % [
					key, LOCALES[i], line.length(), PHONE_MENU_CHARS])
	return found
