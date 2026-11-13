shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;

// Agua de ilustración: turquesa, nervaduras claras y espuma de contacto.
// El reloj de la partida congela también los shaders al pausar.
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform float reloj = 0.0;
uniform float amplitud = 0.03;
uniform float presencia = 1.0;
uniform vec4 limites = vec4(-4.45, -0.1, 2.41, 12.38);
uniform int cantidad_impactos = 0;
uniform vec4 impactos[32]; // X/Z, instante, fuerza; solo en vértices.
varying vec2 mundo;
varying float cresta;

vec2 semilla(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(semilla(i).x, semilla(i + vec2(1.0, 0.0)).x, f.x),
		mix(semilla(i + vec2(0.0, 1.0)).x, semilla(i + vec2(1.0, 1.0)).x, f.x), f.y);
}

float turbulencia(vec2 p) {
	return ruido(p) * 0.57 + ruido(p * 2.03 + 11.7) * 0.28 + ruido(p * 4.07 - 8.3) * 0.15;
}

float celulas(vec2 p) {
	vec2 celda = floor(p);
	vec2 local = fract(p);
	float primera = 8.0;
	float segunda = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 vecina = vec2(float(x), float(y));
			vec2 sitio = 0.08 + semilla(celda + vecina) * 0.84;
			vec2 distancia = vecina + sitio - local;
			float d = dot(distancia, distancia);
			segunda = max(primera, min(segunda, d));
			primera = min(primera, d);
		}
	}
	return sqrt(segunda) - sqrt(primera);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float ola_a = sin(dot(mundo, vec2(2.2, 1.1)) - reloj * 1.45);
	float ola_b = sin(dot(mundo, vec2(-1.3, 3.1)) + reloj * 1.12);
	float altura = amplitud * (ola_a + ola_b * 0.48);
	for (int i = 0; i < 32; i++) {
		if (i >= cantidad_impactos) { break; }
		float edad = reloj - impactos[i].z;
		float distancia = length(mundo - impactos[i].xy);
		float frente = distancia - edad * 1.35;
		float envolvente = exp(-frente * frente * 14.0) * exp(-edad * 1.35);
		altura += sin(frente * 16.0) * envolvente * impactos[i].w * 0.055 * presencia;
	}
	VERTEX.y += altura;
	cresta = ola_a * 0.5 + ola_b * 0.25;
}

void fragment() {
	vec2 corriente = mundo * 2.6 + vec2(reloj * 0.075, -reloj * 0.065);
	// El dominio se deforma en varias escalas: sin polígonos rígidos repetidos.
	vec2 remolino = vec2(turbulencia(corriente * 0.8 + reloj * 0.13),
		turbulencia(corriente * 0.8 + 19.2 - reloj * 0.11)) - 0.5;
	vec2 ondulado = corriente + remolino * 2.1;
	float celula = celulas(ondulado);
	float mascara = turbulencia(corriente * 1.2 - reloj * 0.17);
	float filtro = min(0.09, fwidth(celula) * 0.65);
	float trazo = 1.0 - smoothstep(0.009 - filtro, 0.055 + filtro, celula);
	float filamento = trazo * smoothstep(0.35, 0.69, mascara) * 0.65;
	float mancha = turbulencia(mundo * 1.8 + remolino + vec2(reloj * 0.07, 0.0));
	float detalle = (mancha - 0.5) * 2.0;
	float d = texture(profundidad, SCREEN_UV).r;
	// Compatibility usa NDC [-1,1]; Forward+ usa [0,1].
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, d) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
	#endif
	vec4 fondo = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float distancia_fondo = max(0.0, -fondo.z / fondo.w + VERTEX.z);
	float orilla = 1.0 - smoothstep(0.025, 0.13 + detalle * 0.035, distancia_fondo);
	float borde = min(min(mundo.x - limites.x, limites.z - mundo.x), min(mundo.y - limites.y, limites.w - mundo.y));
	orilla = max(orilla, 1.0 - smoothstep(0.025, 0.10 + detalle * 0.025, borde));
	float poco_profundo = 1.0 - smoothstep(0.15, 1.5, distancia_fondo);
	vec3 profundo = vec3(0.075, 0.43, 0.45);
	vec3 claro = vec3(0.39, 0.83, 0.73);
	vec3 color = mix(profundo, claro, clamp(0.12 + poco_profundo * 0.26 + smoothstep(0.25, 0.73, mancha) * 0.62 + cresta * 0.06, 0.0, 1.0));
	color = mix(color, vec3(0.71, 0.97, 0.91), filamento * presencia);
	color = mix(color, vec3(0.83, 1.0, 0.95), orilla * 0.78 * presencia);
	ALBEDO = color;
	ALPHA = mix(0.52, 0.72, smoothstep(0.1, 1.5, distancia_fondo)) + filamento * 0.15 + orilla * 0.18;
}
