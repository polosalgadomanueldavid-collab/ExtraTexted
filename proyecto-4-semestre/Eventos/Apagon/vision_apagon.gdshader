shader_type canvas_item;
render_mode unshaded;

uniform vec2 centro_uv = vec2(0.5);
uniform float radio_pixeles = 180.0;
uniform float suavizado = 0.45;

void fragment() {
	vec2 distancia_pixeles = (SCREEN_UV - centro_uv) / SCREEN_PIXEL_SIZE;
	float distancia = length(distancia_pixeles);
	float oscuridad = smoothstep(radio_pixeles * (1.0 - suavizado), radio_pixeles, distancia);
	COLOR = vec4(vec3(0.0), oscuridad);
}
