// Flat, near-white faces for the sharp-lines style: two hard light bands instead of a
// gradient, so every face reads as one tone. The ink lines come from edge_pass.gdshader
// or outline_hull.gdshader, not from here.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(0.97, 0.97, 0.98, 1.0);
// The sun's cos(angle) where each of the three light bands starts. Below the lowest
// a face gets only ambient. Three hard bands give top, front and side faces their own tone.
uniform vec3 band_edges = vec3(0.2, 0.45, 0.65);
// How much light the brightest band adds on top of ambient.
uniform float lit_strength : hint_range(0.0, 1.0) = 0.6;
// Faint tile lines for the ground. 0 turns them off.
uniform float grid_strength : hint_range(0.0, 1.0) = 0.0;
uniform float grid_size = 1.0;
uniform vec4 grid_color : source_color = vec4(0.62, 0.66, 0.74, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = albedo.rgb;
	if (grid_strength > 0.0) {
		vec2 cell = world_pos.xz / grid_size;
		vec2 distance_to_line = abs(fract(cell - 0.5) - 0.5) / fwidth(cell);
		float line = 1.0 - min(min(distance_to_line.x, distance_to_line.y), 1.0);
		color = mix(color, grid_color.rgb, line * grid_strength);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	vec3 passed = step(band_edges, vec3(facing));
	float lit = (passed.x + passed.y + passed.z) / 3.0 * lit_strength;
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
}
