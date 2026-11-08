shader_type spatial;
// A flat, cartoon planet: up to three colour bands from noise or stripes, optional polar
// caps, and two-tone lighting from the star (a lit side and a tinted night side), worked
// out in fragment() (see two_tone_light.gdshaderinc). Unshaded, so the ambient light and
// specular never touch its colours.
render_mode unshaded;

#include "res://shared/two_tone_light.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.3, 0.55, 0.85);
uniform vec3 mid_color : source_color = vec3(0.45, 0.75, 0.4);
uniform vec3 top_color : source_color = vec3(0.92, 0.85, 0.6);
// Where the noise switches from base to mid, and from mid to top.
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float top_threshold : hint_range(0.0, 1.0) = 0.62;
uniform float noise_scale : hint_range(0.1, 8.0) = 2.0;
// 0 is blobs (continents, craters), 1 is horizontal stripes (a gas giant).
uniform float stripes : hint_range(0.0, 1.0) = 0.0;
uniform float stripe_count : hint_range(1.0, 20.0) = 6.0;
uniform vec3 cap_color : source_color = vec3(0.95, 0.97, 1.0);
// The share of the sphere's height each polar cap covers. 0 is no caps.
uniform float cap_size : hint_range(0.0, 0.5) = 0.0;
uniform float seed = 0.0;
// Extra blur on the day-night edge. 0 keeps it a crisp line about a pixel wide at any zoom.
uniform float terminator_softness : hint_range(0.0, 0.5) = 0.0;

varying vec3 local_position;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * value_noise(p);
		p = p * 2.03 + vec3(17.1, 3.7, 9.2);
		amp *= 0.5;
	}
	return sum / 0.9375;
}

// 0 below edge, 1 above it, with an antialiased step one pixel wide.
float crisp_step(float edge, float x) {
	float width = max(fwidth(x), 1e-4);
	return smoothstep(edge - width, edge + width, x);
}

void vertex() {
	// Object space, so the pattern turns with the planet's spin.
	local_position = normalize(VERTEX);
}

void fragment() {
	vec3 p = local_position;
	float blobs = fbm(p * noise_scale + seed);
	// Stripes along the height, wobbled by the noise so they aren't ruler-straight.
	float bands = 0.5 + 0.5 * sin((p.y * stripe_count + blobs * 1.5) * PI);
	float h = mix(blobs, bands, stripes);
	vec3 color = base_color;
	color = mix(color, mid_color, crisp_step(mid_threshold, h));
	color = mix(color, top_color, crisp_step(top_threshold, h));
	// A wobbly cap edge, from the same noise.
	float cap = abs(p.y) + (blobs - 0.5) * 0.15;
	color = mix(color, cap_color, crisp_step(1.0 - cap_size, cap) * step(0.001, cap_size));
	ALBEDO = two_tone_light(color, NORMAL, VERTEX, INV_VIEW_MATRIX, terminator_softness);
}
