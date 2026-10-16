// Shared by the soft-flat shaders: the banded light ramp and a little value noise.

uniform float band_mid : hint_range(0.0, 1.0) = 0.22;
uniform float band_high : hint_range(0.0, 1.0) = 0.6;
uniform float band_softness : hint_range(0.01, 0.5) = 0.14;
uniform float light_strength : hint_range(0.0, 3.0) = 0.7;

// Three bands (dark, mid, lit) with soft edges. The dark band is just the ambient light.
float soft_ramp(float n_dot_l) {
	float mid = smoothstep(band_mid - band_softness, band_mid + band_softness, n_dot_l);
	float high = smoothstep(band_high - band_softness, band_high + band_softness, n_dot_l);
	return mid * 0.55 + high * 0.45;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
