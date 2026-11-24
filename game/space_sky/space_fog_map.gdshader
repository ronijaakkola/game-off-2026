shader_type canvas_item;

// Draws a part of the space sky's fog layer into SpaceFogMap's texture: the two fog
// tints' amounts, in red and green, for space_sky_layers.gdshader to read.

#include "res://game/space_sky/space_fog.gdshaderinc"

// The part drawn, in the units of the sky's fog_layer_point(): where its top left corner
// lies, and how far it spans.
uniform vec2 origin;
uniform vec2 span = vec2(1.0);

void fragment() {
	COLOR = vec4(fog_amounts(vec3(origin + UV * span, 0.0)), 0.0, 1.0);
}
