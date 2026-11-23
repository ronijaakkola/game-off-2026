shader_type canvas_item;
// The menus' background: a picture two screens wide, of which one half covers the screen,
// cropped round its middle to the screen's shape. [pan] slides from the left half (0) to
// the right one (1), as the campaign screen opens.

uniform float pan : hint_range(0.0, 1.0) = 0.0;
// The screen's width over its height.
uniform float screen_aspect = 1.7777778;

// One half's width over its height.
const float HALF_ASPECT = 1.7777778;

void fragment() {
	vec2 window = screen_aspect >= HALF_ASPECT
		? vec2(0.5, HALF_ASPECT / screen_aspect)
		: vec2(0.5 * screen_aspect / HALF_ASPECT, 1.0);
	vec2 corner = vec2(pan * 0.5 + (0.5 - window.x) * 0.5, (1.0 - window.y) * 0.5);
	COLOR = texture(TEXTURE, corner + UV * window);
}
