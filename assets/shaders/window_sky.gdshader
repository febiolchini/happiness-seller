shader_type sky;

// Il cielo visto dalla vetrata dell'ufficio (`window_view.gd`).
//
// Un gradiente dall'orizzonte allo zenit, nuvole a tre toni che scorrono col
// vento e, di notte, le stelle. I colori li decide lo script dall'ora e dal
// meteo: qui non c'e' nessuna idea di che ore sono.
//
// Le nuvole sono a soglia e non sfumate, come l'erba e le montagne del bordo:
// e' pixel art, e una nuvola a gradiente morbido sembra fumo.

uniform vec3 top : source_color = vec3(0.37, 0.6, 0.85);
uniform vec3 horizon : source_color = vec3(0.75, 0.85, 0.93);
uniform vec3 cloud_lit : source_color = vec3(0.97, 0.97, 0.98);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.76, 0.84);
// Quanto cielo coprono le nuvole, 0-1: il `clouds` del meteo.
uniform float cover = 0.2;
// Lo spostamento delle nuvole: lo fa avanzare lo script, col vento del giorno.
uniform float drift = 0.0;
uniform float stars = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon, top, smoothstep(-0.02, 0.32, h));
	if (h > 0.0) {
		// Le nuvole stanno su un piano alto: vicino all'orizzonte si stringono.
		vec2 uv = d.xz / (h + 0.06) * 0.22;
		uv.x += drift;
		float n = texture(noise, uv * 0.35).r * 0.7 + texture(noise, uv * 1.3 + vec2(3.1, 1.7)).r * 0.3;
		float edge = 1.0 - cover;
		float c = smoothstep(edge - 0.04, edge + 0.04, n);
		c = floor(c * 3.0 + 0.5) / 3.0;
		// La pancia in ombra: il rumore letto un po' piu' in su.
		float n2 = texture(noise, (uv + vec2(0.0, 0.035)) * 0.35).r * 0.7
			+ texture(noise, (uv + vec2(0.0, 0.035)) * 1.3 + vec2(3.1, 1.7)).r * 0.3;
		vec3 cc = mix(cloud_shade, cloud_lit, step(n2, n));
		float fade = smoothstep(0.0, 0.05, h);
		col = mix(col, cc, c * fade * 0.92);
		float s = step(0.9975, hash(floor(d.xz / (h + 0.25) * 260.0)));
		col += vec3(s * stars * (1.0 - c) * smoothstep(0.04, 0.2, h));
	}
	COLOR = col;
}
