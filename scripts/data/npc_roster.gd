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
const ROLE_SEEDS := "seeds"     ## vende semi (l'amico della clinica)
const ROLE_BUYER := "buyer"     ## compra erba al dettaglio
const ROLE_COP := "cop"         ## avverte in base a quanta attenzione hai addosso

## Divise: le pattuglie si devono riconoscere a colpo d'occhio da lontano.
const COP_COLOR := Color(0.235, 0.290, 0.400)
const COP_ACCENT := Color(0.149, 0.180, 0.251)

const NPCS := [
	# ==== L'amico della clinica: l'unica fonte di semi ====
	{
		# Sta sul marciapiede davanti alla CLINIC, e solo in orario di lavoro.
		"id": "milo", "name": "MILO", "role": ROLE_SEEDS,
		"route": [Vector2(3760, 256), Vector2(3860, 256)],
		"speed": 26.0, "pause": 3.2, "hours": Vector2(8, 20),
		"color": Color(0.847, 0.878, 0.898), "accent": Color(0.298, 0.478, 0.545),
	},
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
			"Landlord raised the rent again. On this place. Can you believe it?",
			"They say the mall is hiring. They always say the mall is hiring.",
			"Keep an eye on your bike. Nothing stays out here for long.",
		],
	},
	{
		"id": "delroy", "name": "DELROY", "role": ROLE_WANDER,
		"route": [Vector2(-200, 1088), Vector2(600, 1088)],
		"speed": 28.0, "pause": 3.0, "hours": Vector2(8, 20),
		"color": Color(0.451, 0.400, 0.337), "accent": Color(0.271, 0.259, 0.235),
		"lines": [
			"Two buses a day down here. Both of them full.",
			"You walk everywhere too? Figures.",
			"The projects had heat until March. March.",
		],
	},
	{
		"id": "yusuf", "name": "YUSUF", "role": ROLE_WANDER,
		"route": [Vector2(900, 1664), Vector2(1700, 1664)],
		"speed": 31.0, "pause": 2.4, "hours": Vector2(7, 19),
		"color": Color(0.502, 0.451, 0.353), "accent": Color(0.290, 0.271, 0.243),
		"lines": [
			"Been trying to open a shop on this row for six years.",
			"Permits go through city hall. City hall goes through nobody.",
			"Quiet street. Too quiet for business.",
		],
	},
	{
		"id": "marge", "name": "MARGE", "role": ROLE_WANDER,
		"route": [Vector2(200, 2224), Vector2(1000, 2224)],
		"speed": 24.0, "pause": 4.2, "hours": Vector2(9, 20),
		"color": Color(0.663, 0.596, 0.478), "accent": Color(0.361, 0.333, 0.298),
		"lines": [
			"I have lived on this avenue longer than it has had a name.",
			"Careful past the tow yard. They take anything that stands still.",
			"You look like you are up to something. Good for you.",
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
			"Cops never come down Mill Road. Just saying.",
			"You got anything? No? Cool. Cool cool cool.",
			"I have cleared that whole stair set. Twice.",
		],
	},
	{
		"id": "hank", "name": "HANK", "role": ROLE_WANDER,
		"route": [Vector2(2000, 384), Vector2(2600, 384)],
		"speed": 26.0, "pause": 4.0, "hours": Vector2(6, 18),
		"color": Color(0.502, 0.451, 0.294), "accent": Color(0.290, 0.259, 0.208),
		"lines": [
			"Third shift at the plant. Cough came free with the job.",
			"Whole yard is scrap now. Used to be four hundred of us in there.",
			"You want work, talk to the depot. You want money, do not.",
		],
	},
	{
		"id": "otis", "name": "OTIS", "role": ROLE_WANDER,
		"route": [Vector2(1848, 200), Vector2(1848, 1600)],
		"speed": 34.0, "pause": 2.0, "hours": Vector2(6, 20),
		"color": Color(0.400, 0.427, 0.400), "accent": Color(0.251, 0.259, 0.251),
		"lines": [
			"I walk this street twice a day. Nothing ever changes on it.",
			"Dock Street is the line. Flats that side, works this side.",
			"Watch the trucks. They do not watch you.",
		],
	},
	{
		"id": "shay", "name": "SHAY", "role": ROLE_WANDER,
		"route": [Vector2(2100, 960), Vector2(3300, 960)],
		"speed": 33.0, "pause": 2.2, "hours": Vector2(8, 19),
		"color": Color(0.545, 0.451, 0.322), "accent": Color(0.278, 0.259, 0.231),
		"lines": [
			"Foreman says one more month. He said that last winter.",
			"Smell that? That is the tank farm. You get used to it.",
			"Everything here runs on somebody owing somebody.",
		],
	},
	{
		"id": "gus", "name": "GUS", "role": ROLE_WANDER,
		"route": [Vector2(2000, 2224), Vector2(3300, 2224)],
		"speed": 25.0, "pause": 4.4, "hours": Vector2(7, 17),
		"color": Color(0.475, 0.416, 0.290), "accent": Color(0.282, 0.251, 0.212),
		"lines": [
			"Forty years on the line and they gave me a clock.",
			"Division Avenue. Good name. Right idea.",
			"Nothing gets built here any more. Only moved.",
		],
	},
	{
		"id": "nora", "name": "NORA", "role": ROLE_WANDER,
		"route": [Vector2(3620, 960), Vector2(4900, 960)],
		"speed": 36.0, "pause": 1.8, "hours": Vector2(9, 22),
		"color": Color(0.435, 0.475, 0.596), "accent": Color(0.243, 0.259, 0.310),
		"lines": [
			"Rent downtown is a joke. The punchline is me.",
			"Everyone here is late for something.",
			"The clinic is the only place in this city that answers the phone.",
		],
	},
	{
		"id": "trev", "name": "TREV", "role": ROLE_WANDER,
		"route": [Vector2(3620, 1792), Vector2(4900, 1792)],
		"speed": 32.0, "pause": 2.6, "hours": Vector2(10, 23),
		"color": Color(0.502, 0.416, 0.545), "accent": Color(0.259, 0.239, 0.290),
		"lines": [
			"I know a guy who knows a guy. That is the whole economy.",
			"Market square on a weekday. Dead as anything.",
			"You are not from downtown. It shows.",
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
			"The fountain has been dry twice this month. Nobody at city hall answers.",
			"Quiet down here. That is what I pay the taxes for.",
			"You are a long way from the Flats, friend.",
		],
	},
	{
		"id": "abel", "name": "ABEL", "role": ROLE_WANDER,
		"route": [Vector2(-200, 2352), Vector2(1700, 2352)],
		"speed": 30.0, "pause": 2.8, "hours": Vector2(8, 20),
		"color": Color(0.529, 0.510, 0.451), "accent": Color(0.290, 0.282, 0.259),
		"lines": [
			"Third window on the left, and bring two forms of everything.",
			"I have been to every office on this avenue. Twice.",
			"They moved the registry again. Nobody knows where.",
		],
	},
	{
		"id": "imani", "name": "IMANI", "role": ROLE_WANDER,
		"route": [Vector2(900, 3536), Vector2(1780, 3536)],
		"speed": 29.0, "pause": 3.0, "hours": Vector2(8, 19),
		"color": Color(0.596, 0.529, 0.400), "accent": Color(0.310, 0.290, 0.251),
		"lines": [
			"School board meets Tuesdays. Nobody comes.",
			"That plaza cost more than the school it faces.",
			"Careful who sees you down here in the daytime.",
		],
	},
	{
		"id": "elder", "name": "MRS ELDER", "role": ROLE_WANDER,
		"route": [Vector2(2100, 2928), Vector2(3400, 2928)],
		"speed": 22.0, "pause": 5.0, "hours": Vector2(9, 18),
		"color": Color(0.796, 0.769, 0.706), "accent": Color(0.400, 0.376, 0.361),
		"lines": [
			"We have a committee about people like you walking up here.",
			"Lovely day. Do move along.",
			"The gardener comes Tuesdays. You are not the gardener.",
		],
	},
	{
		"id": "harold", "name": "HAROLD", "role": ROLE_WANDER,
		"route": [Vector2(2100, 3664), Vector2(3400, 3664)],
		"speed": 23.0, "pause": 4.8, "hours": Vector2(9, 18),
		"color": Color(0.741, 0.706, 0.639), "accent": Color(0.376, 0.365, 0.337),
		"lines": [
			"Bought this place before the boulevard went in. Best decision I made.",
			"The club has a waiting list. It has had one since 1974.",
			"You want the Flats. Straight down, then keep going.",
		],
	},
	{
		"id": "celia", "name": "CELIA", "role": ROLE_WANDER,
		"route": [Vector2(4248, 2500), Vector2(4248, 3900)],
		"speed": 27.0, "pause": 3.4, "hours": Vector2(10, 19),
		"color": Color(0.769, 0.706, 0.671), "accent": Color(0.396, 0.365, 0.353),
		"lines": [
			"Hill Drive is private above the boulevard. Officially.",
			"I walk this every morning. I have never met a neighbour.",
			"If you are selling something, the answer is no. Probably.",
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
static func random_line(entry: Dictionary) -> String:
	var lines: Array = entry.get("lines", [])
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])

## Se a quest'ora è per strada. `hours` può scavallare la mezzanotte
## (es. 22-4), quindi i due casi vanno distinti.
static func is_out_at(entry: Dictionary, time_of_day: float) -> bool:
	var span: Vector2 = entry.get("hours", Vector2(0, 24))
	if is_equal_approx(span.x, span.y):
		return true
	if span.x < span.y:
		return time_of_day >= span.x and time_of_day < span.y
	return time_of_day >= span.x or time_of_day < span.y
