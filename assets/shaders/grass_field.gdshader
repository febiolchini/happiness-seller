shader_type canvas_item;

// L'erba alta del campo abbandonato.
//
// **Perche' uno shader e non un render di Blender.** Il campo e' una superficie
// piatta grande quanto mezzo isolato: fotografata da Blender sarebbe un PNG da
// settecento pixel di lato, immobile, e ogni campo della citta' avrebbe le
// stesse identiche chiazze. Qui invece il disegno si calcola dalla posizione nel
// mondo, quindi non si ripete mai, non pesa niente in memoria, e soprattutto si
// muove: il vento e' meta' di quello che fa sembrare viva un'erba alta.
//
// **Perche' non sembra 3D.** Niente geometria, niente sfumature: quattro tinte
// piatte scelte a soglia e un ritaglio netto dove il terreno e' nudo. E' la
// stessa logica di un pixel art dipinto a mano — poche campiture e bordi duri —
// invece che di un prato renderizzato.
//
// Sotto ci sta il terreno disegnato da `city_ground.gd` (terra e righe
// sbiadite del campo): dove l'erba si dirada l'alpha va a zero e quello che c'e'
// sotto si vede. E' quello che fa leggere il campo come *semi* abbandonato e non
// come un prato qualsiasi — le righe spuntano a tratti.

// Le quattro tinte, dalla terra bruciata all'erba ancora viva.
uniform vec4 secco : source_color = vec4(0.443, 0.396, 0.239, 1.0);
uniform vec4 paglia : source_color = vec4(0.522, 0.478, 0.271, 1.0);
uniform vec4 erba : source_color = vec4(0.318, 0.412, 0.227, 1.0);
uniform vec4 erba_chiara : source_color = vec4(0.404, 0.522, 0.275, 1.0);

// Lato del pixel in unita' di mondo. A 1.0 coincide col pixel dello sprite alla
// scala 1x della camera: sotto, l'erba brulicherebbe di puntini piu' piccoli di
// un pixel; sopra, diventa a blocchi.
uniform float grana = 1.0;
// Quanto si sposta l'erba col vento, in pixel di mondo. Tre e' una piegatina;
// sopra i sei sembra alga.
uniform float vento = 3.0;
uniform float velocita = 0.8;
// Alza la soglia e il campo si spela. Serve anche a far vedere le righe del
// campo, che stanno sotto: passano solo dai buchi, quindi quanto e' spelato
// decide quanto si legge che li' sotto c'era un terreno di gioco.
uniform float copertura : hint_range(0.25, 0.65) = 0.475;
uniform float scala_chiazze = 0.009;
uniform float scala_ciuffi = 0.085;

varying vec2 mondo;

void vertex() {
	mondo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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

float fbm(vec2 p) {
	return rumore(p) * 0.55 + rumore(p * 2.13) * 0.30 + rumore(p * 4.37) * 0.15;
}

void fragment() {
	vec2 m = floor(mondo / grana) * grana;

	// Le chiazze grandi NON si muovono col vento. Se ondeggiassero anche loro
	// sembrerebbe il terreno a scorrere sotto i piedi, non l'erba a piegarsi:
	// e' l'errore che fa sembrare finta qualunque erba animata.
	float chiazze = fbm(m * scala_chiazze);

	// Il vento tocca solo ciuffi e steli. La fase dipende anche dalla chiazza,
	// cosi' il campo non si piega tutto insieme come un unico telo.
	float onda = sin(TIME * velocita + m.y * 0.030 + chiazze * 6.2);
	vec2 s = m + vec2(onda * vento, 0.0);

	float ciuffi = fbm(s * scala_ciuffi);
	// Stretti in x e lunghi in y: e' la proporzione che li fa leggere come
	// steli invece che come macchie.
	float steli = rumore(vec2(s.x * 1.15, s.y * 0.28));

	float t = chiazze * 0.60 + ciuffi * 0.40;

	if (t < copertura - 0.16) {
		// Terra nuda: passa quello che c'e' sotto, righe del campo comprese.
		COLOR = vec4(0.0);
	} else {
		vec3 col;
		if (t < copertura - 0.06) {
			col = secco.rgb;
		} else if (t < copertura + 0.05) {
			col = paglia.rgb;
		} else if (t < copertura + 0.15) {
			col = erba.rgb;
		} else {
			col = erba_chiara.rgb;
		}
		if (steli > 0.74) {
			col = mix(col, erba_chiara.rgb, 0.55);
		}
		COLOR = vec4(col, 1.0);
	}
}
