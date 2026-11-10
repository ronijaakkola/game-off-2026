shader_type canvas_item;
// Frosted glass for a panel's StyleBoxFlat: the screen behind it, blurred, under the
// style box's colours. The style box is drawn opaque, so its alpha is only its coverage
// (1 inside, less on its antialiased edge), and the glass lets the screen show through
// with [fill_opacity] of the style box's colour on top. Fill and border both go through
// it, so a border keeps its colour over the blur.
// Set on a panel as its material, it touches only the panel's own style box: the panel's
// children draw with their own materials.
// Godot blurs the screen copy itself: each mipmap level is a Gaussian blur of the one
// before, in Compatibility too, so a higher blur_lod is a stronger blur.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 4.0;
// How much of the style box's colour covers the blurred screen.
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec3 behind = textureLod(screen, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(behind, COLOR.rgb, fill_opacity), COLOR.a);
}
