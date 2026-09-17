class_name CityMap
extends RefCounted

## La pianta della cittadina, come DATI e non come scena.
##
## `City.tscn` è quasi vuota: strade, quartieri, edifici, traffico e NPC
## vengono costruiti a runtime leggendo queste tabelle.
##
## ## Due strati di edifici
##
## `BUILDINGS` contiene i **punti di riferimento**: quelli che hanno un nome, un
## ruolo o una posizione che conta (la casa iniziale, gli alimentari, il palazzo
## occupato). Sono scritti a mano, uno per uno.
##
## Tutto il resto — le file di case qualunque che riempiono i blocchi — lo
## genera `all_buildings()` percorrendo i fronti stradali, pescando dal catalogo
## `FILL_ART`. Sono un centinaio: scritti a mano non si rileggerebbero e non si
## sposterebbero più, e ogni ritocco al reticolo vorrebbe dire rifarli tutti.
## Generandoli, spostare una strada risistema il quartiere da sé.
##
## La generazione è **deterministica** (`FILL_SEED`): la città è identica a ogni
## avvio. Non è un requisito tecnico — gli edifici di sfondo non hanno stato —
## ma una città che si rimescola a ogni lancio è disorientante.
##
## ## Un quartiere solo, e tutto disegnato
##
## Gli edifici sono **sempre** un PNG: quelli scritti a mano e quelli generati
## pescano dagli stessi otto disegni. Prima esisteva anche un segnaposto —
## rettangolo colorato con l'insegna e la griglia di finestre — e riempiva i
## quattro quartieri che i disegni non ce l'hanno. Adesso quei quartieri sono
## terreno, strade e lampioni, e basta: un edificio finto accanto a uno disegnato
## si riconosce a colpo d'occhio, e una città mezza finta si legge peggio di una
## metà costruita. `BUILT_DISTRICTS` dice quali sono costruiti.
##
## ## Come si aggiunge un disegno
##
## Un edificio di sfondo in più: una riga in `FILL_ART` con il file e la sua
## misura in pixel, e il riempimento comincia a seminarlo. Un edificio che deve
## avere un nome, una posizione precisa o un interno: una voce in `BUILDINGS`,
## con `texture`, `offset` e `click`. Quelle due righe non si scrivono a mano —
## escono da `scripts_tools/import_flats_art.py`, che porta il disegno originale
## alla scala del gioco e le stampa già pronte da incollare.
##
## ## Il reticolo
##
## Tutto è allineato alla griglia da 32 px. Le strade sono definite dal
## rettangolo del loro ASFALTO; marciapiedi e cordoli li disegna
## `city_ground.gd` intorno, così gli incroci si fondono da sé.
##
## L'origine di un edificio è il PUNTO A TERRA al centro della facciata: il
## corpo si sviluppa verso l'alto. Quindi un edificio sul lato NORD di una strada
## ha la base sul bordo alto del marciapiede, e uno sul lato SUD ha la base più
## in basso della strada, con il corpo che arriva a toccare il marciapiede. È il
## campo `"front"` a dire quale dei due casi è, e da lì si ricava da che parte
## il giocatore si avvicina.

const TILE := 32.0
const SIDEWALK_DEPTH := 32.0
const ROAD_WIDTH := 96.0

## Confini del mondo: li usa la camera per non mostrare il vuoto oltre i bordi.
## Il mondo è cresciuto a nord (-608) e a ovest (-480). Era -352 su tutti e due
## i lati, ed era dimensionato quando gli edifici erano alti duecento pixel.
##
## Adesso sono renderizzati alla scala del personaggio — 22,3 px per metro, vedi
## `render_buildings.py` — e a quella scala un palazzo di otto piani è alto quasi
## settecento pixel e ne occupa cinquecento di fronte strada. Col vecchio
## confine il suo tetto finiva fuori dal mondo a nord, e il primo isolato di THE
## FLATS non teneva il palazzo accanto a casa.
##
## Il margine in più sta solo dove serve: sopra MAIN STREET, dove vanno i tetti,
## e a ovest della casa iniziale, che non si può spostare perché è lì che nasce
## il protagonista.
const WORLD_BOUNDS := Rect2(-480, -608, 10880, 9536)

# --- Strade ----------------------------------------------------------------
## Rettangoli dell'asfalto. Orizzontali e verticali stanno separate perché la
## segnaletica (mezzeria, strisce) va disegnata lungo l'asse giusto.
##
## MAIN STREET resta dov'era (y 272): tutto il quartiere povero originale è
## costruito intorno a quella quota, casa iniziale compresa, e spostarla
## vorrebbe dire rifare le posizioni buone che ci sono già.
const ROADS_H := [
	Rect2(-480, 272, 10880, 96),   # MAIN STREET
	Rect2(-480, 976, 10880, 96),   # CROSS STREET
	Rect2(-480, 1680, 10880, 96),  # FOUNDRY ROW
	Rect2(-480, 2240, 10880, 96),  # DIVISION AVENUE
	Rect2(-480, 2944, 10880, 96),  # PARK LANE
	Rect2(-480, 3552, 10880, 96),  # SOUTH BOULEVARD
	Rect2(-480, 4256, 10880, 96),  # LOWER MAIN
	Rect2(-480, 4960, 10880, 96),  # CANAL ROAD
	Rect2(-480, 5664, 10880, 96),  # RIVER ROW
	Rect2(-480, 6368, 10880, 96),  # SOUTH GATE
	Rect2(-480, 7072, 10880, 96),  # QUARRY LANE
	Rect2(-480, 7776, 10880, 96),  # OLD MILL ROAD
	Rect2(-480, 8480, 10880, 96),  # COUNTY LINE
]
const ROADS_V := [
	Rect2(752, -608, 96, 9536),   # MILL ROAD
	Rect2(1856, -608, 96, 9536),  # DOCK STREET
	Rect2(2672, -608, 96, 9536),  # FURNACE STREET
	Rect2(3488, -608, 96, 9536),  # EAST STREET
	Rect2(4256, -608, 96, 9536),  # HILL DRIVE
	Rect2(5072, -608, 96, 9536),  # PORT STREET
	Rect2(5888, -608, 96, 9536),  # LOCK STREET
	Rect2(6704, -608, 96, 9536),  # SEVENTH STREET
	Rect2(7520, -608, 96, 9536),  # EIGHTH STREET
	Rect2(8336, -608, 96, 9536),  # NINTH STREET
	Rect2(9152, -608, 96, 9536),  # TENTH STREET
	Rect2(9968, -608, 96, 9536),  # COUNTY ROAD
]

## Nomi delle strade, nello stesso ordine di `ROADS_H`/`ROADS_V`. Finora
## stavano solo nei commenti qui sopra, che va benissimo finché servono a chi
## legge il codice: da quando un nome va MOSTRATO al giocatore — Brian che dice
## dove aspetta — deve essere un dato leggibile e non un commento.
##
## Sono di sole lettere e spazio, quindi si possono scrivere col font del gioco.
const ROAD_NAMES_H := [
	"MAIN STREET", "CROSS STREET", "FOUNDRY ROW",
	"DIVISION AVENUE", "PARK LANE", "SOUTH BOULEVARD",
	"LOWER MAIN", "CANAL ROAD", "RIVER ROW",
	"SOUTH GATE", "QUARRY LANE", "OLD MILL ROAD",
	"COUNTY LINE",
]
const ROAD_NAMES_V := [
	"MILL ROAD", "DOCK STREET", "FURNACE STREET",
	"EAST STREET", "HILL DRIVE", "PORT STREET",
	"LOCK STREET", "SEVENTH STREET", "EIGHTH STREET",
	"NINTH STREET", "TENTH STREET", "COUNTY ROAD",
]

# --- Dove si cammina -------------------------------------------------------
## Quote dei marciapiedi, una per strada nell'ordine di `ROADS_H`/`ROADS_V`.
## Sono i numeri da usare per scrivere i percorsi degli NPC: presi da qui non si
## finisce a camminare dentro a un muro o in mezzo alla carreggiata.
const SIDEWALK_N := [
	256.0, 960.0, 1664.0, 2224.0, 2928.0, 3536.0,
	4240.0, 4944.0, 5648.0, 6352.0, 7056.0, 7760.0,
	8464.0,
]
const SIDEWALK_S := [
	384.0, 1088.0, 1792.0, 2352.0, 3056.0, 3664.0,
	4368.0, 5072.0, 5776.0, 6480.0, 7184.0, 7888.0,
	8592.0,
]
const SIDEWALK_W := [
	736.0, 1840.0, 2656.0, 3472.0, 4240.0, 5056.0,
	5872.0, 6688.0, 7504.0, 8320.0, 9136.0, 9952.0,
]
const SIDEWALK_E := [
	864.0, 1968.0, 2784.0, 3600.0, 4368.0, 5184.0,
	6000.0, 6816.0, 7632.0, 8448.0, 9264.0, 10080.0,
]
## Ascisse su cui cadono le strisce pedonali che attraversano le strade
## orizzontali: è lì che le pattuglie devono cambiare lato.
const CROSS_X := [
	744.0, 1848.0, 2664.0, 3480.0, 4248.0, 5064.0,
	5880.0, 6696.0, 7512.0, 8328.0, 9144.0, 9960.0,
]

