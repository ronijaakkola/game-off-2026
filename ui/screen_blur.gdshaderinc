// The screen behind a canvas item, blurred, for the frosted glass of the panels and the
// resource bar: SCREEN_BLUR_TAPS samples on a spiral round the pixel, averaged. Each pixel
// turns its spiral by its own angle. With one spiral for all, a bright thing behind the
// glass (a planet's label, an orbit line) shows as that many faint sharp copies of itself;
// turned per pixel, the copies break up into a fine grain that reads as frost.
//
// The blur is done here, not by reading the screen's mipmaps. With filter_linear_mipmap
// Godot blurs the whole screen into a mipmap chain every frame, about six more full
// render passes for each CanvasLayer that shows glass, however small the panel; without
// it, it only copies the screen once, and the blur costs these samples on the panel's own
// pixels.

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// How far the blur reaches, in pixels of the 648-high design size: it grows with the
// window, as the panels do.
uniform float blur_radius = 24.0;

const int SCREEN_BLUR_TAPS = 16;
// The angle between one sample and the next, which spreads them evenly over the disc.
const float GOLDEN_ANGLE = 2.39996323;

// [param pixel] is FRAGCOORD.xy.
vec3 screen_blur(vec2 screen_uv, vec2 screen_pixel_size, vec2 pixel) {
	// One design pixel is 1/648 of the screen's height; the width follows by the aspect.
	vec2 reach = blur_radius / 648.0 * vec2(screen_pixel_size.x / screen_pixel_size.y, 1.0);
	// Interleaved gradient noise: a value in 0..1 that differs evenly between neighbours.
	float noise = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	vec3 sum = vec3(0.0);
	for (int i = 0; i < SCREEN_BLUR_TAPS; i++) {
		float distance_from_centre = sqrt((float(i) + noise) / float(SCREEN_BLUR_TAPS));
		float angle = float(i) * GOLDEN_ANGLE + noise * TAU;
		vec2 offset = vec2(cos(angle), sin(angle)) * distance_from_centre * reach;
		sum += textureLod(screen, screen_uv + offset, 0.0).rgb;
	}
	return sum / float(SCREEN_BLUR_TAPS);
}
