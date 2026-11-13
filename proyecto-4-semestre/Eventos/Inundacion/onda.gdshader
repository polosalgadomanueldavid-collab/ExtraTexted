shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float edad = 0.0;
uniform vec4 limites = vec4(-4.45, -0.1, 2.41, 12.38);
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = (UV - 0.5) * 4.0;
	float angulo = atan(p.y, p.x);
	float distancia = length(p);
	float perturbacion = (sin(angulo * 7.0 + edad * 2.0) + sin(angulo * 11.0 - edad)) * 0.018;
	float radio = 0.17 + edad * 1.05;
	float ancho = mix(0.048, 0.009, clamp(edad / 1.8, 0.0, 1.0));
	float anillo = 1.0 - smoothstep(ancho, ancho + 0.014, abs(distancia + perturbacion - radio));
	float segundo = 1.0 - smoothstep(ancho * 0.6, ancho + 0.005, abs(distancia - perturbacion - radio + 0.17));
	float rotura = smoothstep(-0.65, 0.1, sin(angulo * 5.0 + edad * 0.7) + sin(angulo * 9.0) * 0.5);
	float visible = smoothstep(0.0, 0.07, edad) * (1.0 - smoothstep(0.45, 1.8, edad));
	float dentro = step(limites.x, mundo.x) * step(mundo.x, limites.z) * step(limites.y, mundo.y) * step(mundo.y, limites.w);
	ALBEDO = vec3(0.80, 1.0, 0.95);
	ALPHA = max(anillo, segundo * 0.45) * rotura * visible * dentro * 0.85;
}
