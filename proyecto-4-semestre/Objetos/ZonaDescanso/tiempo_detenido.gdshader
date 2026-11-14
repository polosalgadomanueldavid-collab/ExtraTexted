shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 centro = vec2(0.5);
uniform float radio = 0.0;
uniform float fuerza = 1.0;
void fragment() {
	vec2 d = SCREEN_UV - centro;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float distancia = length(d);
	float dentro = (1.0 - smoothstep(radio - 0.035, radio, distancia)) * fuerza;
	float borde = (1.0 - smoothstep(0.0, 0.035, abs(distancia - radio))) * fuerza;
	vec3 original = texture(pantalla, SCREEN_UV).rgb;
	float gris = dot(original, vec3(0.299, 0.587, 0.114));
	vec3 detenido = vec3(gris) * vec3(0.81, 0.85, 0.94);
	COLOR = vec4(mix(original, detenido, dentro) + borde * 0.28, 1.0);
}
