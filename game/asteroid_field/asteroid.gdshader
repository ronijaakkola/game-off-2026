shader_type spatial;
// An asteroid in a MultiMesh: a flat colour with the planets' two-tone light, darkened or
// lightened a little per rock by its instance colour, and tumbling slowly on its own axis,
// which the instance's custom data gives. The light is worked out in fragment(), see
// two_tone_light.gdshaderinc.
render_mode unshaded;

#include "res://shared/two_tone_light.gdshaderinc"

uniform vec3 color : source_color = vec3(0.7, 0.58, 0.55);
// How fast the rocks tumble, from 0 (still, as under Reduce motion) to 1.
uniform float tumble : hint_range(0.0, 1.0) = 1.0;
// Seconds the rocks have tumbled for, which the field counts itself, so they hold still while
// the game is paused: the shader's own TIME keeps running then.
uniform float tumble_time = 0.0;
// How big each rock is drawn where it sits, from 0 (gone) to 1.
uniform float size : hint_range(0.0, 1.0) = 1.0;
// The fastest a rock tumbles, in radians a second.
const float MAX_TUMBLE = 0.8;

varying vec3 shade;

// Turns [param v] by [param angle] radians about the unit [param axis] (Rodrigues).
vec3 turn(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	// The axis comes in 0 to 1 per channel, so it is moved back to -1 to 1.
	vec3 axis = normalize(INSTANCE_CUSTOM.xyz * 2.0 - 1.0 + vec3(1e-4));
	float angle = tumble_time * tumble * MAX_TUMBLE * (INSTANCE_CUSTOM.w - 0.5) * 2.0;
	VERTEX = turn(VERTEX, axis, angle) * size;
	NORMAL = turn(NORMAL, axis, angle);
	shade = COLOR.rgb;
}

void fragment() {
	ALBEDO = two_tone_light(color * shade, NORMAL, VERTEX, INV_VIEW_MATRIX, 0.0);
}
