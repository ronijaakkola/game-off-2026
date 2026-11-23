// The fog of the space sky: two tints' amounts at a point, from layered value noise.
// SpaceSky's shaders share it, so the fog drawn per pixel and the fog map hold the same
// fog.

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
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

// How much of the main fog tint (x) and of the accent tint (y) shows at p, each 0 to 1.
vec2 fog_amounts(vec3 p) {
	return vec2(
		smoothstep(0.3, 0.75, fbm(p)),
		smoothstep(0.4, 0.8, fbm(p * 1.4 + vec3(5.2, 1.3, 8.1))));
}
