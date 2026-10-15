// Fully flat shading with cast shadows drawn as one flat colour.
//
// The surface is a single colour, lit_color, where the sun reaches it and shadow_color where
// it doesn't: in the cast shadow of another mesh, or facing away from the sun. Nothing else
// shades it: no gradient, no specular, no ambient variation.
//
// Compatibility draws a shadowed light in an extra pass that is added on top of the base
// pass after both are converted to sRGB. So the base pass paints shadow_color (the ambient
// must be white at energy 1 to leave it untouched), and light() adds the difference
// lit_color - shadow_color wherever the shadow term says "lit". Adding can only brighten,
// so every channel of shadow_color has to be <= the same channel of lit_color.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 lit_color : source_color = vec3(0.98, 0.9, 0.7);
uniform vec3 shadow_color : source_color = vec3(0.6, 0.55, 0.7);
// Value multipliers per face direction, to stand in for authored face colours: up, and the
// sides that face along world X and along world Z. All 1.0 for a smooth mesh like a sphere.
uniform float top_value = 1.0;
uniform float x_value = 1.0;
uniform float z_value = 1.0;
// Authored colours: when use_albedo_tex is on, the lit colour comes from albedo_tex at the
// mesh's own UV (a Kenney colormap, say) and the shadow colour is that colour times
// shadow_tint, so every face keeps its own colour and every shadow shares one tint. Each
// channel of shadow_tint has to be <= 1.
uniform bool use_albedo_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec3 shadow_tint = vec3(0.62, 0.56, 1.0);
// Shadow term (0 shadowed .. 1 lit) where the edge sits, and how wide the edge is.
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float edge_width : hint_range(0.001, 0.5) = 0.08;

varying float face_value;

vec3 to_linear(vec3 c) {
	vec3 hi = pow((max(c, vec3(0.04045)) + 0.055) / 1.055, vec3(2.4));
	return mix(c / 12.92, hi, step(vec3(0.04045), c));
}

float get_face_value(vec3 world_normal) {
	vec3 n = abs(world_normal);
	if (n.y > n.x && n.y > n.z) {
		return top_value;
	}
	return n.x > n.z ? x_value : z_value;
}

void vertex() {
	face_value = get_face_value(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

void fragment() {
	vec3 shadow = use_albedo_tex ? texture(albedo_tex, UV).rgb * shadow_tint : shadow_color;
	ALBEDO = shadow * face_value;
}

void light() {
	float sun_side = step(0.0, dot(NORMAL, LIGHT));
	float shadow = smoothstep(edge_threshold - edge_width, edge_threshold + edge_width, ATTENUATION);
	// With a texture ALBEDO is already shadow * face_value, and lit = shadow / shadow_tint.
	vec3 gain = use_albedo_tex
		? ALBEDO * (1.0 / max(shadow_tint, vec3(0.002)) - 1.0)
		: max(lit_color - shadow_color, vec3(0.0)) * face_value;
	// The light pass computes DIFFUSE_LIGHT * linear(ALBEDO) and encodes that to sRGB, so
	// ask for linear(gain) / linear(ALBEDO) to land exactly on gain.
	DIFFUSE_LIGHT += to_linear(gain) / max(ALBEDO, vec3(0.002)) * sun_side * shadow;
}
