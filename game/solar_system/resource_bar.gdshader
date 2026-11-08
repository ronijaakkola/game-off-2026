shader_type canvas_item;
// The resource bar's pill, drawn whole here: a soft drop shadow, frosted glass (the
// screen behind blurred under a translucent fill) and a thin border. The panel's style
// box is a plain rectangle reaching past the panel on every side, so this runs once for
// each pixel the pill or its shadow covers, and nothing else draws them.
// Godot blurs the screen copy itself: each mipmap level is a Gaussian blur of the one
// before, in Compatibility too, so a higher blur_lod is a stronger blur.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// The panel's size in pixels, set by resource_bar.gd. The pill is this rect with fully
// rounded ends.
uniform vec2 size = vec2(0.0);
uniform float blur_lod : hint_range(0.0, 6.0) = 4.0;
uniform vec4 fill_color : source_color = vec4(0.078, 0.055, 0.18, 0.55);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.12);
uniform float border_width = 1.0;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.2);
uniform vec2 shadow_offset = vec2(0.0, 6.0);
// How far the shadow fades out on either side of the pill's edge, in pixels: a CSS blur.
uniform float shadow_blur = 18.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

// Signed distance from p to the pill's edge, negative inside.
float pill(vec2 p) {
	vec2 half_size = size * 0.5;
	float radius = min(half_size.x, half_size.y);
	vec2 q = abs(p - half_size) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Coverage of the area inside distance d, antialiased over one pixel.
float cover(float d) {
	return clamp(0.5 - d, 0.0, 1.0);
}

void fragment() {
	float d = pill(local);
	float inside = cover(d);
	float border = inside - cover(d + border_width);
	vec3 glass = textureLod(screen, SCREEN_UV, blur_lod).rgb;
	glass = mix(glass, fill_color.rgb, fill_color.a);
	glass = mix(glass, border_color.rgb, border_color.a * border / max(inside, 0.001));
	float shadow_d = pill(local - shadow_offset);
	float shadow = shadow_color.a * (1.0 - smoothstep(-shadow_blur, shadow_blur, shadow_d));
	COLOR = mix(vec4(shadow_color.rgb, shadow), vec4(glass, 1.0), inside);
}
