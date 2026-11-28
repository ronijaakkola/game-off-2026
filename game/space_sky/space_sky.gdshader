shader_type sky;

// Procedural space: a dark base, two faint fog tints and two star layers.
// Without parallax they're painted on the sky sphere, so they move only when the camera
// turns. With parallax they're flat layers far behind the scene, facing the camera, so a
// camera that pans or zooms without turning slides them, the farthest the slowest.
// It works the fog out for every pixel, every frame. SpaceSky draws the game's parallax
// sky with space_sky_layers.gdshader instead, which reads the same fog from a map.

#include "res://game/space_sky/space_sky.gdshaderinc"

uniform bool parallax;

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 fog_point;
	vec3 near_stars;
	vec3 far_stars;
	if (parallax) {
		fog_point = vec3(fog_layer_point(dir), 0.0);
		far_stars = far_star_layer_point(dir);
		near_stars = near_star_layer_point(dir);
	} else {
		fog_point = dir * FOG_SCALE;
		near_stars = dir * star_density;
		far_stars = dir * star_density * 2.3 + 41.0;
	}
	float stars = star_layer(near_stars, parallax) + 0.6 * star_layer(far_stars, parallax);
	stars *= star_uncovered(dir);
	COLOR = sky_color(fog_amounts(fog_point), stars, FRAGCOORD.xy);
}
