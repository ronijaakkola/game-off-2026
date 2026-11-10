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
// Light from a screen in front and a little below, on the sides that face it, as on a
// passenger portrait's face while they watch something. It lifts each channel toward
// white by its share, rather than adding, so a skin already full in the light's colour,
// such as blue under blue, still gets paler. Black, the default, shows none.
uniform vec3 screen_light : source_color = vec3(0.0);
// Which side of the screen its light comes from, from -1 at the left to 1, as the bright
// part of its picture moves.
uniform float screen_side = 0.0;
// Toward the screen, in view space, and how far to the side its light swings.
const vec3 SCREEN_DIRECTION = vec3(0.0, -0.5, 0.866);
const float SCREEN_SWING = 0.5;

void fragment() {
	ALBEDO = two_tone_light(color, NORMAL, VERTEX, INV_VIEW_MATRIX, 0.0);
	vec3 to_screen = normalize(SCREEN_DIRECTION + vec3(screen_side * SCREEN_SWING, 0.0, 0.0));
	float facing = smoothstep(-0.1, 0.7, dot(normalize(NORMAL), to_screen));
	ALBEDO += (1.0 - ALBEDO) * screen_light * facing;
}
