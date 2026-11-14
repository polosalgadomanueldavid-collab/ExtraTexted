shader_type canvas_item;
render_mode unshaded;

uniform vec2 centro_uv = vec2(0.5);
uniform float radio_pixeles = 180.0;
uniform float suavizado = 0.45;
uniform vec2 centro_relevo_uv = vec2(0.5);
uniform float radio_relevo_pixeles = 0.0;

void fragment() {
	vec2 distancia_pixeles = (SCREEN_UV - centro_uv) / SCREEN_PIXEL_SIZE;
	float distancia = length(distancia_pixeles);
	float oscuridad = radio_pixeles > 0.0 ? smoothstep(radio_pixeles * (1.0 - suavizado), radio_pixeles, distancia) : 1.0;
	if (radio_relevo_pixeles > 0.0) {
		float distancia_relevo = length((SCREEN_UV - centro_relevo_uv) / SCREEN_PIXEL_SIZE);
		oscuridad = min(oscuridad, smoothstep(radio_relevo_pixeles * (1.0 - suavizado), radio_relevo_pixeles, distancia_relevo));
	}
	COLOR = vec4(vec3(0.0), oscuridad);
}
