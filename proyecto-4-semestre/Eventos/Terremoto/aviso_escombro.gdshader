shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec2 medidas = vec2(0.46);
uniform float progreso : hint_range(0.0, 1.0) = 0.0;
uniform float reloj = 0.0;

float caja(vec2 p, vec2 mitad) {
	vec2 d = abs(p) - mitad;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * (medidas + vec2(0.16));
	vec2 mitad = medidas * 0.5;
	float aa = max(fwidth(p.x) + fwidth(p.y), 0.001);
	float fondo = 1.0 - smoothstep(-aa, aa, caja(p, mitad));
	float exterior = 1.0 - smoothstep(-aa, aa, caja(p, mitad + vec2(0.065)));
	float interior = 1.0 - smoothstep(-aa, aa, caja(p, mitad + vec2(0.018)));
	float borde = exterior - interior;
	float contorno = 1.0 - smoothstep(-aa, aa, caja(p, mitad + vec2(0.077)));
	float franjas = smoothstep(0.43, 0.56, fract((p.x + p.y) * 10.0));
	vec3 peligro = mix(vec3(1.0, 0.63, 0.12), vec3(1.0, 0.16, 0.06), smoothstep(0.30, 1.0, progreso));
	float pulso = 0.5 + 0.5 * sin(reloj * mix(7.0, 24.0, progreso));
	// El borde se consume en sentido horario hasta el impacto.
	float angulo = fract(atan(p.x / mitad.x, -p.y / mitad.y) / 6.283185 + 1.0);
	float restante = smoothstep(progreso - 0.015, progreso + 0.015, angulo);
	vec3 tinta = mix(vec3(0.055, 0.035, 0.018), peligro, fondo * mix(0.30, 0.65, franjas));
	float opacidad = contorno * 0.90;
	opacidad = mix(opacidad, 0.20 + 0.16 * franjas, fondo);
	tinta = mix(tinta, peligro * mix(0.34, 1.0, restante), borde);
	opacidad = max(opacidad, borde * (0.80 + 0.20 * pulso));
	// Triángulo de advertencia y exclamación legibles desde la cámara de juego.
	vec2 icono = p / min(medidas.x, medidas.y);
	float triangular = max(abs(icono.x) * 0.88 - (icono.y + 0.24) * 0.5, max(-0.24 - icono.y, icono.y - 0.20));
	float insignia = 1.0 - smoothstep(-0.01, 0.01, triangular);
	tinta = mix(tinta, vec3(0.10, 0.055, 0.025), insignia);
	opacidad = max(opacidad, insignia * 0.98);
	float barra = 1.0 - smoothstep(-0.005, 0.005, caja(icono - vec2(0.0, -0.045), vec2(0.028, 0.09)));
	float punto = 1.0 - smoothstep(0.028, 0.039, length(icono - vec2(0.0, 0.13)));
	float signo = max(barra, punto);
	tinta = mix(tinta, vec3(1.0, 0.97, 0.79), signo);
	ALBEDO = tinta;
	ALPHA = max(opacidad, signo);
}
