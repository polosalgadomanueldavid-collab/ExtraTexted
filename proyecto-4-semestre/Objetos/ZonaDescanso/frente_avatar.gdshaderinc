// Mismo frente espacial que ResolucionAvatar.peso_en(). Reloj explícito: pausa/LAN.
uniform bool avatar_activo = false;
uniform vec2 avatar_origen = vec2(0.0);
uniform float avatar_tiempo = 0.0;
uniform float avatar_alcance = 15.0;

float avance_avatar(vec2 punto) {
	float llegada = distance(punto, avatar_origen) / avatar_alcance * 1.4;
	return avatar_activo ? smoothstep(llegada, llegada + .85, avatar_tiempo) : 0.0;
}
