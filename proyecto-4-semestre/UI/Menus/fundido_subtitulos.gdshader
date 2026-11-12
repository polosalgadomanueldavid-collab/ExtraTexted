shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float inferior = smoothstep(0.35, 1.0, UV.y);
	float izquierda = 1.0 - smoothstep(0.28, 1.0, UV.x);
	COLOR.a *= inferior * izquierda;
}
