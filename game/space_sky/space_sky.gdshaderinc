// What SpaceSky's two sky shaders share: the uniforms SpaceSky (space_sky.gd) sets, named
// after its exports, which hold their defaults, so those have none here; the stars, whose
// layout is fixed here; and where a view ray meets a parallax layer.

#include "res://game/space_sky/space_fog.gdshaderinc"

uniform vec3 background_color : source_color;
uniform vec3 fog_color : source_color;
uniform vec3 fog_accent_color : source_color;
uniform float fog_strength : hint_range(0.0, 2.0);
uniform vec3 star_color : source_color;
uniform float star_brightness : hint_range(0.0, 4.0);
uniform float star_density = 70.0;
uniform float star_chance : hint_range(0.0, 1.0) = 0.12;
// Star centres sit 0.2–0.8 into their cell, so a radius above 0.2 clips at the cell edge.
uniform float star_size : hint_range(0.01, 0.2) = 0.12;
uniform float parallax_depth;
// Set every frame by SpaceSky while parallax is on.
uniform vec3 camera_position;
uniform mat3 camera_basis = mat3(1.0);

// The fog layer sits this many parallax depths away and the far stars this many, and
// the fog spans this many of its noise's cells across one depth. SpaceSky lays the fog
// map out by the same numbers (FOG_DEPTH and FOG_SCALE in space_sky.gd).
const float FOG_DEPTH = 4.0;
const float FAR_STAR_DEPTH = 2.0;
const float FOG_SCALE = 2.2;

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// p is in star cells. On the sphere, most stars sit off its surface and show dim or not
// at all; a flat layer measures across the layer only, so every star in it shows. Flat
// layers keep FLAT_STAR_SHARE of the stars, so both look as busy.
const float FLAT_STAR_SHARE = 0.08;

float star_layer(vec3 p, bool flat_layer) {
	vec3 cell = floor(p);
	if (hash13(cell) > star_chance * (flat_layer ? FLAT_STAR_SHARE : 1.0)) {
		return 0.0;
	}
	vec3 offset = p - (cell + 0.2 + 0.6 * hash33(cell));
	float d = flat_layer ? length(offset.xy) : length(offset);
	float twinkle = 0.3 + 0.7 * hash13(cell + 17.0);
	return smoothstep(star_size, 0.0, d) * twinkle;
}

// Where the view ray hits a layer facing the camera, depth past the world origin, in
// world units across the layer. The layers stay put in the world, so the camera's own
// movement slides them on screen.
vec2 on_layer(vec3 dir, float depth) {
	vec3 forward = -camera_basis[2];
	float along = depth - dot(camera_position, forward);
	vec3 hit = camera_position + dir * (along / max(dot(dir, forward), 0.001));
	return vec2(dot(hit, camera_basis[0]), dot(hit, camera_basis[1]));
}

// Sizes in world units scale with depth, so at a camera near the origin each layer looks
// like the sphere version: the fog spans the same share of the view, and so does a star
// cell.
vec2 fog_layer_point(vec3 dir) {
	float fog_depth = parallax_depth * FOG_DEPTH;
	return on_layer(dir, fog_depth) * (FOG_SCALE / fog_depth);
}

vec3 far_star_layer_point(vec3 dir) {
	float far_depth = parallax_depth * FAR_STAR_DEPTH;
	return vec3(on_layer(dir, far_depth) * (star_density * 2.3 / far_depth), 41.5);
}

vec3 near_star_layer_point(vec3 dir) {
	return vec3(on_layer(dir, parallax_depth) * (star_density / parallax_depth), 0.5);
}

// The sky's colour from the fog tints' amounts and the two star layers' brightness.
vec3 sky_color(vec2 fog, float stars, vec2 pixel) {
	vec3 col = background_color;
	col += fog_color * fog.x * fog_strength;
	col += fog_accent_color * fog.y * fog_strength;
	col += star_color * stars * star_brightness;
	// No debanding on the web: dither one 8-bit step.
	col += (hash13(vec3(pixel, 7.0)) - 0.5) / 255.0;
	return col;
}
