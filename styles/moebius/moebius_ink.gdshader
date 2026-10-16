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
// Spacing between hatch lines, in the mesh's own units.
uniform float line_spacing = 0.05;
uniform float line_width : hint_range(0.05, 0.9) = 0.34;
// Hand-drawn look. Each is in line spacings, so they scale with line_spacing.
// How far each line sits off the grid.
uniform float spacing_jitter : hint_range(0.0, 0.3) = 0.22;
// How far each line wanders sideways along its length.
uniform float waver : hint_range(0.0, 0.3) = 0.22;
// How much a line's weight swells and thins along its length, 0 to 1.
uniform float line_variation : hint_range(0.0, 0.6) = 0.4;
// How far apart in tone the strokes of one hatch stop, so the hatched area has a ragged edge.
uniform float end_jitter : hint_range(0.0, 0.5) = 0.18;
// How sharply the three hatch projections hand over on curved surfaces. Higher is a
// narrower blend zone, where strokes from two directions overlap.
uniform float projection_sharpness : hint_range(1.0, 16.0) = 12.0;
// Hatch along the mesh's UVs instead: the first strokes follow v, the cross strokes follow u,
// so on a UV sphere they run along parallels and meridians and follow the form. Only for
// meshes with continuous UVs; uv_lines is how many strokes fit across u and v.
uniform bool uv_hatching = false;
uniform vec2 uv_lines = vec2(40.0, 20.0);
uniform bool highlight = false;
uniform float highlight_size : hint_range(0.001, 0.1) = 0.012;

// Strokes are pinned to the mesh: they are laid out in object space, so they move with the
// surface instead of sliding over it when the camera moves.
varying vec3 object_pos;
varying vec3 object_normal;
varying vec2 surface_uv;

void vertex() {
	object_pos = VERTEX;
	object_normal = NORMAL;
	surface_uv = UV;
}

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// Smooth random value along a line, between 0 and 1.
float noise(float x) {
	float cell = floor(x);
	return mix(hash(cell), hash(cell + 1.0), smoothstep(0.0, 1.0, fract(x)));
}

// Ink coverage of one family of parallel strokes: 1 on a stroke, 0 on paper. across counts
// strokes and along runs down them, both in line spacings. Every stroke gets its own offset,
// waver, weight and end point, seeded by its index. Strokes fade to their average coverage once
// they are too dense to resolve, which prevents moire.
float strokes(float across, float along, float width, float tone, float threshold) {
	float footprint = fwidth(across);
	float id = floor(across);
	float seed = hash(id * 1.7 + 3.1);
	float seed_b = hash(id * 2.3 + 9.7);
	float offset = fract(across) - 0.5 - (seed - 0.5) * spacing_jitter;
	offset += (noise(along * 0.22 + seed_b * 50.0) - 0.5) * waver;
	float weight = width * (1.0 - line_variation + 2.0 * line_variation * noise(along * 0.17 + seed * 40.0));
	float edge = max(footprint * 1.5, 0.02);
	float ink = 1.0 - smoothstep(weight - edge, weight + edge, abs(offset) * 2.0);
	float blur = fwidth(tone) * 0.5 + 0.003;
	float stroke_tone = tone + (seed_b - 0.5) * end_jitter;
	ink *= 1.0 - smoothstep(threshold - blur, threshold + blur, stroke_tone);
	return mix(ink, width * (1.0 - smoothstep(threshold - blur, threshold + blur, tone)), smoothstep(0.25, 0.6, footprint));
}

// Both stroke families of a hatch drawn on one of the three axis planes.
float plane_ink(vec2 plane, float tone) {
	vec2 cell = plane / line_spacing;
	float diagonal = (cell.x + cell.y) * 0.7071;
	float anti_diagonal = (cell.x - cell.y) * 0.7071;
	return max(
		strokes(diagonal, anti_diagonal, line_width, tone, light_edge),
		strokes(anti_diagonal, diagonal, line_width, tone, dark_edge)
	);
}

void fragment() {
	ALBEDO = fill.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float tone = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;

	float ink;
	if (uv_hatching) {
		vec2 cell = surface_uv * uv_lines;
		ink = max(
			strokes(cell.y, cell.x, line_width, tone, light_edge),
			strokes(cell.x, cell.y, line_width, tone, dark_edge)
		);
	} else {
		// Triplanar: each axis plane draws its own hatch, weighted by how squarely the surface
		// faces that axis. Flat faces get one clean hatch; curves blend over a narrow band.
		vec3 weights = pow(abs(normalize(object_normal)), vec3(projection_sharpness));
		weights /= weights.x + weights.y + weights.z;
		ink = weights.x * plane_ink(object_pos.zy, tone)
			+ weights.y * plane_ink(object_pos.xz, tone)
			+ weights.z * plane_ink(object_pos.xy, tone);
	}

	DIFFUSE_LIGHT = vec3(mix(1.0, ink_floor, ink));

	if (highlight) {
		float shine = dot(reflect(-LIGHT, NORMAL), VIEW);
		SPECULAR_LIGHT = vec3(step(1.0 - highlight_size, shine) * step(0.5, ATTENUATION));
	}
}
