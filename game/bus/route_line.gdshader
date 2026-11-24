// The bus's route (route_line.gd): a thin line in one colour with a dark outline, as wide on
// screen at any zoom, and a diamond at each marked point. The script builds the geometry
// facing the camera. On the line, UV.y runs from -1 to 1 across it; on a diamond, UV is
// pixels from its middle. UV2.x is the opacity there, and UV2.y is 1 on a diamond.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.08, 0.07, 0.18, 0.7);
// Half the line's width, the outline outside it, and how far a diamond reaches, in pixels.
uniform float half_width = 1.25;
uniform float outline = 1.25;
uniform float marker_reach = 6.0;

void fragment() {
	float distance_out;
	float aa;
	if (UV2.y > 0.5) {
		aa = max(fwidth(UV.x), 0.001);
		distance_out = (abs(UV.x) + abs(UV.y) - marker_reach) * 0.7071;
		distance_out += half_width;
	} else {
		float across = UV.y * (half_width + outline);
		aa = max(fwidth(across), 0.001);
		distance_out = abs(across);
	}
	float reach = half_width + outline;
	float line = 1.0 - smoothstep(half_width - aa * 0.5, half_width + aa * 0.5, distance_out);
	float edge = 1.0 - smoothstep(reach - aa * 0.5, reach + aa * 0.5, distance_out);
	ALBEDO = mix(outline_color.rgb, color.rgb, line);
	ALPHA = mix(outline_color.a * edge, color.a, line) * UV2.x;
}