# --- Quartieri -------------------------------------------------------------
## Il colore è il terreno di fondo, non gli edifici: serve a far capire a
## occhio dove finisce un quartiere e comincia l'altro. `label_at` è dove mettere
## il nome, scelto a mano per non finire sopra a un edificio.
##
## `names` sono le insegne generiche del quartiere: quelle di cui in giro ce n'è
## più d'una, e che quindi non valgono come indicazione stradale (vedi
## `_is_generic()`). Ce l'ha solo THE FLATS perché è l'unico quartiere
## costruito: negli altri quattro ci sono al massimo dei punti di riferimento
## singoli — la clinica in HILLSIDE, il grossista in DOWNTOWN — e un edificio
## solo non ha bisogno di insegne generiche per non essere confuso con altri.
const DISTRICTS := [
	{
		"id": "flats",
		"name": "THE FLATS",
		"rect": Rect2(-480, -608, 2336, 2848),
		"color": Color(0.243, 0.235, 0.169),
		"label_at": Vector2(-160, 40),
		"names": [
			"HOUSE", "APARTMENTS", "CORNER STORE", "GARAGE", "LAUNDRY",
			"ROOMS", "AUTO PARTS", "BARBER", "BODEGA", "TENEMENT", "MOTEL",
		],
	},
	{
		"id": "industrial",
		"name": "INDUSTRIAL PARK",
		"rect": Rect2(1952, -608, 1536, 2848),
		"color": Color(0.310, 0.259, 0.212),
		"label_at": Vector2(2100, -232),
	},
	{
		"id": "downtown",
		"name": "DOWNTOWN",
		"rect": Rect2(3584, -608, 6816, 2848),
		"color": Color(0.251, 0.278, 0.341),
		"label_at": Vector2(3700, -232),
	},
	{
		"id": "civic",
		"name": "CIVIC CENTER",
		"rect": Rect2(-480, 2336, 3968, 6592),
		"color": Color(0.204, 0.302, 0.263),
		"label_at": Vector2(-176, 2376),
	},
	{
		"id": "hillside",
		"name": "HILLSIDE",
		"rect": Rect2(3584, 2336, 6816, 6592),
		"color": Color(0.322, 0.392, 0.216),
		"label_at": Vector2(4500, 2376),
	},
]

# --- Superfici particolari -------------------------------------------------
## Pezzi di terreno che non sono né strada né edificio: prato del parco, piazza,
## ghiaia dello sfasciacarrozze. Gli stili sono in `city_ground.gd`, qui c'è
## solo dove stanno.
##
## Servono anche al riempimento automatico, che ci gira intorno: un capannone
## in mezzo a un campo non ci va.
##
## Era vuota (2026-09-16): c'era dentro una ventina di segnaposto — campo da
## football, parcheggi, piscine, campo da tennis, parchi — nessuno dei quali un
## pezzo di città vero, tutti terreno colorato in attesa di essere deciso.
## Federico ha chiesto di toglierli tutti tranne le strade, che restano perché
## non sono segnaposto: sono la pianta della città.
##
## Ci torna dentro il primo che è stato deciso: il parcheggio del grossista.
const LOTS := [
	# Il parcheggio del magazzino all'ingrosso, dietro all'edificio.
	#
	# **Perché è profondo 330 px e non 160.** Dietro a un edificio alto dieci
	# metri, in questa vista, non si vede niente: lo sprite del magazzino sale
	# per 299 px sopra la sua riga di terra, e copre tutto il terreno che gli
	# sta dietro per altrettanti. Un parcheggio appoggiato al muro di dietro
	# sarebbe nascosto per intero dal tetto, lampioni compresi, e nessuno
	# saprebbe mai che c'è. Così invece i primi 171 px spuntano sopra alla
	# sagoma dell'edificio, ed è lì che stanno i lampioni.
	{"rect": Rect2(4400, -230, 624, 330), "kind": "asphalt"},
]

## Quanti pixel di lato stanno fra un lampione e l'altro dentro a un piazzale.
## Più fitti che in strada: un parcheggio buio con tre lampioni in croce non è
## un parcheggio illuminato, è un parcheggio con tre lampioni.
const LOT_LAMP_SPACING := 176.0
## Quanto sopra al bordo alto del piazzale cade la fila dei lampioni.
##
## 130 px e non a metà piazzale: dietro a un edificio alto si vede solo la
## fascia in cima, e un palo piantato nella parte nascosta è un palo che non si
## vede mai. Questo cade in mezzo alla fascia che spunta.
const LOT_LAMP_INSET := 130.0

# --- Fontane ---------------------------------------------------------------
## Nodi veri (l'acqua si muove), non disegno di fondo: stanno in `Props`.
const FOUNTAINS := [Vector2(160, 2660), Vector2(1700, 3350)]

