shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform float reloj = 0.0;
uniform float presencia = 0.0;
uniform float opacidad = .65;

void fragment() {
	vec2 flujo = vec2(UV.x * 4.0 - reloj * .95, UV.y * 3.0 + reloj * .32);
	float n = texture(ruido, flujo).r;
	float detalle = texture(ruido, flujo * 2.1 + vec2(-reloj * .4, .7)).r;
	float linea = .5 + .5 * sin(UV.y * 34.0 - UV.x * 17.0 + reloj * 6.0 + n * 5.0);
	float estela = pow(linea, 12.0) * smoothstep(.35, .62, detalle);
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float espuma = clamp(COLOR.r * (.65 + n * .65) + estela * .55, 0.0, 1.0);
	vec3 profundo = vec3(.025, .26, .40);
	vec3 claro = vec3(.16, .64, .78);
	vec3 blanco = vec3(.80, .96, 1.0);
	vec3 agua = mix(profundo, claro, clamp(.25 + n * .5 + fresnel * .35, 0.0, 1.0));
	ALBEDO = mix(agua, blanco, espuma * .92);
	ROUGHNESS = mix(.13, .38, espuma);
	SPECULAR = .85;
	float reflejo = pow(max(0.0, dot(reflect(-normalize(VIEW), normalize(NORMAL)), normalize(vec3(-.4, .8, .4)))), 24.0);
	EMISSION = blanco * (espuma * .20 + reflejo * .28) + claro * fresnel * .16;
	ALPHA = clamp(presencia * COLOR.a * (opacidad + fresnel * .18 + espuma * .25), 0.0, .96);
}
