shader_type sky;

// Procedural space: a dark base, two faint fog tints and two star layers.
// Without parallax they're painted on the sky sphere, so they move only when the camera
// turns. With parallax they're flat layers far behind the scene, facing the camera, so a
// camera that pans or zooms without turning slides them, the farthest the slowest.
// SpaceSky (space_sky.gd) sets the uniforms named after its exports, and its exports
// hold their defaults, so those have none here. The star layout below is fixed here.
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
uniform bool parallax;
uniform float parallax_depth;
// Set every frame by SpaceSky while parallax is on.
uniform vec3 camera_position;
uniform mat3 camera_basis = mat3(1.0);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * value_noise(p);
		// Rotate each octave so the lattice of the value noise doesn't line up.
		p = mat3(vec3(0.00, 0.80, 0.60), vec3(-0.80, 0.36, -0.48), vec3(-0.60, -0.48, 0.64)) * p * 2.03;
		amp *= 0.5;
	}
	return sum;
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

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 fog_point;
	vec3 near_stars;
	vec3 far_stars;
	if (parallax) {
		// Sizes in world units scale with depth, so at a camera near the origin each layer
		// looks like the sphere version: the fog spans the same share of the view, and so
		// does a star cell.
		float fog_depth = parallax_depth * 4.0;
		float far_depth = parallax_depth * 2.0;
		fog_point = vec3(on_layer(dir, fog_depth) * (2.2 / fog_depth), 0.0);
		far_stars = vec3(on_layer(dir, far_depth) * (star_density * 2.3 / far_depth), 41.5);
		near_stars = vec3(on_layer(dir, parallax_depth) * (star_density / parallax_depth), 0.5);
	} else {
		fog_point = dir * 2.2;
		near_stars = dir * star_density;
		far_stars = dir * star_density * 2.3 + 41.0;
	}
	vec3 col = background_color;
	col += fog_color * smoothstep(0.3, 0.75, fbm(fog_point)) * fog_strength;
	col += fog_accent_color * smoothstep(0.4, 0.8, fbm(fog_point * 1.4 + vec3(5.2, 1.3, 8.1))) * fog_strength;
	float stars = star_layer(near_stars, parallax) + 0.6 * star_layer(far_stars, parallax);
	col += star_color * stars * star_brightness;
	// No debanding on the web: dither one 8-bit step.
	col += (hash13(vec3(FRAGCOORD.xy, 7.0)) - 0.5) / 255.0;
	COLOR = col;
}
