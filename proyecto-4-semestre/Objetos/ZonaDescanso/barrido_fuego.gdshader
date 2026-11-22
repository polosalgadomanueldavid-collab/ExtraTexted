shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform float reloj = 0.0;
uniform float presencia = 1.0;

void vertex() {
	float punta = UV.y * UV.y;
	VERTEX += NORMAL * sin(UV.y * 18.0 - reloj * 14.0 + UV.x * 9.0) * .12 * punta;
}

void fragment() {
	vec2 uv = vec2(UV.x * .8, UV.y * .75 - reloj * .95);
	float ruido_grande = texture(ruido, uv).r;
	float n = ruido_grande * .85 + texture(ruido, uv * 1.6).r * .15;
	float borde = smoothstep(0.0, .10, UV.y) * (1.0 - smoothstep(.60 + n * .25, 1.0, UV.y));
	float extremos = smoothstep(0.0, .09, UV.x) * (1.0 - smoothstep(.88, 1.0, UV.x));
	float calor = clamp((1.0 - UV.y) * .65 + n * .50, 0.0, 1.0);
	vec3 color = mix(vec3(1.0, .10, .008), vec3(1.0, .55, .035), smoothstep(.22, .65, calor));
	color = mix(color, vec3(1.0, .91, .46), smoothstep(.65, .96, calor));
	ALBEDO = color;
	EMISSION = color * .24;
	ALPHA = COLOR.a * presencia * borde * extremos * smoothstep(.17, .39, n);
}
