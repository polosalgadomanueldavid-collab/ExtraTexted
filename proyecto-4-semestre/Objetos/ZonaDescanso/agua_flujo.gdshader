shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform float reloj = 0.0;
uniform float presencia = 1.0;

void fragment() {
	// Ondas que viajan a lo largo del chorro, en dos escalas distintas.
	vec2 flujo = vec2(UV.x * 3.5 - reloj * 1.3, UV.y * 2.0);
	float n = texture(ruido, flujo).r;
	float fino = texture(ruido, flujo * vec2(2.3, 1.7) + vec2(-reloj * .8, reloj * .15)).r;
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	float cresta = smoothstep(.59, .78, n * .55 + fino * .45);
	vec3 profundo = vec3(.035, .29, .38);
	vec3 claro = vec3(.16, .64, .74);
	vec3 agua = mix(profundo, claro, .30 + n * .45 + fresnel * .25);
	vec3 espuma = vec3(.72, .94, .97);
	float reflejo = pow(max(0.0, dot(reflect(-normalize(VIEW), normalize(NORMAL)), normalize(vec3(-.35, .8, .45)))), 28.0);
	float filamento = pow(.5 + .5 * sin(UV.y * 25.13 + UV.x * 14.0 - reloj * 5.0 + n * 3.0), 22.0) * smoothstep(.38, .70, fino);
	ALBEDO = mix(agua, espuma, clamp(cresta * .45 + fresnel * .55 + filamento * .45, 0.0, .88));
	ROUGHNESS = .07 + fino * .08;
	SPECULAR = .85;
	METALLIC = .06;
	// Reflejo de cielo suave: conserva lectura en Compatibility sin SSR.
	EMISSION = vec3(.09, .22, .25) * fresnel * .6 + espuma * (reflejo * .65 + filamento * .12);
	ALPHA = presencia * (.43 + fresnel * .30 + cresta * .10 + reflejo * .12);
}
