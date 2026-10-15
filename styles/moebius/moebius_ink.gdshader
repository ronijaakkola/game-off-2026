// Moebius-style surface: flat pastel fill, with ink hatching where the surface is in
// shade. The light() function reads the sun's shading and its shadow, so cast shadows
// get hatched the same way as the dark side of a form.
//
// The fill is the albedo and the ink is how far the lit result is pulled towards black,
// so keep the scene's ambient at 0: ambient would add colour on top of the hatching.
// It also means only one shadowed light adds to the frame, which avoids the
// ambient + shadowed sun clipping documented in docs/web-constraints.md.
shader_type spatial;

uniform vec4 fill : source_color = vec4(0.9, 0.55, 0.45, 1.0);
uniform float light_edge : hint_range(0.0, 1.0) = 0.5;
uniform float dark_edge : hint_range(0.0, 1.0) = 0.2;
uniform float ink_floor : hint_range(0.0, 1.0) = 0.01;
// Spacing between hatch lines: world units, or pixels with screen_space_hatching.
uniform float line_spacing = 0.07;
uniform float line_width : hint_range(0.05, 0.9) = 0.38;
uniform float wobble : hint_range(0.0, 1.0) = 0.12;
uniform bool screen_space_hatching = false;
uniform bool highlight = false;
uniform float highlight_size : hint_range(0.001, 0.1) = 0.012;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Ink coverage of one family of parallel lines: 1 on a line, 0 on paper. Lines fade to
// their average coverage once they are too dense to resolve, which prevents moire.
float lines(float coord, float width) {
	float footprint = fwidth(coord);
	float edge = max(footprint * 1.5, 0.02);
	float distance_to_line = abs(fract(coord) - 0.5) * 2.0;
	float ink = 1.0 - smoothstep(width - edge, width + edge, distance_to_line);
	return mix(ink, width, smoothstep(0.25, 0.6, footprint));
}

void fragment() {
	ALBEDO = fill.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float tone = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;

	vec2 wobble_offset = vec2(
		sin(dot(world_pos, vec3(9.1, 6.7, 7.3))) + sin(dot(world_pos, vec3(3.3, 11.9, 5.1))),
		sin(dot(world_pos, vec3(6.2, 8.8, 10.4))) + sin(dot(world_pos, vec3(12.7, 4.1, 3.9)))
	) * 0.5 * wobble;

	float first_family;
	float second_family;
	if (screen_space_hatching) {
		vec2 pixel = FRAGCOORD.xy / line_spacing;
		first_family = (pixel.x + pixel.y) * 0.7071 + wobble_offset.x;
		second_family = (pixel.x - pixel.y) * 0.7071 + wobble_offset.y;
	} else {
		vec3 from_world = world_pos / line_spacing;
		first_family = dot(from_world, normalize(vec3(1.0, 0.35, 0.55))) + wobble_offset.x;
		second_family = dot(from_world, normalize(vec3(-0.6, 0.35, 1.0))) + wobble_offset.y;
	}

	float blur = fwidth(tone) + 0.01;
	float shaded = 1.0 - smoothstep(light_edge - blur, light_edge + blur, tone);
	float darkest = 1.0 - smoothstep(dark_edge - blur, dark_edge + blur, tone);
	float ink = max(shaded * lines(first_family, line_width), darkest * lines(second_family, line_width));

	DIFFUSE_LIGHT = vec3(mix(1.0, ink_floor, ink));

	if (highlight) {
		float shine = dot(reflect(-LIGHT, NORMAL), VIEW);
		SPECULAR_LIGHT = vec3(step(1.0 - highlight_size, shine) * step(0.5, ATTENUATION));
	}
}
