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
## ruolo o una posizione che conta (la casa iniziale, la clinica dove sta Milo,
## il municipio, la fabbrica). Sono scritti a mano, uno per uno.
##
## Tutto il resto — le file di case e capannoni qualunque che riempiono i
## blocchi — lo genera `all_buildings()` percorrendo i fronti stradali. Con una
## città di questa dimensione servono circa duecento edifici di sfondo: scritti
## a mano non si rileggerebbero e non si sposterebbero più, e ogni ritocco al
## reticolo vorrebbe dire rifarli tutti. Generandoli, spostare una strada
## risistema il quartiere da sé.
##
## La generazione è **deterministica** (`FILL_SEED`): la città è identica a ogni
## avvio. Non è un requisito tecnico — gli edifici di sfondo non hanno stato —
## ma una città che si rimescola a ogni lancio è disorientante.
##
## ## Come sostituire un segnaposto con la pixel art
##
## Basta aggiungere `"texture"` (e l'eventuale `"offset"`) alla voce
## dell'edificio: lo spawner in `city.gd` costruisce uno `Sprite2D` invece del
## rettangolo, nella stessa posizione e con lo stesso comportamento al click.
## `FirstHouse` qui sotto è già così, ed è il modello da copiare. Un edificio di
## sfondo che merita un disegno suo va prima promosso a punto di riferimento,
## cioè scritto in `BUILDINGS`.
##
## ## Il reticolo
##
## Tutto è allineato alla griglia da 32 px. Le strade sono definite dal
## rettangolo del loro ASFALTO; marciapiedi e cordoli li disegna
## `city_ground.gd` intorno, così gli incroci si fondono da soli.
##
## L'origine di un edificio è il PUNTO A TERRA al centro della facciata, come
## vuole `BuildingPlaceholder`: il corpo si sviluppa verso l'alto. Quindi un
## edificio sul lato NORD di una strada ha la base sul bordo alto del
## marciapiede, e uno sul lato SUD ha la base più in basso della strada, con il
## corpo che arriva a toccare il marciapiede. È il campo `"front"` a dire quale
## dei due casi è, e da lì si ricava da che parte il giocatore si avvicina.

const TILE := 32.0
const SIDEWALK_DEPTH := 32.0
const ROAD_WIDTH := 96.0

## Confini del mondo: li usa la camera per non mostrare il vuoto oltre i bordi.
const WORLD_BOUNDS := Rect2(-352, -352, 5312, 4512)

# --- Strade ----------------------------------------------------------------
## Rettangoli dell'asfalto. Orizzontali e verticali stanno separate perché la
## segnaletica (mezzeria, strisce) va disegnata lungo l'asse giusto.
##
## MAIN STREET resta dov'era (y 272): tutto il quartiere povero originale è
## costruito intorno a quella quota, casa iniziale compresa, e spostarla
## vorrebbe dire rifare le posizioni buone che ci sono già.
const ROADS_H := [
	Rect2(-352, 272, 5312, 96),   # MAIN STREET
	Rect2(-352, 976, 5312, 96),   # CROSS STREET
	Rect2(-352, 1680, 5312, 96),  # FOUNDRY ROW
	Rect2(-352, 2240, 5312, 96),  # DIVISION AVENUE  (divide le due file di quartieri)
	Rect2(-352, 2944, 5312, 96),  # PARK LANE
	Rect2(-352, 3552, 5312, 96),  # SOUTH BOULEVARD
]
const ROADS_V := [
	Rect2(752, -352, 96, 4512),   # MILL ROAD
	Rect2(1856, -352, 96, 4512),  # DOCK STREET   (divide FLATS/CIVIC dal resto)
	Rect2(2672, -352, 96, 4512),  # FURNACE STREET
	Rect2(3488, -352, 96, 4512),  # EAST STREET   (divide INDUSTRIAL da DOWNTOWN)
	Rect2(4256, -352, 96, 4512),  # HILL DRIVE
]