# --- Punti di riferimento --------------------------------------------------
## `base`   punto a terra al centro della facciata.
##
##          La **y** non e' libera come la x: e' la riga di terra su cui poggia
##          l'edificio, e deve stare al bordo del marciapiede o piu' su
##          (`SIDEWALK_N`/`SIDEWALK_S` meno `SIDEWALK_DEPTH`), mai dentro.
##          Abbassarla di venti pixel per farlo "appoggiare" al marciapiede
##          rompe tre cose in una volta, e nessuna delle tre da' un errore:
##          l'ingombro finisce sul marciapiede, la porta (`base + entry`)
##          scivola in carreggiata, e soprattutto **chi cammina davanti
##          sparisce dietro l'edificio** — l'Y-sort mette avanti chi ha la y
##          piu' grande, quindi un passante a y 250 sta "dietro" a una facciata
##          che poggia a y 260, ed e' geometricamente giusto: e' l'edificio a
##          essere finito sopra al marciapiede. Lo controllano
##          "nessun edificio sull'asfalto o sul marciapiede" e "ogni porta sta
##          sul marciapiede" in `game_tests.gd`.
## `front`  "north" = la strada è sotto, "south" = la strada è sopra.
##          Decide da che lato il protagonista si avvicina.
## `label`  l'insegna: il nome che compare passandoci sopra col mouse, e quello
##          con cui Brian da' gli appuntamenti. Non si traduce (vedi `strings.gd`).
## `interior` scena in cui si entra cliccando (opzionale)
## `owned`  se vero, dentro ci si entra solo dopo aver comprato la proprieta'
##          dall'agenzia (`SaveData.owns()` sullo stesso `id`)
## `in_front` a parita' di riga di terra, questo edificio si disegna davanti agli
##          altri (l'Y-sort, a parita' di y, non ha niente da decidere)
## `lit`    il PNG delle finestre accese, appoggiato sopra al disegno e acceso
##          la sera (`building_lights.gd`). Esce dallo stesso scatto del
##          disegno — `render_buildings.py`, funzione `modo_luci()` — quindi e'
##          gia' allineato: stesso scostamento, nessuna coordinata da scrivere.
##          Senza questo campo l'edificio di notte si spegne tutto, muro e
##          finestre insieme, ed e' il motivo per cui va messo su tutti.
## `sign`/`sign_at` un PNG appeso sulla facciata e dove, rispetto alla base.
##          E' un file a parte e non una scritta dipinta sul disegno perche' i
##          PNG degli edifici li riscrive `import_flats_art.py`: vedi
##          `scripts_tools/make_signs.py`.
## `texture`/`offset`/`click` il PNG, il suo scostamento dall'origine e l'area
##          cliccabile. `offset` esce da `scripts_tools/import_flats_art.py`.
##
##          `click` invece e' il MURO e non tutto il PNG, e la differenza conta:
##          i disegni con un cortile comprendono anche la recinzione, e
##          prendendo tutto il rettangolo due edifici accostati muro contro muro
##          risulterebbero sovrapposti — al piazzamento, al mouse e alla griglia
##          dei percorsi. Il click segue quello che si legge come edificio.
##
## `district` a quale quartiere appartiene l'edificio, se non è THE FLATS
##          (il valore di default quando manca il campo). Serve solo al
##          controllo automatico che nessuno finisca fuori dal quartiere giusto
##          — vedi `_test_city_layout()`.
##
## Erano tutti in THE FLATS, l'unico quartiere costruito; la clinica è il primo
## punto di riferimento fuori di lì, in HILLSIDE, e il grossista dei semi il
## primo di DOWNTOWN. Restano terreno, strade e lampioni INDUSTRIAL PARK e
## CIVIC CENTER, in attesa dei loro disegni — e DOWNTOWN e HILLSIDE hanno un
## edificio a testa, che è un punto di riferimento, non un quartiere.
const BUILDINGS := [
	{
		# Casa. Resta a x 320 perche' li' nasce il protagonista quando comincia
		# una partita nuova, e quel numero e' scritto in tre posti: il default
		# di `SaveData.player_position`, il suo ripiego in lettura, e
		# `home_doorstep()`. Per accostarle si sono spostati gli altri due.
		#
		# `click` e' il MURO, non il PNG: il disegno comprende anche il cortile
		# con la staccionata, largo 153 px per parte contro i 211 del corpo.
		# Vedi la nota sopra `BUILDINGS`.
		"id": "FirstHouse", "base": Vector2(320, 240),
		"label": "HOME",
		# Davanti ai due vicini. I tre poggiano sulla stessa riga di terra, quindi
		# l'Y-sort non ha niente da decidere e il muro dell'agenzia le copriva
		# veranda e staccionata. Fra i tre è la casa a dover restare intera: e'
		# quella che si guarda, ed e' l'unica in cui si entra.
		"in_front": true,
		"texture": "res://assets/sprites/buildings/flatsHouse.png",
		"lit": "res://assets/sprites/buildings/flatsHouseLit.png",
		"offset": Vector2(-153, -361), "click": Rect2(-107, -361, 211, 361),
		# Ventiquattro e non quaranta: a quaranta la porta cadeva a y 280, cioe'
		# otto pixel DENTRO l'asfalto di MAIN STREET (272..368), e si andava a
		# bussare da mezza carreggiata. Cosi' invece coincide con
		# `home_doorstep()` (320, 264), che e' lo stesso zerbino visto da un
		# altro file: da li' si esce, li' aspetta a volte Brian, e i due numeri
		# devono dire lo stesso posto.
		"entry": Vector2(0, 24), "interior": "res://scenes/rooms/Entrance.tscn",
	},
	{
		# Il palazzo occupato, muro contro muro con casa. E' il pezzo piu' alto
		# del quartiere ed e' voluto — da lontano dice dove sta casa meglio di
		# qualunque cartello, e vale solo se casa e' li' sotto.
		#
		# Sta a SINISTRA: alla scala vera occupa 495 px di fronte strada, e fra
		# casa e MILL ROAD (x 752 piu' il marciapiede) non ce ne sono abbastanza.
		#
		# La x e' esatta e non tonda: bordo sinistro del MURO di casa (213) meno
		# la mezza larghezza del muro del palazzo (162), cosi' le due facciate si
		# toccano senza spazio. I cortili dei due disegni si sovrappongono ed e'
		# voluto — sono recinzioni, e in un quartiere popolare la
		# staccionata dell'uno e' quella dell'altro. Se uno dei due disegni
		# cambia larghezza va rifatta, o in mezzo si riapre il buco.
		"id": "Condo", "base": Vector2(-70, 240),
		"label": "SQUATTED CONDO",
		"texture": "res://assets/sprites/buildings/tenement.png",
		"lit": "res://assets/sprites/buildings/tenementLit.png",
		"offset": Vector2(-248, -694), "click": Rect2(-162, -694, 324, 694),
		"entry": Vector2(0, 26),
	},
	{
		# L'agenzia immobiliare, attaccata a casa dall'altra parte. Ci si clicca
		# sopra come su casa, ma invece di entrare in una stanza apre una
		# finestra: e' l'unico edificio della citta' che si comporta cosi', e il
		# campo `"window"` e' quello che lo dice.
		#
		# Sta accanto a casa di proposito: la prima proprieta' in vendita si
		# guarda uscendo di casa, senza doverla cercare. La x e' quella che
		# appoggia il suo muro sinistro al muro destro di casa (424).
		#
		# L'insegna sulla fascia e' quello che la fa riconoscere da fuori: senza
		# scritta e' una palazzina come le altre, e l'unico modo di sapere cos'e'
		# era cliccarci sopra. Vedi `scripts_tools/make_signs.py`.
		"id": "RealEstate", "base": Vector2(584, 240),
		"label": "REAL ESTATE",
		"texture": "res://assets/sprites/buildings/realEstate.png",
		"lit": "res://assets/sprites/buildings/realEstateLit.png",
		"offset": Vector2(-114, -334), "click": Rect2(-114, -334, 227, 334),
		"entry": Vector2(0, 30),
		"sign": "res://assets/sprites/buildings/signs/realEstateSign.png",
		"sign_at": Vector2(-51, -107),
		"window": "res://scenes/ui/RealEstateWindow.tscn",
	},
	{
		# Il garage in vendita. Si entra come in casa, ma solo dopo averlo
		# comprato dall'agenzia: `"owned"` e' quello che lo dice, e finche' non
		# e' proprio il protagonista ci cammina davanti e si ferma.
		#
		# Sta su CROSS STREET, a un isolato da casa: abbastanza vicino da
		# andarci a piedi a vederlo, abbastanza lontano da essere un posto.
		"id": "Garage", "base": Vector2(300, 944),
		"label": "GARAGE",
		"texture": "res://assets/sprites/buildings/garage.png",
		"lit": "res://assets/sprites/buildings/garageLit.png",
		"offset": Vector2(-98, -197), "click": Rect2(-98, -197, 196, 197),
		"entry": Vector2(0, 30),
		"interior": "res://scenes/rooms/Garage.tscn", "owned": true,
	},
	{
		# Il grossista dei semi: il magazzino all'ingrosso dove Brian prende la
		# merce. Primo edificio disegnato di DOWNTOWN — lo costruisce
		# `render_buildings.py` sotto la voce "magazzino".
		#
		# **Compare solo dopo il furgone.** `unlock_flag` è la chiave che lo
		# tiene fuori dalla città finché Brian non lo presenta (vedi `SeedRun` e
		# `GameState._check_milestones()`): prima di allora l'edificio non
		# esiste proprio, invece di stare lì spento a dire che c'è qualcosa che
		# non puoi ancora avere.
		#
		# Sta in DOWNTOWN, fra HILL DRIVE e PORT STREET: è la zona commerciale,
		# ed è lontano da casa abbastanza da giustificare le due ore di viaggio.
		#
		# Il parcheggio sta DIETRO e non è in questo disegno: è il lotto
		# "asphalt" qui sopra in `LOTS`, coi suoi lampioni in `lot_lamps()`.
		# Dentro allo sprite non poteva starci — un lampione disegnato in una
		# texture la sera si spegne insieme al muro (vedi `street_lamp.gd`), e
		# un parcheggio che non si accende di notte è un rettangolo grigio.
		#
		# Non è più fra EAST STREET e HILL DRIVE come col segnaposto, e non è un
		# ripensamento: quell'isolato è largo 640 px fra un marciapiede e
		# l'altro, e l'ingombro del magazzino ne misura 624. Ci stava per otto
		# pixel per parte, cioè non ci stava — il disegno, che è 644 px col
		# parcheggio, sarebbe finito sui due marciapiedi. Questo isolato ne ha
		# 688, e ne restano trentadue per parte.
		"id": "SeedSupplier", "base": Vector2(4712, 240),
		"district": "DOWNTOWN",
		"unlock_flag": SeedRun.UNLOCK_FLAG,
		"label": "SW_NAME",
		"texture": "res://assets/sprites/buildings/wholesale.png",
		"lit": "res://assets/sprites/buildings/wholesaleLit.png",
		# `click` è il costruito e non tutto il PNG: davanti al muro il disegno
		# ha ancora la sua striscia di marciapiede, 17 px, e prendendola dentro
		# all'ingombro il magazzino risulterebbe appoggiato sul marciapiede di
		# MAIN STREET. Su quella striscia ci si cammina sopra.
		"offset": Vector2(-323, -299), "click": Rect2(-318, -299, 636, 282),
		# La porta non è al centro del disegno: a sinistra c'è l'ala bassa, che
		# sposta il corpo alto — e quindi l'ingresso — di 71 px a destra. Senza
		# quei 71 px il protagonista andrebbe a bussare sul muro accanto
		# all'ingresso.
		"entry": Vector2(71, 30),
		# L'insegna sta sulla fascia blu del corpo rialzato. La x non è zero
		# perché il corpo alto non è al centro del disegno: a sinistra c'è
		# l'ala bassa, e il centro della facciata cade 71 px più a destra.
		"sign": "res://assets/sprites/buildings/signs/wholesaleSign.png",
		"sign_at": Vector2(32, -196),
		"window": "res://scenes/ui/SeedWholesaleWindow.tscn",
	},
	{
		# La clinica dove lavora Brian: primo punto di riferimento fuori da THE
		# FLATS, in HILLSIDE. Nessun interno — con Brian ci si vede per strada
		# (`SeedDeal`), qui dentro non si entra mai — quindi resta cliccabile e
		# basta, come quasi tutto il resto della città.
		#
		# Posizione provvisoria: sul lato nord di SOUTH BOULEVARD, fra HILL
		# DRIVE e PORT STREET, nell'isolato libero fra PARK LANE e SOUTH
		# BOULEVARD. Non è un posto scelto per una ragione di storia — va bene
		# qualunque punto libero di HILLSIDE finché il quartiere non ha una
		# pianta sua.
		"id": "Clinic", "base": Vector2(4712, 3520),
		"district": "HILLSIDE",
		"label": "CLINIC",
		"texture": "res://assets/sprites/buildings/clinic.png",
		"lit": "res://assets/sprites/buildings/clinicLit.png",
		"offset": Vector2(-288, -428), "click": Rect2(-288, -428, 576, 428),
		"entry": Vector2(30, 26),
	},
]

