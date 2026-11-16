shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform float reloj = 0.0;
uniform float presion = 0.0;
uniform float nivel = -100.0;
varying float altura;

void vertex() {
	VERTEX.x += sin(UV.y * 28.0 - reloj * 19.0) * 0.006 * UV.y;
	altura = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (altura < nivel) { discard; }
	float brillo = 0.5 + 0.5 * sin(UV.y * 52.0 - reloj * 23.0);
	ALBEDO = mix(vec3(0.18, 0.64, 0.78), vec3(0.75, 0.95, 1.0), brillo * 0.55);
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	EMISSION = vec3(0.07, 0.18, 0.20);
	ALPHA = presion * (0.55 + brillo * 0.15) * (1.0 - smoothstep(0.75, 1.0, UV.y));
}
