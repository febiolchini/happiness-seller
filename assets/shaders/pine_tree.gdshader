shader_type canvas_item;

// Un abete delle colline, dipinto a palchi come l'erba a strati.
//
// Ogni albero e' un quadrilatero disegnato da `pine_trees.gd`. La UV porta la
// posizione del pixel dentro all'albero, in pixel di mondo: x dal tronco
// (negativa a sinistra), y in altezza dalla base (verso l'alto). Il colore del
// vertice porta i due numeri che cambiano da albero ad albero: `r` e' il seme,
// `g` l'altezza diviso 512. Con `b` a 1 invece il quadrilatero e' la sua ombra
// per terra, e si dipinge solo di nero trasparente.
//
// **Come e' fatto.** Un tronco e sopra `PALCHI` palchi di rami, uno sopra
// l'altro, sempre piu' stretti verso la cima. Ogni palco e' una gonna: stretta
// in alto, larga in basso, coi rami che alle punte scendono un po' e il bordo
// dentellato. Il palco di sopra copre quello di sotto e ci getta l'ombra. La
// luce viene da nord-ovest come in tutto il gioco, quindi il lato sinistro e'
// piu' chiaro. Quattro tinte piatte e niente sfumature: pixel art dipinta, non
// un albero renderizzato.
//
// **Il vento.** La cima si piega e la base no (lo spostamento cresce col
// quadrato dell'altezza). Ogni albero ha una sua raffica, che arriva ogni
// tanto e non tutti insieme: un bosco che ondeggia a tempo sembra un GIF.

uniform vec4 ombra : source_color = vec4(0.086, 0.180, 0.125, 1.0);
uniform vec4 medio : source_color = vec4(0.149, 0.290, 0.153, 1.0);
uniform vec4 chiaro : source_color = vec4(0.251, 0.420, 0.184, 1.0);
uniform vec4 luce : source_color = vec4(0.380, 0.557, 0.224, 1.0);
uniform vec4 corteccia : source_color = vec4(0.439, 0.282, 0.169, 1.0);
uniform vec4 corteccia_scura : source_color = vec4(0.278, 0.169, 0.106, 1.0);

// Quanto tira il vento, 0-1 e oltre. Lo scrive `pine_trees.gd` dal meteo.
uniform float vento = 0.3;

const int PALCHI = 7;
// Dove comincia la chioma, in frazione dell'altezza: sotto si vede il tronco.
const float CHIOMA = 0.13;

float caso(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

// Un dente: 0 ai lati, 1 in punta.
float dente(float t) {
	float f = fract(t);
	return 1.0 - abs(f * 2.0 - 1.0);
}

float palco_basso(float i, float alto) {
	return (CHIOMA + (1.0 - CHIOMA) * i / float(PALCHI)) * alto;
}

float palco_alto(float i, float alto) {
	return min((CHIOMA + (1.0 - CHIOMA) * (i + 1.9) / float(PALCHI)) * alto, alto);
}

float mezza_larghezza(float i, float alto, float seme) {
	float su = i / float(PALCHI);
	return alto * 0.30 * pow(1.0 - su, 0.85) * (0.88 + 0.24 * caso(vec2(seme * 7.0, i))) + 3.0;
}

// Il bordo basso del palco `i` alla colonna `x`: le punte scendono e sono
// dentellate.
float bordo_basso(float i, float x, float alto, float seme) {
	float largo = mezza_larghezza(i, alto, seme);
	float s = clamp(abs(x) / largo, 0.0, 1.0);
	float giu = (palco_alto(i, alto) - palco_basso(i, alto)) * 0.32 * s * s;
	float denti = dente((x + seme * 53.0 + i * 2.3) / 5.0) * (1.5 + 2.0 * s);
	return palco_basso(i, alto) - giu - denti;
}

bool nel_palco(float i, vec2 q, float alto, float seme) {
	float y0 = bordo_basso(i, q.x, alto, seme);
	float y1 = palco_alto(i, alto);
	if (q.y < y0 || q.y > y1) {
		return false;
	}
	float su = clamp((q.y - palco_basso(i, alto)) / (y1 - palco_basso(i, alto)), 0.0, 1.0);
	float largo = mezza_larghezza(i, alto, seme) * pow(1.0 - su, 1.1);
	largo -= dente(q.y / 4.0 + i * 0.37) * 2.0;
	return abs(q.x) <= largo;
}

void fragment() {
	vec4 dati = COLOR;
	if (dati.b > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.22);
	} else {
		float seme = dati.r;
		float alto = dati.g * 512.0;
		vec2 q = floor(UV) + 0.5;
		float h = clamp(q.y / alto, 0.0, 1.0);

		float raffica = smoothstep(0.35, 1.0, sin(TIME * 0.23 + seme * 31.0) * 0.5 + 0.5);
		float piega = sin(TIME * 1.3 + seme * 17.0) * vento * (0.25 + raffica) * 3.5;
		q.x = floor(q.x - piega * h * h) + 0.5;

		vec4 colore = vec4(0.0);
		for (int k = PALCHI - 1; k >= 0; k--) {
			float i = float(k);
			if (!nel_palco(i, q, alto, seme)) {
				continue;
			}
			float largo = mezza_larghezza(i, alto, seme);
			float l = 0.58 - 0.42 * clamp(q.x / largo, -1.0, 1.0);
			// La pennellata: macchie allungate in orizzontale, come i ciuffi
			// di aghi del disegno.
			l += (rumore(vec2(q.x * 0.30, q.y * 0.55) + seme * 13.0) - 0.5) * 0.45;
			// Vicino al tronco la chioma e' fitta e scura.
			l -= 0.22 * (1.0 - clamp(abs(q.x) / (largo * 0.35), 0.0, 1.0));
			// Sotto la gonna del palco di sopra c'e' ombra.
			if (k < PALCHI - 1) {
				float sopra = bordo_basso(i + 1.0, q.x, alto, seme);
				if (q.y > sopra - 5.0 && abs(q.x) < mezza_larghezza(i + 1.0, alto, seme)) {
					l -= 0.35;
				}
			}
			vec3 c = l < 0.28 ? ombra.rgb : (l < 0.55 ? medio.rgb : (l < 0.80 ? chiaro.rgb : luce.rgb));
			colore = vec4(c, 1.0);
			break;
		}
		if (colore.a < 0.5) {
			float tronco = alto * 0.045 * (1.0 + 0.9 * (1.0 - smoothstep(0.0, 0.07, h)));
			if (abs(q.x) < tronco && h < 0.95 && q.y >= 0.0) {
				bool lato_luce = q.x < -tronco * 0.2;
				float venatura = rumore(vec2(q.x * 0.5, q.y * 0.12) + seme * 5.0);
				colore = vec4(lato_luce && venatura > 0.35 ? corteccia.rgb : corteccia_scura.rgb, 1.0);
			}
		}
		COLOR = colore;
	}
}
