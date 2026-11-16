shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D frente : source_color, filter_linear;
uniform sampler2D reverso : source_color, filter_linear;
uniform float lado = 1.0;
uniform float giro : hint_range(0.0, 1.0) = 0.0;
uniform bool pasando = false;
uniform float sombra : hint_range(0.0, 1.0) = 0.0;
uniform int pestana_desde = 0;
uniform int pestana_hasta = 2;

void vertex() {
	float u = UV.x;
	float angulo = giro * PI - sin(giro * PI) * 0.28 * u;
	VERTEX.x = lado * u * 6.4 * cos(angulo);
	VERTEX.z = 0.10 + 0.12 * sin(u * PI) + u * 6.4 * sin(angulo);
	VERTEX.z += sin(giro * PI) * 0.16 * sin(UV.y * PI) * u;
	if (pasando) { VERTEX.z += 0.025; }
}

void fragment() {
	bool dorso = pasando && !FRONT_FACING;
	float cara = dorso ? -lado : lado;
	vec2 uv_papel = vec2(0.5 + cara * UV.x * 0.5, UV.y);
	if (pasando && (uv_papel.x < 70.0 / 1280.0 || uv_papel.x > 1210.0 / 1280.0)) {
		int pestana = int(floor((uv_papel.y * 720.0 - 140.0) / 66.0));
		if (pestana < pestana_desde || pestana > pestana_hasta) { discard; }
	}
	vec4 papel;
	if (dorso) { papel = texture(reverso, uv_papel); }
	else { papel = texture(frente, uv_papel); }
	// El pliegue y la hoja levantada proyectan una sombra suave sobre el papel.
	float pliegue = 0.09 * exp(-UV.x * 16.0);
	float volumen = pasando ? 0.16 * sin(giro * PI) * (0.35 + 0.65 * UV.x) : 0.0;
	float proyectada = sombra * 0.17 * exp(-UV.x * 3.0);
	ALBEDO = papel.rgb * (1.0 - pliegue - volumen - proyectada);
	ALPHA = papel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.1;
}
