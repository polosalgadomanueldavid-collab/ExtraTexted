shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform float reloj = 0.0;
uniform float amplitud = 0.024;
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += amplitud * (sin(mundo.x * 2.7 + reloj * 1.8) + sin(mundo.y * 3.3 - reloj * 1.4) * 0.55);
	NORMAL = normalize(vec3(-amplitud * 2.7 * cos(mundo.x * 2.7 + reloj * 1.8), 1.0, -amplitud * 1.815 * cos(mundo.y * 3.3 - reloj * 1.4)));
}

void fragment() {
	float onda = sin(mundo.x * 7.0 + mundo.y * 3.0 + reloj * 1.8) * sin(mundo.y * 8.0 - mundo.x * 2.0 - reloj);
	float espuma = smoothstep(0.87, 0.99, onda);
	float brillo = 0.5 + 0.5 * sin(mundo.y * 3.3 - reloj * 1.4);
	ALBEDO = mix(vec3(0.025, 0.31, 0.43), vec3(0.13, 0.65, 0.72), brillo * 0.45);
	ALBEDO = mix(ALBEDO, vec3(0.70, 0.94, 0.94), espuma * 0.65);
	EMISSION = ALBEDO * 0.23;
	ROUGHNESS = 0.23;
	SPECULAR = 0.65;
	ALPHA = 0.79;
}
