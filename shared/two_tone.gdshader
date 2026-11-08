shader_type spatial;
// A flat colour with two-tone light, as on the planets: a lit side in the colour itself, and
// a night side multiplied by the same purple. The light is worked out in fragment(), see
// two_tone_light.gdshaderinc.
render_mode unshaded;
// Marks where it draws, so the bus's border (game/bus/bus_outline.gdshader) shows only past
// its edge.
stencil_mode write, compare_always, 1;

#include "res://shared/two_tone_light.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.3);

void fragment() {
	ALBEDO = two_tone_light(color, NORMAL, VERTEX, INV_VIEW_MATRIX, 0.0);
}
