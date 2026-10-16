// Draws the ribbons CreaseLines builds: a screen-space strip of constant pixel width
// along each edge, in front of the surface it sits on so the faces can't hide it.
// Real triangles, so MSAA smooths the line like any other edge.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 line_color : source_color = vec4(0.1, 0.11, 0.16, 1.0);
uniform float line_px : hint_range(0.5, 6.0) = 2.0;
// How far toward the camera the line is pulled, in metres, so it wins the depth test
// against the faces on both sides of it.
uniform float depth_bias = 0.015;

vec4 to_clip(vec3 model_pos, mat4 modelview, mat4 projection) {
	vec3 view_pos = (modelview * vec4(model_pos, 1.0)).xyz;
	if (projection[3][3] > 0.5) {
		view_pos.z += depth_bias;
	} else {
		view_pos *= 1.0 - depth_bias / length(view_pos);
	}
	return projection * vec4(view_pos, 1.0);
}

void vertex() {
	vec4 here = to_clip(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	vec4 there = to_clip(CUSTOM0.xyz, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	vec2 along = normalize(((there.xy / there.w) - (here.xy / here.w)) * VIEWPORT_SIZE);
	vec2 across = vec2(-along.y, along.x);
	// One half-width in NDC is line_px * 0.5 pixels * 2 / viewport size. Pushing the end
	// outward by the same amount rounds off the corners where lines meet.
	vec2 half_width = line_px / VIEWPORT_SIZE;
	here.xy += (across * UV.x - along) * half_width * here.w;
	POSITION = here;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
