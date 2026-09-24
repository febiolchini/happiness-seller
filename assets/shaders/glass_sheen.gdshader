shader_type canvas_item;

// Il sole che scorre sul vetro dei grattacieli.
//
// **Perche' uno shader e non dei fotogrammi.** Il riflesso cambia con l'ora, e
// l'ora cambia in continuazione: cotto dentro allo sprite vorrebbe dire una
// striscia di dodici disegni alti duemila pixel per ogni torre, decine di
// megabyte di texture, e comunque uno scatto ogni ora e mezza di gioco. Qui
// invece il disegno resta uno e il riflesso si calcola, quindi non pesa niente
// e non ha scalini.
//
// **Come sa dove riflettere.** Una maschera, renderizzata dalla stessa camera
// che ha fotografato la torre (`scripts_tools/blender_grattacieli.py`), in cui
// ogni faccia di vetro e' tinta secondo dove guarda:
//
//     rosso  = guarda a est (destra)      il sole ce l'ha addosso la mattina
//     verde  = guarda la strada (sud)     a mezzogiorno
//     blu    = guarda a ovest (sinistra)  la sera
//
// Le facce oblique portano i colori mescolati, perche' prendono luce in due
// momenti. Il nero — cemento, solette, basamento — non riflette niente.
//
// **Perche' non da' fastidio.** Tre cose lo tengono buono. Si somma, non
// sostituisce: il vetro resta il vetro disegnato e sopra ci arriva un velo.
// E' legato all'altezza del sole, quindi all'alba e al tramonto e' quasi
// niente e di notte non c'e'. E segue il meteo: sotto le nuvole sparisce,
// esattamente come spariscono le ombre portate della citta'.

// La maschera del vetro. `filter_nearest`: e' un dato, non un'immagine, e
// interpolarla mescolerebbe le orientazioni sui bordi fra una faccia e l'altra.
uniform sampler2D maschera : filter_nearest, hint_default_black;

// Dove sta il sole sull'orizzonte: +1 alba (est, a destra), -1 tramonto.
// Glielo passa `sun_glass.gd` da `Daylight.sun_across()`, lo stesso numero con
// cui la citta' gira le ombre.
uniform float sole_x = 0.0;
// Quanto e' alto: 0 sotto l'orizzonte, 1 a mezzogiorno.
uniform float sole_alto = 0.0;
// Quanto e' netta la luce: 1 col sereno, giu' fino a zero col cielo coperto.
uniform float nitidezza = 1.0;

uniform vec4 colore : source_color = vec4(1.0, 0.95, 0.84, 1.0);
// 0,16 e non 0,42. A 0,42 a mezzogiorno la facciata sud andava tutta al
// bianco: il vetro spariva e restava una sagoma accecante — il "fastidio" da
// evitare. Il riflesso deve farsi notare da chi guarda la torre, non da chi sta
// passando di li' per altro.
uniform float forza = 0.16;
// Larghezza della campana: quanto "resta accesa" una faccia mentre il sole si
// sposta. Stretta fa tre lampi separati, larga accende tutto insieme e il
// riflesso smette di muoversi.
uniform float apertura = 0.75;

float peso(float centro) {
	float d = (sole_x - centro) / apertura;
	return exp(-d * d);
}

void fragment() {
	vec3 m = texture(maschera, UV).rgb;
	// Ogni canale prende luce quando il sole e' dalla sua parte.
	float riflesso = m.r * peso(1.0) + m.g * peso(0.0) + m.b * peso(-1.0);
	// Piu' forte in alto che in basso. In cima il vetro ha davanti il cielo
	// aperto, in basso ha gli edifici di fronte: senza questo il velo e' una
	// patina uniforme su tutta la torre, e una patina uniforme si legge come
	// un errore di disegno invece che come un riflesso.
	riflesso *= mix(1.0, 0.45, UV.y);
	riflesso *= sole_alto * nitidezza * forza;
	// Moltiplicato per l'alpha: fuori dalla sagoma non deve comparire un velo
	// luminoso al posto del niente.
	COLOR.rgb += colore.rgb * riflesso * COLOR.a;
}
