shader_type spatial;
render_mode blend_mix, depth_draw_never;

uniform float presencia : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origen = vec2(2.12, 8.95);
varying vec3 mundo;
varying float arriba;

float ruido(vec2 p) {
	return 0.5 + 0.24 * sin(p.x * 1.57 + 0.8 * sin(p.y * 1.31))
		+ 0.17 * sin(p.y * 1.91 - p.x * 0.53) + 0.09 * sin(p.x * 2.73 + p.y * 1.17);
}

void vertex() {
	vec3 normal_mundo = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	arriba = smoothstep(0.45, 0.85, normal_mundo.y);
	VERTEX += NORMAL * 0.003;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grano = fract(sin(dot(floor(mundo.xz * 170.0), vec2(12.9898, 78.233))) * 43758.5453);
	float manchas = ruido(mundo.xz * 5.3) * 0.7 + ruido(mundo.xz * 12.0) * 0.3;
	float polvo = smoothstep(0.46, 0.72, manchas);
	ALBEDO = mix(vec3(0.38, 0.57, 0.82), vec3(0.84, 0.92, 1.0), arriba) + grano * 0.025;
	ROUGHNESS = mix(0.28, 0.95, arriba);
	float frente = smoothstep(distance(mundo.xz, origen) / 15.0, distance(mundo.xz, origen) / 15.0 + 0.15, presencia * 1.16);
	// Escarcha ligera entre los montículos: todavía se ve el material del mueble.
	ALPHA = frente * mix(0.12, 0.14 + polvo * 0.45, arriba);
}
