shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform int zona = 1;
uniform float presencia = 0.0;
uniform float pulso = 0.0;
varying vec3 reposo;
void vertex() {
 reposo = CUSTOM0.xyz;
 VERTEX += NORMAL * 0.0025;
}
float linea(vec2 p, vec2 a, vec2 b, float ancho) {
 vec2 ab = b-a;
 return length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0))/ancho;
}
void fragment() {
 vec3 p = reposo;
 float d = 100.0;
 if (zona == 0) {
  float angulo = atan((p.z-.012)/.416, (p.y-1.982)/.391);
  float ancho = .073;
  if (angulo > .84) { ancho = .190 * clamp((1.48-angulo)/.64,0.0,1.0); }
  // La franja trasera llega hasta la base real de la cabeza, sin extremo plano.
  if (angulo < 1.48 && angulo > -3.14) { d = abs(p.x)/max(ancho,.0001); }
 } else {
  if (p.z < -.04 && p.y > .44) {
   d = linea(p.xy,vec2(0.0,.70),vec2(0.0,1.84),.061);
   d = min(d,linea(vec2(abs(p.x),p.y),vec2(0.0,.70),vec2(.30,.44),.047));
   d = min(d,linea(vec2(abs(p.x),p.y),vec2(0.0,1.48),vec2(.43,1.52),.053));
   d = min(d,linea(vec2(abs(p.x),p.y),vec2(.43,1.52),vec2(.744,.76),.051));
   if (p.y < .79 && p.y > .59) {
    float ancho = .115 * clamp((p.y-.59)/.20,0.0,1.0);
    d = min(d,abs(abs(p.x)-.744)/max(ancho,.0001));
   }
  }
  // Las bandas descienden por las piernas y terminan en flechas sobre los pies.
  if (p.y < .45 && abs(p.x) > .12) {
   float angulo = atan(abs(p.x)-.30,p.z);
   float rumbo = 3.14159265*smoothstep(.23,.45,p.y);
   float diferencia = abs(atan(sin(angulo-rumbo),cos(angulo-rumbo)));
   d = min(d,diferencia*.14/.046);
   if (p.y < .22 && p.z > .06) {
    float ancho = .105*clamp((.235-p.z)/.175,0.0,1.0);
    d = abs(abs(p.x)-.30)/max(ancho,.0001);
   }
  }
 }
 float borde = 1.0-smoothstep(.90,1.03,d);
 if (borde * presencia < .002) { discard; }
 float centro = 1.0-smoothstep(.48,.92,d);
 vec3 color = mix(vec3(.04,.70,1.0),vec3(.90,1.0,1.0),centro);
 ALBEDO = color;
 EMISSION = color * (2.0 + .3*pulso);
 ALPHA = borde * presencia;
}
