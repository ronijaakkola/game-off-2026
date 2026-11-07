shader_type spatial;
// A flat colour with two-tone light from the star, as on the planets: a lit side in the
// colour itself, and a night side multiplied by the same purple.
render_mode ambient_light_disabled, specular_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.3);
// The night side is the colour multiplied by this.
uniform vec3 shadow_color : source_color = vec3(0.5, 0.45, 0.78);

void fragment() {
	ALBEDO = color;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Blend over one screen pixel, so the edge stays crisp at any zoom.
	float width = fwidth(ndl) + 1e-4;
	DIFFUSE_LIGHT += mix(shadow_color, vec3(1.0), smoothstep(-width, width, ndl));
}
