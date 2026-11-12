shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float edad = 0.0;
uniform float fuerza = 1.0;
uniform bool chorro = false;
varying float punta;

void vertex() {
	float t = max(0.0, edad - (chorro ? 0.10 : 0.0));
	float subir = smoothstep(0.0, 0.16, t);
	float caer = 1.0 - smoothstep(0.22, 0.67, t);
	float angulo = UV.x * 6.283185;
	float picos = pow(0.5 + 0.5 * sin(angulo * 7.0 + sin(angulo * 3.0) * 0.6 + 0.8), 3.0);
	float perfil = 0.30 + picos * (0.50 + sin(angulo * 11.0 + 1.2) * 0.18);
	float abertura = UV.y * UV.y * (0.14 + t * 0.25);
	float radio = chorro ? (0.065 * pow(1.0 - UV.y, 2.0) + 0.008) : (0.13 + t * 0.65 + abertura);
	float alto = chorro ? 1.12 : 0.51 * perfil;
	radio += chorro ? 0.0 : sin(angulo * 5.0 + t * 3.0) * 0.018 * UV.y;
	VERTEX = vec3(cos(angulo) * radio, UV.y * alto * subir * caer, sin(angulo) * radio) * fuerza;
	VERTEX.x += (chorro ? UV.y * UV.y * 0.12 * subir : 0.0) * fuerza;
	punta = UV.y;
}

void fragment() {
	float lineas = pow(0.5 + 0.5 * sin(UV.x * 6.283185 * (chorro ? 6.0 : 14.0)), 5.0);
	float labio = smoothstep(0.82, 0.98, punta);
	float espuma = max(labio, lineas * 0.55);
	float ruptura = smoothstep(0.22, 0.65, edad) * smoothstep(0.28, 0.9, punta)
		* smoothstep(0.25, 0.65, sin(UV.x * 69.0 + sin(UV.y * 14.0)));
	ALBEDO = mix(vec3(0.38, 0.78, 0.75), vec3(0.86, 1.0, 0.97), espuma);
	ALPHA = (0.49 + espuma * 0.43) * (1.0 - ruptura) * (1.0 - smoothstep(0.4, 0.78, edad)) * smoothstep(0.0, 0.035, edad);
}
