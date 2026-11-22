shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://Objetos/ZonaDescanso/frente_avatar.gdshaderinc"
uniform vec4 tinte : source_color = vec4(.4, .85, 1.0, 1.0);
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float avance = avance_avatar(mundo);
	float cresta = sin(avance * PI);
	float distancia = length(mundo - avatar_origen);
	float filamentos = .65 + .35 * sin(distancia * 16.0 - avatar_tiempo * 19.0);
	ALBEDO = mix(tinte.rgb, vec3(1.0), cresta * .35);
	EMISSION = tinte.rgb * .25;
	ALPHA = pow(cresta, 3.0) * filamentos * .24;
}
