shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 grid_color : source_color = vec4(0.56, 0.72, 0.83, 0.19);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 14.0;
	vec2 d = abs(fract(p + 0.5) - 0.5);
	vec2 width = fwidth(p) * 1.15;
	vec2 line = vec2(1.0) - smoothstep(vec2(0.008), width + vec2(0.008), d);
	float edge = 1.0 - smoothstep(6.55, 6.70, length(p));
	ALBEDO = grid_color.rgb;
	ALPHA = max(line.x, line.y) * grid_color.a * edge;
}
