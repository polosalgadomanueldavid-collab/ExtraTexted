shader_type spatial;
render_mode cull_disabled;

uniform vec4 tinte : source_color = vec4(1.0);
uniform float rugosidad = 0.64;
uniform float metal = 0.0;
uniform float reloj = 0.0;
uniform mat4 pecho;
uniform mat4 pelvis;
uniform vec4 capsulas_a[8];
uniform vec4 capsulas_b[8];

vec3 deformar(vec3 p, vec2 uv, bool manto) {
	float v = uv.y;
	if (!manto) {
		// El tejido neutro ya contiene la ondulacion de t=0.
		p.z -= .07 * (sin(reloj * 3.2 - v * 3.0 + uv.x * 2.0) - sin(-v * 3.0 + uv.x * 2.0)) * v * v;
		p.x += .055 * (sin(reloj * 3.0 - v * 4.0) - sin(-v * 4.0)) * v * v;
	}
	float peso = manto ? 0.0 : smoothstep(.15, .85, v) * .55;
	p = mix((pecho * vec4(p, 1.0)).xyz, (pelvis * vec4(p, 1.0)).xyz, peso);
	vec3 arriba = normalize(pecho[1].xyz);
	vec3 deslizamiento = manto ? arriba : -normalize(pecho[2].xyz);
	for (int pasada = 0; pasada < 3; pasada++) {
		bool movido = false;
		for (int i = 0; i < 8; i++) {
			vec3 a = capsulas_a[i].xyz;
			vec3 ab = capsulas_b[i].xyz - a;
			float radio = capsulas_a[i].w + (manto ? .04 : 0.0);
			vec3 q = a + ab * clamp(dot(p - a, ab) * capsulas_b[i].w, 0.0, 1.0);
			vec3 delta = p - q;
			float d2 = dot(delta, delta);
			if (d2 < radio * radio) {
				vec3 eje = ab * inversesqrt(max(dot(ab, ab), .000001));
				vec3 dir = deslizamiento - eje * dot(deslizamiento, eje);
				dir = dot(dir, dir) < .000001 ? arriba : normalize(dir);
				float b = dot(delta, dir);
				p += dir * (-b + sqrt(max(0.0, b * b + radio * radio - d2)) + .012);
				movido = true;
			}
		}
		if (!movido) { break; }
	}
	return p;
}

void vertex() {
	bool manto = COLOR.r > .5;
	vec3 n = normalize(NORMAL);
	vec3 eje = abs(n.y) < .9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangente = normalize(cross(eje, n));
	vec3 bitangente = cross(n, tangente);
	vec3 p = deformar(VERTEX, UV, manto);
	vec3 du = deformar(VERTEX + tangente * .002, UV, manto) - p;
	vec3 dv = deformar(VERTEX + bitangente * .002, UV, manto) - p;
	vec3 normal_deformada = cross(du, dv);
	NORMAL = dot(normal_deformada, normal_deformada) > 1e-14 ? normalize(normal_deformada) : normalize(mat3(pecho) * n);
	VERTEX = p;
}

void fragment() {
	ALBEDO = tinte.rgb;
	ROUGHNESS = rugosidad;
	METALLIC = metal;
}
