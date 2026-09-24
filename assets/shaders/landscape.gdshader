shader_type canvas_item;

// Il paesaggio intorno alla città: colline coi boschi subito fuori dall'ultimo
// isolato, poi le montagne, sempre più alte e più velate di foschia fino al
// bordo della mappa. È quello che dice "qui finisce il mondo" senza un muro.
//
// **È un rilievo, non un disegno.** Ogni punto ha una quota (`quota()`), e da
// quella viene tutto il resto: il colore (prato, bosco, roccia, neve), la luce
// (i versanti a nord-ovest illuminati, gli altri in ombra, come gli edifici e
// le strade) e soprattutto la forma. Il gioco si guarda da sud e dall'alto,
// come gli edifici di `render_buildings.py`: un punto alto H si vede H pixel
// più su di dove sta. Qui è lo stesso — per ogni pixel si cerca, scendendo
// verso sud, il primo pezzo di terreno abbastanza alto da arrivarci
// (`superficie()`). Così una montagna si alza davvero e copre la valle dietro,
// invece di essere un triangolo appoggiato per terra.
//
// **Perché uno shader e non un render.** La cornice è grande quanto la città
// più un chilometro per lato: un PNG a un pixel per pixel sarebbe da
// tredicimila di lato, e ridotto non reggerebbe la vista da vicino, dove un
// pixel di mondo è due di schermo. Calcolato dalla posizione, il paesaggio ha
// il dettaglio che serve a ogni zoom, non si ripete e non pesa niente.
//
// **Perché le quote non entrano mai in città.** Una quota è al massimo
// `SPORGENZA` volte la distanza dal bordo della città, quindi nessuna cima,
// proiettata verso l'alto, arriva sopra all'ultimo isolato. È quello che
// permette di disegnare questo strato SOPRA al terreno della città senza
// coprirne niente: dentro alla città non c'è mai terreno da mostrare, e il
// pixel si scarta.

// Il rumore: un fbm morbido per colline e boschi, uno a creste per le
// montagne. Sono `NoiseTexture2D` senza cuciture, create da `city_ground.gd`.
uniform sampler2D colline : filter_linear, repeat_enable;
uniform sampler2D creste : filter_linear, repeat_enable;

// La città (x, y, larghezza, altezza) e le quattro strade che ne escono: nelle
// strade la quota va a zero (sono valli) e il pixel è trasparente, perché
// l'asfalto lo disegna già `city_ground.gd` sotto a questo strato.
uniform vec4 citta;
uniform vec4 strade[4];
// Quanto è profonda la cornice (`CityMap.FRAME_DEPTH`).
uniform float profondita = 1024.0;
// La quota più alta, in pixel di mondo.
uniform float alt_max = 560.0;

const float SPORGENZA = 0.55;
const int PASSI = 44;

// Prato, bosco, roccia, neve: tre toni per ciascuno, dall'ombra alla luce.
// Il prato è vicino al verde dei quartieri, così il bordo della città sfuma
// nella campagna invece di finire con uno scalino di colore.
const vec3 PRATO_0 = vec3(0.235, 0.318, 0.180);
const vec3 PRATO_1 = vec3(0.314, 0.412, 0.224);
const vec3 PRATO_2 = vec3(0.412, 0.510, 0.275);
const vec3 SECCO_1 = vec3(0.447, 0.459, 0.271);
const vec3 BOSCO_0 = vec3(0.106, 0.180, 0.129);
const vec3 BOSCO_1 = vec3(0.157, 0.259, 0.169);
const vec3 BOSCO_2 = vec3(0.231, 0.353, 0.212);
const vec3 ROCCIA_0 = vec3(0.290, 0.271, 0.259);
const vec3 ROCCIA_1 = vec3(0.439, 0.408, 0.369);
const vec3 ROCCIA_2 = vec3(0.580, 0.549, 0.498);
const vec3 NEVE_0 = vec3(0.596, 0.643, 0.710);
const vec3 NEVE_1 = vec3(0.788, 0.820, 0.855);
const vec3 NEVE_2 = vec3(0.925, 0.937, 0.945);
const vec3 SCARPATA = vec3(0.420, 0.384, 0.325);
// La foschia della distanza: è lei a dire che le ultime cime sono lontane.
const vec3 FOSCHIA = vec3(0.553, 0.620, 0.690);

