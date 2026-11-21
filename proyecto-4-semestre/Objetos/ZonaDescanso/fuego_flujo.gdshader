shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform float reloj = 0.0;
uniform float semilla = 0.0;
uniform float largo = .6;
uniform float radio = .09;
uniform float intensidad = 0.0;
uniform float capa = 0.0;

void vertex() {
	float y = UV.y;
	float n = texture(ruido, vec2(UV.x * 2.0 + semilla, y * 2.7 - reloj * 2.4)).r;
	float perfil = pow(max(0.0, sin(y * PI)), .65) * (1.0 - y * .4) + .25 * (1.0 - y);
	VERTEX.xz *= radio * perfil * (.85 + n * .30);
	VERTEX.y = y * largo;
	float ondular = y * y * radio;
	VERTEX.x += (sin(y * 10.0 - reloj * 15.0 + semilla) + sin(y * 19.0 - reloj * 22.0) * .3) * ondular;
	VERTEX.z += cos(y * 12.0 - reloj * 12.0 + semilla) * ondular * .65;
}

void fragment() {
	vec2 uv = vec2(UV.x * 2.7 + semilla, UV.y * 1.3 - reloj * 2.2);
	float grande = texture(ruido, uv).r;
	float fino = texture(ruido, uv * vec2(2.1, 1.65) + vec2(semilla, -reloj)).r;
	float turbulencia = grande * .78 + fino * .22;
	float borde = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), .65);
	float disolver = smoothstep(.16 + UV.y * .32, .46 + UV.y * .24, turbulencia);
	float punta = 1.0 - smoothstep(.68, 1.0, UV.y);
	float calor = clamp((1.0 - UV.y) * .36 + turbulencia * .35 + capa * .34, 0.0, 1.0);
	vec3 rojo = vec3(.95, .075, .008);
	vec3 naranja = vec3(1.0, .35, .035);
	vec3 amarillo = vec3(1.0, .79, .30);
	vec3 color = mix(rojo, naranja, smoothstep(.15, .55, calor));
	color = mix(color, amarillo, smoothstep(.55, .84, calor));
	color = mix(color, vec3(1.0, .94, .70), smoothstep(.84, 1.0, calor));
	ALBEDO = color;
	EMISSION = color * (.15 + calor * .40);
	ALPHA = intensidad * borde * disolver * punta * smoothstep(0.0, .035, UV.y) * (.62 + capa * .2);
}