# --- Riempimento automatico ------------------------------------------------

## Cambiarlo rimescola tutti gli edifici di sfondo. Fisso, perché la città deve
## essere la stessa a ogni avvio.
const FILL_SEED := 20260909
## Spazio fra due edifici della stessa fila.
##
## Zero, o quasi: in un quartiere popolare vero le case **si toccano**, e il
## muro dell'una è il muro dell'altra.
##
## Prima qui c'era da 16 a 56 px, perché i disegni di allora comprendevano il
## loro lotto con la recinzione e accostarli avrebbe sovrapposto i giardini. Gli
## edifici di schiera costruiti in Blender invece finiscono esatti dove finisce
## il muro — niente sporgenze laterali, il cornicione sporge solo davanti — e
## sono fatti apposta per essere accostati senza spazio in mezzo.
const FILL_GAP := Vector2(0.0, 3.0)
## Di quanto ci si sposta quando in un punto non ci sta niente. Otto px e non
## una tile: la fila deve riprendere appena passato l'ostacolo, non un terzo di
## casa dopo.
const FILL_STEP := 8.0
## Distanza minima da un terreno particolare (prato, piazzale, campo).
const LOT_MARGIN := 12.0

## I quartieri che hanno gli edifici di sfondo. Adesso nessuno: il riempimento
## automatico è spento e in città ci sono solo i punti di riferimento.
##
## Il catalogo di `FILL_ART` c'è ed è pronto — sette tipi costruiti in Blender —
## ma piazzati dal riempimento venivano male: la fila li dispone dove entrano,
## non dove avrebbero senso, e il quartiere si leggeva come una stecca di
## facciate messe in ordine di quanto ci stavano. Restano lì per quando il
## piazzamento sarà deciso a mano o con regole migliori.
##
## La lista è letta sia dai fronti strada (`_frontages()`) sia dai cuori degli
## isolati (`_fill_interior()`): svuotarla li spegne entrambi, che è il motivo
## per cui basta questa riga e il catalogo non va toccato.
const BUILT_DISTRICTS := []

## I disegni con cui si riempie il quartiere: gli stessi otto dei punti di
## riferimento, ripetuti lungo tutti i fronti stradali.
##
## Ripetuti davvero, senza variazioni. È quello che si vuole vedere adesso: come
## regge lo stile quando è tutto quello che c'è, e quanto è fitta la città
## quando le case arrivano a toccarsi. Che a quattro isolati di distanza ci sia
## la stessa casa è un problema del giorno in cui i disegni saranno venti, non
## di oggi.
##
## `size` è la misura del PNG, in pixel. Da lì escono `offset` e `click` (vedi
## `_art_entry()`), che sono sempre gli stessi: origine a terra al centro della
## facciata. È scritta a mano e non letta dall'immagine perché questa è una
## tabella di dati: `CityMap` deve poter dire dov'è un edificio senza caricare
## otto texture.
const FILL_ART := [
	{"texture": "res://assets/sprites/buildings/rowBlock.png", "lit": "res://assets/sprites/buildings/rowBlockLit.png", "size": Vector2(283, 391)},
	{"texture": "res://assets/sprites/buildings/rooming.png", "lit": "res://assets/sprites/buildings/roomingLit.png", "size": Vector2(223, 329)},
	{"texture": "res://assets/sprites/buildings/bodega.png", "lit": "res://assets/sprites/buildings/bodegaLit.png", "size": Vector2(210, 255)},
	{"texture": "res://assets/sprites/buildings/laundry.png", "lit": "res://assets/sprites/buildings/laundryLit.png", "size": Vector2(181, 249)},
	{"texture": "res://assets/sprites/buildings/liquorStore.png", "lit": "res://assets/sprites/buildings/liquorStoreLit.png", "size": Vector2(161, 248)},
	{"texture": "res://assets/sprites/buildings/autoRepair.png", "lit": "res://assets/sprites/buildings/autoRepairLit.png", "size": Vector2(263, 219)},
	{"texture": "res://assets/sprites/buildings/garage.png", "lit": "res://assets/sprites/buildings/garageLit.png", "size": Vector2(196, 197)},
]
## La misura più grande del catalogo, in pixel: dice quanto è profonda la
## striscia di terreno che una fila può occupare, e quindi quali ingombri già
## presi vale la pena di controllare.
##
## **Ricavata da `FILL_ART` e non scritta a mano.** Prima era una costante con
## su scritto "il palazzo, 248 px". Quando il catalogo è cambiato è rimasta
## indietro: la striscia si è trovata più stretta degli edifici che ci
## finivano dentro, due file perpendicolari hanno smesso di vedersi all'angolo
## dell'isolato e si sono sovrapposte. Non dava nessun errore — l'ha trovata il
## test del layout. Un numero che descrive un'altra tabella va ricavato da
## quella tabella, o prima o poi le due si separano.
static var _art_max_depth := -1.0

static func art_max_depth() -> float:
	if _art_max_depth < 0.0:
		var found := 0.0
		for art in FILL_ART:
			var size: Vector2 = art["size"]
			found = maxf(found, maxf(size.x, size.y))
		_art_max_depth = found
	return _art_max_depth

## Tutti gli edifici della città: prima i punti di riferimento scritti a mano,
## poi le file generate lungo i fronti stradali.
##
## L'ordine conta: i punti di riferimento occupano il posto per primi, e il
## riempimento gira intorno a quello che trova già occupato. Così spostare un
## punto di riferimento non richiede di aggiustare niente altro — al massimo si
## sposta anche la casa qualunque che gli stava accanto.
static func all_buildings() -> Array:
	# Gli edifici con un `unlock_flag` non ancora acceso non entrano proprio in
	# città: né disegno, né click, né ostacolo per chi cammina. Vedi la voce
	# `SeedSupplier`.
	var landmarks: Array = []
	for entry: Dictionary in BUILDINGS:
		var flag := str(entry.get("unlock_flag", ""))
		if flag.is_empty() or _flag_on(flag):
			landmarks.append(entry)
	var taken: Array[Rect2] = []
	for entry in landmarks:
		taken.append(footprint(entry))
	for lot in LOTS:
		taken.append((lot["rect"] as Rect2).grow(LOT_MARGIN))

	var rng := RandomNumberGenerator.new()
	rng.seed = FILL_SEED
	# Prima tutte le file affacciate sulle strade, poi i cuori degli isolati:
	# quello che si vede camminando ha la precedenza sul fondale, e non il
	# contrario. Girato, un fondale piazzato per primo si prenderebbe il posto
	# di una casa che dà sulla strada e lascerebbe un vuoto sul marciapiede.
	var filler: Array = []
	for frontage in _frontages():
		filler.append_array(_fill_frontage(frontage, taken, rng, filler.size()))
	for district in DISTRICTS:
		if not str(district["id"]) in BUILT_DISTRICTS:
			continue
		for block: Rect2 in _blocks(district):
			filler.append_array(_fill_interior(block, taken, rng, filler.size()))
	return landmarks + filler

## Ingombro a terra di una voce, in coordinate mondo: origine a terra al centro
## della facciata, corpo verso l'alto.
static func footprint(entry: Dictionary) -> Rect2:
	var base: Vector2 = entry["base"]
	if entry.has("size"):
		var size: Vector2 = entry["size"]
		return Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y)
	var click: Rect2 = entry.get("click", Rect2(-64, -128, 128, 128))
	return Rect2(base + click.position, click.size)

## Una voce di edificio bell'e pronta, a partire da un disegno del catalogo.
##
## `offset` e `click` non sono dati del disegno ma la regola di tutta la mappa —
## origine a terra al centro della facciata, corpo verso l'alto — applicata alla
## sua misura. Nei punti di riferimento sono scritti per esteso solo perché lì
## li stampa lo script di importazione.
static func _art_entry(art: Dictionary, id: String, base: Vector2, side: String) -> Dictionary:
	var size: Vector2 = art["size"]
	var box := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	var entry := {
		"id": id,
		"base": base,
		"size": size,
		"front": side,
		"texture": str(art["texture"]),
		"offset": box.position,
		"click": box,
	}
	# Anche gli edifici di sfondo hanno le finestre accese: sono quelli che si
	# vedono da lontano, ed è da lontano che una città di notte si legge per le
	# sue luci.
	if art.has("lit"):
		entry["lit"] = str(art["lit"])
	return entry

