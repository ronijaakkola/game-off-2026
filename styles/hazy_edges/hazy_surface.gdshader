// Flat, low-contrast shading for the hazy-edges style: one tint where the sun reaches a
// surface, one where it doesn't, and nothing else. No gradient, no specular, no outline.
//
// The look of the style is in hazy_edges.gdshader, which smears the borders between these
// flat patches. This shader only has to leave borders worth smearing: a flat lit tint and a
// flat shadow tint, with a narrow edge between them.
//
// Compatibility draws a shadowed light in an extra pass that is added on top of the base pass
// after both are converted to sRGB. So the base pass paints the shadow tint (the ambient must
// be white at energy 1 to leave it untouched), and light() adds the difference
// lit - shadow wherever the sun reaches. Adding can only brighten, so each channel of
// shadow_tint has to be <= 1.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 lit_color : source_color = vec3(0.8, 0.82, 0.74);
// Used when use_albedo_tex is off. Must be <= lit_color per channel.
uniform vec3 shadow_color : source_color = vec3(0.56, 0.62, 0.62);
// Authored colours: with use_albedo_tex the lit colour is albedo_tex at the mesh's own UV and
// the shadow colour is that times shadow_tint.
uniform bool use_albedo_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec3 shadow_tint = vec3(0.7, 0.76, 0.85);
// How far an authored colour is pulled to its own grey, 0 (as authored) to 1 (grey). Kenney's
// colormap is saturated; the look this style is after is chalky and muted.
uniform float mute : hint_range(0.0, 1.0) = 0.35;
// Shadow term (0 shadowed .. 1 lit) where the edge sits, and how wide it is.
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float edge_width : hint_range(0.001, 0.5) = 0.06;

vec3 to_linear(vec3 c) {
	vec3 hi = pow((max(c, vec3(0.04045)) + 0.055) / 1.055, vec3(2.4));
	return mix(c / 12.92, hi, step(vec3(0.04045), c));
}

void fragment() {
	vec3 authored = texture(albedo_tex, UV).rgb;
	authored = mix(authored, vec3(dot(authored, vec3(0.299, 0.587, 0.114))), mute);
	ALBEDO = use_albedo_tex ? authored * shadow_tint : shadow_color;
}

void light() {
	float sun_side = step(0.0, dot(NORMAL, LIGHT));
	float shadow = smoothstep(edge_threshold - edge_width, edge_threshold + edge_width, ATTENUATION);
	vec3 gain = use_albedo_tex
		? ALBEDO * (1.0 / max(shadow_tint, vec3(0.002)) - 1.0)
		: max(lit_color - shadow_color, vec3(0.0));
	// The light pass computes DIFFUSE_LIGHT * linear(ALBEDO) and encodes that to sRGB, so
	// ask for linear(gain) / linear(ALBEDO) to land exactly on gain.
	DIFFUSE_LIGHT += to_linear(gain) / max(ALBEDO, vec3(0.002)) * sun_side * shadow;
}