# --- Dove si cammina -------------------------------------------------------
## Quote dei marciapiedi, una per strada nell'ordine di `ROADS_H`/`ROADS_V`.
## Sono i numeri da usare per scrivere i percorsi degli NPC: presi da qui non si
## finisce a camminare dentro a un muro o in mezzo alla carreggiata.
const SIDEWALK_N := [256.0, 960.0, 1664.0, 2224.0, 2928.0, 3536.0]
const SIDEWALK_S := [384.0, 1088.0, 1792.0, 2352.0, 3056.0, 3664.0]
const SIDEWALK_W := [736.0, 1840.0, 2656.0, 3472.0, 4240.0]
const SIDEWALK_E := [864.0, 1968.0, 2784.0, 3600.0, 4368.0]
## Ascisse su cui cadono le strisce pedonali che attraversano le strade
## orizzontali: è lì che le pattuglie devono cambiare lato.
const CROSS_X := [744.0, 1848.0, 2664.0, 3480.0, 4248.0]

# --- Quartieri -------------------------------------------------------------
## Il colore è il terreno di fondo, non gli edifici: serve a far capire a
## occhio dove finisce un quartiere e comincia l'altro. `label_at` è dove mettere
## il nome, scelto a mano per non finire sopra a un edificio.
##
## Gli altri campi servono al riempimento automatico: `palette` sono le tinte
## degli edifici di sfondo, `names` le insegne fra cui pescare, e le tre coppie
## `width`/`height`/`floors` dicono che taglia hanno gli edifici di qui. Sono
## quelle a dare il carattere a un quartiere — le villette basse e larghe della
## collina non si confondono con i capannoni della zona industriale.
const DISTRICTS := [
	{
		"id": "flats",
		"name": "THE FLATS",
		"rect": Rect2(-352, -352, 2208, 2592),
		"color": Color(0.243, 0.235, 0.169),
		"label_at": Vector2(-160, 40),
		"palette": [
			Color(0.443, 0.353, 0.294), Color(0.396, 0.396, 0.443),
			Color(0.455, 0.341, 0.298), Color(0.353, 0.404, 0.400),
			Color(0.478, 0.435, 0.337), Color(0.365, 0.349, 0.376),
		],
		"names": [
			"HOUSE", "APARTMENTS", "CORNER STORE", "GARAGE", "LAUNDRY",
			"ROOMS", "AUTO PARTS", "BARBER", "BODEGA", "TENEMENT", "MOTEL",
		],
		"width": Vector2(112, 240),
		"height": Vector2(96, 224),
		"floors": Vector2(1, 4),
	},
	{
		"id": "industrial",
		"name": "INDUSTRIAL PARK",
		"rect": Rect2(1952, -352, 1536, 2592),
		"color": Color(0.310, 0.259, 0.212),
		"label_at": Vector2(2100, -232),
		"palette": [
			Color(0.376, 0.376, 0.408), Color(0.325, 0.353, 0.376),
			Color(0.451, 0.333, 0.271), Color(0.290, 0.310, 0.325),
			Color(0.435, 0.400, 0.325),
		],
		"names": [
			"WAREHOUSE", "WORKS", "DEPOT", "PLANT", "FOUNDRY",
			"STORAGE", "YARD OFFICE", "MILL", "TANKS", "MACHINE SHOP",
		],
		"width": Vector2(176, 352),
		"height": Vector2(128, 256),
		"floors": Vector2(1, 2),
	},
	{
		"id": "downtown",
		"name": "DOWNTOWN",
		"rect": Rect2(3584, -352, 1376, 2592),
		"color": Color(0.251, 0.278, 0.341),
		"label_at": Vector2(3700, -232),
		"palette": [
			Color(0.333, 0.365, 0.518), Color(0.243, 0.435, 0.447),
			Color(0.588, 0.565, 0.482), Color(0.427, 0.243, 0.278),
			Color(0.518, 0.416, 0.286), Color(0.361, 0.376, 0.427),
		],
		"names": [
			"OFFICES", "SHOPS", "HOTEL", "CAFE", "PHARMACY",
			"STUDIO", "TOWER", "ARCADE", "BOOKS", "INSURANCE",
		],
		"width": Vector2(128, 256),
		"height": Vector2(160, 320),
		"floors": Vector2(2, 6),
	},
	{
		"id": "civic",
		"name": "CIVIC CENTER",
		"rect": Rect2(-352, 2336, 2208, 1824),
		"color": Color(0.204, 0.302, 0.263),
		"label_at": Vector2(-176, 2376),
		"palette": [
			Color(0.671, 0.651, 0.596), Color(0.573, 0.510, 0.443),
			Color(0.494, 0.475, 0.435), Color(0.647, 0.631, 0.588),
			Color(0.545, 0.549, 0.529),
		],
		"names": [
			"ARCHIVE", "DEPARTMENT", "OFFICE", "MUSEUM", "CLERK",
			"REGISTRY", "ANNEX", "SCHOOL", "WATER BOARD",
		],
		"width": Vector2(160, 288),
		"height": Vector2(128, 240),
		"floors": Vector2(1, 3),
	},
	{
		"id": "hillside",
		"name": "HILLSIDE",
		"rect": Rect2(1952, 2336, 3008, 1824),
		"color": Color(0.322, 0.392, 0.216),
		"label_at": Vector2(4500, 2376),
		"palette": [
			Color(0.686, 0.639, 0.545), Color(0.639, 0.663, 0.588),
			Color(0.741, 0.706, 0.643), Color(0.663, 0.616, 0.588),
			Color(0.702, 0.655, 0.561),
		],
		"names": ["VILLA", "HOUSE", "ESTATE", "COTTAGE", "LODGE", "MANOR"],
		"width": Vector2(176, 288),
		"height": Vector2(128, 208),
		"floors": Vector2(1, 2),
	},
]

