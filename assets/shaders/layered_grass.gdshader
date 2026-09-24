shader_type canvas_item;

// L'erba a strati: file di ciuffi sovrapposte, ognuna col bordo seghettato,
// come un prato dipinto a campiture e non fatto di fili.
//
// **Come si legge la profondita'.** Il prato e' una pila di file orizzontali,
// una ogni `riga` pixel. Ogni fila ha il bordo alto fatto di due cose: dei
// lobi larghi e morbidi (le chiazze) e sopra una dentellatura fitta (le foglie).
// Le file piu' in basso stanno davanti e coprono quelle dietro: per ogni pixel
// vince la fila piu' bassa il cui bordo e' gia' salito fin li'. Il resto sono
// due ritocchi: la punta di ogni fila piu' chiara, e la fila dietro appena
// velata sopra quella davanti. Il velo e' leggero apposta: una riga scura sotto
// ogni fila faceva sembrare il prato disegnato a contorni.
//
// Un materiale solo copre piu' prati: il bordo alto di ognuno arriva nella UV
// dei suoi vertici (`UV.x`), cosi' ogni isolato comincia col suo bordo
// seghettato. Le tinte cambiano per quartiere: le sceglie `layered_grass.gd`.
//
// **Cosa gli arriva da fuori** (lo scrive `layered_grass.gd` a ogni frame):
// - `impronte`: dove sta camminando qualcuno, e le impronte appena lasciate
//   che si stanno rialzando. Li' le foglie si schiacciano e si aprono.
// - `luci`: i lampioni accesi vicini. Dentro la loro luce l'erba si schiarisce
//   a gradini, e resta accesa nel buio come le pozze dei lampioni stessi.
// - `ambiente`: la luce del `CanvasModulate`, per tenere accese le parti
//   illuminate (vedi `Daylight.emissive()`).
// - `vento` e `sole`: quanto ondeggiano le punte e quanto brillano.

uniform vec4 fondo : source_color = vec4(0.200, 0.270, 0.120, 1.0);
uniform vec4 scuro : source_color = vec4(0.280, 0.370, 0.150, 1.0);
uniform vec4 medio : source_color = vec4(0.310, 0.410, 0.165, 1.0);
uniform vec4 chiaro : source_color = vec4(0.340, 0.450, 0.180, 1.0);
uniform vec4 punta : source_color = vec4(0.420, 0.540, 0.220, 1.0);
uniform vec4 stelo : source_color = vec4(0.190, 0.260, 0.100, 1.0);
// Il colore che prende l'erba dentro la luce di un lampione al sodio.
uniform vec4 illuminata : source_color = vec4(0.500, 0.660, 0.220, 1.0);

// Distanza fra una fila e l'altra, in pixel di mondo. Un personaggio e' alto
// una quarantina: a dodici ci stanno tre file dai piedi alla testa.
uniform float riga = 12.0;
// Quanto salgono i lobi e i denti sopra la base della fila.
uniform float lobi = 15.0;
uniform float denti = 2.5;
uniform float passo_denti = 3.5;

uniform float vento = 0.3;
uniform float sole = 1.0;

uniform vec3 ambiente = vec3(1.0);
// x, y, forza (0-1).
uniform vec3 luci[8];
uniform int n_luci = 0;
// Raggi della luce che spande un lampione sull'erba. Piu' larga della pozza
// che disegna il lampione: sull'asfalto la luce si ferma, sul prato si
// sparpaglia fra le foglie.
uniform vec2 alone = vec2(118.0, 54.0);

// x, y, forza (0-1): 1 sotto i piedi, poi scende mentre l'erba si rialza.
uniform vec3 impronte[32];
uniform int n_impronte = 0;
uniform vec2 piede = vec2(16.0, 9.0);

// Di quanto scorre il prato in x, in pixel del nodo. In citta' resta a zero;
// lo usa il filmato del furgone, dove il mondo scorre e il furgone sta fermo.
uniform float scorrimento = 0.0;

