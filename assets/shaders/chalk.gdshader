shader_type canvas_item;

// Il gesso sulla lavagna dell'HUD (`chalkboard.gd`).
//
// Una scritta col gesso non copre tutto: la polvere resta sui rilievi della
// lavagna e manca nei buchi, quindi il tratto è pieno di puntini più chiari e
// più scuri. È quella grana che la fa sembrare scritta SULLA lavagna e non
// appoggiata sopra come un'etichetta.
//
// La grana è fissata allo schermo (`FRAGCOORD`) e non al testo: cambiando un
// numero le lettere nuove passano sulla stessa lavagna, come col gesso vero.

// Quanto si mangia la grana: 0 = tratto pieno, 1 = mezzo tratto sparito.
uniform float grain : hint_range(0.0, 1.0) = 0.55;
// Grandezza di un granello, in pixel di finestra.
uniform float grain_size = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / grain_size);
	float n = hash(cell);
	// Un granello su tre quasi vuoto, gli altri appena più o meno pieni: il
	// gesso si stacca a macchie, non in modo uniforme.
	float keep = n < 0.3 ? 1.0 - grain : 1.0 - grain * 0.35 * n;
	COLOR.a *= keep;
}
