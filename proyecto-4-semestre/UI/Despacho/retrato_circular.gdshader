shader_type canvas_item;

void fragment() {
	vec2 retrato_uv = (UV - vec2(0.5)) / 1.08 + vec2(0.5);
	vec4 retrato = texture(TEXTURE, retrato_uv);
	float barrido = fract(TIME * 0.2) * 1.7 - 0.35;
	float reflejo = exp(-pow((UV.x + UV.y * 0.24 - barrido) * 13.0, 2.0)) * 0.12;
	float circulo = 1.0 - smoothstep(0.43, 0.45, distance(UV, vec2(0.5)));
	COLOR = vec4(retrato.rgb + vec3(reflejo), retrato.a * circulo);
}
