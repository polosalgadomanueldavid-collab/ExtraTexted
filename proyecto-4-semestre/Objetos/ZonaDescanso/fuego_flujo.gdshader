shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform float reloj = 0.0;
uniform float semilla = 0.0;
uniform float largo = .6;
uniform float radio = .09;
uniform float intensidad = 0.0;
uniform float capa = 0.0;
uniform float profundidad = 0.8;

void vertex() {
	float y = UV.y;
	vec2 circulo = vec2(cos(UV.x * TAU), sin(UV.x * TAU));
	float n = textureLod(ruido, circulo * .16 + vec2(y * .65 - reloj * .8, semilla), 2.0).r;
	float perfil = (.10 + pow(max(0.0, sin(y * PI)), .72) * (1.0 + y * .8)) * (1.0 - smoothstep(.88, 1.0, y));
	float lobulos = 1.0 + sin(y * 14.0 - reloj * 11.0 + sin(UV.x * TAU * 3.0) * .8) * .15;
	VERTEX.xz *= radio * perfil * (.90 + n * .20) * lobulos;
	VERTEX.z *= profundidad;
	VERTEX.y = y * largo;
	float ondular = y * y * radio * .6;
	VERTEX.x += (sin(y * 10.0 - reloj * 15.0 + semilla) + sin(y * 19.0 - reloj * 22.0) * .3) * ondular;
	VERTEX.z += cos(y * 12.0 - reloj * 12.0 + semilla) * ondular * .65;
}

void fragment() {
	vec2 uv = vec2(cos(UV.x * TAU), sin(UV.x * TAU)) * .22 + vec2(semilla, UV.y * .85 - reloj * .95);
	float grande = texture(ruido, uv).r;
	float fino = texture(ruido, uv * vec2(1.6, 1.4) + vec2(semilla, -reloj * .4)).r;
	float turbulencia = grande * .86 + fino * .14;
	float vista = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float borde = smoothstep(.02, .35, vista);
	float disolver = smoothstep(.10 + UV.y * .18, .23 + UV.y * .22, turbulencia);
	float punta = 1.0 - smoothstep(.83, 1.0, UV.y);
	float calor = clamp(.18 + (1.0 - UV.y) * .23 + turbulencia * .30 + vista * .30 + capa * .20, 0.0, 1.0);
	vec3 rojo = vec3(.95, .075, .008);
	vec3 naranja = vec3(1.0, .35, .035);
	vec3 amarillo = vec3(1.0, .79, .30);
	vec3 color = mix(rojo, naranja, smoothstep(.15, .55, calor));
	color = mix(color, amarillo, smoothstep(.55, .84, calor));
	color = mix(color, vec3(1.0, .94, .70), smoothstep(.84, 1.0, calor));
	ALBEDO = color;
	EMISSION = color * (.12 + calor * .28);
	ALPHA = intensidad * borde * disolver * punta * smoothstep(0.0, .02, UV.y) * (.92 + capa * .08);
}
