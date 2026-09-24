class_name AirportPlan
extends RefCounted

## L'aeroporto come dati: dove stanno piste, raccordi e piazzale, dove sono
## parcheggiati gli aerei, e la giornata dell'aeroporto — l'aereo di linea che
## atterra e va all'hangar, la scala e il trattorino che lo raggiungono, il
## bimotore che decolla ed esce dalla mappa.
##
## ## La giornata non e' simulata
##
## Come la luce (`Daylight`) e la crescita delle piante: non c'e' niente che
## avanza fotogramma per fotogramma e si salva. Si guarda che ore sono e si
## ricava dove sta ogni mezzo (`pose()`). Chi entra in strada a meta' mattina
## trova l'aereo gia' a meta' raccordo; chi dorme fino a sera lo trova fermo
## all'hangar con la scala accostata; ricaricare una partita non sposta niente.
##
## La giornata e' fatta cosi':
##
## - dalle `START_HOUR` parte la sequenza, lunga un paio di minuti veri (a
##   quattro minuti di gioco al secondo sono qualche ora sull'orologio);
## - finita, tutto resta com'e' per il resto della giornata e la notte;
## - fra `RESET_FROM` e `RESET_TO` si torna alla mattina: aereo di linea, scala
##   e trattorino svaniscono, i mezzi ricompaiono al deposito, il bimotore al
##   suo posto. In dissolvenza, e alle tre di notte, quando e' meno probabile
##   che qualcuno stia guardando.
##
## I tempi della sequenza sono in secondi veri e non in ore: e' una cosa che si
## guarda mentre succede, come il fulmine del temporale, e le velocita' degli
## aerei hanno senso in pixel al secondo.

## Ore di gioco.
const START_HOUR := 9.0
const RESET_FROM := 3.0
const RESET_TO := 3.6
## Quanti secondi veri dura un'ora di gioco (`GameState.GAME_MINUTES_PER_SECOND`).
const SECONDS_PER_HOUR := 15.0

# --- Il disegno dell'aeroporto ----------------------------------------------

## Il piazzale di cemento davanti agli hangar.
const APRON := Rect2(960, 7560, 1680, 230)
## Le piste: estremi dell'asse e larghezza. La principale va da ovest a est;
## l'altra la incrocia in diagonale, da nord-est a sud-ovest.
const RUNWAY_MAIN := [Vector2(960, 8250), Vector2(2560, 8250), 80.0]
const RUNWAY_CROSS := [Vector2(2230, 7800), Vector2(1040, 8390), 64.0]
## I raccordi: polilinee larghe `TAXI_WIDTH`.
const TAXI_WIDTH := 36.0
const TAXIWAYS := [
	[Vector2(2450, 7790), Vector2(2450, 8212)],
	[Vector2(1350, 7790), Vector2(1350, 7880), Vector2(2110, 7880), Vector2(2222, 7806)],
]
const HELIPAD := Vector2(1060, 8010)

## Gli aerei parcheggiati che non si muovono mai: sprite, posizione, direzione
## del muso in gradi (0 = est, 90 = sud).
const PARKED := [
	["elica_gialla", Vector2(1062, 7690), 90.0],
	["elica_viola", Vector2(1592, 7692), 90.0],
	["cartoon_giallo", Vector2(2262, 8052), 205.0],
	["elicottero", HELIPAD, 0.0],
]

## Dove si ferma l'aereo di linea: davanti all'hangar grande, col muso a
## ovest. Il portellone e' sul fianco sinistro, cioe' a sud, vicino al muso.
const JET_STAND := Vector2(1880, 7690)
## Il bimotore aspetta davanti all'hangar piccolo, col muso verso le piste.
const TWIN_STAND := Vector2(1350, 7700)
## Il deposito dei mezzi, accanto alla torre.
const STAIRS_DEPOT := Vector2(2600, 7640)
const TUG_DEPOT := Vector2(2600, 7732)

## Quanti fotogrammi ha la scala (scala chiusa -> tutta alzata).
const STAIRS_FRAMES := 6

## Gli attori della sequenza.
const ACTORS := ["jet", "twin", "stairs", "tug"]

# --- La sequenza, costruita una volta ----------------------------------------

static var _tracks := {}
static var _end := 0.0

## Quanto dura la sequenza, in secondi veri.
static func duration() -> float:
	_build()
	return _end

## Quando comincia e finisce ogni tratto di ogni attore, in secondi: serve
## agli strumenti di scatto per fotografare i momenti giusti.
static func milestones() -> Dictionary:
	_build()
	var out := {}
	for actor: String in _tracks:
		var list: Array = []
		for leg: Dictionary in _tracks[actor]:
			list.append([str(leg["type"]), snappedf(float(leg["t0"]), 0.1), snappedf(float(leg["t1"]), 0.1)])
		out[actor] = list
	return out