# --- Superfici particolari -------------------------------------------------
## Pezzi di terreno che non sono né strada né edificio: prato del parco, piazza,
## ghiaia dello sfasciacarrozze, campo da football. Gli stili sono in
## `city_ground.gd`, qui c'è solo dove stanno.
##
## Servono anche al riempimento automatico, che ci gira intorno: un capannone
## in mezzo al campo da football non ci va.
const LOTS := [
	# THE FLATS (i primi tre erano già qui e non si toccano)
	{"rect": Rect2(224, 400, 288, 192), "kind": "field", "label": "OLD FOOTBALL FIELD"},
	{"rect": Rect2(-320, 432, 224, 160), "kind": "dirt", "label": "VACANT LOT"},
	{"rect": Rect2(384, 640, 288, 112), "kind": "asphalt", "label": ""},
	{"rect": Rect2(960, 1180, 320, 240), "kind": "dirt", "label": "VACANT LOT"},
	{"rect": Rect2(1440, 1860, 340, 300), "kind": "gravel", "label": "TOW YARD"},
	{"rect": Rect2(-320, 1180, 300, 220), "kind": "asphalt", "label": "PARKING"},
	{"rect": Rect2(240, 1860, 380, 280), "kind": "field", "label": "BALL COURT"},
	# INDUSTRIAL PARK
	{"rect": Rect2(2000, 448, 400, 320), "kind": "gravel", "label": "SCRAPYARD"},
	{"rect": Rect2(2820, 448, 360, 288), "kind": "gravel", "label": "TANK FARM"},
	{"rect": Rect2(2800, 1120, 400, 160), "kind": "concrete", "label": ""},
	{"rect": Rect2(2000, 1840, 384, 288), "kind": "concrete", "label": "CONTAINER YARD"},
	{"rect": Rect2(2880, 1860, 400, 280), "kind": "gravel", "label": "SPOIL HEAP"},
	# DOWNTOWN
	{"rect": Rect2(3640, 432, 240, 192), "kind": "asphalt", "label": "PARKING"},
	{"rect": Rect2(4400, 1120, 240, 200), "kind": "asphalt", "label": "PARKING"},
	{"rect": Rect2(3640, 1120, 300, 200), "kind": "plaza", "label": "MARKET SQUARE"},
	{"rect": Rect2(4400, 1860, 300, 280), "kind": "asphalt", "label": "PARKING"},
	# CIVIC CENTER
	{"rect": Rect2(-320, 2400, 960, 512), "kind": "lawn", "label": "CENTRAL PARK"},
	{"rect": Rect2(-320, 3080, 400, 400), "kind": "lawn", "label": "MEMORIAL GARDEN"},
	{"rect": Rect2(1540, 3180, 260, 340), "kind": "plaza", "label": "CITY PLAZA"},
	{"rect": Rect2(1360, 3700, 400, 300), "kind": "dirt", "label": "SCHOOL YARD"},
	{"rect": Rect2(880, 2420, 520, 460), "kind": "lawn", "label": ""},
	# HILLSIDE
	{"rect": Rect2(2000, 2400, 640, 480), "kind": "lawn", "label": ""},
	{"rect": Rect2(2820, 2400, 620, 480), "kind": "lawn", "label": ""},
	{"rect": Rect2(3640, 2400, 240, 320), "kind": "court", "label": "TENNIS"},
	{"rect": Rect2(4400, 2400, 520, 480), "kind": "lawn", "label": ""},
	{"rect": Rect2(2000, 3100, 240, 160), "kind": "pool", "label": "POOL"},
	{"rect": Rect2(2820, 3080, 620, 440), "kind": "lawn", "label": ""},
	{"rect": Rect2(3640, 3700, 560, 400), "kind": "lawn", "label": ""},
	{"rect": Rect2(4400, 3700, 240, 160), "kind": "pool", "label": "POOL"},
]

