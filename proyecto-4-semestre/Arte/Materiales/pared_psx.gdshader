shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D textura_pared : source_color, repeat_enable;
uniform float repeticiones_por_metro = 1.2;

varying vec3 posicion_mundo;
varying vec3 normal_mundo;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 pesos = pow(abs(normalize(normal_mundo)), vec3(4.0));
	pesos /= max(pesos.x + pesos.y + pesos.z, 0.0001);
	vec3 p = posicion_mundo * repeticiones_por_metro;
	vec3 color_x = texture(textura_pared, p.yz).rgb;
	vec3 color_y = texture(textura_pared, p.xz).rgb;
	vec3 color_z = texture(textura_pared, p.xy).rgb;
	ALBEDO = color_x * pesos.x + color_y * pesos.y + color_z * pesos.z;
	ROUGHNESS = 0.96;
}
