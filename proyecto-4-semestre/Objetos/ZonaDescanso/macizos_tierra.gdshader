shader_type spatial;
render_mode cull_back, diffuse_burley;

// Todas las instancias tienen transformación identidad. Los datos inmutables
// guardan origen XZ, altura y tamaño; solo cambia el reloj explícito del gesto.
uniform float fase = 0.0;
uniform float suelo = 0.0;
uniform vec3 mano_l = vec3(-0.3, 0.5, 0.0);
uniform vec3 mano_r = vec3(0.3, 0.5, 0.0);
uniform float pisada_l = 0.29;
uniform float pisada_r = 0.51;

mat3 giro_y(float a) {
	return mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
}

void vertex() {
	vec4 dato = INSTANCE_CUSTOM;
	float semilla = fract(sin(dot(dato.xy, vec2(12.9898, 78.233))) * 43758.5453);
	float pisada = dato.x < 0.0 ? pisada_l : pisada_r;
	float surgir = smoothstep(pisada, pisada + 0.055 + semilla * 0.02, fase);
	float alzar = smoothstep(0.535, 0.635, fase);
	float reunir = smoothstep(0.625, 0.685, fase);
	float lanzar = smoothstep(0.715 + semilla * 0.012, 0.90, fase);
	float devolver = smoothstep(0.88, 1.0, fase);
	vec3 mano = dato.x < 0.0 ? mano_l : mano_r;
	vec3 centro = vec3(dato.x, suelo - dato.w * 1.6, dato.y);
	centro.y += surgir * (dato.w * 1.8 + 0.12) + alzar * dato.z;
	centro.xz *= 1.0 - reunir * 0.12;
	centro += alzar * (1.0 - lanzar) * vec3(clamp(mano.x, -0.6, 0.6) * 0.30, clamp(mano.y - suelo - 0.3, -0.2, 0.6) * 0.30, clamp(mano.z, -0.5, 0.6) * 0.2);
	centro = giro_y(reunir * 0.40) * centro;
	// El frente sigue hacia delante al recoger las manos, no gira de regreso.
	centro.z += lanzar * (4.8 + semilla * 1.3);
	centro.x += lanzar * sign(dato.x) * 0.45;
	centro.y += sin(lanzar * 3.14159265) * 0.5;
	centro.y = mix(centro.y, suelo - dato.w, devolver);
	float escala = dato.w * surgir * (1.0 - smoothstep(0.96, 1.0, fase));
	vec3 proporcion = vec3(0.85 + semilla * 0.35, 1.0 + semilla * 0.65, 0.8 + semilla * 0.25);
	mat3 giro = giro_y(semilla * 6.2831853 + reunir * 0.4 + lanzar * (semilla - 0.5));
	VERTEX = giro * (VERTEX * proporcion * escala) + centro;
	NORMAL = normalize(giro * (NORMAL / proporcion));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.96;
}
