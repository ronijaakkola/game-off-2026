shader_type spatial;
// The stretch of a moon's orbit where a hop location is open, drawn on the orbit plane as
// a band with round ends in the hop zone's colour. UV.x runs across it, UV.y along it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.62, 1.0, 0.93, 1.0);
// How long the band is, in its own widths, so its ends come out round.
uniform float lengths = 20.0;
// From 0 to 1: how much of it shows.
uniform float opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	// How far past the start of either end's cap, in half widths.
	float along = max(1.0 - min(UV.y, 1.0 - UV.y) * lengths * 2.0, 0.0);
	float d = length(vec2(across, along));
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - smoothstep(1.0 - fwidth(d), 1.0, d)) * opacity;
}
