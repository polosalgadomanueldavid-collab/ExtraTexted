shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float reloj = 0.0;
uniform float presencia : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origen_calor = vec2(-1.0, 3.2);
uniform sampler2D semillas : filter_nearest, repeat_disable;
uniform vec2 origen_semillas;
uniform vec2 tamano_semillas;
uniform float escala_placas = 2.4;
// R: charco y ramales; G: núcleo; B/A: costra y su borde caliente.
uniform sampler2D zonas_fundidas : filter_linear, repeat_disable;
uniform vec4 limites_suelo = vec4(-4.45, -0.10, 6.86, 12.48);
varying vec2 mundo;

vec2 azar(vec2 p) {
	// Hash sin números enormes: evita bandas y bloques en el renderizador móvil/OpenGL.
	highp vec3 h = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
	h += dot(h, h.yzx + 33.33);
	return fract((h.xx + h.yz) * h.zy);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i).x, azar(i + vec2(1.0, 0.0)).x, f.x),
		mix(azar(i + vec2(0.0, 1.0)).x, azar(i + vec2(1.0)).x, f.x), f.y);
}

float turbulencia(vec2 p) {
	return ruido(p) * 0.57 + ruido(p * 2.13 + 7.0) * 0.28 + ruido(p * 4.37 - 3.0) * 0.15;
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// La topología permanece fija; se animan el calor y las corrientes del magma.
	vec2 p = mundo * escala_placas;
	vec2 celda = floor(p);
	vec2 local = fract(p);
	float primero = 8.0;
	float segundo = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 vecino = vec2(float(x), float(y));
			vec2 centro = texture(semillas, (celda + vecino - origen_semillas + 0.5) / tamano_semillas).rg;
			float d = length(vecino + centro - local);
			segundo = max(primero, min(segundo, d));
			primero = min(primero, d);
		}
	}
	float relieve = ruido(mundo * 19.0) * 0.65 + ruido(mundo * 45.0) * 0.35;
	float grieta = 1.0 - smoothstep(0.008, 0.055 + relieve * 0.035, segundo - primero);
	float calor_borde = 1.0 - smoothstep(0.02, 0.30, segundo - primero);
	float pulso = 0.5 + 0.5 * sin(mundo.x * 3.0 + mundo.y * 2.3 + reloj * 1.2);
	vec3 costra = mix(vec3(0.027, 0.023, 0.025), vec3(0.115, 0.063, 0.045), relieve);
	costra += vec3(0.19, 0.022, 0.001) * calor_borde * calor_borde;
	vec3 fuego = mix(vec3(0.65, 0.038, 0.006), vec3(1.0, 0.42, 0.045), grieta * (0.55 + pulso * 0.45));
	vec3 color = mix(costra, fuego, grieta);
	vec4 zona = texture(zonas_fundidas, (mundo - limites_suelo.xy) / limites_suelo.zw);
	if (zona.r > 0.001) {
		vec2 deriva = vec2(reloj * 0.07, -reloj * 0.045);
		vec2 corriente = mundo * 5.0 + deriva;
		corriente += vec2(turbulencia(corriente + 3.7), turbulencia(corriente - 8.1)) * 2.0;
		float fundido = turbulencia(corriente);
		float flujo = smoothstep(0.32, 0.74, fundido);
		vec3 magma = mix(vec3(0.68, 0.075, 0.008), vec3(1.0, 0.43, 0.065), flujo);
		magma += vec3(0.06, 0.065, 0.025) * zona.g * (0.6 + 0.4 * pulso);
		// Las islas mantienen el aspecto de las placas que se hundieron en el núcleo.
		vec3 roca_isla = costra * 1.30 + vec3(0.028, 0.012, 0.004);
		magma = mix(magma, roca_isla, zona.b);
		magma += vec3(0.20, 0.075, 0.009) * max(0.0, zona.a - zona.b);
		color = mix(color, magma, zona.r);
	}
	float campo = clamp(length(mundo - origen_calor) / 15.0, 0.0, 0.72) + ruido(mundo * 1.7) * 0.18;
	float frente = presencia * 1.35 - campo;
	float encender = smoothstep(0.0, 0.18, frente) * smoothstep(0.0, 0.15, presencia);
	float cubrir = smoothstep(0.12, 0.42, frente);
	float opacidad = encender * mix(max(grieta * 0.80, zona.r), 1.0, cubrir);
	// Primero aparecen grietas sobre el piso original; después aflora la costra.
	color = mix(fuego * (0.55 + encender * 0.45), color, cubrir);
	ALBEDO = color;
	ALPHA = opacidad;
}