varying vec2 mondo;
// Il bordo alto del prato a cui appartiene il pixel, in y di mondo.
varying float inizio;

void vertex() {
	// Coordinate del nodo e non del canvas: in citta' il nodo sta a (0,0) e le
	// due coincidono; nel filmato il nodo e' ingrandito, e cosi' i pixel
	// dell'erba si ingrandiscono con lui invece di restare minuscoli.
	mondo = VERTEX + vec2(scorrimento, 0.0);
	inizio = UV.x;
}

float caso(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(caso(i), caso(i + vec2(1.0, 0.0)), f.x),
		mix(caso(i + vec2(0.0, 1.0)), caso(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

// Quanto e' schiacciata l'erba in un punto, 0-1, e da che parte si piega (x).
vec2 calpestio(vec2 p) {
	float schiaccia = 0.0;
	float piega = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= n_impronte) {
			break;
		}
		vec3 imp = impronte[i];
		// Un po' piu' in basso dei piedi: a coprire i piedi sono le file che
		// hanno la base li' sotto e le foglie che salgono fino alle caviglie.
		vec2 d = p - imp.xy - vec2(0.0, 4.0);
		float r = length(d / piede);
		float f = imp.z * (1.0 - smoothstep(0.35, 1.0, r));
		schiaccia = max(schiaccia, f);
		piega += sign(d.x) * f;
	}
	return vec2(schiaccia, clamp(piega, -1.0, 1.0));
}

// Il bordo alto della fila `k` alla colonna `x`: sotto questa y la fila c'e'.
float cima(float k, float x) {
	float base = k * riga;
	// Letta a meta' altezza della fila e non alla base: e' li' che la fila si
	// vede, la base e' quasi sempre coperta da quella davanti.
	vec2 pestata = calpestio(vec2(x, base - lobi * 0.6));

	// I lobi non si muovono col vento: se ondeggiassero anche loro sembrerebbe
	// il terreno a scorrere, non l'erba a piegarsi.
	float lobo = rumore(vec2(x * 0.022 + k * 17.3, k * 3.1)) * 0.65
		+ rumore(vec2(x * 0.006 + k * 5.7, k * 1.7)) * 0.35;

	// I denti si': la fase dipende dalla fila, cosi' il prato non si piega tutto
	// insieme come un telo. Dove qualcuno cammina si aprono da parte.
	float onda = sin(TIME * 1.1 + k * 0.73 + x * 0.021) * vento * 2.2;
	float xs = x - onda - pestata.y * 2.5;
	float i = floor(xs / passo_denti);
	float f = fract(xs / passo_denti);
	float picco = 0.25 + 0.5 * caso(vec2(i, k));
	float dente = f < picco ? f / picco : (1.0 - f) / (1.0 - picco);
	float alto = denti * (0.45 + 0.9 * caso(vec2(i, k + 9.1)));

	float salita = lobo * lobi * (1.0 - 0.85 * pestata.x) + dente * alto * (1.0 - pestata.x);
	return base - salita;
}

// La tinta di una fila in un punto: poche campiture piatte, scelte a soglia.
vec3 tinta(float k, float x, float y) {
	// Il confine fra due campiture non cade su una colonna dritta: si sposta
	// con la y, cosi' dentro a una fila il cambio di tono e' una linea storta.
	x += (rumore(vec2(y * 0.11, k * 2.3)) - 0.5) * 70.0;
	float v = rumore(vec2(x * 0.005 + k * 0.9, k * 0.37)) * 0.55
		+ rumore(vec2(x * 0.0018, k * 0.09 + 3.0)) * 0.30
		+ caso(vec2(k, 7.0)) * 0.15;
	if (v < 0.36) {
		return scuro.rgb;
	} else if (v < 0.55) {
		return medio.rgb;
	}
	return chiaro.rgb;
}

// Qualche ciuffo scuro sparso sopra, come nel disegno: tre steli a ventaglio.
float ciuffo(vec2 p) {
	vec2 cella = floor(p / vec2(41.0, 29.0));
	if (caso(cella + 41.0) > 0.16) {
		return 0.0;
	}
	vec2 centro = cella * vec2(41.0, 29.0)
		+ vec2(4.0 + caso(cella + 3.0) * 33.0, 6.0 + caso(cella + 8.0) * 20.0);
	vec2 l = p - floor(centro);
	if (l.y > 0.0 || l.y < -6.0) {
		return 0.0;
	}
	float ondeggia = sin(TIME * 1.4 + cella.x) * vento * 0.35;
	for (int s = -1; s <= 1; s++) {
		float pendenza = float(s) * 0.55 + ondeggia;
		if (abs(l.x - l.y * -pendenza) < 0.6 && l.y >= -6.0 + abs(float(s))) {
			return 1.0;
		}
	}
	return 0.0;
}

void fragment() {
	// Il colore del vertice: bianco in citta', la luce dell'ora nel filmato, che
	// non ha un `CanvasModulate` a tingerlo.
	vec4 tinta_vertice = COLOR;
	vec2 p = floor(mondo) + 0.5;

	// La fila piu' avanti che copre il pixel: si parte dalla piu' bassa che
	// potrebbe arrivarci e si risale.
	float salita_max = lobi + denti * 1.35;
	float k_basso = floor((p.y + salita_max) / riga);
	float k_alto = floor(p.y / riga);
	float k = k_alto;
	float c = cima(k_alto, p.x);
	for (float j = k_basso; j > k_alto; j -= 1.0) {
		float cj = cima(j, p.x);
		if (cj <= p.y) {
			k = j;
			c = cj;
			break;
		}
	}
	// Sopra alla prima fila non c'e' erba: il prato comincia col suo bordo
	// seghettato e non con il taglio dritto del rettangolo.
	bool vuoto = k * riga < inizio + riga || c > p.y;

	vec3 col = tinta(k, p.x, p.y);
	float davanti = cima(k + 1.0, p.x) - p.y;
	float dalla_cima = p.y - c;

	if (dalla_cima < 1.0) {
		col = mix(col, punta.rgb, 0.45 + 0.4 * sole);
	} else if (davanti < 2.0) {
		// La fila dietro, appena sopra le foglie di quella davanti: un velo
		// d'ombra, non un contorno.
		col = mix(col, fondo.rgb, 0.35);
	}

	// Pestata: un filo piu' scura, e' erba piegata che mostra il rovescio.
	float pestata = calpestio(p).x;
	col = mix(col, fondo.rgb, floor(pestata * 3.0) / 3.0 * 0.6);

	if (ciuffo(p) > 0.5) {
		col = stelo.rgb;
	}

	// La luce dei lampioni, a gradini come le campiture: una sfumatura liscia
	// sarebbe l'unica cosa del prato a non sembrare dipinta.
	float luce = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= n_luci) {
			break;
		}
		vec3 l = luci[i];
		float r = length((p - l.xy) / alone);
		luce += l.z * (1.0 - smoothstep(0.15, 1.0, r));
	}
	luce = floor(clamp(luce, 0.0, 1.0) * 4.0) / 4.0;
	if (luce > 0.0) {
		// Moltiplicata e non sostituita: dentro la luce le file si devono leggere
		// ancora, anzi meglio, come nella pozza di un faro sul prato.
		vec3 accesa = col * (illuminata.rgb / chiaro.rgb) * 0.95;
		if (dalla_cima < 1.0) {
			accesa = mix(accesa, vec3(0.72, 0.80, 0.36), 0.6);
		}
		// Pre-divisa per la luce dell'ambiente, come `Daylight.emissive()`: il
		// `CanvasModulate` la rimoltiplica e resta accesa dentro alla notte.
		vec3 emessa = accesa / max(ambiente, vec3(0.2));
		col = mix(col, emessa, luce * 0.85);
	}

	COLOR = vuoto ? vec4(0.0) : vec4(col, 1.0) * tinta_vertice;
}
