class_name Prestige
extends RefCounted

## Il prestigio dell'organizzazione: quanto conta nel giro.
##
## Esiste solo da quando l'attività ha un nome (`SaveData.org_name`): prima si
## è un ragazzo che vende erba, non un'organizzazione, e non c'è niente da
## misurare. Il nome lo si dà al primo assunto, quando Brian lo chiede — vedi
## `GameState._check_milestones()`.
##
## **Come si guadagnano i punti non è ancora deciso.** Qui c'è solo la scala:
## i livelli, quanti punti servono per ognuno, e i conti per mostrarla
## nell'HUD (`scripts/ui/prestige_badge.gd`). Chi darà i punti chiamerà `add()`.

## I livelli, dal primo. `need` sono i punti per passare al successivo: l'ultimo
## livello non ne ha bisogno, ma ne tiene uno lo stesso perché la barra ha
## bisogno di una scala anche lì.
##
## Per ora c'è solo il primo. Gli altri si aggiungono qui sotto, in ordine, e
## HUD e conti li seguono da soli.
const LEVELS := [
	{"name": "PRESTIGE_ROOKIES", "need": 100},
]

## Vero se il prestigio va mostrato: cioè se l'organizzazione ha un nome.
static func active(data: SaveData) -> bool:
	return data != null and not data.org_name.is_empty()

## L'indice del livello raggiunto, e quanti punti ci sono dentro al livello.
static func level(data: SaveData) -> int:
	var points := data.prestige
	for i in LEVELS.size():
		var need := int(LEVELS[i]["need"])
		if points < need or i == LEVELS.size() - 1:
			return i
		points -= need
	return LEVELS.size() - 1

## La chiave del nome del livello attuale.
static func level_name(data: SaveData) -> String:
	return str(LEVELS[level(data)]["name"])

## Quanto è piena la barra del livello attuale, 0-1.
static func progress(data: SaveData) -> float:
	var points := data.prestige
	var idx := level(data)
	for i in idx:
		points -= int(LEVELS[i]["need"])
	return clampf(float(points) / float(LEVELS[idx]["need"]), 0.0, 1.0)

## Aggiunge (o toglie) punti. Non scende sotto zero.
static func add(data: SaveData, points: int) -> void:
	data.prestige = maxi(0, data.prestige + points)
