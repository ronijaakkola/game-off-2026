// PROTOTYPE: a planet's border on the shell round its body, measured in pixels past the
// body's edge on screen.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform int style = 0;
uniform float body_radius = 1.0;
uniform float world_per_pixel = 0.01;
uniform float gap_px = 0.0;
uniform float ring_px = 2.0;
uniform float glow_px = 4.0;
uniform float glow_alpha = 0.35;

varying vec3 center_view;

void vertex() {
	center_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
	vec3 ray = normalize(VERTEX);
	float d = length(cross(ray, center_view)) - body_radius;
	float px = d / world_per_pixel;
	float aa = max(fwidth(px), 0.001);
	float alpha = 1.0;
	if (style == 1 || style == 2) {
		float mid = gap_px + ring_px * 0.5;
		float off = abs(px - mid);
		float ring = 1.0 - smoothstep(ring_px * 0.5 - aa * 0.5, ring_px * 0.5 + aa * 0.5, off);
		float glow = glow_alpha * (1.0 - smoothstep(ring_px * 0.5, ring_px * 0.5 + glow_px, off));
		if (style == 1) {
			// Hugging the body: nothing inside it.
			glow *= step(0.0, px);
		}
		alpha = max(ring, glow);
	} else if (style == 3) {
		alpha = 0.7 * (1.0 - smoothstep(0.0, glow_px, px));
	}
	ALBEDO = color.rgb;
	ALPHA = alpha * color.a;
}
