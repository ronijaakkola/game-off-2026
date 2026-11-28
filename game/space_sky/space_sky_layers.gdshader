shader_type sky;

// The space sky's parallax layers (space_sky.gdshader has the look), with the fog read
// from a map instead of worked out per pixel. The fog layer is one fixed picture that the
// camera only slides over, and working it out is most of the sky's cost: two noises of
// five octaves each, on every pixel of the screen, every frame. SpaceSky keeps the part
// of the layer in view drawn in a texture (SpaceFogMap) and says here where that part
// lies.

#include "res://game/space_sky/space_sky.gdshaderinc"

// The fog tints' amounts in red and green, over the part of the fog layer that starts at
// fog_map_origin and spans fog_map_span, in the units of fog_layer_point().
uniform sampler2D fog_map : filter_linear, repeat_disable;
uniform vec2 fog_map_origin;
uniform vec2 fog_map_span = vec2(1.0);

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec2 map_uv = (fog_layer_point(dir) - fog_map_origin) / fog_map_span;
	vec2 fog = textureLod(fog_map, map_uv, 0.0).rg;
	float stars = star_layer(near_star_layer_point(dir), true)
		+ 0.6 * star_layer(far_star_layer_point(dir), true);
	stars *= star_uncovered(dir);
	COLOR = sky_color(fog, stars, FRAGCOORD.xy);
}
