shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 sombra : source_color = vec4(0.35, 0.49, 0.50, 1.0);
uniform vec4 claro : source_color = vec4(0.62, 0.73, 0.70, 1.0);

varying vec2 posicion_vidrio;

void vertex() {
	posicion_vidrio = VERTEX.xy;
}

void fragment() {
	// Suaviza las estrías subpíxel cuando se ven desde el lateral.
	float fase = posicion_vidrio.x * 21.0;
	float detalle = 1.0 - smoothstep(0.18, 0.5, fwidth(fase));
	float luz_difusa = smoothstep(-0.23, 0.17, posicion_vidrio.y - 0.25 * posicion_vidrio.x);
	float relieve = detalle * cos(fase * TAU);
	ALBEDO = mix(sombra.rgb, claro.rgb, 0.28 + 0.37 * luz_difusa + 0.13 * relieve);
	NORMAL_MAP = vec3(0.5 + 0.055 * detalle * sin(fase * TAU), 0.5, 1.0);
	ROUGHNESS = 0.42;
	SPECULAR = 0.42;
}
