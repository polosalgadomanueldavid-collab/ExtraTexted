// Mismo frente espacial que ResolucionAvatar.peso_en(). Reloj explícito: pausa/LAN.
uniform bool avatar_activo = false;
uniform vec2 avatar_origen = vec2(0.0);
uniform float avatar_tiempo = 0.0;
uniform float avatar_alcance = 15.0;
uniform vec2 avatar_ritmo = vec2(1.4, .85);

float avance_avatar(vec2 punto) {
	float llegada = distance(punto, avatar_origen) / avatar_alcance * avatar_ritmo.x;
	float t = clamp((avatar_tiempo - llegada) / avatar_ritmo.y, 0.0, 1.0);
	return avatar_activo ? t * t * t * (t * (t * 6.0 - 15.0) + 10.0) : 0.0;
}
