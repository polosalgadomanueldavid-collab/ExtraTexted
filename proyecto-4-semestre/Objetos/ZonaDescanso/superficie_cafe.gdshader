shader_type spatial;
render_mode cull_disabled;

uniform float centro_x = 0.021208;
uniform float altura_taza = 0.0825;
uniform float radio_fondo = 0.0275;
uniform float llenado : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// La gravedad en coordenadas de la taza mantiene horizontal el líquido.
	vec3 arriba = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
	vec2 pendiente = -arriba.xz / max(arriba.y, 0.5);
	// Reserva margen bajo el labio también en el lado elevado del sorbo.
	float nivel_maximo = min(altura_taza - 0.012, altura_taza - 0.006 - 0.040 * length(pendiente));
	// El último sorbo permanece por encima del fondo y del tramo curvo interior.
	float nivel_minimo = 0.017 + 0.038 * length(pendiente);
	float nivel = mix(min(nivel_minimo, nivel_maximo), nivel_maximo, llenado);
	float conicidad = (0.0375 - radio_fondo) / (altura_taza - 0.019);
	vec2 direccion = UV * 2.0 - 1.0;
	float fraccion = length(direccion);
	direccion /= max(fraccion, 0.0001);
	float inclinacion = dot(pendiente, direccion);
	// Intersección exacta del plano con la pared cónica, sin huecos laterales.
	float radio = (radio_fondo + conicidad * (nivel - 0.015)) / (1.0 - conicidad * inclinacion);
	vec2 punto = direccion * radio * fraccion;
	float menisco = smoothstep(0.96, 1.0, fraccion) * 0.00025;
	VERTEX = vec3(centro_x + punto.x, nivel + dot(pendiente, punto) + menisco, punto.y);
	NORMAL = normalize(vec3(-pendiente.x, 1.0, -pendiente.y));
}

void fragment() {
	float borde = smoothstep(0.94, 1.0, length(UV * 2.0 - 1.0));
	ALBEDO = mix(vec3(0.095, 0.036, 0.014), vec3(0.17, 0.074, 0.027), borde * 0.4);
	ROUGHNESS = 0.24;
	SPECULAR = 0.48;
}
