shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Kenney-style colormap lookup: the colour comes from a small gradient palette, picked by
// swatch (a column) and by height along the object (a row), then lit with soft wrapped
// diffuse so the shading never goes dark.

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float swatch_count = 8.0;
uniform float swatch = 0.0;
// Rows of the swatch to use, top to bottom. A narrow range makes a nearly flat colour.
uniform vec2 v_range = vec2(0.0, 1.0);
// Take the gradient from the object's height, not from its UVs. Rounded cube faces have
// UVs that run in a different direction on every face, so the cube uses this; a mesh with
// authored UVs, like the sphere, doesn't need it.
uniform bool gradient_from_height = false;
// Read the palette at the mesh's own UV instead of picking a swatch. For Kenney models, whose
// UVs already point into their colormap: every face keeps the colour the artist gave it.
uniform bool uv_lookup = false;
// How far light wraps past the terminator. 0 is plain Lambert, 1 lights the whole object.
uniform float wrap : hint_range(0.0, 1.0) = 0.5;

varying float local_height;

void vertex() {
	local_height = VERTEX.y;
}

void fragment() {
	float t = gradient_from_height ? clamp(0.5 - local_height, 0.0, 1.0) : UV.y;
	float row = mix(v_range.x, v_range.y, t);
	vec2 palette_uv = uv_lookup ? UV : vec2((swatch + 0.5) / swatch_count, row);
	ALBEDO = texture(palette, palette_uv).rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float wrapped = clamp((n_dot_l + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * wrapped / PI;
}