# --- Fontane ---------------------------------------------------------------
## Nodi veri (l'acqua si muove), non disegno di fondo: stanno in `Props`.
const FOUNTAINS := [Vector2(160, 2660), Vector2(1700, 3350)]

# --- Punti di riferimento --------------------------------------------------
## `base`   punto a terra al centro della facciata
## `size`   ingombro del segnaposto (larghezza x altezza del prospetto)
## `front`  "north" = la strada è sotto, "south" = la strada è sopra.
##          Decide da che lato il protagonista si avvicina.
## `floors` righe orizzontali del segnaposto, per suggerire i piani
## `interior` scena in cui si entra cliccando (opzionale)
## `texture`/`offset`/`click` PNG definitivo al posto del rettangolo (opzionale)
const BUILDINGS := [
	# ==== THE FLATS: il blocco originale, invariato ====
	{
		"id": "Pawnshop", "base": Vector2(-208, 240), "size": Vector2(160, 128),
		"label": "PAWN SHOP", "color": Color(0.443, 0.353, 0.294), "front": "north",
	},
	{
		"id": "TrailerCamp", "base": Vector2(128, 240), "size": Vector2(192, 96),
		"label": "TRAILER CAMP", "color": Color(0.506, 0.463, 0.353), "front": "north",
	},
	{
		# L'unico con la pixel art vera: il modello per tutti gli altri.
		"id": "FirstHouse", "base": Vector2(320, 224),
		"texture": "res://assets/sprites/buildings/firstHouse.png",
		"offset": Vector2(-73, -161), "click": Rect2(-73, -161, 140, 176),
		"entry": Vector2(0, 40), "interior": "res://scenes/rooms/Entrance.tscn",
	},
	{
		"id": "Condo", "base": Vector2(496, 240), "size": Vector2(160, 288),
		"label": "SQUATTED CONDO", "color": Color(0.396, 0.396, 0.443),
		"front": "north", "floors": 6,
	},
	{
		"id": "Laundromat", "base": Vector2(656, 240), "size": Vector2(112, 112),
		"label": "LAUNDROMAT", "color": Color(0.353, 0.404, 0.400), "front": "north",
	},
	{
		"id": "SouthHouse", "base": Vector2(112, 560), "size": Vector2(160, 160),
		"label": "HOUSE", "color": Color(0.455, 0.341, 0.298), "front": "south", "floors": 2,
	},
	{
		"id": "Minimarket", "base": Vector2(624, 528), "size": Vector2(160, 128),
		"label": "MINIMARKET", "color": Color(0.243, 0.435, 0.447), "front": "south",
	},
	{
		"id": "ChopShop", "base": Vector2(528, 752), "size": Vector2(160, 112),
		"label": "CHOP SHOP", "color": Color(0.396, 0.310, 0.263), "front": "south",
	},
	{
		"id": "Projects", "base": Vector2(192, 880), "size": Vector2(224, 192),
		"label": "THE PROJECTS", "color": Color(0.365, 0.349, 0.376),
		"front": "south", "floors": 4,
	},
	{
		"id": "LiquorStore", "base": Vector2(-176, 752), "size": Vector2(144, 112),
		"label": "LIQUOR STORE", "color": Color(0.478, 0.353, 0.267), "front": "south",
	},
	# ==== THE FLATS: la metà nuova ====
	{
		"id": "Motel", "base": Vector2(1040, 240), "size": Vector2(288, 144),
		"label": "MOTEL", "color": Color(0.510, 0.400, 0.298), "front": "north",
	},
	{
		"id": "Church", "base": Vector2(1640, 240), "size": Vector2(176, 208),
		"label": "CHURCH", "color": Color(0.545, 0.510, 0.443), "front": "north", "floors": 2,
	},
	{
		"id": "Projects2", "base": Vector2(1500, 592), "size": Vector2(240, 192),
		"label": "THE PROJECTS", "color": Color(0.365, 0.349, 0.376),
		"front": "south", "floors": 5,
	},
	{
		"id": "Gym", "base": Vector2(1200, 1648), "size": Vector2(224, 160),
		"label": "BOXING GYM", "color": Color(0.435, 0.318, 0.286), "front": "north", "floors": 2,
	},
	{
		"id": "Flophouse", "base": Vector2(500, 2208), "size": Vector2(224, 192),
		"label": "FLOPHOUSE", "color": Color(0.400, 0.376, 0.353), "front": "north", "floors": 3,
	},
	# ==== INDUSTRIAL PARK ====
	{
		"id": "Factory", "base": Vector2(2280, 240), "size": Vector2(480, 320),
		"label": "FACTORY", "color": Color(0.376, 0.376, 0.408), "front": "north", "floors": 2,
	},
	{
		"id": "Silo", "base": Vector2(2580, 240), "size": Vector2(112, 320),
		"label": "SILO", "color": Color(0.545, 0.529, 0.482), "front": "north",
	},
	{
		"id": "PowerPlant", "base": Vector2(2960, 240), "size": Vector2(288, 288),
		"label": "POWER PLANT", "color": Color(0.451, 0.333, 0.271), "front": "north", "floors": 3,
	},
	{
		"id": "Warehouse", "base": Vector2(2440, 640), "size": Vector2(360, 240),
		"label": "WAREHOUSE", "color": Color(0.325, 0.353, 0.376), "front": "south",
	},
	{
		"id": "LoadingDock", "base": Vector2(3120, 620), "size": Vector2(320, 220),
		"label": "LOADING DOCK", "color": Color(0.290, 0.310, 0.325), "front": "south",
	},
	{
		"id": "TruckDepot", "base": Vector2(2960, 2008), "size": Vector2(320, 200),
		"label": "TRUCK DEPOT", "color": Color(0.376, 0.325, 0.263), "front": "south",
	},
	# ==== DOWNTOWN ====
	{
		# La clinica dove lavora l'amico che procura i semi. Lui sta fuori, sul
		# marciapiede: vedi `npc_roster.gd`.
		"id": "Clinic", "base": Vector2(3800, 240), "size": Vector2(288, 224),
		"label": "CLINIC", "color": Color(0.780, 0.792, 0.804), "front": "north", "floors": 2,
	},
	{
		"id": "Mall", "base": Vector2(4620, 240), "size": Vector2(440, 320),
		"label": "SHOPPING MALL", "color": Color(0.333, 0.365, 0.518), "front": "north", "floors": 2,
	},
	{
		"id": "Bank", "base": Vector2(3760, 592), "size": Vector2(240, 192),
		"label": "BANK", "color": Color(0.588, 0.565, 0.482), "front": "south", "floors": 3,
	},
	{
		"id": "Bar", "base": Vector2(4080, 528), "size": Vector2(200, 128),
		"label": "BAR", "color": Color(0.427, 0.243, 0.278), "front": "south",
	},
	{
		"id": "Hardware", "base": Vector2(4560, 560), "size": Vector2(240, 160),
		"label": "HARDWARE", "color": Color(0.518, 0.416, 0.286), "front": "south",
	},
	{
		"id": "Diner", "base": Vector2(3980, 1264), "size": Vector2(260, 160),
		"label": "DINER", "color": Color(0.545, 0.400, 0.325), "front": "south",
	},
	# ==== CIVIC CENTER ====
	{
		"id": "CityHall", "base": Vector2(1300, 3520), "size": Vector2(440, 340),
		"label": "CITY HALL", "color": Color(0.671, 0.651, 0.596), "front": "north", "floors": 3,
	},
	{
		"id": "PoliceStation", "base": Vector2(300, 3520), "size": Vector2(280, 224),
		"label": "POLICE", "color": Color(0.286, 0.333, 0.427), "front": "north", "floors": 2,
	},
	{
		"id": "Library", "base": Vector2(600, 3520), "size": Vector2(200, 176),
		"label": "LIBRARY", "color": Color(0.573, 0.510, 0.443), "front": "north",
	},
	{
		"id": "Courthouse", "base": Vector2(500, 3940), "size": Vector2(360, 260),
		"label": "COURTHOUSE", "color": Color(0.647, 0.631, 0.588), "front": "south", "floors": 2,
	},
	{
		"id": "PostOffice", "base": Vector2(1020, 3920), "size": Vector2(260, 240),
		"label": "POST OFFICE", "color": Color(0.494, 0.475, 0.435), "front": "south",
	},
	# ==== HILLSIDE ====
	{
		"id": "CountryClub", "base": Vector2(2300, 2608), "size": Vector2(400, 240),
		"label": "COUNTRY CLUB", "color": Color(0.729, 0.694, 0.600), "front": "south",
	},
	{
		"id": "Villa1", "base": Vector2(2300, 2912), "size": Vector2(280, 200),
		"label": "VILLA", "color": Color(0.686, 0.639, 0.545), "front": "north", "floors": 2,
	},
	{
		"id": "Villa2", "base": Vector2(3100, 2912), "size": Vector2(300, 220),
		"label": "VILLA", "color": Color(0.639, 0.663, 0.588), "front": "north", "floors": 2,
	},
	{
		"id": "Mansion", "base": Vector2(3900, 2912), "size": Vector2(400, 260),
		"label": "MANSION", "color": Color(0.741, 0.706, 0.643), "front": "north", "floors": 2,
	},
	{
		"id": "Villa3", "base": Vector2(4600, 2912), "size": Vector2(300, 220),
		"label": "VILLA", "color": Color(0.663, 0.616, 0.588), "front": "north", "floors": 2,
	},
	{
		"id": "Villa4", "base": Vector2(2200, 3520), "size": Vector2(280, 200),
		"label": "VILLA", "color": Color(0.702, 0.655, 0.561), "front": "north", "floors": 2,
	},
	{
		"id": "Villa5", "base": Vector2(3000, 3520), "size": Vector2(300, 220),
		"label": "VILLA", "color": Color(0.616, 0.647, 0.596), "front": "north", "floors": 2,
	},
	{
		"id": "GatedHouse", "base": Vector2(2400, 3940), "size": Vector2(300, 260),
		"label": "GATED HOUSE", "color": Color(0.678, 0.627, 0.522), "front": "south", "floors": 2,
	},
	{
		"id": "Villa6", "base": Vector2(4600, 3920), "size": Vector2(320, 240),
		"label": "VILLA", "color": Color(0.706, 0.671, 0.596), "front": "south", "floors": 2,
	},
]

