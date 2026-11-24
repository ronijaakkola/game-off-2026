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
uniform vec4 outline_color : source_color = vec4(0.08, 0.07, 0.18, 0.7);
uniform float outline_px = 1.25;

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
	vec3 rgb = color.rgb;
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
	} else if (style == 4 || style == 5) {
		// A ring with the route line's dark edge outside it, and with 5 inside it too.
		float inner = style == 5 ? outline_px : 0.0;
		float ring_in = smoothstep(inner - aa * 0.5, inner + aa * 0.5, px);
		float ring_out = 1.0 - smoothstep(inner + ring_px - aa * 0.5, inner + ring_px + aa * 0.5, px);
		float ring = ring_in * ring_out;
		float reach = inner + ring_px + outline_px;
		float edge = 1.0 - smoothstep(reach - aa * 0.5, reach + aa * 0.5, px);
		rgb = mix(outline_color.rgb, color.rgb, ring);
		alpha = mix(outline_color.a * edge, 1.0, ring);
	}
	ALBEDO = rgb;
	ALPHA = alpha * color.a;
}
