shader_type sky;

// Procedural space: a dark base, two faint fog tints and two star layers.
// SpaceSky (space_sky.gd) sets every uniform; its exports are where to change them.
uniform vec3 background_color : source_color;
uniform vec3 fog_color : source_color;
uniform vec3 fog_accent_color : source_color;
uniform float fog_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec3 star_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float star_density = 70.0;
uniform float star_chance : hint_range(0.0, 1.0) = 0.12;
uniform float star_size : hint_range(0.01, 0.5) = 0.12;
uniform float star_brightness : hint_range(0.0, 4.0) = 2.0;

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

float star_layer(vec3 dir, float density, float seed) {
	vec3 p = dir * density + seed;
	vec3 cell = floor(p);
	if (hash13(cell + seed) > star_chance) {
		return 0.0;
	}
	vec3 star = cell + 0.2 + 0.6 * hash33(cell);
	float d = length(p - star);
	float twinkle = 0.3 + 0.7 * hash13(cell + 17.0);
	return smoothstep(star_size, 0.0, d) * twinkle;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = background_color;
	col += fog_color * smoothstep(0.3, 0.75, fbm(dir * 2.2)) * fog_strength;
	col += fog_accent_color * smoothstep(0.4, 0.8, fbm(dir * 3.1 + vec3(5.2, 1.3, 8.1))) * fog_strength;
	float stars = star_layer(dir, star_density, 0.0) + 0.6 * star_layer(dir, star_density * 2.3, 41.0);
	col += star_color * stars * star_brightness;
	// No debanding on the web: dither one 8-bit step.
	col += (hash13(vec3(FRAGCOORD.xy, 7.0)) - 0.5) / 255.0;
	COLOR = col;
}
