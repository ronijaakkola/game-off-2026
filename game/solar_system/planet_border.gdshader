// A planet's border (planet.gd), on a shell round its body drawn from behind: a ring in one
// colour with a thin dark line either side, as the route line has, measured in pixels past
// the body's edge on screen.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.08, 0.07, 0.18, 0.7);
// The body's radius in world units, and how many world units a pixel spans at the body.
uniform float body_radius = 1.0;
uniform float world_per_pixel = 0.01;
// The ring's width and each dark line's, in pixels.
uniform float ring = 2.5;
uniform float outline = 1.25;

varying vec3 center_view;

void vertex() {
	center_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
	// How far the view ray passes from the body's centre, past its edge, in pixels.
	vec3 ray = normalize(VERTEX);
	float past = (length(cross(ray, center_view)) - body_radius) / world_per_pixel;
	float aa = max(fwidth(past), 0.001);
	float ring_in = smoothstep(outline - aa * 0.5, outline + aa * 0.5, past);
	float ring_end = outline + ring;
	float ring_out = 1.0 - smoothstep(ring_end - aa * 0.5, ring_end + aa * 0.5, past);
	float reach = ring_end + outline;
	float edge = 1.0 - smoothstep(reach - aa * 0.5, reach + aa * 0.5, past);
	float fill = ring_in * ring_out;
	ALBEDO = mix(outline_color.rgb, color.rgb, fill);
	ALPHA = mix(outline_color.a * edge, 1.0, fill) * color.a;
}
