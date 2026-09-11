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
##    Sono quelle mostrate col font del gioco (`alphabet.fnt`), che ha
##    cinquantatré caratteri: A-Z, a-z e lo spazio. Niente cifre, niente
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
	"MENU_NEW_GAME": ["new game", "nuova partita", "partida nueva"],
	"MENU_SAVES": ["saves", "salvataggi", "partidas"],
	"MENU_SETTINGS": ["settings", "impostazioni", "ajustes"],
	"MENU_BACK": ["back", "indietro", "atras"],
	"MENU_VIDEO": ["video", "video", "video"],
	"MENU_AUDIO": ["audio", "audio", "audio"],
	"MENU_COMMANDS": ["commands", "comandi", "controles"],
	"MENU_LANGUAGE": ["language", "lingua", "idioma"],
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

	# --- Stanze (PIXEL) ----------------------------------------------------
	"ROOM_ENTRANCE": ["ENTRANCE", "INGRESSO", "ENTRADA"],
	"ROOM_KITCHEN": ["KITCHEN", "CUCINA", "COCINA"],
	"ROOM_BASEMENT": ["BASEMENT", "CANTINA", "SOTANO"],
	"ROOM_GENERIC": ["ROOM", "STANZA", "CUARTO"],
	"ROOM_EXIT": ["EXIT", "ESCI", "SALIR"],

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
	"PC_WHOLESALE_TODAY": ["WHOLESALE TODAY", "INGROSSO OGGI", "MAYOREO HOY"],
	"PC_STREET_PRICE": ["STREET PRICE", "PREZZO IN STRADA", "PRECIO EN LA CALLE"],
	"PC_STOCK_VALUE": ["STOCK VALUE", "VALORE SCORTA", "VALOR EXISTENCIAS"],
	## %d numero del vaso. Font di sistema: contiene una cifra.
	"PC_POT_N": ["POT %d", "VASO %d", "MACETA %d"],
	## %s giorni, %s orario
	"PC_DAY_VALUE": ["%d   %s", "%d   %s", "%d   %s"],

	# --- Il PC: scheda GROW ------------------------------------------------
	"PC_PLOT_EMPTY": ["empty", "vuoto", "vacio"],
	"PC_PLOT_EMPTY_AUTO": [
		"empty  (self-watering)", "vuoto  (si annaffia da solo)", "vacio  (se riega solo)",
	],
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
	## %d grammi, %s incasso
	"PC_SELL_N": ["SELL %d G  -  %s", "VENDI %d G  -  %s", "VENDER %d G  -  %s"],
	## %s incasso
	"PC_SELL_ALL": [
		"SELL EVERYTHING  -  %s", "VENDI TUTTO  -  %s", "VENDER TODO  -  %s",
	],
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
	## %d quanti vasi ci stanno
	"PC_SHOP_POT_NOTE": [
		"One more pot down in the basement, up to %d.",
		"Un vaso in più giù in cantina, fino a %d.",
		"Una maceta mas en el sotano, hasta %d.",
	],

	# --- Il PC: scheda STAFF -----------------------------------------------
	## %s paga giornaliera
	"PC_WAGES_VALUE": ["%s / day", "%s / giorno", "%s / dia"],
	## %d quanti, %d massimo, %s paga
	"PC_STAFF_COUNT": [
		"%d / %d   (%s / day)", "%d / %d   (%s / giorno)", "%d / %d   (%s / dia)",
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
	"PC_MORE_WHOLESALE": [
		"MORE WHOLESALE  (safer)", "PIU' INGROSSO  (piu' sicuro)", "MAS MAYOREO  (mas seguro)",
	],
	"PC_MORE_STREET": [
		"MORE STREET  (pays better)", "PIU' STRADA  (rende di piu')", "MAS CALLE  (paga mejor)",
	],
	## %d percentuale in più della strada
	"PC_SPLIT_NOTE": [
		"Street pays %d%% more than wholesale, but every gram that changes hands out there raises attention. The split is for the dealers you hire: what you sell yourself is still up to you. Wages come out of the till at midnight.",
		"La strada rende il %d%% in più dell'ingrosso, ma ogni grammo che passa di mano là fuori alza l'attenzione. La ripartizione vale per i dealer che assumi: quello che vendi di persona resta affar tuo. Le paghe escono di cassa a mezzanotte.",
		"La calle paga un %d%% mas que el mayoreo, pero cada gramo que cambia de manos ahi fuera levanta atencion. El reparto vale para los vendedores que contratas: lo que vendas tu sigue siendo cosa tuya. Los sueldos salen de la caja a medianoche.",
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
		"Red lamps over the pots: each set cuts 8% off the growing time. Applies to plants put in from now on.",
		"Lampade rosse sopra ai vasi: ogni set taglia l'8% del tempo di crescita. Vale per le piante messe da qui in avanti.",
		"Lamparas rojas sobre las macetas: cada juego recorta un 8% del tiempo de cultivo. Vale para las plantas que siembres de ahora en adelante.",
	],
	"SHOP_AUTO_WATER": ["SELF-WATERING POT", "VASO AUTOINNAFFIANTE", "MACETA DE AUTORRIEGO"],
	"SHOP_AUTO_WATER_NOTE": [
		"A tank and a slow drip: a pot that never gets thirsty. One pot per purchase, starting from the first.",
		"Serbatoio e goccia lenta: un vaso che non ha più sete. Se ne equipaggia uno per acquisto, partendo dal primo.",
		"Deposito y goteo lento: una maceta que nunca pasa sed. Se equipa una por compra, empezando por la primera.",
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
		"Works the basement: plants whatever seeds he finds, waters, harvests. Two pots each.",
		"Sta in cantina: pianta i semi che trova, annaffia e raccoglie. Segue due vasi a testa.",
		"Trabaja en el sotano: siembra las semillas que encuentra, riega y cosecha. Dos macetas cada uno.",
	],
	"STAFF_DEALER": ["DEALER", "SPACCIATORE", "VENDEDOR"],
	"STAFF_DEALER_NOTE": [
		"Moves the product in the split set below. What goes to the street pays more and raises attention.",
		"Piazza la merce nella proporzione decisa qui sotto. Quello che va in strada rende di più e alza l'attenzione.",
		"Mueve la mercancia en la proporcion de abajo. Lo que va a la calle paga mas y levanta atencion.",
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

	# --- Messaggi sul telefono ---------------------------------------------
	"MSG_COUSIN_SPEAKER": ["BRIAN", "BRIAN", "BRIAN"],
	"MSG_COUSIN_BODY": [
		"I see you are putting the work in, cousin. If the business keeps growing like this, soon you should get someone in to help you.\n\nCheck the PC: there is a place to hire people now.",
		"Vedo che ti stai impegnando, cugino. Se l'attività cresce ancora, fra poco ti conviene assumere qualcuno che ti dia una mano.\n\nGuarda il PC: adesso c'è il posto per assumere.",
		"Veo que te estas esforzando, primo. Si el negocio sigue creciendo asi, dentro de poco te conviene contratar a alguien que te eche una mano.\n\nMira el PC: ahora hay un sitio para contratar.",
	],
	"MSG_STAFF_SPEAKER": ["STAFF", "PERSONALE", "PERSONAL"],
	## %s ruolo
	"MSG_STAFF_QUIT": [
		"%s walked out: there was not enough in the till to cover the wages.",
		"%s se n'è andato: in cassa non c'era abbastanza per pagare le paghe.",
		"%s se ha largado: no habia bastante en la caja para pagar los sueldos.",
	],
	"MSG_OK": ["OK", "OK", "OK"],

	# --- Brian all'appuntamento --------------------------------------------
	"NPC_SEEDS_EMPTY": [
		"That was the last of it. Give me a couple of hours and ask again.",
		"Quello era l'ultimo. Dammi un paio d'ore e richiedimelo.",
		"Ese era el ultimo. Dame un par de horas y vuelve a pedirmelo.",
	],
	## %d prezzo, %d quanti ne ha portati, %d quanti ne hai, %d soldi
	"NPC_SEEDS_BODY": [
		"Straight out of the clinic stock, cousin. %d $ a seed, and you never got them from me.\n\nI brought %d. You have %d seed(s), %d $.",
		"Presi dritti dal magazzino della clinica, cugino. %d $ al seme, e non te li ho dati io.\n\nNe ho portati %d. Tu hai %d seme/i, %d $.",
		"Sacados del almacen de la clinica, primo. %d $ la semilla, y yo no te los he dado.\n\nHe traido %d. Tu tienes %d semilla(s), %d $.",
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

## Caratteri che il font del gioco sa disegnare: lettere e spazio, nient'altro.
## Vedi la regola 2 in cima al file.
const PIXEL_FONT_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz "

## Le chiavi mostrate col font del gioco, e quindi limitate a lettere e spazio.
## L'elenco è scritto a mano perché è una proprietà di **dove** finisce la
## stringa, non della stringa: la stessa frase in un'altra Label andrebbe bene.
const PIXEL_KEYS := [
	"MENU_NEW_GAME", "MENU_SAVES", "MENU_SETTINGS", "MENU_BACK", "MENU_VIDEO",
	"MENU_AUDIO", "MENU_COMMANDS", "MENU_LANGUAGE", "MENU_LOAD", "MENU_DELETE",
	"MENU_SURE",
	"ROOM_ENTRANCE", "ROOM_KITCHEN", "ROOM_BASEMENT", "ROOM_GENERIC", "ROOM_EXIT",
	"PC_TITLE", "PC_CLOSE",
	"PC_TAB_OVERVIEW", "PC_TAB_GROW", "PC_TAB_SHOP", "PC_TAB_MARKET", "PC_TAB_STAFF",
	"PC_CASH", "PC_DAY", "PC_STOCK", "PC_SEEDS", "PC_POTS_IN_USE", "PC_READY_TO_CUT",
	"PC_ATTENTION", "PC_GRAMS_HARVESTED", "PC_GRAMS_SOLD", "PC_TOTAL_EARNED",
	"PC_STAFF", "PC_WAGES", "PC_SALES_SPLIT", "PC_WHOLESALE_TODAY",
	"PC_STREET_PRICE", "PC_STOCK_VALUE",
	"MSG_COUSIN_SPEAKER", "MSG_STAFF_SPEAKER", "MSG_OK",
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
	return found
