shader_type spatial;
// The zone round a planet a fly past quest asks the bus to fly through, drawn on the orbit
// plane: a faint cool fill, a little stronger toward its edge, inside a ring of dashes that
// slowly turns. turn is set from outside, so the dashes can hold still.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 fill_color : source_color = vec4(0.5, 0.95, 0.88, 0.07);
uniform vec4 ring_color : source_color = vec4(0.62, 1.0, 0.93, 0.5);
// How much of the radius the ring takes.
uniform float ring_width : hint_range(0.0, 0.5) = 0.035;
// How many dashes the ring has, and how much of each is drawn.
uniform float dashes = 28.0;
uniform float dash_share : hint_range(0.0, 1.0) = 0.62;
// How far the dashes have turned, in radians.
uniform float turn = 0.0;
// From 0 to 1: how much brighter it shows, as it pulses while the pointer is on its quest.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float flash_gain = 1.6;
// From 0 to 1: how open it is. Closed, as a hop location outside its window, it has no
// fill and a faint ring.
uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform float closed_ring = 0.4;
// From 0 to 1: how much of it shows, as it fades in and out with the quest.
uniform float opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float pixel = fwidth(d);
	float inside = 1.0 - smoothstep(1.0 - pixel, 1.0, d);
	float ring = smoothstep(1.0 - ring_width - pixel, 1.0 - ring_width, d);
	float along = fract((atan(p.y, p.x) + turn) / TAU * dashes);
	// A pixel's width along the ring, in dashes.
	float edge = clamp(dashes * pixel / (TAU * max(d, 0.01)), 0.001, 0.25);
	float dash = smoothstep(0.0, edge, along) * (1.0 - smoothstep(dash_share, dash_share + edge, along));
	float line = ring * dash;
	float fill = fill_color.a * mix(0.45, 1.0, d * d) * open;
	ALBEDO = mix(fill_color.rgb, ring_color.rgb, line);
	float shade = mix(fill * (1.0 + flash * flash_gain), ring_color.a * mix(closed_ring, 1.0, open) * (1.0 + flash), line);
	ALPHA = shade * inside * opacity;
}