# --- Riempimento automatico ------------------------------------------------

## Cambiarlo rimescola tutti gli edifici di sfondo. Fisso, perché la città deve
## essere la stessa a ogni avvio.
const FILL_SEED := 20260909
## Spazio fra due edifici della stessa fila.
const FILL_GAP := Vector2(16, 56)
## Distanza minima da un terreno particolare (prato, piazzale, campo).
const LOT_MARGIN := 12.0

## Tutti gli edifici della città: prima i punti di riferimento scritti a mano,
## poi le file generate lungo i fronti stradali.
##
## L'ordine conta: i punti di riferimento occupano il posto per primi, e il
## riempimento gira intorno a quello che trova già occupato. Così spostare un
## punto di riferimento non richiede di aggiustare niente altro — al massimo si
## sposta anche la casa qualunque che gli stava accanto.
static func all_buildings() -> Array:
	var landmarks: Array = BUILDINGS
	var taken: Array[Rect2] = []
	for entry in landmarks:
		taken.append(footprint(entry))
	for lot in LOTS:
		taken.append((lot["rect"] as Rect2).grow(LOT_MARGIN))

	var rng := RandomNumberGenerator.new()
	rng.seed = FILL_SEED
	var filler: Array = []
	for frontage in _frontages():
		filler.append_array(_fill_frontage(frontage, taken, rng, filler.size()))
	return landmarks + filler

