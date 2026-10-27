shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = vec3(0.025, 0.045, 0.075);
	ALPHA = (1.0 - smoothstep(0.05, 0.98, radius)) * opacity;
}
