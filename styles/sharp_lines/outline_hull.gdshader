// Inverted-hull outline for the sharp-lines style: the mesh drawn again with its back
// faces, pushed out along its normals by a fixed number of pixels. Use it as the
// next_pass of a flat_face material. It only draws silhouettes, and it opens gaps at the
// corners of meshes with hard edges (a box), which is why edge_pass.gdshader exists.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 line_color : source_color = vec4(0.1, 0.11, 0.16, 1.0);
uniform float line_px : hint_range(0.5, 6.0) = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 push = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	// clip.w scales the push so the line stays line_px wide at any distance.
	clip.xy += normalize(push) * line_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
