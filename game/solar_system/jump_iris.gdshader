// Black over everything but a circle round center: the iris the jump closes and opens.
shader_type canvas_item;

// Where the circle is and how big the rect is, in the rect's own pixels.
uniform vec2 center = vec2(0.0);
uniform vec2 size = vec2(1.0);
// The circle's radius in those pixels, and how see-through the black is, 0 to 1.
uniform float radius = 0.0;
uniform float opacity = 1.0;
// How many pixels the circle's edge takes to go from clear to black.
uniform float softness = 1.5;

void fragment() {
	float away = distance(UV * size, center);
	float black = smoothstep(radius - softness, radius + softness, away);
	COLOR = vec4(0.0, 0.0, 0.0, black * opacity);
}