## Dove sta un attore all'ora data, e come:
## `{"visible", "pos", "heading" (radianti), "alt" (px), "alpha", "frame"}`.
static func pose(actor: String, hour: float) -> Dictionary:
	_build()
	var track: Array = _tracks[actor]
	var h := fposmod(hour, 24.0)
	if h >= RESET_FROM and h < RESET_TO:
		return _reset_pose(actor, track, (h - RESET_FROM) / (RESET_TO - RESET_FROM))
	var t: float
	if h >= START_HOUR:
		t = (h - START_HOUR) * SECONDS_PER_HOUR
	elif h < RESET_FROM:
		t = INF
	else:
		t = -INF
	return _pose_at(actor, track, t)

## Il secondo della sequenza a quell'ora, o -1 fuori dalla sequenza. Serve a
## chi vuole sapere se sta succedendo qualcosa (gli strumenti di scatto).
static func seconds_at(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h < START_HOUR:
		return -1.0
	var t := (h - START_HOUR) * SECONDS_PER_HOUR
	return t if t <= duration() else -1.0

## L'ora a cui la sequenza e' al secondo `t`.
static func hour_at(t: float) -> float:
	return START_HOUR + t / SECONDS_PER_HOUR

static func _pose_at(actor: String, track: Array, t: float) -> Dictionary:
	var first: Dictionary = track[0]
	var last: Dictionary = track[track.size() - 1]
	if t < float(first["t0"]):
		var p := _leg_pose(first, float(first["t0"]))
		# L'aereo di linea la mattina non c'e' ancora: arriva da fuori.
		p["visible"] = actor != "jet"
		return p
	if t >= float(last["t1"]):
		var p := _leg_pose(last, float(last["t1"]))
		# Il bimotore, decollato, e' uscito dalla mappa.
		p["visible"] = actor != "twin"
		return p
	var held: Dictionary = first
	for leg: Dictionary in track:
		if t < float(leg["t0"]):
			return _leg_pose(held, float(held["t1"]))
		if t <= float(leg["t1"]):
			return _leg_pose(leg, t)
		held = leg
	return _leg_pose(last, float(last["t1"]))

## La notte: la sera svanisce, la mattina ricompare.
static func _reset_pose(actor: String, track: Array, k: float) -> Dictionary:
	var evening := _pose_at(actor, track, INF)
	var morning := _pose_at(actor, track, -INF)
	match actor:
		"jet":
			evening["alpha"] = 1.0 - k
			return evening
		"twin":
			morning["alpha"] = k
			return morning
	if k < 0.5:
		evening["alpha"] = 1.0 - k * 2.0
		return evening
	morning["alpha"] = k * 2.0 - 1.0
	return morning

static func _leg_pose(leg: Dictionary, t: float) -> Dictionary:
	var out := {"visible": true, "alpha": 1.0, "alt": 0.0, "frame": 0}
	var t0 := float(leg["t0"])
	var t1 := float(leg["t1"])
	var u := 0.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	match str(leg["type"]):
		"turn":
			out["pos"] = leg["pos"]
			out["heading"] = lerp_angle(float(leg["h0"]), float(leg["h1"]), smoothstep(0.0, 1.0, u))
			out["frame"] = int(leg.get("frame", 0))
		"frames":
			out["pos"] = leg["pos"]
			out["heading"] = float(leg["heading"])
			out["frame"] = int(round(lerpf(float(leg["f0"]), float(leg["f1"]), u)))
		_:
			# Velocita' che cambia in modo uniforme da v0 a v1: la strada fatta
			# e' v0*t + a*t^2/2.
			var v0 := float(leg["v0"])
			var v1 := float(leg["v1"])
			var dt := (t1 - t0) * u
			var acc := (v1 - v0) / maxf(t1 - t0, 0.001)
			var s := v0 * dt + 0.5 * acc * dt * dt
			var at := _along(leg["pts"], leg["cum"], s)
			out["pos"] = at[0]
			out["heading"] = at[1]
			var length: float = (leg["cum"] as PackedFloat32Array)[-1]
			var f := clampf(s / maxf(length, 0.001), 0.0, 1.0)
			out["alt"] = lerpf(float(leg["alt0"]), float(leg["alt1"]), pow(f, float(leg.get("alt_pow", 1.0))))
			out["frame"] = int(leg.get("frame", 0))
	return out

## Il punto a distanza `s` lungo la polilinea, e la direzione in cui si va.
static func _along(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Array:
	for i in range(1, pts.size()):
		if s <= cum[i] or i == pts.size() - 1:
			var seg := cum[i] - cum[i - 1]
			var k := 0.0 if seg <= 0.0 else clampf((s - cum[i - 1]) / seg, 0.0, 1.0)
			var d := pts[i] - pts[i - 1]
			return [pts[i - 1].lerp(pts[i], k), d.angle()]
	return [pts[0], 0.0]

# --- Il copione ---------------------------------------------------------------

static func _build() -> void:
	if not _tracks.is_empty():
		return
	var t := 0.0
	var jet: Array = []
	var main_y := (RUNWAY_MAIN[0] as Vector2).y
	# In volo da ovest, in discesa lungo l'asse della pista, fino a toccare
	# terra poco dopo la soglia. `alt_pow` sotto 1: la discesa e' ripida
	# all'inizio e si appiana verso la pista, che e' la richiamata.
	t = _move(jet, [Vector2(-1900, main_y), Vector2(1010, main_y)], t, 240.0, 215.0, 330.0, 0.0, 0.8)
	# La corsa di frenata sulla pista.
	t = _move(jet, [Vector2(1010, main_y), Vector2(2330, main_y)], t, 215.0, 42.0)
	# Il rullaggio: fuori dalla pista sul raccordo est, su al piazzale e a
	# ovest fino all'hangar grande.
	t = _move(jet, _smooth([Vector2(2330, main_y), Vector2(2450, main_y - 40), Vector2(2450, 7790),
		Vector2(2440, 7700), Vector2(2300, 7690), Vector2(2010, JET_STAND.y)]), t, 42.0, 75.0)
	t = _move(jet, [Vector2(2010, JET_STAND.y), JET_STAND], t, 75.0, 0.0)

	# I mezzi partono quando l'aereo e' fermo.
	t += 2.5
	var stairs: Array = []
	var tug: Array = []
	var door := JET_STAND + Vector2(-128, 0)
	# Di corsa fin sotto all'aereo, poi l'accostata piano: frenare lungo tutto
	# il tragitto li faceva arrancare per mezzo minuto.
	var s_end := _move(stairs, _smooth([STAIRS_DEPOT, Vector2(STAIRS_DEPOT.x, 7860),
		Vector2(door.x + 60, 7860), Vector2(door.x, 7830)]), t, 110.0, 110.0)
	s_end = _move(stairs, [Vector2(door.x, 7830), Vector2(door.x, 7762)], s_end, 110.0, 0.0)
	# La scala si alza verso il portellone.
	stairs.append({"type": "frames", "t0": s_end + 0.6, "t1": s_end + 3.6, "pos": Vector2(door.x, 7762),
		"heading": -PI * 0.5, "f0": 0, "f1": STAIRS_FRAMES - 1})
	s_end += 3.6
	var g_end := _move(tug, _smooth([TUG_DEPOT, Vector2(TUG_DEPOT.x, 7885), Vector2(door.x - 20, 7885),
		Vector2(door.x - 66, 7850)]), t + 1.5, 120.0, 120.0)
	g_end = _move(tug, [Vector2(door.x - 66, 7850), Vector2(door.x - 66, 7792)], g_end, 120.0, 0.0)
	t = maxf(s_end, g_end) + 2.5

	# Il bimotore: giu' dal suo posto, a est sul raccordo sud, in testa alla
	# pista incrociata; si gira, rulla, decolla verso sud-ovest ed esce.
	var twin: Array = []
	var cross_a: Vector2 = RUNWAY_CROSS[0]
	var cross_b: Vector2 = RUNWAY_CROSS[1]
	var along := (cross_b - cross_a).normalized()
	var head := Vector2(2222, 7806)
	t = _move(twin, _smooth([TWIN_STAND, Vector2(1350, 7880), Vector2(2110, 7880), head]), t, 85.0, 35.0)
	var h0 := float(_leg_pose(twin[twin.size() - 1], t)["heading"])
	twin.append({"type": "turn", "t0": t, "t1": t + 3.5, "pos": head, "h0": h0, "h1": along.angle()})
	t += 4.0
	var lift := head + along * 760.0
	t = _move(twin, [head, lift], t, 0.0, 240.0)
	t = _move(twin, [lift, lift + along * 4200.0], t, 240.0, 300.0, 0.0, 520.0, 1.35)

	_tracks = {"jet": jet, "twin": twin, "stairs": stairs, "tug": tug}
	_end = t

## Un tratto di strada lungo la polilinea `pts`, da `v0` a `v1` px/s, con la
## quota da `alt0` a `alt1`. Restituisce il secondo in cui finisce.
static func _move(track: Array, pts: Array, t0: float, v0: float, v1: float,
		alt0 := 0.0, alt1 := 0.0, alt_pow := 1.0) -> float:
	var packed := PackedVector2Array(pts)
	var cum := PackedFloat32Array([0.0])
	for i in range(1, packed.size()):
		cum.append(cum[i - 1] + packed[i - 1].distance_to(packed[i]))
	var length := cum[cum.size() - 1]
	var t1 := t0 + 2.0 * length / maxf(v0 + v1, 0.001)
	track.append({"type": "move", "t0": t0, "t1": t1, "pts": packed, "cum": cum,
		"v0": v0, "v1": v1, "alt0": alt0, "alt1": alt1, "alt_pow": alt_pow})
	return t1

## Smussa gli spigoli di una polilinea (Chaikin, tre passate): i mezzi girano
## in curva invece di ruotare di colpo sul posto. Gli estremi restano dove
## sono, perche' sono i posti in cui ci si ferma.
static func _smooth(pts: Array) -> Array:
	var out: Array = pts
	for pass_ in 3:
		var next: Array = [out[0]]
		for i in range(out.size() - 1):
			var a: Vector2 = out[i]
			var b: Vector2 = out[i + 1]
			if i > 0:
				next.append(a.lerp(b, 0.25))
			if i < out.size() - 2:
				next.append(a.lerp(b, 0.75))
		next.append(out[out.size() - 1])
		out = next
	return out
