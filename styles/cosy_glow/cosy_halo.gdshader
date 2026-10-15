// A fake bloom halo: a camera-facing quad with a radial falloff, drawn additively over the
// light source. Glow in the environment only catches pixels above its threshold; this one
// is always there and its size and colour are set per light. It is drawn over everything
// (a billboard would otherwise cut into the machine), so it fades out as the camera moves
// round to the side of the light that the halo isn't on.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.55, 0.3);
uniform float intensity = 0.45;
uniform float falloff = 2.5;
// World direction the light faces. The halo is strongest when the camera is along it.
uniform vec3 facing = vec3(0.0, 0.0, 1.0);

varying float view_fade;

void vertex() {
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
	view_fade = smoothstep(0.1, 0.6, dot(to_camera, normalize(facing)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = color * pow(1.0 - smoothstep(0.0, 1.0, d), falloff) * intensity * view_fade;
}
