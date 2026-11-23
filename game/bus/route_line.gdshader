// PROTOTYPE: the route line in screen space. UV.x is pixels along the line, UV.y -1..1
// across the strip (reach pixels each side). UV2.x opacity, UV2.y 1 for a marker, where UV
// is pixels from its middle.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.08, 0.07, 0.18, 0.7);
uniform int style = 0;
uniform float reach = 4.0;
uniform float half_width = 1.25;
uniform float outline = 1.25;
uniform float dash_length = 8.0;
uniform float gap = 6.0;
uniform float scroll = 0.0;
uniform float chevron = 3.5;
uniform float track_alpha = 0.35;
uniform float marker_radius = 5.0;
uniform bool marker_hollow = false;

uniform bool glow = false;

vec4 over(vec4 top, vec4 bottom) {
	float a = top.a + bottom.a * (1.0 - top.a);
	if (a <= 0.0) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / a, a);
}

float coverage(float d, float edge, float aa) {
	return 1.0 - smoothstep(edge - aa * 0.5, edge + aa * 0.5, d);
}

float dash_distance(float along, float across, float len, float g) {
	float period = len + g;
	float a = mod(along - scroll, period) - period * 0.5;
	float half_straight = max(len * 0.5 - half_width, 0.0);
	return length(vec2(max(abs(a) - half_straight, 0.0), across));
}

void fragment() {
	float aa;
	float d;
	float base = 0.0;
	if (UV2.y > 0.5) {
		aa = max(fwidth(UV.x), 0.001);
		d = (abs(UV.x) + abs(UV.y) - marker_radius) * 0.7071;
		float fill = coverage(d, 0.0, aa);
		if (marker_hollow) {
			fill *= 1.0 - coverage(d, -half_width * 1.6, aa);
		}
		float rim = coverage(d, outline, aa);
		if (marker_hollow) {
			float inner = coverage(d, -half_width * 1.6 - outline, aa);
			rim = max(rim * (1.0 - inner), fill);
		}
		ALBEDO = mix(outline_color.rgb, color.rgb, fill);
		ALPHA = mix(outline_color.a * rim, color.a, fill) * UV2.x;
	} else {
		float across = UV.y * reach;
		aa = max(fwidth(across), 0.001);
		if (style == 0) {
			d = abs(across);
		} else if (style == 1 || style == 2) {
			d = dash_distance(UV.x, across, dash_length, gap);
		} else if (style == 3) {
			float period = dash_length + gap;
			float a = mod(UV.x - scroll, period) - period * 0.5;
			float c = abs(across);
			d = abs(a + c - chevron * 0.5) * 0.7071;
			d = max(d, c - chevron);
		} else {
			d = dash_distance(UV.x, across, dash_length, gap);
			base = coverage(abs(across), half_width * 0.45, aa) * track_alpha;
		}
		float line = coverage(d, half_width, aa);
		float edge = glow ? 1.0 - smoothstep(half_width, half_width + outline, d)
			: coverage(d, half_width + outline, aa);
		vec4 c = over(vec4(outline_color.rgb, outline_color.a * edge), vec4(color.rgb, base));
		c = over(vec4(color.rgb, color.a * line), c);
		ALBEDO = c.rgb;
		ALPHA = c.a * UV2.x;
	}
}