## Un fronte stradale da riempire: una fila di edifici affacciati sulla stessa
## strada, dentro allo stesso quartiere.
##
## Vengono ricavati dal reticolo invece di essere elencati: cambiano tutti se si
## sposta una strada, e riscriverli a mano ogni volta sarebbe l'unico modo
## garantito di sbagliarne qualcuno.
##
## Ci sono anche i fronti sulle strade **verticali**: senza, i blocchi
## risultano costruiti solo sopra e sotto e con le fiancate vuote, e da lontano
## la città si legge come una serie di righe invece che di isolati.
static func _frontages() -> Array:
	var list: Array = []
	for road: Rect2 in ROADS_H:
		for district in DISTRICTS:
			if not str(district["id"]) in BUILT_DISTRICTS:
				continue
			var rect: Rect2 = district["rect"]
			for side in ["north", "south"]:
				var at := road.position.y - SIDEWALK_DEPTH if side == "north" \
					else road.end.y + SIDEWALK_DEPTH
				# Il fronte deve cadere dentro al quartiere: una strada che
				# passa fra due quartieri ha un fronte per ciascuno, non due
				# per uno.
				if at <= rect.position.y or at >= rect.end.y:
					continue
				list.append({
					"district": district, "at": at, "side": side, "vertical": false,
					"from": rect.position.x + SIDEWALK_DEPTH,
					"to": rect.end.x - SIDEWALK_DEPTH,
				})
	for road: Rect2 in ROADS_V:
		for district in DISTRICTS:
			if not str(district["id"]) in BUILT_DISTRICTS:
				continue
			var rect: Rect2 = district["rect"]
			for side in ["west", "east"]:
				var at := road.position.x - SIDEWALK_DEPTH if side == "west" \
					else road.end.x + SIDEWALK_DEPTH
				if at <= rect.position.x or at >= rect.end.x:
					continue
				list.append({
					"district": district, "at": at, "side": side, "vertical": true,
					"from": rect.position.y + SIDEWALK_DEPTH,
					"to": rect.end.y - SIDEWALK_DEPTH,
				})
	return list

## Riempie un fronte, avanzando lungo la strada e piazzando un edificio dove
## c'è posto.
##
## In ogni punto si prova **tutto il catalogo** in ordine sparso e vince il
## primo che ci sta. Provarne uno solo — com'era quando gli edifici erano
## rettangoli di misura sorteggiata — lascerebbe un buco ogni volta che il
## sorteggio pesca il palazzo da 248 px davanti a uno spiazzo da 200: con otto
## misure fisse quei buchi sarebbero la regola, e la fila fitta non verrebbe
## mai.
##
## Uno slot occupato non interrompe la fila: si scivola avanti di qualche pixel
## e si riprova. Altrimenti un solo punto di riferimento in mezzo a un isolato
## lascerebbe vuoto tutto quello che viene dopo.
static func _fill_frontage(frontage: Dictionary, taken: Array[Rect2], rng: RandomNumberGenerator, offset: int) -> Array:
	var district: Dictionary = frontage["district"]
	var bounds: Rect2 = district["rect"]
	var side: String = frontage["side"]
	var vertical: bool = frontage["vertical"]
	var at: float = frontage["at"]
	var along: float = frontage["from"]
	var limit: float = frontage["to"]

	# Gli ingombri che possono dare fastidio a QUESTA fila: quelli dentro alla
	# striscia di terreno che occupa. Controllarli tutti vorrebbe dire, a ogni
	# passo da otto pixel di ogni fila, un giro su qualche centinaio di
	# rettangoli che stanno a mezza mappa di distanza.
	var band := _frontage_band(at, side, vertical, along, limit)
	var near: Array[Rect2] = []
	for rect in taken:
		if rect.intersects(band):
			near.append(rect)

	var order := _art_order(rng)
	var result: Array = []
	while along < limit:
		var placed := false
		for index: int in order:
			var art: Dictionary = FILL_ART[index]
			var size: Vector2 = art["size"]
			# Lungo una strada verticale è l'altezza a scorrere: due edifici
			# affiancati in verticale si toccano per l'altezza, non per la base.
			var span := size.y if vertical else size.x
			if along + span > limit:
				continue

			var base: Vector2
			if vertical:
				# La facciata tocca il marciapiede: a ovest della strada
				# l'edificio sta alla sua sinistra, a est alla sua destra.
				var center_x := at - size.x * 0.5 if side == "west" else at + size.x * 0.5
				base = Vector2(center_x, along + size.y)
			else:
				base = Vector2(along + size.x * 0.5, at if side == "north" else at + size.y)
			var rect := Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y)

			# Un edificio non deve uscire dal suo quartiere né finire sopra a
			# una strada, a un terreno particolare o a un altro edificio.
			if not bounds.encloses(rect) or _on_road(rect) or not _is_free(rect, near):
				continue
			taken.append(rect)
			near.append(rect)
			result.append(_art_entry(
				art, "Fill%d_%d" % [offset, result.size()], base, side))
			along += span + rng.randf_range(FILL_GAP.x, FILL_GAP.y)
			placed = true
			break
		if placed:
			# L'ordine si rimescola dopo ogni edificio e non a ogni passo:
			# rimescolarlo anche quando non si è piazzato niente vorrebbe dire
			# qualche migliaio di giri buttati via per fila.
			order = _art_order(rng)
		else:
			along += FILL_STEP
	return result

## Riempie il cuore di un isolato: tutto quello che resta libero dopo le file
## affacciate sulle strade.
##
## Senza questo passaggio il quartiere è una corona di case intorno a un buco:
## le strade sono costruite e dentro agli isolati c'è il vuoto. In una città
## vera dentro a un isolato c'è un altro isolato — cortili chiusi, retri,
## baracche, case che danno le spalle a quelle davanti — ed è quello che si
## vede da lontano, perché un tetto dietro a un altro tetto è quello che
## distingue una città da una fila di casette.
##
## Sono **fondali** (`backdrop`): non si clicca, non si entra, e non hanno una
## porta. Non per pigrizia — non ce l'hanno perché non ce l'avrebbero: sono
## murati dietro alla fila che dà sulla strada, e una porta che si affaccia sul
## muro di un altro edificio non è una porta. Chi cammina li vede e basta. È
## anche il motivo per cui il controllo "da casa si arriva a ogni edificio" li
## salta: non c'è dove arrivare.
##
## Si procede per righe, dall'alto in basso: ogni riga si appoggia col bordo di
## sopra a quella prima. Le altezze sono diverse, quindi le basi vengono
## sfalsate e l'Y-sort le mette in ordine da sé.
static func _fill_interior(block: Rect2, taken: Array[Rect2], rng: RandomNumberGenerator, offset: int) -> Array:
	var near: Array[Rect2] = []
	for rect in taken:
		if rect.intersects(block):
			near.append(rect)

	var order := _art_order(rng)
	var result: Array = []
	var y := block.position.y
	while y < block.end.y:
		# La riga dopo si appoggia all'edificio più BASSO di questa, non al più
		# alto: gli otto disegni vanno da 88 a 248 px, e scendere sempre di 248
		# lascerebbe una fascia di terreno morto sotto a ogni casa bassa. Chi
		# non ci sta perché sopra c'è ancora il vicino alto viene scartato dal
		# controllo di sovrapposizione e scivola avanti da sé — che è il motivo
		# per cui si può essere ottimisti qui.
		var shortest := 0.0
		var x := block.position.x
		while x < block.end.x:
			var placed := false
			for index: int in order:
				var art: Dictionary = FILL_ART[index]
				var size: Vector2 = art["size"]
				if x + size.x > block.end.x or y + size.y > block.end.y:
					continue
				var rect := Rect2(x, y, size.x, size.y)
				if not _is_free(rect, near):
					continue
				taken.append(rect)
				near.append(rect)
				var entry := _art_entry(
					art, "Back%d_%d" % [offset, result.size()],
					Vector2(x + size.x * 0.5, y + size.y), "north")
				entry["backdrop"] = true
				result.append(entry)
				x += size.x + rng.randf_range(FILL_GAP.x, FILL_GAP.y)
				shortest = size.y if shortest == 0.0 else minf(shortest, size.y)
				placed = true
				order = _art_order(rng)
				break
			if not placed:
				x += FILL_STEP
		# Una riga in cui non è entrato niente è terreno già occupato dalla fila
		# che dà sulla strada: si scende di una tile invece che di otto px, o si
		# rifarebbe la stessa scansione a vuoto trenta volte.
		y += (shortest + rng.randf_range(FILL_GAP.x, FILL_GAP.y)) if shortest > 0.0 else TILE
	return result

