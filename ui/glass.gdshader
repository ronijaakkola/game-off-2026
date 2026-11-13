shader_type canvas_item;
// Frosted glass for a panel's StyleBoxFlat: the screen behind it, blurred, under the
// style box's colours. The style box is drawn opaque, so its alpha is only its coverage
// (1 inside, less on its antialiased edge), and the glass lets the screen show through
// with [fill_opacity] of the style box's colour on top. Fill and border both go through
// it, so a border keeps its colour over the blur.
// Set on a panel as its material, it touches only the panel's own style box: the panel's
// children draw with their own materials.

#include "res://ui/screen_blur.gdshaderinc"

// How much of the style box's colour covers the blurred screen.
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec3 behind = screen_blur(SCREEN_UV, SCREEN_PIXEL_SIZE, FRAGCOORD.xy);
	COLOR = vec4(mix(behind, COLOR.rgb, fill_opacity), COLOR.a);
}
