class_name NpcRoster
extends RefCounted

## Chi c'è per strada, e cosa fa.
##
## Come `CityMap`, è una tabella di dati: `city.gd` la legge e istanzia un
## `Npc.tscn` per voce. Aggiungere un personaggio vuol dire aggiungere una riga.
##
## Un percorso (`route`) è una fila di punti sui marciapiedi: l'NPC li ripercorre
## fermandosi a ogni tappa. Le quote giuste stanno in `CityMap.SIDEWALK_N/S/W/E`,
## una per strada, e prese da lì non si finisce a camminare dentro a un muro o in
## mezzo alla carreggiata.
##
## Chi deve **attraversare** una strada orizzontale lo fa sulle ascisse di
## `CityMap.CROSS_X`: sono le uniche su cui cadono le strisce pedonali, e sono
## anche marciapiede valido, quindi valgono sia per camminarci sia per
## attraversare. Le pattuglie e chi cammina in verticale le usano tutte.
##
## `hours` è la fascia in cui il personaggio è in giro: fuori da quella la
## strada si svuota. È il primo uso vero dell'orologio di gioco oltre all'HUD.
##
## I clienti sono sparsi apposta su tutti e cinque i quartieri e su fasce orarie
## diverse: la città è larga cinque schermi, e doverla attraversare tutta per
## trovare qualcuno a cui vendere sarebbe solo tempo perso.

## Ruoli. Il ruolo decide cosa succede parlandogli, non come cammina.
const ROLE_WANDER := "wander"   ## comparsa: due battute e nient'altro
const ROLE_SEEDS := "seeds"     ## vende semi (Brian, su appuntamento: vedi `SeedDeal`)
const ROLE_BUYER := "buyer"     ## compra erba al dettaglio
const ROLE_COP := "cop"         ## avverte in base a quanta attenzione hai addosso

## Divise: le pattuglie si devono riconoscere a colpo d'occhio da lontano.
const COP_COLOR := Color(0.235, 0.290, 0.400)
const COP_ACCENT := Color(0.149, 0.180, 0.251)

