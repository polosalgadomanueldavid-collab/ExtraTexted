shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;

// Contorno visible también en Compatibility, sin depender del bloom del entorno.
uniform vec4 color_resaltado : source_color = vec4(1.0, 0.843, 0.604, 1.0);
uniform float grosor : hint_range(0.0, 0.03) = 0.0;

void vertex() {
	VERTEX += NORMAL * grosor;
}

void fragment() {
	// El interior queda transparente: el brillo sigue los biseles y la silueta.
	float borde = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	ALBEDO = color_resaltado.rgb;
	EMISSION = color_resaltado.rgb * 0.35;
	ALPHA = borde * borde * 0.85;
}
