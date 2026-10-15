// A fake pool of light on the ground: a radial falloff drawn additively on a quad that
// lies just above the ground. Stands in for a decal, which Compatibility doesn't have.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.5, 0.3);
uniform float intensity = 0.5;
uniform float falloff = 2.0;

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	float a = pow(1.0 - smoothstep(0.0, 1.0, d), falloff);
	ALBEDO = color * a * intensity;
}
