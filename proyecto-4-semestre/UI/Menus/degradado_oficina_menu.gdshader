shader_type canvas_item;

void fragment() {
	float transicion = smoothstep(0.10, 0.66, UV.x);
	float opacidad = 0.76 * (1.0 - transicion);
	COLOR = vec4(0.018, 0.065, 0.09, opacidad);
}
