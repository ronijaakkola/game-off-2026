shader_type canvas_item;
// The menus' background: a picture two screens wide, of which one half covers the screen,
// cropped round its middle to the screen's shape. [pan] slides from the left half (0) to
// the right one (1), as the campaign screen opens. Two layers of stars drift over it
// toward the bus's tail, the near one faster, and both pan farther than the picture, so
// the scene has depth. They pass behind the bus and the planets: a star fades out where
// the picture under it is redder than the navy of space.

uniform float pan : hint_range(0.0, 1.0) = 0.0;
// The screen's width over its height.
uniform float screen_aspect = 1.7777778;
// The screen's height in the UI's pixels, which sizes the stars.
uniform float screen_height = 648.0;
// Seconds the stars have drifted for.
uniform float drift = 0.0;

// One half's width over its height.
const float HALF_ASPECT = 1.7777778;
// Each star layer: cells across the screen's height, screen heights it drifts a second,
// how many times as far as the picture it moves as the picture pans, and its stars'
// largest radius in pixels.
const vec4 FAR_LAYER = vec4(9.0, 0.006, 1.15, 1.6);
const vec4 NEAR_LAYER = vec4(5.0, 0.016, 1.5, 2.6);
// The picture's red at which a star starts to fade, and where it is gone. Space stays
// under the first; the bus, its glow and the planets, even the bus's shaded purple
// underside, are over the second.
const vec2 HIDDEN_RED = vec2(0.24, 0.3);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A [param layer] of stars over screen point [param at], in screen heights from the top
// left, once the picture has panned [param moved] as far in the same units: at most one
// star in each cell, off its middle, between [param light]'s dimmest and brightest. Gives
// the star's light here, and its centre in screen UV, where the picture decides whether it
// shows, so a star fades whole rather than being cut at the bus's edge.
vec3 layer(vec2 at, float moved, vec4 layer, vec2 light) {
	vec2 shift = vec2(moved * layer.z - drift * layer.y, 0.0);
	vec2 p = (at + shift) * layer.x;
	vec2 cell = floor(p);
	float chance = hash(cell);
	if (chance > 0.4) {
		return vec3(0.0);
	}
	vec2 centre = cell + vec2(hash(cell + 17.0), hash(cell + 41.0)) * 0.7 + 0.15;
	vec2 centre_uv = (centre / layer.x - shift) / vec2(screen_aspect, 1.0);
	float cell_px = screen_height / layer.x;
	float d = length(p - centre) * cell_px;
	float size = layer.w * mix(0.5, 1.0, hash(cell + 73.0));
	float glow = smoothstep(size, size * 0.3, d) * mix(light.x, light.y, chance / 0.4);
	return vec3(glow, clamp(centre_uv, 0.0, 1.0));
}

void fragment() {
	vec2 window = screen_aspect >= HALF_ASPECT
		? vec2(0.5, HALF_ASPECT / screen_aspect)
		: vec2(0.5 * screen_aspect / HALF_ASPECT, 1.0);
	vec2 corner = vec2(pan * 0.5 + (0.5 - window.x) * 0.5, (1.0 - window.y) * 0.5);
	vec4 picture = texture(TEXTURE, corner + UV * window);

	vec2 at = UV * vec2(screen_aspect, 1.0);
	float moved = pan * 0.5 / window.x * screen_aspect;
	vec3 far = layer(at, moved, FAR_LAYER, vec2(0.25, 0.55));
	vec3 near = layer(at, moved, NEAR_LAYER, vec2(0.35, 0.8));
	float far_red = textureLod(TEXTURE, corner + far.yz * window, 0.0).r;
	float near_red = textureLod(TEXTURE, corner + near.yz * window, 0.0).r;
	float light = far.x * (1.0 - smoothstep(HIDDEN_RED.x, HIDDEN_RED.y, far_red));
	light += near.x * (1.0 - smoothstep(HIDDEN_RED.x, HIDDEN_RED.y, near_red));
	COLOR = vec4(picture.rgb + vec3(0.85, 0.88, 1.0) * light, picture.a);
}
