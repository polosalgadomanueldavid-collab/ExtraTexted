shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float fase = 0.0;
uniform float reloj = 0.0;
// Paleta compensada para el tono fílmico de la oficina.
uniform vec4 naranja : source_color = vec4(1.0, 0.305, 0.08, 1.0);
uniform vec4 amarillo : source_color = vec4(1.0, 0.54, 0.21, 1.0);
uniform vec4 crema : source_color = vec4(1.0, 0.77, 0.40, 1.0);
uniform vec4 borde : source_color = vec4(0.49, 0.12, 0.025, 1.0);
varying float altura;
varying vec3 radial_local;
varying vec3 posicion_local;
varying vec3 camara_local;

void vertex() {
	altura = VERTEX.y;
	radial_local = vec3(NORMAL.x, 0.0, NORMAL.z);
	posicion_local = VERTEX;
	camara_local = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = reloj * 4.6 + fase;
	float pulso = sin(t - altura * 7.0);
	// Ondas que ascienden, estrechan el cuello y curvan la punta.
	VERTEX.xz *= 1.0 + pulso * 0.16 * sin(altura * 3.14159);
	VERTEX.x += (sin(t - altura * 3.8) * 0.23 + sin(t * 0.5) * 0.12) * altura * altura;
	VERTEX.z += cos(t * 0.7 - altura * 4.0) * 0.13 * altura * altura;
	VERTEX.y *= 1.0 + sin(t) * 0.17;
}

void fragment() {
	// Núcleo pintado sobre el volumen, visible desde cualquier lado.
	vec2 vista = normalize(camara_local.xz - posicion_local.xz);
	vec2 radial = normalize(radial_local.xz);
	float frente = abs(dot(radial, vista));
	float lateral = dot(radial, vec2(-vista.y, vista.x));
	float t = reloj * 4.6 + fase;
	float onda = sin(altura * 12.0 - t) * 0.09 + sin(altura * 22.0 + t * 0.7) * 0.035;
	float anchura = 0.64 * (1.0 - smoothstep(0.16, 0.84, altura));
	float interior = 0.29 * (1.0 - smoothstep(0.03, 0.40, altura));
	float corazon = (1.0 - smoothstep(anchura - 0.02, anchura + 0.02, abs(lateral + onda))) * (1.0 - smoothstep(0.79, 0.85, altura));
	float centro = (1.0 - smoothstep(interior - 0.02, interior + 0.02, abs(lateral + onda * 0.5))) * (1.0 - smoothstep(0.35, 0.41, altura));
	vec3 color = mix(naranja.rgb, amarillo.rgb, corazon);
	color = mix(color, crema.rgb, centro);
	color = mix(borde.rgb, color, smoothstep(0.07, 0.19, frente));
	ALBEDO = color;
}
