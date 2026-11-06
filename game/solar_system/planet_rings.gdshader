shader_type spatial;
// Flat planet rings: a few bands of two colours with thin gaps between them, unlit so
// they stay flat. Planet.make_annulus() gives UV.x from 0 at the inner edge to 1 outside.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

uniform vec3 color_a : source_color = vec3(0.95, 0.8, 0.6);
uniform vec3 color_b : source_color = vec3(0.85, 0.6, 0.45);
uniform float band_count : hint_range(1.0, 8.0, 1.0) = 3.0;
// The gap between two bands, as a share of a band's width.
uniform float gap : hint_range(0.0, 0.5) = 0.12;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float t = UV.x * band_count;
	float band = floor(t);
	float f = fract(t);
	float width = max(fwidth(t), 1e-4);
	// Open in the middle of each gap, closed across the band.
	float solid = smoothstep(gap * 0.5 - width, gap * 0.5 + width, f)
		* (1.0 - smoothstep(1.0 - gap * 0.5 - width, 1.0 - gap * 0.5 + width, f));
	ALBEDO = mod(band, 2.0) < 1.0 ? color_a : color_b;
	ALPHA = solid * opacity;
}
