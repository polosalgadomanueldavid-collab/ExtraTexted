shader_type canvas_item;
render_mode unshaded;

uniform vec2 centro_uv = vec2(0.5);
uniform float radio_pixeles = 180.0;
uniform float suavizado = 0.45;
uniform vec2 centro_relevo_uv = vec2(0.5);
uniform float radio_relevo_pixeles = 0.0;
uniform float apertura_avatar = 0.0;

void fragment() {
	vec2 distancia_pixeles = (SCREEN_UV - centro_uv) / SCREEN_PIXEL_SIZE;
	float distancia = length(distancia_pixeles);
	float radio_pantalla = length(max(centro_uv, vec2(1.0) - centro_uv) / SCREEN_PIXEL_SIZE) + radio_pixeles * .4;
	float radio_abierto = mix(radio_pixeles, max(radio_pixeles, radio_pantalla), apertura_avatar);
	float oscuridad = radio_abierto > 0.0 ? smoothstep(radio_abierto * (1.0 - suavizado), radio_abierto, distancia) : 1.0;
	if (radio_relevo_pixeles > 0.0) {
		float distancia_relevo = length((SCREEN_UV - centro_relevo_uv) / SCREEN_PIXEL_SIZE);
		oscuridad = min(oscuridad, smoothstep(radio_relevo_pixeles * (1.0 - suavizado), radio_relevo_pixeles, distancia_relevo));
	}
	COLOR = vec4(vec3(0.0), oscuridad * (1.0 - smoothstep(.35, 1.0, apertura_avatar)));
}
