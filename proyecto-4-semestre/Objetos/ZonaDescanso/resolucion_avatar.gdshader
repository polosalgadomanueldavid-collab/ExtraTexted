shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

void fragment() {
	// Motas suaves, sin esferas sólidas ni una capa luminosa sobre toda la oficina.
	float radio = length((UV - .5) * 2.0);
	float borde = 1.0 - smoothstep(.05, 1.0, radio);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * borde * borde;
}
