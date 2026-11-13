shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform float presencia : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origen = vec2(2.12, 8.95);
varying vec3 mundo;
varying float frente;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float distancia = distance(mundo.xz, origen) / 15.0;
	frente = smoothstep(distancia, distancia + 0.15, presencia * 1.16);
	// Crece y se derrite desde la superficie; UV2 guarda la base y el espesor.
	VERTEX.y = UV2.x + UV2.y * frente;
}

void fragment() {
	float grano = fract(sin(dot(floor(UV * 320.0), vec2(12.9898, 78.233))) * 43758.5453);
	float profundidad = smoothstep(0.0, 0.10, UV2.y);
	ALBEDO = mix(vec3(0.65, 0.80, 0.94), vec3(0.94, 0.97, 1.0), 0.55 + profundidad * 0.45);
	ALBEDO += (grano - 0.5) * 0.035;
	ROUGHNESS = 0.87;
	SPECULAR = 0.22;
	EMISSION = vec3(0.025, 0.035, 0.045);
	ALPHA = frente * smoothstep(0.001, 0.009, UV2.y);
}
