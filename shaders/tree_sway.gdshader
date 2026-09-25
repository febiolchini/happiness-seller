shader_type canvas_item;

// Un albero che si piega col vento, senza fotogrammi: si sposta di lato quello
// che si legge dalla texture, poco in basso e di piu' in cima.
//
// Lo spostamento e' in pixel INTERI della texture: mezzo pixel di scarto
// ricampionerebbe il disegno a meta' fra due pixel, e con il filtro Nearest si
// vedrebbero colonne che saltano avanti e indietro invece di una chioma che
// ondeggia. A scatti di un pixel la chioma resta netta.
//
// Il quadrato dello sprite e' allargato di `margin` pixel per lato: piegandosi
// la chioma esce dal rettangolo del PNG, e senza margine il bordo verrebbe
// tagliato di netto.

// Di quanti pixel si piega la cima, col segno del verso.
uniform float sway = 0.0;
// Il fremito delle foglie durante una raffica, 0-1.
uniform float flutter = 0.0;
// Fin dove arriva il tronco, dal basso, in frazione d'altezza: sotto non si
// piega niente, o sembrerebbe un albero di gomma.
uniform float trunk = 0.3;
uniform float margin = 4.0;

void vertex() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 outward = UV * 2.0 - 1.0;
	VERTEX += outward * margin;
	UV = (UV * size + outward * margin) / size;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	float height = clamp((1.0 - UV.y - trunk) / (1.0 - trunk), 0.0, 1.0);
	vec2 px = UV * size;
	// Le foglie fremono a bande orizzontali che scorrono: sfalsate fra loro,
	// e non tutte insieme come un cartone che trema.
	float ripple = sin(px.y * 0.35 + TIME * 9.0) * flutter * height;
	float shift = round(sway * height * height + ripple);
	vec2 uv = (px - vec2(shift, 0.0)) / size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv) * COLOR;
	}
}