varying vec2 mondo;

void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float caso(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Quanto `p` sta fuori dalla città: zero dentro, poi la distanza dal bordo.
// Agli angoli è la distanza vera e non la maggiore delle due, così le colline
// girano l'angolo invece di fare uno spigolo a novanta gradi.
float fuori(vec2 p) {
	vec2 a = citta.xy - p;
	vec2 b = p - (citta.xy + citta.zw);
	return length(max(max(a, b), vec2(0.0)));
}

float dal_rettangolo(vec2 p, vec4 r) {
	vec2 d = abs(p - (r.xy + r.zw * 0.5)) - r.zw * 0.5;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float dalla_strada(vec2 p) {
	float v = 1e9;
	for (int i = 0; i < 4; i++) {
		v = min(v, dal_rettangolo(p, strade[i]));
	}
	return v;
}

// La quota di un punto, in pixel di mondo.
float quota(vec2 p) {
	float d = fuori(p);
	if (d <= 0.0) {
		return 0.0;
	}
	float t = d / profondita;
	float c = texture(colline, p / 4096.0).r;
	float r = texture(creste, p / 5120.0 + vec2(0.37, 0.11)).r;
	// Le colline: basse e morbide, cominciano subito fuori città.
	float h = smoothstep(0.0, 0.32, t) * (0.05 + 0.20 * c);
	// Le montagne: dalla metà della cornice in poi, sempre più alte verso il
	// bordo. Le creste danno le catene, le colline le rendono irregolari.
	h += smoothstep(0.22, 0.90, t) * (0.20 + 0.80 * r) * (0.65 + 0.45 * c);
	// Le strade passano in fondo a una valle: la quota si spegne avvicinandosi.
	h *= smoothstep(40.0, 520.0, dalla_strada(p));
	return min(h * alt_max, d * SPORGENZA);
}

// Il terreno che si vede nel pixel `p`: quanto più a sud sta (0 = proprio lì).
// Si scende da sud verso il pixel e ci si ferma al primo punto abbastanza alto
// da arrivarci — il primo, perché è quello più vicino a chi guarda.
float superficie(vec2 p) {
	float passo = alt_max / float(PASSI);
	float trovato = 0.0;
	for (int i = PASSI; i > 0; i--) {
		float t = float(i) * passo;
		if (quota(p + vec2(0.0, t)) >= t) {
			trovato = t;
			break;
		}
	}
	if (trovato <= 0.0) {
		return 0.0;
	}
	// Rifinitura: fra `trovato` (arriva) e un passo più a sud (non arriva).
	float lo = trovato;
	float hi = trovato + passo;
	for (int k = 0; k < 5; k++) {
		float m = (lo + hi) * 0.5;
		if (quota(p + vec2(0.0, m)) >= m) {
			lo = m;
		} else {
			hi = m;
		}
	}
	return lo;
}

vec3 tono(vec3 a, vec3 b, vec3 c, float luce, float ombra) {
	// Tre tinte piatte a soglia, non una sfumatura: è pixel art, non un
	// rilievo cartografico.
	if (luce < ombra) {
		return a;
	}
	return luce < 0.80 ? b : c;
}

void fragment() {
	vec2 p = floor(mondo) + 0.5;
	if (fuori(p) <= 0.0) {
		discard;
	}
	// Quanti pixel di mondo per pixel di schermo: sopra i tre, i singoli alberi
	// sono più piccoli di un pixel e brulicherebbero muovendo la camera.
	float scala = fwidth(mondo.x);

	float t = superficie(p);
	vec2 q = p + vec2(0.0, t);
	float strada = dalla_strada(q);
	if (strada <= 0.0) {
		// L'asfalto è sotto, in `city_ground.gd`.
		discard;
	}

	float h = quota(q);
	float e = 3.0;
	float hx = quota(q + vec2(e, 0.0)) - quota(q - vec2(e, 0.0));
	float hy = quota(q + vec2(0.0, e)) - quota(q - vec2(0.0, e));
	vec3 n = normalize(vec3(-hx, -hy, 2.0 * e));
	// La luce da nord-ovest e dall'alto, come in tutto il gioco.
	float luce = clamp(dot(n, normalize(vec3(-0.55, -0.65, 0.75))) * 1.25, 0.0, 1.0);
	float quota01 = h / alt_max;
	float fine = texture(colline, q / 700.0 + vec2(0.5, 0.2)).r;
	float macchia = texture(colline, q / 1800.0 + vec2(0.21, 0.63)).r;
	float pend = 1.0 - n.z;

	// La fascia del terreno: il retino fa da confine, così fra prato e roccia
	// non c'è una riga dritta ma un bordo sfrangiato.
	float retino = caso(floor(q)) * 0.06;
	vec3 colore;
	if (quota01 + fine * 0.10 - retino > 0.78 && pend < 0.55) {
		colore = tono(NEVE_0, NEVE_1, NEVE_2, luce, 0.42);
	} else if (quota01 + fine * 0.12 + pend * 0.35 - retino > 0.42) {
		colore = tono(ROCCIA_0, ROCCIA_1, ROCCIA_2, luce, 0.42);
	} else {
		vec3 medio = mix(PRATO_1, SECCO_1, smoothstep(0.55, 0.75, macchia) * 0.7);
		// Il prato ha l'ombra piu' corta della roccia: su colline basse, con la
		// soglia della roccia, ogni gobba diventava una macchia scura e il
		// prato sembrava una tuta mimetica.
		colore = tono(PRATO_0, medio, PRATO_2, luce, 0.24);
		// I boschi: macchie sui versanti, non sul fondovalle delle strade.
		float bosco = smoothstep(0.46, 0.60, macchia) * step(0.02, quota01)
			* smoothstep(60.0, 160.0, strada) * (1.0 - smoothstep(0.34, 0.44, quota01));
		if (scala < 3.0) {
			// Un albero per cella, spostato a caso dentro alla cella.
			vec2 cella = floor(q / 15.0);
			vec2 centro = (cella + 0.3 + 0.4 * vec2(caso(cella), caso(cella + 7.3))) * 15.0;
			float raggio = 4.5 + 2.2 * caso(cella + 3.1);
			vec2 dv = q - centro;
			bool c_e = caso(cella + 1.7) < bosco * 1.3;
			if (c_e && length(dv) < raggio) {
				float lato = (dv.x + dv.y) / raggio;
				colore = lato < -0.45 ? BOSCO_2 : (lato < 0.35 ? BOSCO_1 : BOSCO_0);
			} else if (c_e && length(dv - vec2(2.0, 2.5)) < raggio) {
				// L'ombra dell'albero, a sud-est: è quella che lo stacca dal prato.
				colore = mix(colore, BOSCO_0, 0.55);
			}
		} else {
			colore = mix(colore, BOSCO_1, bosco * 0.75);
		}
		// Il ciglio della strada: una fascia di terra battuta.
		if (strada < 10.0) {
			colore = SCARPATA;
		}
	}

	// La foschia sale con la distanza dalla città: le ultime creste sono
	// sbiadite, ed è questo a farle leggere come lontane e non come un muro.
	float d = fuori(q) / profondita;
	float velo = smoothstep(0.45, 1.0, d) * 0.62;
	colore = mix(colore, FOSCHIA, velo);
	COLOR = vec4(colore, 1.0);
}