## I blocchi di terreno di un quartiere: quello che resta fra una strada e
## l'altra, marciapiedi esclusi.
##
## Ricavati dalle strade come tutto il resto: un isolato scritto a mano
## smetterebbe di combaciare col reticolo alla prima strada spostata, e il
## risultato sarebbe una fila di case in mezzo alla carreggiata.
static func _blocks(district: Dictionary) -> Array:
	var rect: Rect2 = district["rect"]
	var list: Array = []
	for span_x: Vector2 in _gaps(ROADS_V, rect.position.x, rect.end.x, false):
		for span_y: Vector2 in _gaps(ROADS_H, rect.position.y, rect.end.y, true):
			list.append(Rect2(
				span_x.x, span_y.x, span_x.y - span_x.x, span_y.y - span_y.x))
	return list

## Gli intervalli liberi fra `from` e `to` una volta tolte le strade (e i loro
## marciapiedi) che li attraversano.
static func _gaps(roads: Array, from: float, to: float, horizontal: bool) -> Array:
	var cuts: Array = []
	for road: Rect2 in roads:
		var band := road.grow(SIDEWALK_DEPTH)
		var a := band.position.y if horizontal else band.position.x
		var b := band.end.y if horizontal else band.end.x
		if b > from and a < to:
			cuts.append(Vector2(a, b))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var list: Array = []
	var at := from
	for cut: Vector2 in cuts:
		if cut.x > at:
			list.append(Vector2(at, cut.x))
		at = maxf(at, cut.y)
	if to > at:
		list.append(Vector2(at, to))
	return list

## La striscia di terreno in cui può finire qualcosa di questa fila: lunga
## quanto il fronte, profonda quanto il disegno più alto del catalogo.
static func _frontage_band(at: float, side: String, vertical: bool, from: float, to: float) -> Rect2:
	var length := to - from
	var depth := art_max_depth()
	if vertical:
		if side == "west":
			return Rect2(at - depth, from, depth, length)
		return Rect2(at, from, depth, length)
	if side == "north":
		return Rect2(from, at - depth, length, depth)
	return Rect2(from, at, length, depth)

## Gli indici del catalogo in ordine sparso.
static func _art_order(rng: RandomNumberGenerator) -> Array:
	var order: Array = []
	for i in FILL_ART.size():
		order.append(i)
	# Rimescolata a mano: `Array.shuffle()` usa il generatore globale, e la
	# città deve venire uguale a ogni avvio.
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	return order

## Vero se il rettangolo tocca l'asfalto di una strada o il suo marciapiede.
static func _on_road(rect: Rect2) -> bool:
	for road: Rect2 in ROADS_H:
		if rect.intersects(road.grow(SIDEWALK_DEPTH)):
			return true
	for road: Rect2 in ROADS_V:
		if rect.intersects(road.grow(SIDEWALK_DEPTH)):
			return true
	return false

static func _is_free(rect: Rect2, taken: Array[Rect2]) -> bool:
	for other in taken:
		if rect.intersects(other):
			return false
	return true

# --- Alberi ----------------------------------------------------------------

## Alberi segnaposto sparsi nei prati, disegnati sul piano del terreno come il
## campo da football: il giocatore ci cammina sopra. Quando diventeranno sprite
## andranno spostati fra i nodi Y-sortati.
##
## Sono generati dai prati e non elencati: un prato spostato si riporta dietro
## i suoi alberi, e non restano alberi a mezz'aria in mezzo alla strada.
static func trees() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = FILL_SEED + 1
	var list: Array = []
	for lot in LOTS:
		if str(lot["kind"]) != "lawn":
			continue
		var rect: Rect2 = (lot["rect"] as Rect2).grow(-40.0)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		# Un albero ogni 12000 px2 circa: abbastanza per leggere "parco", non
		# tanti da diventare un bosco impenetrabile.
		var count := clampi(int(rect.get_area() / 12000.0), 2, 14)
		for i in count:
			list.append(rect.position + Vector2(
				rng.randf() * rect.size.x, rng.randf() * rect.size.y))
	return list

# --- Lampioni --------------------------------------------------------------

## Passo fra un lampione e l'altro lungo la stessa strada.
##
## A 384 px (dodici tile) le pozze di luce restano staccate una dall'altra
## invece di fondersi in una striscia continua: è quello che fa leggere la
## strada di notte come una fila di luci e non come un corridoio illuminato.
const LAMP_SPACING := 384.0
## Quanto sta il palo dentro al marciapiede, misurato dal bordo dell'asfalto.
## Sul cordolo esatto verrebbe investito dalle auto, che passano a 24 px.
const LAMP_CURB := 12.0

## Tutti i lampioni della città, ricavati dalle strade.
##
## Generati e non elencati, per lo stesso motivo delle corsie del traffico: un
## lampione scritto a mano che non combacia con la sua strada si vede come una
## luce in mezzo al prato, e con undici strade prima o poi succede.
##
## I lati si alternano lungo la strada — uno a nord, il prossimo a sud — invece
## di stare in fila su un lato solo: è come sono messi davvero, costa la metà
## dei nodi e illumina lo stesso la carreggiata da entrambe le parti.
##
## Niente lampioni dentro agli incroci: lì la luce arriva dai quattro angoli, e
## un palo in mezzo alla piazzola sarebbe in mezzo alla strada.
static func street_lamps() -> Array:
	var list: Array = []
	for index in ROADS_H.size():
		var road: Rect2 = ROADS_H[index]
		var x := road.position.x + LAMP_SPACING * 0.5
		var flip := index % 2 == 0
		while x < road.end.x:
			if not _crosses(ROADS_V, Vector2(x, road.get_center().y)):
				var y := road.position.y - LAMP_CURB if flip else road.end.y + LAMP_CURB
				# Il braccio sporge verso la carreggiata, quindi la pozza di
				# luce cade sull'asfalto e non sul marciapiede dietro.
				list.append({"pos": Vector2(x, y), "reach": Vector2(0, 1 if flip else -1)})
			flip = not flip
			x += LAMP_SPACING
	for index in ROADS_V.size():
		var road: Rect2 = ROADS_V[index]
		var y := road.position.y + LAMP_SPACING * 0.5
		var flip := index % 2 == 0
		while y < road.end.y:
			if not _crosses(ROADS_H, Vector2(road.get_center().x, y)):
				var x := road.position.x - LAMP_CURB if flip else road.end.x + LAMP_CURB
				list.append({"pos": Vector2(x, y), "reach": Vector2(1 if flip else -1, 0)})
			flip = not flip
			y += LAMP_SPACING
	return list

## I lampioni dei piazzali: una fila per ogni lotto asfaltato.
##
## Generati dal lotto e non elencati a mano, come gli alberi dai prati: se il
## parcheggio si sposta o si allarga, i pali ci vanno dietro invece di restare
## in mezzo al terreno dove il parcheggio stava prima.
##
## Stanno nella parte ALTA del piazzale, che è l'unica che si vede: il resto è
## dietro all'edificio. Il braccio guarda in basso, verso la fila di posti, così
## la pozza di luce cade sull'asfalto che si vede e non su quello nascosto.
static func lot_lamps() -> Array:
	var list: Array = []
	for lot in LOTS:
		if str(lot["kind"]) != "asphalt":
			continue
		var rect: Rect2 = lot["rect"]
		var y := rect.position.y + LOT_LAMP_INSET
		var quanti := int(floorf(rect.size.x / LOT_LAMP_SPACING))
		if quanti < 1:
			continue
		var passo := rect.size.x / float(quanti + 1)
		for i in range(1, quanti + 1):
			list.append({
				"pos": Vector2(rect.position.x + passo * float(i), y),
				"reach": Vector2(0, 1),
			})
	return list

# --- Le strutture del campo da football ------------------------------------

## Le misure dei tre PNG, in pixel. Da qui esce lo scostamento: come per gli
## edifici, l'origine è il punto a terra al centro della facciata.
const FIELD_ART := {
	"terrace": Vector2(675, 124),
	"floodlight": Vector2(74, 356),
	"goal": Vector2(201, 63),
}

