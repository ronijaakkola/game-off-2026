// A passenger's trip arc and the ring round its destination (trip_arc.gd): a flat line in
// one colour with a thin dark outline, as wide on screen at any zoom. The script builds the
// geometry facing the camera: UV.x is pixels along the line, UV.y runs from -1 to 1 across
// it, and UV2.x is the opacity there. Dashed, the line is rounded dashes that the script
// scrolls along it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.08, 0.07, 0.18, 0.7);
// Half the line's width, and the outline outside it, in pixels.
uniform float half_width = 2.0;
uniform float outline = 1.5;
uniform bool dashed = true;
// In pixels: each dash, the gap between two, and how far they have moved along.
uniform float dash_length = 10.0;
uniform float gap = 7.0;
uniform float scroll = 0.0;

void fragment() {
	float reach = half_width + outline;
	float across = UV.y * reach;
	float distance_out = abs(across);
	if (dashed) {
		// Each period holds one dash at its middle, so the outline never wraps round.
		float period = dash_length + gap;
		float along = mod(UV.x - scroll, period) - period * 0.5;
		float half_straight = max(dash_length * 0.5 - half_width, 0.0);
		float off_end = max(abs(along) - half_straight, 0.0);
		distance_out = length(vec2(off_end, across));
	}
	float aa = max(fwidth(across), 0.001);
	float line = 1.0 - smoothstep(half_width - aa * 0.5, half_width + aa * 0.5, distance_out);
	float edge = 1.0 - smoothstep(reach - aa * 0.5, reach + aa * 0.5, distance_out);
	ALBEDO = mix(outline_color.rgb, color.rgb, line);
	ALPHA = mix(outline_color.a * edge, color.a, line) * UV2.x;
}
