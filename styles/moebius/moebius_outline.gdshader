// Inked outline: an inverted hull pushed out along the normal by a fixed number of
// pixels, so lines keep their weight at any distance. Needs smooth, connected meshes.
// Use it as the next_pass of a surface material.
shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 ink_color : source_color = vec4(0.04, 0.03, 0.07, 1.0);
uniform float width_px = 3.0;
// How much the line weight swells and thins along a form, for a hand-inked look.
uniform float weight_variation : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 direction = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = 1.0 + weight_variation * 0.5 * (sin(dot(world, vec3(4.1, 3.3, 5.7))) + sin(dot(world, vec3(2.3, 6.1, 3.7))));
	clip.xy += normalize(direction + vec2(1e-5)) * (width_px * weight * 2.0 / VIEWPORT_SIZE) * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
