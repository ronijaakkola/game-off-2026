shader_type canvas_item;
render_mode blend_premul_alpha;
// An old screen drawn over the transmission's portrait, so it reads as a picture on a
// tube: dark scanlines, a dark rim, faint static and a soft bright band rolling down.
// It only darkens what is under it and adds light, so it needs no copy of the screen.
// [power] turns the tube on: from off (all [off_color]) a bright line opens across the
// middle, then opens out to the whole picture, under a burst of static. Set back to 0, it
// closes the same way.

uniform vec3 off_color : source_color = vec3(0.043, 0.035, 0.125);
// 0 off, 1 fully on.
uniform float power : hint_range(0.0, 1.0) = 1.0;
// How much static covers the picture, from 0 to 1.
uniform float static_amount : hint_range(0.0, 1.0) = 0.06;
// 0 under Reduce motion: the static and the rolling band hold still.
uniform float motion : hint_range(0.0, 1.0) = 1.0;
// Scanlines across the picture's height.
uniform float lines = 112.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// The line opens across first, then down and up.
	float wide = smoothstep(0.0, 0.35, power);
	float tall = smoothstep(0.3, 1.0, power);
	vec2 half_size = vec2(0.5 * wide, max(0.006, 0.5 * tall));
	vec2 from_middle = abs(uv - 0.5);
	vec2 edge = (half_size - from_middle) / max(fwidth(uv), vec2(1e-5));
	float lit = clamp(min(edge.x, edge.y), 0.0, 1.0) * step(0.001, power);

	// Static: grey snow, one grain per scanline pair, a new frame 24 times a second.
	float frame_time = floor(TIME * 24.0 * motion);
	float snow = hash(floor(uv * lines * 0.5) + frame_time);
	// The opening line glows white, fading as the picture opens.
	float flash = (1.0 - tall) * 0.55;

	float scan = 0.5 + 0.5 * sin(uv.y * lines * PI);
	float vignette = smoothstep(0.35, 0.75, length(uv - 0.5));
	float band = smoothstep(0.1, 0.0, abs(fract(uv.y - TIME * 0.12 * motion) - 0.5));

	// Premultiplied: rgb is light added, alpha darkens what is under it.
	vec3 light = vec3(snow) * static_amount * 0.6 + vec3(flash) + vec3(band * 0.035);
	float dark = max(static_amount, flash) + scan * 0.16 + vignette * 0.35;
	vec4 on = vec4(light, clamp(dark, 0.0, 1.0));
	COLOR = mix(vec4(off_color, 1.0), on, lit);
}
