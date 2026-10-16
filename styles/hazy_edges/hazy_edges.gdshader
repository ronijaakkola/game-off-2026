// Full-screen hazy edges, for the hazy-edges style.
//
// Put a 2x2 QuadMesh under the camera with this material. Every pixel reads the finished
// scene from somewhere near itself instead of from itself, and "near" is decided by a noise
// field that is fixed in the world, not on the screen. Flat areas are unchanged. Wherever two
// colours meet (a silhouette, a shadow border, a window) the border comes out ragged, and
// averaging a few reads that each wander a little differently turns the border from a hard
// line into a short haze of partly covered pixels, like the edge of a dabbed paint stroke.
//
// Fixed in the world means the raggedness belongs to the surface it sits on. Move the camera
// and a ragged edge on the building stays the same ragged edge, instead of boiling or
// sliding like a texture laid on the glass.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

// How far a read may wander, in metres at the surface (so the haze is the same size on the
// building whether it is near or far). Roughly the width of the ragged zone.
uniform float amount : hint_range(0.0, 0.2) = 0.03;
// Noise cell size in metres. The first octave is the slow wobble of an edge, the second the
// small ragged teeth on top of it.
uniform float wobble_size : hint_range(0.05, 1.0) = 0.25;
uniform float tooth_size : hint_range(0.01, 0.3) = 0.1;
// How much of amount the teeth take; the wobble takes the rest.
uniform float tooth_share : hint_range(0.0, 1.0) = 0.25;
// How far apart in the noise the three reads sit. 0 puts them on one spot (a sharp but ragged
// edge); 1 gives each its own noise (a wide haze).
uniform float haze : hint_range(0.0, 1.0) = 0.35;

vec4 hash4(vec3 p) {
	// Four independent values per lattice point from one hash (no sin, so it is the same on
	// every GPU).
	vec4 q = fract(vec4(p.xyzx) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

// Smooth value noise, four channels, each in -1..1.
vec4 noise4(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 a = mix(mix(hash4(i), hash4(i + vec3(1, 0, 0)), f.x),
			mix(hash4(i + vec3(0, 1, 0)), hash4(i + vec3(1, 1, 0)), f.x), f.y);
	vec4 b = mix(mix(hash4(i + vec3(0, 0, 1)), hash4(i + vec3(1, 0, 1)), f.x),
			mix(hash4(i + vec3(0, 1, 1)), hash4(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z) * 2.0 - 1.0;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

// View-space position of the pixel at uv, from the depth buffer.
vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return v.xyz / v.w;
}

void fragment() {
	vec3 vp = view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 world = (INV_VIEW_MATRIX * vec4(vp, 1.0)).xyz;

	// Two octaves, four channels each: channels xy and zw are two independent offsets.
	vec4 slow = noise4(world / wobble_size);
	vec4 fine = noise4(world / tooth_size + 17.3);
	vec4 slow2 = noise4(world / wobble_size + vec3(41.7, 9.2, 23.5));
	vec4 fine2 = noise4(world / tooth_size + vec3(5.1, 31.9, 12.8));
	vec4 n1 = mix(slow, fine, tooth_share);
	vec4 n2 = mix(slow2, fine2, tooth_share);

	// Read 0 uses the shared wobble; reads 1 and 2 add their own on top, scaled by haze.
	vec2 o0 = n1.xy;
	vec2 o1 = mix(n1.xy, n1.zw, haze);
	vec2 o2 = mix(n1.xy, n2.xy, haze);

	vec3 col = vec3(0.0);
	vec2 offs[3] = vec2[3](o0, o1, o2);
	for (int i = 0; i < 3; i++) {
		// Move in view space (a metre is a metre on the surface), then project back.
		vec4 clip = PROJECTION_MATRIX * vec4(vp + vec3(offs[i] * amount, 0.0), 1.0);
		vec2 puv = clip.xy / clip.w * 0.5 + 0.5;
		col += textureLod(screen_tex, puv, 0.0).rgb;
	}
	ALBEDO = col / 3.0;
}
