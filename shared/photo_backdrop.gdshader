shader_type canvas_item;
// A portrait photo's background, as if snapped outdoors with the focus on the face: a sky
// in a tint of the passenger's race's backdrop colour, a few soft out-of-focus lights,
// and a blurred horizon along the bottom. Its edges fade over one pixel, so it stays
// smooth when the frame is tilted. With space, it is open space instead: the backdrop
// colour as fog over a darker shade of it, with stars, and no ground.

uniform vec3 backdrop_color : source_color = vec3(0.82, 0.8, 0.93);
// The night side multiply shared with the planets.
uniform vec3 shadow_color : source_color = vec3(0.5, 0.45, 0.78);
// Places the lights, so each photo differs.
uniform float seed = 0.0;
uniform bool space = false;
// How many stars across, and how far they are from sharp, in the photo's width.
const float STAR_CELLS = 7.0;
const float STAR_RADIUS = 0.011;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	// A touch of the night tint keeps a pale sky apart from the white frame.
	vec3 sky = mix(backdrop_color, vec3(1.0), 0.3) * mix(vec3(1.0), shadow_color, 0.22);
	vec3 deep = backdrop_color * shadow_color;
	vec3 col = mix(sky, backdrop_color, UV.y * 0.6);

	// Out-of-focus lights: soft discs, some bright, some deep.
	for (int i = 0; i < 4; i++) {
		float n = seed * 17.0 + float(i) * 7.31;
		vec2 centre = vec2(hash(n), hash(n + 1.7) * 0.7);
		float radius = 0.12 + 0.14 * hash(n + 3.1);
		float blob = 1.0 - smoothstep(radius * 0.2, radius, length(UV - centre));
		vec3 tint = i % 2 == 0 ? vec3(1.0) : deep;
		col = mix(col, tint, blob * 0.3);
	}

	// The blurred horizon, a wide curve along the bottom.
	float ground = length((UV - vec2(0.5, 1.75)) * vec2(0.55, 1.0));
	col = mix(col, mix(backdrop_color, deep, 0.35), 1.0 - smoothstep(0.82, 1.02, ground));

	if (space) {
		vec3 dark = backdrop_color * 0.4;
		col = mix(dark, backdrop_color * 0.8, UV.y);
		// Fog: wide soft clouds, lighter than the space between.
		for (int i = 0; i < 4; i++) {
			float n = seed * 17.0 + float(i) * 7.31;
			vec2 centre = vec2(hash(n), hash(n + 1.7));
			float radius = 0.3 + 0.25 * hash(n + 3.1);
			float cloud = 1.0 - smoothstep(0.0, radius, length(UV - centre));
			vec3 tint = i % 2 == 0 ? backdrop_color * 3.0 + 0.04 : dark * 0.5;
			col = mix(col, tint, cloud * 0.55);
		}
		// Stars: one to a cell, each somewhere in it, most of them faint.
		vec2 cell = floor(UV * STAR_CELLS);
		float n = dot(cell, vec2(12.99, 78.23)) + seed;
		vec2 at = (cell + 0.2 + 0.6 * vec2(hash(n), hash(n + 1.3))) / STAR_CELLS;
		float size = STAR_RADIUS * (0.4 + hash(n + 2.9));
		float star = 1.0 - smoothstep(size * 0.3, size, length(UV - at));
		col += star * pow(hash(n + 4.7), 2.0) * vec3(0.9, 0.9, 1.0);
	}

	COLOR.rgb = col;
	vec2 edge = min(UV, 1.0 - UV) / max(fwidth(UV), vec2(1e-5));
	COLOR.a = clamp(min(edge.x, edge.y) + 0.5, 0.0, 1.0);
}