## Gradinata, torre faro e le due porte sfondate.
##
## **Non sono edifici e non stanno in `BUILDINGS`.** Non ci si clicca, non ci si
## entra e non hanno un nome da mostrare: hanno solo bisogno di essere
## Y-sortate, perché sono alte e il protagonista ci deve poter passare davanti e
## dietro. È esattamente il caso dei lampioni, e ci passano dalla stessa porta —
## `city.gd` le appende a `Props`.
##
## Le posizioni sono **relative al lotto**, non scritte a mano: spostando o
## allargando il campo in `LOTS` si sposta tutto insieme, invece di ritrovarsi la
## torre faro in mezzo alla strada e le porte fuori dal terreno di gioco.
##
## L'erba non è qui perché non è un PNG: la disegna `grass_field.gdshader`.
static func field_props() -> Array:
	var list: Array = []
	for lot in LOTS:
		if str(lot["kind"]) != "football":
			continue
		var rect: Rect2 = lot["rect"]
		var cx := rect.get_center().x
		# La gradinata poggia appena dentro al bordo alto: da lì il suo corpo
		# sale verso il marciapiede senza arrivarci.
		list.append(_field_prop("terrace", Vector2(cx, rect.position.y + 6.0)))
		# La torre faro all'angolo di nord-est, dentro al recinto. È alta sedici
		# metri: il fusto finisce disegnato sopra a MAIN STREET, ed è giusto
		# così — sta davanti alla strada, non sopra.
		list.append(_field_prop(
			"floodlight", Vector2(rect.end.x - 44.0, rect.position.y + 20.0)))
		# Le due porte, in mezzo ai lati corti visti di fronte. Guardano
		# entrambe la camera: una porta messa di taglio sarebbe due pali.
		list.append(_field_prop("goal", Vector2(cx, rect.position.y + 46.0)))
		list.append(_field_prop("goal", Vector2(cx, rect.end.y - 12.0)))
	return list

static func _field_prop(nome: String, pos: Vector2) -> Dictionary:
	var size: Vector2 = FIELD_ART[nome]
	return {
		"texture": "res://assets/sprites/buildings/%s.png" % nome,
		"offset": Vector2(-size.x * 0.5, -size.y),
		"pos": pos,
	}

## Il flag della partita in corso è acceso? Senza partita — la mappa aperta
## dall'editor — si risponde di sì: una città a cui mancano metà edifici sarebbe
## una città rotta da guardare.
static func _flag_on(flag: String) -> bool:
	var data := GameState.current
	return data == null or bool(data.get_flag(flag, false))

## Se un punto cade dentro a una delle strade date. Serve a saltare gli incroci.
static func _crosses(roads: Array, point: Vector2) -> bool:
	for road: Rect2 in roads:
		if road.has_point(point):
			return true
	return false

# --- Traffico --------------------------------------------------------------

## Due corsie per strada, ricavate dalle strade stesse.
##
## Non sono una tabella a parte di proposito: una corsia scritta a mano che non
## combacia col suo asfalto si vede come un'auto che viaggia sul marciapiede, e
## con undici strade prima o poi succede.
##
## Le corsie seguono la guida a destra: su una strada orizzontale chi va verso
## est sta nella corsia più in basso, su una verticale chi va verso sud sta in
## quella più a ovest.
static func lanes() -> Array:
	var list: Array = []
	for index in ROADS_H.size():
		var road: Rect2 = ROADS_H[index]
		list.append(_lane("h", road.end.y - 24.0, 1, road.position.x, road.end.x, index))
		list.append(_lane("h", road.position.y + 24.0, -1, road.position.x, road.end.x, index + 7))
	for index in ROADS_V.size():
		var road: Rect2 = ROADS_V[index]
		list.append(_lane("v", road.position.x + 24.0, 1, road.position.y, road.end.y, index + 13))
		list.append(_lane("v", road.end.x - 24.0, -1, road.position.y, road.end.y, index + 19))
	return list

static func _lane(axis: String, pos: float, direction: int, from: float, to: float, index: int) -> Dictionary:
	var length := to - from
	return {
		"axis": axis,
		"pos": pos,
		"dir": direction,
		# Un margine oltre gli estremi, così le auto entrano ed escono dal
		# campo invece di comparire sul bordo.
		"from": from - 68.0,
		"to": to + 68.0,
		"cars": clampi(int(length / 1100.0), 2, 6),
		# Velocità diverse per corsia: tutte uguali si muovono come un trenino.
		"speed": 52.0 + float(index % 5) * 5.0,
	}

# --- Comodità --------------------------------------------------------------

## Quartiere che contiene un punto, "" se il punto è in mezzo a una strada.
static func district_at(point: Vector2) -> String:
	for district in DISTRICTS:
		if (district["rect"] as Rect2).has_point(point):
			return str(district["name"])
	return ""

## Punto in cui si va a finire uscendo di casa: il marciapiede davanti alla
## casa iniziale. È anche la posizione di partenza di una partita nuova.
static func home_doorstep() -> Vector2:
	return Vector2(320, 264)

## Dove sta il furgone dell'ingrosso quando non e' in viaggio: nel vialetto a
## fianco della casa iniziale, col muso verso la strada.
##
## Un mezzo comprato per cinquemila dollari deve **vedersi**. Finche' stava solo
## dentro all'animazione della partenza, chi lo comprava dal PC in cantina non
## lo vedeva mai: usciva di casa e la strada era identica a prima. Parcheggiato
## li' invece la spesa ha una faccia, e si capisce a colpo d'occhio se il
## furgone e' fermo o fuori con un carico.
##
## **In sosta sta a casa, non in strada.** Al bordo dell'asfalto sembrava
## un'auto del traffico che si era fermata li': un mezzo di proprieta' sta nel
## vialetto, e il vialetto e' la striscia fra la casa e il palazzo a fianco. Il
## muso verso la carreggiata (`VAN_PARK_ANGLE`) e' quello che lo dice a colpo
## d'occhio — e' fermo ma pronto a uscire, non parcheggiato di traverso.
##
## Il punto e' a lato della porta e non davanti: lo zerbino (`home_doorstep()`)
## e' dove si esce e dove Brian a volte aspetta, e un furgone in mezzo
## sembrerebbe un ostacolo.
static func van_parking() -> Vector2:
	return Vector2(home_doorstep().x + -115.0, SIDEWALK_N[0] - 110.0)

## Di quanto e' girato lo sprite in sosta. Mezzo giro a destra rispetto al muso
## verso est con cui e' disegnato: cioe' rivolto a sud, verso la strada.
const VAN_PARK_ANGLE := PI * 0.5

# --- Punti d'incontro ------------------------------------------------------

## Quanto lontano da casa può dare appuntamento Brian: uno o due isolati.
##
## Il minimo conta quanto il massimo. Sotto i 220 px l'appuntamento cadrebbe
## sul marciapiede di casa, e "esci ed è già lì" non è un incontro: è un
## bottone con qualche secondo di attesa davanti.
const MEET_MIN_DISTANCE := 220.0
const MEET_MAX_DISTANCE := 900.0
## Passo con cui si campionano i marciapiedi in cerca di posti buoni. A 64 px i
## punti restano distinguibili fra loro: a 32 due appuntamenti diversi
## finirebbero a un passo l'uno dall'altro e sembrerebbero lo stesso posto.
const MEET_STEP := TILE * 2.0
## Oltre questa distanza un'insegna non serve più a dire dove si è.
const MEET_SIGN_RANGE := 150.0
## Entro questa distanza dall'asse di una strada si è "all'incrocio"; oltre, si
## è a nord, a sud, a est o a ovest di quella. Novantasei px sono tre tile: la
## larghezza di una carreggiata, cioè quanto basta per vedere l'incrocio da dove
## si è.
const MEET_CROSS_RANGE := 96.0

## Quanto deve restare libero intorno a un punto d'incontro.
##
## Non basta che il punto sia fuori dai muri: la griglia dei percorsi si tiene
## un margine dagli edifici e lavora a celle da 16 px, quindi un punto a filo di
## una facciata cade su una cella che la griglia considera piena. Succede su
## tutta la quota dei marciapiedi a SUD di una strada, dove gli edifici hanno il
## corpo che sale fino a toccarli: ci si passa, ma non ci si può stare.
##
## Il numero è più largo di quel margine più una cella. È scritto qui e non
## preso da `CityNavigation` perché la pianta non deve dipendere da chi ci
## cammina sopra; a tenere i due d'accordo c'è il controllo automatico
## "ogni posto è calpestabile", che fallisce se si allontanano.
const MEET_CLEARANCE := 28.0

## I posti in cui Brian può dare appuntamento: punti di marciapiede a uno o due
## isolati da casa.
##
## Sono RICAVATI dal reticolo e non elencati a mano, per lo stesso motivo degli
## edifici di riempimento: un elenco scritto a mano smetterebbe di combaciare
## alla prima strada spostata, e un appuntamento finito in mezzo alla
## carreggiata si scoprirebbe solo andandoci.
static func meet_spots() -> Array:
	var home := home_doorstep()
	# Gli ingombri servono a scartare i punti a filo di una facciata, e vanno
	# presi da `all_buildings()` e non da `BUILDINGS`: intorno a casa la maggior
	# parte di quello che c'è è riempimento generato, ed è proprio quello che
	# occupa i fronti stradali.
	var solid: Array[Rect2] = []
	for entry in all_buildings():
		solid.append(footprint(entry).grow(MEET_CLEARANCE))

	var spots: Array = []
	for i in ROADS_H.size():
		for side: float in [SIDEWALK_N[i], SIDEWALK_S[i]]:
			if absf(side - home.y) <= MEET_MAX_DISTANCE:
				_scan_meet_line(spots, home, true, side, solid)
	for i in ROADS_V.size():
		for side: float in [SIDEWALK_W[i], SIDEWALK_E[i]]:
			if absf(side - home.x) <= MEET_MAX_DISTANCE:
				_scan_meet_line(spots, home, false, side, solid)
	return spots

