shader_type spatial;
// Flat rings around the star: a quad that always faces the camera, drawn as a few
// concentric discs with crisp edges, added on top so they lighten what is behind them.
// No glow pass, so it costs one quad.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 halo_color : source_color = vec4(1.0, 0.85, 0.3, 0.18);
// The number of discs, each a step smaller and stacked on the one behind it.
uniform int ring_count : hint_range(1, 5) = 2;
// The radius of the smallest disc, as a share of the quad's half-width.
uniform float inner_radius : hint_range(0.0, 1.0) = 0.62;

void vertex() {
	// Billboard: keep the quad's origin and scale, but face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float width = max(fwidth(d), 1e-4);
	float alpha = 0.0;
	for (int i = 0; i < ring_count; i++) {
		float t = ring_count > 1 ? float(i) / float(ring_count - 1) : 0.0;
		float radius = mix(1.0, inner_radius, t);
		alpha += 1.0 - smoothstep(radius - width, radius, d);
	}
	ALBEDO = halo_color.rgb;
	ALPHA = clamp(halo_color.a * alpha, 0.0, 1.0);
}
