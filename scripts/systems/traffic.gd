class_name Traffic
extends RefCounted

## Si può attraversare adesso, o passa una macchina?
##
## È la domanda che si fa il protagonista quando arriva al cordolo, e la
## risposta è tutta qui dentro: un conto di tempi, non di distanze.
##
## ## Perché i tempi e non le distanze
##
## "C'è un'auto entro cento pixel" non dice niente: un'auto lenta a cento pixel
## la si passa davanti comodamente, una veloce a duecento no. Quello che conta è
## se l'auto e il pedone si troveranno **nello stesso punto nello stesso
## momento**, e per saperlo bastano due intervalli di tempo:
##
## - quando il pedone occupa la corsia — da quando entra nella fascia di
##   sicurezza a quando ne esce, camminando a passo suo;
## - quando la corsia è occupata dall'auto — dal muso alla coda, più la stessa
##   fascia di sicurezza davanti e dietro.
##
## Se i due intervalli si sovrappongono si aspetta; se no si passa. Questo fa
## venire fuori da solo il comportamento giusto senza scriverlo: si taglia la
## strada davanti a un'auto lontana, si lascia passare quella vicina, e dietro a
## una che è appena transitata si parte subito invece di restare fermi.
##
## ## Il verso conta, la corsia no
##
## Non si guarda "la strada", si guardano le singole auto: ognuna ha la sua
## corsia, il suo verso e la sua velocità. Un'auto che ha già superato il punto
## di attraversamento non ferma nessuno — è la differenza fra un pedone che
## guarda e uno che aspetta un semaforo che non c'è.
##
## ## Nessuno stallo
##
## Le auto frenano per chi sta **sulla carreggiata** (vedi `car.gd`), non per
## chi aspetta sul marciapiede: se frenassero anche per lui i due si
## fermerebbero a guardarsi per sempre, il pedone perché l'auto è lì e l'auto
## perché il pedone è lì. Chi aspetta al cordolo vede quindi sempre auto in
## movimento, e prima o poi il buco arriva.

## Gruppo dei veicoli che contano per un attraversamento. Ci stanno le auto del
## traffico; il furgone dei semi no, perché fa una cutscene e non un giro.
const GROUP := "traffic"

## Quanto si sta larghi da un'auto, in pixel: mezza carreggiata di margine
## davanti e dietro al mezzo, e altrettanto ai lati del pedone.
const CLEARANCE := 26.0

## Margini di prudenza, in secondi. Il primo è quanto prima del pedone può
## passare un'auto perché lui parta lo stesso, il secondo quanto dopo.
##
## Sono diversi apposta: passare **davanti** a un'auto che arriva è la cosa che
## fa sembrare un pedone incosciente, e infatti il margine più largo è quello.
const MARGIN_BEFORE := 1.1
const MARGIN_AFTER := 0.5

## Oltre questo tempo un'auto è troppo lontana per contare: senza, su una strada
## lunga si aspetterebbe un'auto che arriva fra venti secondi.
const HORIZON := 7.0

## Si può cominciare ad attraversare da `from` verso `to`?
##
## `cars` sono i nodi del gruppo — li passa chi chiama, così questa resta una
## funzione pura che si può provare senza mettere in piedi una città.
static func crossing_clear(cars: Array, from: Vector2, to: Vector2,
		walk_speed: float) -> bool:
	if walk_speed <= 0.0:
		return false
	for car in cars:
		if not is_instance_valid(car):
			continue
		if not _car_clear(car as Car, from, to, walk_speed):
			return false
	return true

## Questa singola auto lascia passare?
static func _car_clear(car: Car, from: Vector2, to: Vector2, walk_speed: float) -> bool:
	if car == null:
		return true
	var forward := car.lane_forward()
	# Dove il tragitto taglia la corsia di quest'auto. Se non la taglia —
	# l'attraversamento è su un'altra strada, o su un'altra carreggiata — questa
	# non ha voce in capitolo.
	var lane_axis := Vector2(0.0, 1.0) if car.lane_horizontal() else Vector2(1.0, 0.0)
	var span := (to - from).dot(lane_axis)
	if absf(span) < 0.001:
		return true
	var ratio := (car.lane_position() - from.dot(lane_axis)) / span
	if ratio < 0.0 or ratio > 1.0:
		return true
	var meeting := from.lerp(to, ratio)

	# Quando ci arriva il pedone, e quando ne è fuori. La fascia da liberare si
	# percorre con la sola componente PERPENDICOLARE alla corsia: attraversando
	# di sbieco si resta in mezzo alla strada più a lungo, ed è giusto che il
	# conto se ne accorga.
	var across := absf((to - from).normalized().dot(lane_axis))
	var enter := from.distance_to(meeting) / walk_speed
	var leave := enter + 2.0 * CLEARANCE / (walk_speed * maxf(across, 0.35))

	# Quando ci arriva l'auto, e quando ha finito di passare.
	var speed := maxf(car.lane_speed(), 1.0)
	var reach := (meeting - car.global_position).dot(forward)
	var half := car.lane_half_length() + CLEARANCE
	if reach + half < 0.0:
		return true  # è già passata
	var arrives := maxf(0.0, reach - half) / speed
	if arrives > HORIZON:
		return true
	var leaves := (reach + half) / speed
	# Sovrapposizione fra i due intervalli, allargata dai margini di prudenza.
	return arrives > leave + MARGIN_AFTER or leaves < enter - MARGIN_BEFORE
