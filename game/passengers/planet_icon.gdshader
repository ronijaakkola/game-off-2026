shader_type canvas_item;
// A planet as a flat icon in a square: a disc with a night side, and optional rings
// that pass behind the disc at the top and in front of it at the bottom. Lengths are in
// icon widths, with one pixel being a fourteenth, so the icon looks the same at any size.

uniform vec4 color : source_color = vec4(1.0);
// The night side's multiply: planet.gdshader's default shadow_color, so it matches.
uniform vec4 night_tint : source_color = vec4(0.5, 0.45, 0.78, 1.0);
uniform bool has_rings = false;
uniform vec4 ring_color : source_color = vec4(1.0);
// The rings' lean in radians, the planet's tilt.
uniform float ring_tilt = 0.0;
// A circle cut out of the icon, as where something sits on top of it, in UV. A radius
// of 0 cuts nothing.
uniform vec2 cut_center = vec2(0.0);
uniform float cut_radius = 0.0;

const float PIXEL = 1.0 / 14.0;
const float RING_RX = 1.75;
const float RING_RY = 0.5;
const float RING_WIDTH = 1.5 * PIXEL;
const float MARGIN = 0.5 * PIXEL;
const float BARE_RADIUS = 0.42;

// Coverage of a shape at signed distance d (negative inside), antialiased over aa.
float cover(float d, float aa) {
	return clamp(0.5 - d / aa, 0.0, 1.0);
}

// Lays colour c with coverage a over the premultiplied colour under.
vec4 over(vec4 under, vec3 c, float a) {
	return vec4(c * a + under.rgb * (1.0 - a), a + under.a * (1.0 - a));
}

void fragment() {
	vec2 p = UV - 0.5;
	float aa = max(fwidth(UV.x), fwidth(UV.y));
	// With rings, the disc shrinks until the rings' long axis fits at any tilt.
	float r = has_rings ? (0.5 - MARGIN - RING_WIDTH * 0.5) / RING_RX : BARE_RADIUS;

	float ring = 0.0;
	bool front = false;
	if (has_rings) {
		float c = cos(ring_tilt);
		float s = sin(ring_tilt);
		vec2 q = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
		vec2 axes = vec2(RING_RX, RING_RY) * r;
		float e = length(q / axes);
		vec2 grad = q / (axes * axes) / max(e, 1e-5);
		float d = (e - 1.0) / max(length(grad), 1e-5);
		ring = cover(abs(d) - RING_WIDTH * 0.5, aa);
		front = q.y > 0.0;
	}

	vec4 acc = vec4(0.0);
	if (!front) {
		acc = over(acc, ring_color.rgb, ring);
	}
	// Lit from the upper left: the night side is the disc outside a larger, offset circle.
	float lit = cover(length(p + vec2(0.55, 0.45) * r) - 1.05 * r, aa);
	vec3 surface = mix(color.rgb * night_tint.rgb, color.rgb, lit);
	acc = over(acc, surface, cover(length(p) - r, aa));
	if (front) {
		acc = over(acc, ring_color.rgb, ring);
	}
	if (cut_radius > 0.0) {
		acc *= 1.0 - cover(length(UV - cut_center) - cut_radius, aa);
	}
	COLOR = vec4(acc.rgb / max(acc.a, 1e-5), acc.a);
}