## Percorre un marciapiede nel raggio utile e tiene i punti buoni. `horizontal`
## dice se la quota fissa è la y (marciapiede di una strada orizzontale) o la x.
static func _scan_meet_line(
		spots: Array, home: Vector2, horizontal: bool, fixed: float,
		solid: Array[Rect2]) -> void:
	var center := home.x if horizontal else home.y
	var to := center + MEET_MAX_DISTANCE
	var at := floorf((center - MEET_MAX_DISTANCE) / MEET_STEP) * MEET_STEP
	while at <= to:
		var point := Vector2(at, fixed) if horizontal else Vector2(fixed, at)
		at += MEET_STEP
		var distance := point.distance_to(home)
		if distance < MEET_MIN_DISTANCE or distance > MEET_MAX_DISTANCE:
			continue
		if not WORLD_BOUNDS.has_point(point):
			continue
		# Agli incroci il marciapiede di una strada finisce sull'asfalto di
		# quella perpendicolare: lì l'appuntamento sarebbe in carreggiata.
		if _on_asphalt(point):
			continue
		if _too_close_to_building(point, solid):
			continue
		spots.append(point)

static func _too_close_to_building(point: Vector2, solid: Array[Rect2]) -> bool:
	for rect in solid:
		if rect.has_point(point):
			return true
	return false

static func _on_asphalt(point: Vector2) -> bool:
	for road: Rect2 in ROADS_H:
		if road.has_point(point):
			return true
	for road: Rect2 in ROADS_V:
		if road.has_point(point):
			return true
	return false

## Come si chiama, a parole, il posto in cui si dà appuntamento.
##
## Una coppia di coordinate non dice niente a nessuno: il nome esce dalla
## strada su cui cade il punto più l'insegna del punto di riferimento più
## vicino ("MAIN STREET BY THE LAUNDROMAT"). Ricavato e non scritto a mano,
## così resta giusto anche se l'edificio si sposta.
##
## Senza punteggiatura di proposito: solo lettere e spazi si possono scrivere
## anche col font del gioco, che di cifre e virgole non ne ha.
## Come si dice a voce dove ci si vede.
##
## ## Un nome che non aiuta a trovare il posto è peggio di nessun nome
##
## La prima versione diceva solo strada + insegna più vicina entro 320 px, e
## sbagliava in due modi che si vedevano solo giocando:
##
## 1. **L'insegna poteva stare su un'altra strada.** Un appuntamento a
##    (736, -64), su MILL ROAD, veniva annunciato "BY THE LAUNDROMAT" perché la
##    lavanderia era a 314 px — ma la lavanderia sta su MAIN STREET, tre isolati
##    più in basso. Chi ci andava si trovava davanti alla lavanderia con Brian
##    fuori schermo, e non aveva nessun motivo di sospettare di essere nel posto
##    sbagliato: il gioco gli aveva detto proprio quello.
## 2. **Lo stesso nome copriva posti diversi.** Ventisei posti d'incontro
##    finivano in undici nomi, e uno solo ne copriva sette, distanti fra loro
##    fino a 286 px.
##
## Adesso l'insegna si usa solo se è **vicina davvero** (`MEET_SIGN_RANGE`) e
## **sulla stessa strada** del punto. Quando non ce n'è una, si dà l'incrocio col
## verso — "MILL ROAD NORTH OF MAIN STREET" — che in una città a reticolo è un
## indirizzo vero e c'è sempre.
##
## I nomi restano in inglese come le insegne degli edifici: è una cittadina
## americana inventata, e "MILL ROAD a nord di MAIN STREET" la sposterebbe
## altrove. Vedi la nota in cima a `strings.gd`.
static func place_name(point: Vector2) -> String:
	var here := street_of(point)
	var street: String = here["name"]
	var sign_name := _nearest_sign(point, street)
	if not sign_name.is_empty():
		# Un'insegna che comincia già per "THE" l'articolo ce l'ha: senza questo
		# si ottiene "BY THE THE PROJECTS".
		var by := "BY %s" % sign_name if sign_name.begins_with("THE ") else "BY THE %s" % sign_name
		return by if street.is_empty() else "%s %s" % [street, by]

	if street.is_empty():
		return "THE FLATS"
	var cross := _cross_reference(point, bool(here["vertical"]))
	return street if cross.is_empty() else "%s %s" % [street, cross]

## Nome della strada su cui cade un punto, contando anche i marciapiedi.
## "" se il punto è lontano da qualsiasi strada.
static func street_at(point: Vector2) -> String:
	return str(street_of(point)["name"])

## La strada su cui cade un punto, e se è una di quelle verticali.
##
## Restituisce le due cose insieme perché a chi deve dare un indirizzo servono
## tutte e due: l'incrocio da nominare è su una strada **perpendicolare**, e per
## sapere quali sono bisogna sapere com'è messa questa.
static func street_of(point: Vector2) -> Dictionary:
	for i in ROADS_H.size():
		if (ROADS_H[i] as Rect2).grow(SIDEWALK_DEPTH).has_point(point):
			return {"name": str(ROAD_NAMES_H[i]), "vertical": false, "index": i}
	for i in ROADS_V.size():
		if (ROADS_V[i] as Rect2).grow(SIDEWALK_DEPTH).has_point(point):
			return {"name": str(ROAD_NAMES_V[i]), "vertical": true, "index": i}
	return {"name": "", "vertical": false, "index": -1}

## Insegna del punto di riferimento più vicino, "" se non ce n'è una che serva.
##
## Due filtri, e il secondo conta quanto il primo:
##
## - **Solo i punti di riferimento** di `BUILDINGS`, non tutti gli edifici:
##   quelli generati hanno insegne generiche pescate a caso dal quartiere, e
##   "BY THE HOUSE" non dice a nessuno dove andare. Per la stessa ragione le
##   insegne che compaiono anche nel pool di un quartiere non valgono: ce n'è
##   più d'una in città, e mandano alla copia sbagliata.
## - **Solo sulla stessa strada**: un'insegna vicina in linea d'aria ma affacciata
##   su un'altra via manda dall'altra parte di un isolato. Vedi sopra.
static func _nearest_sign(point: Vector2, street: String) -> String:
	var best := ""
	var best_distance := MEET_SIGN_RANGE
	for entry: Dictionary in BUILDINGS:
		if not entry.has("label"):
			continue
		var base: Vector2 = entry["base"]
		var distance := base.distance_to(point)
		if distance >= best_distance:
			continue
		if street_at(base) != street:
			continue
		var label := str(entry["label"])
		if _is_generic(label):
			continue
		best_distance = distance
		best = label
	return best

## Se questa insegna è una di quelle generiche del quartiere, e quindi in città
## di posti così ce n'è più d'uno.
##
## Adesso che gli edifici di sfondo sono gli stessi otto disegni ripetuti la
## cosa è ancora più vera di prima: di negozietti uguali agli alimentari il
## quartiere ne ha una ventina, e mandare qualcuno "al CORNER STORE" vorrebbe
## dire mandarlo a uno qualsiasi. Un quartiere senza `names` non ha edifici, e
## quindi non ha nemmeno insegne da sconsigliare.
static func _is_generic(label: String) -> bool:
	for district: Dictionary in DISTRICTS:
		if label in (district.get("names", []) as Array):
			return true
	return false

## L'incrocio più vicino, col verso: "AT MAIN STREET", "NORTH OF CROSS STREET".
##
## Il verso non è un vezzo: fra due incroci ci sono settecento pixel, e senza
## sapere da che parte dell'incrocio si è, metà delle volte si cammina nella
## direzione sbagliata.
static func _cross_reference(point: Vector2, on_vertical: bool) -> String:
	var roads: Array = ROADS_H if on_vertical else ROADS_V
	var names: Array = ROAD_NAMES_H if on_vertical else ROAD_NAMES_V
	var value := point.y if on_vertical else point.x
	var best := -1
	var best_distance := INF
	for i in roads.size():
		var centre: float = (roads[i] as Rect2).get_center().y if on_vertical else (roads[i] as Rect2).get_center().x
		var distance := absf(value - centre)
		if distance < best_distance:
			best_distance = distance
			best = i
	if best < 0:
		return ""

	var name: String = str(names[best])
	if best_distance <= MEET_CROSS_RANGE:
		return "AT %s" % name
	var centre: float = (roads[best] as Rect2).get_center().y if on_vertical else (roads[best] as Rect2).get_center().x
	if on_vertical:
		return "%s OF %s" % ["NORTH" if value < centre else "SOUTH", name]
	return "%s OF %s" % ["WEST" if value < centre else "EAST", name]
