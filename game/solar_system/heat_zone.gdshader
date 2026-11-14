shader_type spatial;
// The heat zone round the star, drawn on the orbit plane: a faint warm glow with no edge
// lines, fading out softly over its outer rim, and a deeper red-orange where the hot zone
// starts, blended in rather than cut. Faint orange smoke churns slowly through it, in two
// layers turning round the star opposite ways. flash brightens it all, while the bus is
// inside. A touch of dither keeps the soft fades from banding, as there is no debanding on
// the web.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 zone_color : source_color = vec4(0.98, 0.72, 0.38, 0.07);
uniform vec4 hot_color : source_color = vec4(1.0, 0.42, 0.28, 0.12);
// Where the hot zone starts, as a share of the zone's radius.
uniform float hot_share : hint_range(0.0, 1.0) = 0.63;
// How much of the radius the outer rim and the hot zone's edge take to fade over.
uniform float softness : hint_range(0.0, 0.5) = 0.12;
// From 0 to 1: how much brighter it shows, as it pulses while the bus is inside.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float flash_gain = 1.8;
// The smoke: its colour, how much it adds over the glow at its thickest, how big its wisps
// are (wisps across the zone's width), and how fast it drifts. 0 holds it still.
uniform vec4 smoke_color : source_color = vec4(1.0, 0.6, 0.3, 0.07);
uniform float smoke_scale = 5.0;
uniform float drift = 1.0;

float dither(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715)))) - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, from 0 to 1.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Turns p by angle radians round the centre.
vec2 turned(vec2 p, float angle) {
	return mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * p;
}

// Two layers of wisps turning slowly round the centre, the finer one the other way and a
// little faster, so they seem to churn without drifting off anywhere.
float smoke(vec2 p, float t) {
	float n = noise(turned(p, t * 0.01) * smoke_scale) * 0.65;
	n += noise(turned(p, -t * 0.017) * smoke_scale * 2.1 + vec2(3.7, 1.3)) * 0.35;
	return smoothstep(0.45, 0.85, n);
}

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float rim = 1.0 - smoothstep(1.0 - softness, 1.0, d);
	float hot = 1.0 - smoothstep(hot_share - softness, hot_share + softness * 0.5, d);
	vec4 glow = mix(zone_color, hot_color, hot);
	float wisps = smoke(p, TIME * drift) * smoke_color.a;
	vec3 color = mix(glow.rgb, smoke_color.rgb, wisps / max(glow.a + wisps, 1e-4));
	ALBEDO = color;
	ALPHA = (glow.a + wisps) * rim * (1.0 + flash * flash_gain) + dither(FRAGCOORD.xy) / 255.0;
}
