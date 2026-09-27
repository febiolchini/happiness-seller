shader_type spatial;
render_mode unshaded, cull_disabled;

// Le montagne all'orizzonte della vista dall'ufficio (`window_view.gd`).
//
// Tre file di creste, dalla piu' lontana alla piu' vicina: rocce azzurrine con
// la neve in cima, una fila di mezzo piu' scura, e le colline verdi coi boschi
// davanti. Colori a soglia e colonne larghe qualche pixel: e' la stessa pixel
// art del paesaggio del bordo, vista di fronte invece che dall'alto.
//
// `valley` e' dove passa la strada d'uscita a nord: li' le creste si aprono,
// come nel paesaggio del bordo.

uniform vec3 far_rock : source_color = vec3(0.56, 0.62, 0.72);
uniform vec3 far_shade : source_color = vec3(0.44, 0.49, 0.60);
uniform vec3 snow : source_color = vec3(0.93, 0.95, 0.98);
uniform vec3 mid_rock : source_color = vec3(0.40, 0.45, 0.47);
uniform vec3 mid_shade : source_color = vec3(0.31, 0.35, 0.38);
uniform vec3 hill : source_color = vec3(0.33, 0.47, 0.27);
uniform vec3 hill_shade : source_color = vec3(0.24, 0.36, 0.21);
uniform vec3 forest : source_color = vec3(0.17, 0.29, 0.17);
// La luce dell'ora, moltiplicata su tutto.
uniform vec3 tint : source_color = vec3(1.0);
uniform float valley = 0.5;
uniform float columns = 1400.0;
uniform sampler2D noise : repeat_enable, filter_linear;

float ridge(float x, float freq, float seed) {
	float a = texture(noise, vec2(x * freq, seed)).r;
	float b = texture(noise, vec2(x * freq * 3.1, seed + 0.37)).r;
	// Creste a punta e non a panettone: il valore piegato attorno al mezzo.
	float r = 1.0 - abs(a * 2.0 - 1.0);
	return r * 0.9 + b * 0.1;
}

void fragment() {
	float x = floor(UV.x * columns) / columns;
	float h = 1.0 - UV.y;
	float open = smoothstep(0.0, 0.06, abs(x - valley));
	float step_x = 1.0 / columns;

	float far_h = (0.50 + 0.48 * ridge(x, 1.1, 0.11)) * mix(0.75, 1.0, open);
	float mid_h = (0.28 + 0.30 * ridge(x, 2.3, 0.43)) * mix(0.35, 1.0, open);
	float near_h = (0.08 + 0.12 * ridge(x, 4.5, 0.71)) * mix(0.15, 1.0, open);

	vec3 col;
	if (h < near_h) {
		float slope = ridge(x + step_x * 18.0, 4.5, 0.71) - ridge(x - step_x * 18.0, 4.5, 0.71);
		col = slope > 0.0 ? hill_shade : hill;
		// I boschi: macchie scure a soglia sul verde.
		float woods = texture(noise, vec2(x * 40.0, h * 6.0 + 0.2)).r;
		if (woods > 0.58 && h < near_h - 0.01) {
			col = forest;
		}
	} else if (h < mid_h) {
		float slope = ridge(x + step_x * 18.0, 2.3, 0.43) - ridge(x - step_x * 18.0, 2.3, 0.43);
		col = slope > 0.0 ? mid_shade : mid_rock;
	} else if (h < far_h) {
		float slope = ridge(x + step_x * 18.0, 1.1, 0.11) - ridge(x - step_x * 18.0, 1.1, 0.11);
		col = slope > 0.0 ? far_shade : far_rock;
		if (h > far_h - 0.07 - 0.05 * texture(noise, vec2(x * 30.0, 0.9)).r && far_h > 0.8) {
			col = snow;
		}
	} else {
		discard;
	}
	ALBEDO = col * tint;
}