## Ingombro a terra di una voce, in coordinate mondo: origine a terra al centro
## della facciata, corpo verso l'alto.
static func footprint(entry: Dictionary) -> Rect2:
	var base: Vector2 = entry["base"]
	if entry.has("size"):
		var size: Vector2 = entry["size"]
		return Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y)
	# Voce con la pixel art: l'ingombro è l'area cliccabile, in locale.
	var click: Rect2 = entry.get("click", Rect2(-64, -128, 128, 128))
	return Rect2(base + click.position, click.size)

## Un fronte stradale da riempire: una fila di edifici affacciati sulla stessa
## strada, dentro allo stesso quartiere.
##
## Vengono ricavati dal reticolo invece di essere elencati: sono più di cento,
## cambiano tutti se si sposta una strada, e riscriverli a mano ogni volta
## sarebbe l'unico modo garantito di sbagliarne qualcuno.
##
## Ci sono anche i fronti sulle strade **verticali**: senza, i blocchi
## risultano costruiti solo sopra e sotto e con le fiancate vuote, e da lontano
## la città si legge come una serie di righe invece che di isolati.
static func _frontages() -> Array:
	var list: Array = []
	for road: Rect2 in ROADS_H:
		for district in DISTRICTS:
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
## Uno slot occupato non interrompe la fila: si scivola avanti di un tile e si
## riprova. Altrimenti un solo punto di riferimento in mezzo a un isolato
## lascerebbe vuoto tutto quello che viene dopo.
static func _fill_frontage(frontage: Dictionary, taken: Array[Rect2], rng: RandomNumberGenerator, offset: int) -> Array:
	var district: Dictionary = frontage["district"]
	var bounds: Rect2 = district["rect"]
	var width_range: Vector2 = district["width"]
	var height_range: Vector2 = district["height"]
	var floors_range: Vector2 = district["floors"]
	var palette: Array = district["palette"]
	var names: Array = district["names"]
	var side: String = frontage["side"]
	var vertical: bool = frontage["vertical"]
	var at: float = frontage["at"]

	var result: Array = []
	var along: float = frontage["from"]
	var limit: float = frontage["to"]
	while along < limit:
		var width := _snap(rng.randf_range(width_range.x, width_range.y))
		var height := _snap(rng.randf_range(height_range.x, height_range.y))
		# Lungo una strada verticale è l'altezza a scorrere: due edifici
		# affiancati in verticale si toccano per l'altezza, non per la base.
		var span := height if vertical else width
		if along + span > limit:
			break

		var base: Vector2
		if vertical:
			# La facciata tocca il marciapiede: a ovest della strada l'edificio
			# sta alla sua sinistra, a est alla sua destra.
			var center_x := at - width * 0.5 if side == "west" else at + width * 0.5
			base = Vector2(center_x, along + height)
		else:
			base = Vector2(along + width * 0.5, at if side == "north" else at + height)
		var rect := Rect2(base.x - width * 0.5, base.y - height, width, height)

		# Un edificio non deve uscire dal suo quartiere né finire sopra a una
		# strada, a un terreno particolare o a un altro edificio.
		if bounds.encloses(rect) and not _on_road(rect) and _is_free(rect, taken):
			taken.append(rect)
			result.append({
				"id": "Fill%d_%d" % [offset, result.size()],
				"base": base,
				"size": Vector2(width, height),
				"label": str(names[rng.randi() % names.size()]),
				"color": palette[rng.randi() % palette.size()],
				"front": side,
				"floors": rng.randi_range(int(floors_range.x), int(floors_range.y)),
			})
			along += span + _snap(rng.randf_range(FILL_GAP.x, FILL_GAP.y))
		else:
			along += TILE
	return result

static func _snap(value: float) -> float:
	return maxf(TILE, roundf(value / 16.0) * 16.0)

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
