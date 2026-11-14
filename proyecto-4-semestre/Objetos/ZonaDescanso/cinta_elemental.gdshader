shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec4 tinte : source_color = vec4(0.15, 0.65, 1.0, 1.0);
uniform float tiempo = 0.0;
uniform float presencia = 1.0;
uniform bool aire = false;
void fragment() {
	float borde = smoothstep(0.0, 0.20, UV.y) * (1.0 - smoothstep(0.80, 1.0, UV.y));
	float onda = sin(UV.x * 60.0 - tiempo * 8.0 + sin(UV.y * 9.0)) * 0.5 + 0.5;
	float destello = pow(onda, 9.0) * 0.55;
	ALBEDO = mix(tinte.rgb * 0.58, vec3(0.92, 0.98, 1.0), destello);
	EMISSION = tinte.rgb * 0.25 + vec3(destello * 0.25);
	ALPHA = borde * presencia * (aire ? 0.38 : 0.66) * (0.60 + onda * 0.4);
}
