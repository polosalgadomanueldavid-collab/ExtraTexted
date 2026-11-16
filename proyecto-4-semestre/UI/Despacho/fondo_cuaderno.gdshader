shader_type canvas_item;
render_mode unshaded;
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec3 fondo = textureLod(pantalla, SCREEN_UV, 3.5).rgb;
	float vineta = smoothstep(0.2, 0.75, length(SCREEN_UV - vec2(0.5)));
	COLOR = vec4(mix(fondo, vec3(0.055, 0.085, 0.10), 0.48 + vineta * 0.24), 1.0);
}
