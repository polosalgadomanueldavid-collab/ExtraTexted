shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int mode = 0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.8, 1.2) = 1.0;
uniform float contrast_boost : hint_range(0.8, 1.4) = 1.08;
uniform float saturation_boost : hint_range(0.8, 1.4) = 1.05;

// Adaptado del shader de referencia; conserva su correccion aproximada.
vec3 simulate_protanopia(vec3 color) {
	return vec3(
		dot(color, vec3(0.56667, 0.43333, 0.0)),
		dot(color, vec3(0.55833, 0.44167, 0.0)),
		dot(color, vec3(0.0, 0.24167, 0.75833))
	);
}

vec3 simulate_deuteranopia(vec3 color) {
	return vec3(
		dot(color, vec3(0.625, 0.375, 0.0)),
		dot(color, vec3(0.7, 0.3, 0.0)),
		dot(color, vec3(0.0, 0.3, 0.7))
	);
}

vec3 simulate_tritanopia(vec3 color) {
	return vec3(
		dot(color, vec3(0.95, 0.05, 0.0)),
		dot(color, vec3(0.0, 0.43333, 0.56667)),
		dot(color, vec3(0.0, 0.475, 0.525))
	);
}

vec3 boost_clarity(vec3 color) {
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 saturated = mix(vec3(luma), color, saturation_boost);
	return clamp((saturated - 0.5) * contrast_boost + 0.5, 0.0, 1.0);
}

vec3 daltonize(vec3 original, vec3 simulated, int filter_mode) {
	vec3 error = original - simulated;
	vec3 correction = vec3(0.0);
	if (filter_mode == 1 || filter_mode == 2) {
		correction = vec3(0.0, error.r * 0.7 + error.g, error.r * 0.7 + error.b);
	} else if (filter_mode == 3) {
		correction = vec3(error.r + error.b * 0.2, error.g + error.b * 0.25, 0.0);
	}
	return clamp(original + correction, 0.0, 1.0);
}

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 corrected = source.rgb;
	if (mode == 1) {
		corrected = daltonize(source.rgb, simulate_deuteranopia(source.rgb), mode);
	} else if (mode == 2) {
		corrected = daltonize(source.rgb, simulate_protanopia(source.rgb), mode);
	} else if (mode == 3) {
		corrected = daltonize(source.rgb, simulate_tritanopia(source.rgb), mode);
	}
	vec3 color = source.rgb;
	if (mode >= 1 && mode <= 3) {
		color = mix(source.rgb, boost_clarity(corrected), intensity);
	}
	COLOR = vec4(clamp(color * brightness, 0.0, 1.0), source.a);
}
