// The rect's own colour over everything but a rounded hole: the dim under a feature hint.
shader_type canvas_item;

// How big the rect is, and the hole's middle and half its size, in the rect's own pixels.
uniform vec2 size = vec2(1.0);
uniform vec2 hole_center = vec2(0.0);
uniform vec2 hole_half = vec2(0.0);
// The hole's corner radius in those pixels.
uniform float radius = 0.0;

void fragment() {
	vec2 corner = abs(UV * size - hole_center) - hole_half + radius;
	float away = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
	COLOR.a *= smoothstep(-0.5, 0.5, away);
}
