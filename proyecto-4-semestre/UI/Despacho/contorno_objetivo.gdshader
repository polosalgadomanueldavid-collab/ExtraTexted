shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

// Ancho en píxeles, independiente del tamaño y de la escala del modelo.
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 normal = (PROJECTION_MATRIX * vec4(MODELVIEW_NORMAL_MATRIX * NORMAL, 0.0)).xy;
	vec2 direccion = normal / max(length(normal), 0.001);
	clip.xy += direccion * 2.8 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = vec3(1.0, 0.85, 0.53);
	ALPHA = 0.82;
}
