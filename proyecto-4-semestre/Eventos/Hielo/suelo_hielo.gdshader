shader_type spatial;
render_mode blend_mix, cull_back;

uniform float presencia : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origen = vec2(2.12, 8.95);
varying vec3 mundo;

vec2 azar(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float ruido(vec2 p) {
	// Campo continuo: no produce juntas cuadradas al cambiar de celda.
	return 0.5 + 0.24 * sin(p.x * 1.57 + 0.8 * sin(p.y * 1.31))
		+ 0.17 * sin(p.y * 1.91 - p.x * 0.53) + 0.09 * sin(p.x * 2.73 + p.y * 1.17);
}

float nubes(vec2 p) {
	return ruido(p) * 0.57 + ruido(p * 2.1 + 8.7) * 0.29 + ruido(p * 4.3 - 2.4) * 0.14;
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 suelo = mundo.xz;
	// Placas grandes deformadas: fracturas orgánicas en lugar de baldosas regulares.
	vec2 deformacion = vec2(ruido(suelo * 1.8), ruido(suelo * 1.8 + 21.7)) - 0.5;
	vec2 p = suelo * 1.12 + deformacion * 0.48;
	vec2 celda = floor(p);
	vec2 f = fract(p);
	float primero = 8.0;
	float segundo = 8.0;
	vec2 elegido = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 vecino = vec2(float(x), float(y));
			vec2 semilla = azar(celda + vecino);
			float d = length(vecino + semilla - f);
			if (d < primero) { segundo = primero; primero = d; elegido = semilla; }
			else if (d < segundo) { segundo = d; }
		}
	}
	float borde = segundo - primero;
	float irregularidad = nubes(suelo * 4.2);
	float grieta = (1.0 - smoothstep(0.003, 0.018, borde)) * (0.32 + irregularidad * 0.68);
	float halo = 1.0 - smoothstep(0.0, 0.13, borde);
	float profundidad = nubes(suelo * 0.78);
	float sedimento = nubes(suelo * 2.0 + vec2(5.6, -7.3));
	float distancia_pared = min(min(suelo.x + 4.45, 2.41 - suelo.x), min(suelo.y + 0.1, 12.38 - suelo.y));
	float orilla = 1.0 - smoothstep(0.10, 0.65 + sedimento * 0.55, distancia_pared);
	float escarcha = clamp(smoothstep(0.56, 0.75, sedimento) * 0.52 + orilla * (0.52 + irregularidad * 0.40), 0.0, 1.0);
	float veta = pow(max(0.0, sin(suelo.x * 11.0 + suelo.y * 6.2 + profundidad * 9.0)), 18.0);
	float polvo = ruido(suelo * 46.0);
	vec3 azul = mix(vec3(0.15, 0.34, 0.60), vec3(0.43, 0.68, 0.88), profundidad * 0.72 + elegido.x * 0.23);
	azul += halo * vec3(0.035, 0.055, 0.07) + veta * 0.025;
	ALBEDO = mix(azul, vec3(0.76, 0.89, 0.97), grieta * 0.65);
	ALBEDO = mix(ALBEDO, vec3(0.85, 0.92, 0.98) + (polvo - 0.5) * 0.05, escarcha);
	METALLIC = 0.10 * (1.0 - escarcha);
	ROUGHNESS = 0.29 + profundidad * 0.12 + escarcha * 0.42;
	SPECULAR = 0.48;
	EMISSION = vec3(0.08, 0.16, 0.28) * (0.12 + grieta * 0.20);
	// Frente sólido de cristalización, sin ondulación ni subida del agua.
	ALPHA = smoothstep(distance(mundo.xz, origen) / 15.0, distance(mundo.xz, origen) / 15.0 + 0.12, presencia * 1.16);
}
