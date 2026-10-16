// Full-screen ink lines from the depth buffer, for the sharp-lines style.
//
// Put a 2x2 QuadMesh under the camera with this material. Every pixel measures how far
// its depth is from the plane through its neighbours (a second difference). A flat face
// gives 0, a crease gives a spike, and a silhouette gives a big one, so one pass draws
// both outlines and hard edges. No normal buffer is needed, which the web doesn't have.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.1, 0.11, 0.16, 1.0);
// Line width in screen pixels (the sampling distance).
uniform float line_px : hint_range(0.5, 4.0) = 1.0;
// How sharp an edge has to be before it gets a line. Higher keeps only the strong ones.
uniform float threshold : hint_range(0.01, 4.0) = 0.7;
// How soft the line's edge is, as a fraction of the threshold. 0 is a hard, aliased line.
uniform float softness : hint_range(0.0, 2.0) = 0.5;

// Distance along the view axis for a depth-buffer value, from the inverse projection.
float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return -v.z / v.w;
}

void vertex() {
	// Cover the whole screen whatever the transform is; z 0 is inside both depth ranges.
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	vec2 px = line_px / VIEWPORT_SIZE;
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	// Orthographic depth is already linear in screen space. In perspective, 1/depth is.
	float c = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float l = view_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float r = view_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = view_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float d = view_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float response;
	if (ortho) {
		// World size of one sampling step, so the response is a slope change, not metres.
		float step_world = abs(INV_PROJECTION_MATRIX[0][0]) * 2.0 * px.x;
		response = (abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c)) / step_world;
	} else {
		float ic = 1.0 / c;
		float lap = abs(1.0 / l + 1.0 / r - 2.0 * ic) + abs(1.0 / u + 1.0 / d - 2.0 * ic);
		response = lap / ic / (px.x * 2.0);
	}
	float lo = threshold * (1.0 - softness * 0.5);
	float hi = threshold * (1.0 + softness * 0.5) + 0.0001;
	ALBEDO = line_color.rgb;
	ALPHA = smoothstep(lo, hi, response) * line_color.a;
}
