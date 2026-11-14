shader_type spatial;
render_mode unshaded;

uniform sampler2D textura_piso : source_color, repeat_enable, filter_nearest;
uniform sampler2D mascara_huecos : repeat_disable, filter_nearest;
uniform vec2 origen_grid = vec2(-4.5, -0.1);
uniform vec2 tamano_piso = vec2(7.0, 12.5);
uniform bool usar_mascara_huecos = false;

varying vec3 posicion_mundo;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = posicion_mundo.xz - origen_grid;
	if (usar_mascara_huecos) {
		vec2 uv_mascara = uv / tamano_piso;
		if (texture(mascara_huecos, uv_mascara).r < 0.5) {
			discard;
		}
	}
	ALBEDO = texture(textura_piso, uv).rgb;
}