## Qui dentro c'è chi sta per strada a orari fissi. L'unico con ruolo
## `ROLE_SEEDS` — Brian, il cugino che lavora alla clinica — NON è in questo
## elenco: esiste solo quando c'è un appuntamento, e a tirarlo su dove aspetta è
## `city.gd` leggendo `SeedDeal`. Un venditore di semi fermo a un indirizzo
## sarebbe un distributore automatico, e la scelta di quando chiamarlo
## sparirebbe.
const NPCS := [
	# ==== Clienti: uno o due per quartiere, su fasce orarie diverse ====
	{
		"id": "tony", "name": "TONY", "role": ROLE_BUYER,
		"route": [Vector2(240, 384), Vector2(700, 384)],
		"speed": 34.0, "pause": 2.0, "hours": Vector2(10, 24),
		"color": Color(0.541, 0.318, 0.278), "accent": Color(0.278, 0.286, 0.353),
	},
	{
		"id": "curtis", "name": "CURTIS", "role": ROLE_BUYER,
		"route": [Vector2(900, 960), Vector2(1500, 960)],
		"speed": 36.0, "pause": 1.8, "hours": Vector2(12, 24),
		"color": Color(0.435, 0.400, 0.290), "accent": Color(0.243, 0.259, 0.290),
	},
	{
		"id": "whit", "name": "WHIT", "role": ROLE_BUYER,
		"route": [Vector2(300, 1792), Vector2(900, 1792)],
		"speed": 33.0, "pause": 2.2, "hours": Vector2(13, 24),
		"color": Color(0.400, 0.353, 0.451), "accent": Color(0.231, 0.243, 0.278),
	},
	{
		"id": "dee", "name": "DEE", "role": ROLE_BUYER,
		"route": [Vector2(3620, 256), Vector2(4200, 256)],
		"speed": 38.0, "pause": 1.6, "hours": Vector2(9, 23),
		"color": Color(0.478, 0.361, 0.545), "accent": Color(0.220, 0.231, 0.271),
	},
	{
		"id": "priya", "name": "PRIYA", "role": ROLE_BUYER,
		"route": [Vector2(4400, 1088), Vector2(4900, 1088)],
		"speed": 35.0, "pause": 2.0, "hours": Vector2(10, 23),
		"color": Color(0.671, 0.435, 0.353), "accent": Color(0.259, 0.243, 0.282),
	},
	{
		"id": "mona", "name": "MONA", "role": ROLE_BUYER,
		"route": [Vector2(2000, 1088), Vector2(2600, 1088)],
		"speed": 32.0, "pause": 2.4, "hours": Vector2(11, 24),
		"color": Color(0.596, 0.475, 0.286), "accent": Color(0.251, 0.267, 0.302),
	},
	{
		"id": "lou", "name": "LOU", "role": ROLE_BUYER,
		"route": [Vector2(200, 3056), Vector2(700, 3056)],
		"speed": 31.0, "pause": 2.6, "hours": Vector2(12, 24),
		"color": Color(0.373, 0.475, 0.443), "accent": Color(0.239, 0.267, 0.271),
	},
	{
		"id": "brenda", "name": "BRENDA", "role": ROLE_BUYER,
		"route": [Vector2(2600, 3536), Vector2(3300, 3536)],
		"speed": 30.0, "pause": 3.0, "hours": Vector2(14, 23),
		"color": Color(0.729, 0.596, 0.510), "accent": Color(0.353, 0.322, 0.310),
	},
	# ==== Pattuglie: sempre in giro, e attraversano sulle strisce ====
	{
		"id": "beatty", "name": "OFFICER BEATTY", "role": ROLE_COP,
		"route": [
			Vector2(0, 256), Vector2(744, 256),
			Vector2(744, 384), Vector2(0, 384),
		],
		"speed": 28.0, "pause": 3.6, "hours": Vector2(0, 24),
		"color": COP_COLOR, "accent": COP_ACCENT,
	},
	{
		"id": "parks", "name": "OFFICER PARKS", "role": ROLE_COP,
		"route": [
			Vector2(-40, 3536), Vector2(744, 3536),
			Vector2(744, 3664), Vector2(-40, 3664),
		],
		"speed": 30.0, "pause": 2.8, "hours": Vector2(0, 24),
		"color": COP_COLOR, "accent": COP_ACCENT,
	},
	{
		"id": "naka", "name": "OFFICER NAKA", "role": ROLE_COP,
		"route": [
			Vector2(3620, 256), Vector2(4248, 256),
			Vector2(4248, 384), Vector2(3620, 384),
		],
		"speed": 29.0, "pause": 3.2, "hours": Vector2(0, 24),
		"color": COP_COLOR, "accent": COP_ACCENT,
	},
	{
		"id": "vance", "name": "OFFICER VANCE", "role": ROLE_COP,
		"route": [
			Vector2(2000, 1664), Vector2(2664, 1664),
			Vector2(2664, 1792), Vector2(2000, 1792),
		],
		"speed": 27.0, "pause": 4.0, "hours": Vector2(0, 24),
		"color": COP_COLOR, "accent": COP_ACCENT,
	},
	# ==== Comparse ====
	{
		"id": "rita", "name": "RITA", "role": ROLE_WANDER,
		"route": [Vector2(-40, 256), Vector2(600, 256)],
		"speed": 30.0, "pause": 2.6, "hours": Vector2(7, 21),
		"color": Color(0.588, 0.541, 0.400), "accent": Color(0.322, 0.290, 0.243),
		"lines": [
			"LINE_FLATS_1_A",
			"LINE_FLATS_1_B",
			"LINE_FLATS_1_C",
		],
	},
	{
		"id": "delroy", "name": "DELROY", "role": ROLE_WANDER,
		"route": [Vector2(-200, 1088), Vector2(600, 1088)],
		"speed": 28.0, "pause": 3.0, "hours": Vector2(8, 20),
		"color": Color(0.451, 0.400, 0.337), "accent": Color(0.271, 0.259, 0.235),
		"lines": [
			"LINE_FLATS_2_A",
			"LINE_FLATS_2_B",
			"LINE_FLATS_2_C",
		],
	},
	{
		"id": "yusuf", "name": "YUSUF", "role": ROLE_WANDER,
		"route": [Vector2(900, 1664), Vector2(1700, 1664)],
		"speed": 31.0, "pause": 2.4, "hours": Vector2(7, 19),
		"color": Color(0.502, 0.451, 0.353), "accent": Color(0.290, 0.271, 0.243),
		"lines": [
			"LINE_FLATS_3_A",
			"LINE_FLATS_3_B",
			"LINE_FLATS_3_C",
		],
	},
	{
		"id": "marge", "name": "MARGE", "role": ROLE_WANDER,
		"route": [Vector2(200, 2224), Vector2(1000, 2224)],
		"speed": 24.0, "pause": 4.2, "hours": Vector2(9, 20),
		"color": Color(0.663, 0.596, 0.478), "accent": Color(0.361, 0.333, 0.298),
		"lines": [
			"LINE_FLATS_4_A",
			"LINE_FLATS_4_B",
			"LINE_FLATS_4_C",
		],
	},
	{
		"id": "skater", "name": "SKATER KID", "role": ROLE_WANDER,
		"route": [
			Vector2(744, 180), Vector2(744, 900),
			Vector2(864, 900), Vector2(864, 180),
		],
		"speed": 52.0, "pause": 0.8, "hours": Vector2(10, 23),
		"color": Color(0.400, 0.482, 0.545), "accent": Color(0.243, 0.243, 0.278),
		"lines": [
			"LINE_FLATS_5_A",
			"LINE_FLATS_5_B",
			"LINE_FLATS_5_C",
		],
	},
	{
		"id": "hank", "name": "HANK", "role": ROLE_WANDER,
		"route": [Vector2(2000, 384), Vector2(2600, 384)],
		"speed": 26.0, "pause": 4.0, "hours": Vector2(6, 18),
		"color": Color(0.502, 0.451, 0.294), "accent": Color(0.290, 0.259, 0.208),
		"lines": [
			"LINE_IND_1_A",
			"LINE_IND_1_B",
			"LINE_IND_1_C",
		],
	},
	{
		"id": "otis", "name": "OTIS", "role": ROLE_WANDER,
		"route": [Vector2(1848, 200), Vector2(1848, 1600)],
		"speed": 34.0, "pause": 2.0, "hours": Vector2(6, 20),
		"color": Color(0.400, 0.427, 0.400), "accent": Color(0.251, 0.259, 0.251),
		"lines": [
			"LINE_IND_2_A",
			"LINE_IND_2_B",
			"LINE_IND_2_C",
		],
	},
	{
		"id": "shay", "name": "SHAY", "role": ROLE_WANDER,
		"route": [Vector2(2100, 960), Vector2(3300, 960)],
		"speed": 33.0, "pause": 2.2, "hours": Vector2(8, 19),
		"color": Color(0.545, 0.451, 0.322), "accent": Color(0.278, 0.259, 0.231),
		"lines": [
			"LINE_IND_3_A",
			"LINE_IND_3_B",
			"LINE_IND_3_C",
		],
	},
	{
		"id": "gus", "name": "GUS", "role": ROLE_WANDER,
		"route": [Vector2(2000, 2224), Vector2(3300, 2224)],
		"speed": 25.0, "pause": 4.4, "hours": Vector2(7, 17),
		"color": Color(0.475, 0.416, 0.290), "accent": Color(0.282, 0.251, 0.212),
		"lines": [
			"LINE_IND_4_A",
			"LINE_IND_4_B",
			"LINE_IND_4_C",
		],
	},
	{
		"id": "nora", "name": "NORA", "role": ROLE_WANDER,
		"route": [Vector2(3620, 960), Vector2(4900, 960)],
		"speed": 36.0, "pause": 1.8, "hours": Vector2(9, 22),
		"color": Color(0.435, 0.475, 0.596), "accent": Color(0.243, 0.259, 0.310),
		"lines": [
			"LINE_DOWN_1_A",
			"LINE_DOWN_1_B",
			"LINE_DOWN_1_C",
		],
	},
	{
		"id": "trev", "name": "TREV", "role": ROLE_WANDER,
		"route": [Vector2(3620, 1792), Vector2(4900, 1792)],
		"speed": 32.0, "pause": 2.6, "hours": Vector2(10, 23),
		"color": Color(0.502, 0.416, 0.545), "accent": Color(0.259, 0.239, 0.290),
		"lines": [
			"LINE_DOWN_2_A",
			"LINE_DOWN_2_B",
			"LINE_DOWN_2_C",
		],
	},
	{
		"id": "rosa", "name": "ROSA", "role": ROLE_WANDER,
		"route": [
			Vector2(-280, 2500), Vector2(560, 2500),
			Vector2(560, 2820), Vector2(-280, 2820),
		],
		"speed": 24.0, "pause": 4.4, "hours": Vector2(8, 19),
		"color": Color(0.435, 0.529, 0.408), "accent": Color(0.290, 0.322, 0.263),
		"lines": [
			"LINE_CIVIC_1_A",
			"LINE_CIVIC_1_B",
			"LINE_CIVIC_1_C",
		],
	},
	{
		"id": "abel", "name": "ABEL", "role": ROLE_WANDER,
		"route": [Vector2(-200, 2352), Vector2(1700, 2352)],
		"speed": 30.0, "pause": 2.8, "hours": Vector2(8, 20),
		"color": Color(0.529, 0.510, 0.451), "accent": Color(0.290, 0.282, 0.259),
		"lines": [
			"LINE_CIVIC_2_A",
			"LINE_CIVIC_2_B",
			"LINE_CIVIC_2_C",
		],
	},
	{
		"id": "imani", "name": "IMANI", "role": ROLE_WANDER,
		"route": [Vector2(900, 3536), Vector2(1780, 3536)],
		"speed": 29.0, "pause": 3.0, "hours": Vector2(8, 19),
		"color": Color(0.596, 0.529, 0.400), "accent": Color(0.310, 0.290, 0.251),
		"lines": [
			"LINE_CIVIC_3_A",
			"LINE_CIVIC_3_B",
			"LINE_CIVIC_3_C",
		],
	},
	{
		"id": "elder", "name": "MRS ELDER", "role": ROLE_WANDER,
		"route": [Vector2(2100, 2928), Vector2(3400, 2928)],
		"speed": 22.0, "pause": 5.0, "hours": Vector2(9, 18),
		"color": Color(0.796, 0.769, 0.706), "accent": Color(0.400, 0.376, 0.361),
		"lines": [
			"LINE_HILL_1_A",
			"LINE_HILL_1_B",
			"LINE_HILL_1_C",
		],
	},
	{
		"id": "harold", "name": "HAROLD", "role": ROLE_WANDER,
		"route": [Vector2(2100, 3664), Vector2(3400, 3664)],
		"speed": 23.0, "pause": 4.8, "hours": Vector2(9, 18),
		"color": Color(0.741, 0.706, 0.639), "accent": Color(0.376, 0.365, 0.337),
		"lines": [
			"LINE_HILL_2_A",
			"LINE_HILL_2_B",
			"LINE_HILL_2_C",
		],
	},
	{
		"id": "celia", "name": "CELIA", "role": ROLE_WANDER,
		"route": [Vector2(4248, 2500), Vector2(4248, 3900)],
		"speed": 27.0, "pause": 3.4, "hours": Vector2(10, 19),
		"color": Color(0.769, 0.706, 0.671), "accent": Color(0.396, 0.365, 0.353),
		"lines": [
			"LINE_HILL_3_A",
			"LINE_HILL_3_B",
			"LINE_HILL_3_C",
		],
	},
]

## Il roster ma indicizzato per id, per ritrovare una voce senza scorrere.
static func by_id(npc_id: String) -> Dictionary:
	for entry in NPCS:
		if str(entry["id"]) == npc_id:
			return entry
	return {}

## Una battuta a caso fra le sue, "" se non ne ha.
## Una battuta a caso fra le sue, già tradotta.
##
## Nella tabella ci sono le CHIAVI e non le frasi: le tre lingue stanno in
## `Strings`, e questa resta una tabella di chi c'è per strada invece di
## diventare anche un file di testo in triplice copia.
static func random_line(entry: Dictionary) -> String:
	var lines: Array = entry.get("lines", [])
	if lines.is_empty():
		return ""
	return TranslationServer.translate(str(lines[randi() % lines.size()]))

## Se a quest'ora è per strada. `hours` può scavallare la mezzanotte
## (es. 22-4), quindi i due casi vanno distinti.
static func is_out_at(entry: Dictionary, time_of_day: float) -> bool:
	var span: Vector2 = entry.get("hours", Vector2(0, 24))
	if is_equal_approx(span.x, span.y):
		return true
	if span.x < span.y:
		return time_of_day >= span.x and time_of_day < span.y
	return time_of_day >= span.x or time_of_day < span.y
