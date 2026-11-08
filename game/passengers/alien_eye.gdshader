shader_type spatial;
// A flat cartoon eye drawn on a quad: an eyeball with an optional outline, an optional
// iris, a pupil that looks around, shines, and an upper lid in the skin colour that
// closes over it, showing a curved line once shut. Every edge blends over one screen pixel, so it stays crisp and smooth
// at any size. An AlienEyeStyle sets everything but look, open and lid_color.
render_mode unshaded, cull_back, shadows_disabled, blend_mix;

uniform vec3 white_color : source_color = vec3(0.97, 0.96, 1.0);
uniform vec3 iris_color : source_color = vec3(0.95, 0.6, 0.2);
uniform vec3 pupil_color : source_color = vec3(0.1, 0.08, 0.2);
uniform vec3 outline_color : source_color = vec3(0.1, 0.08, 0.2);
uniform vec3 lid_color : source_color = vec3(0.3, 0.75, 0.68);
// Sizes are fractions of the eye's radius. An iris or a pupil of 0 isn't drawn.
uniform float outline_width : hint_range(0.0, 0.4) = 0.14;
uniform float iris_size : hint_range(0.0, 1.0) = 0.0;
uniform float pupil_size : hint_range(0.0, 1.0) = 0.48;
// Squashes the pupil: (0.3, 1.0) makes a slit.
uniform vec2 pupil_stretch = vec2(1.0);
uniform float shine_size : hint_range(0.0, 0.5) = 0.13;
// Where the shine sits from the pupil's centre.
uniform vec2 shine_offset = vec2(-0.2, 0.2);
// A second, smaller shine opposite the first. 0 for none.
uniform float second_shine_size : hint_range(0.0, 0.3) = 0.0;
// How far the pupil moves from the middle at the most.
uniform float look_range : hint_range(0.0, 1.0) = 0.38;
// Where the pupil looks, from -1 to 1 on each axis (+y is up).
uniform vec2 look = vec2(0.0);
// How far the lid is open, from 0 (shut) to 1.
uniform float open : hint_range(0.0, 1.0) = 1.0;
// How angry they look, from 0 to 1: the lid slants down toward the face's middle like a
// frown, and its edge thickens into a brow.
uniform float anger : hint_range(0.0, 1.0) = 0.0;
// Which way along x the face's middle is from this eye: 1 to the right, -1 to the left,
// 0 for an eye in the middle, whose lids stay flat instead: any curve on one eye in the
// middle of the face reads as a mouth.
uniform float inner_side = 0.0;
// How joyful they look, from 0 to 1: a lower lid rises in an arch, so the eye smiles into
// a crescent, as in ^ ^.
uniform float joy : hint_range(0.0, 1.0) = 0.0;
// Scales the pupil, such as smaller in anger.
uniform float pupil_scale = 1.0;
// How far toward the camera the eye draws, in metres, so a flat disc on a curved head
// isn't cut by the skin around it.
uniform float lift = 0.05;

// How far the lid's inner end drops at full anger, in eye radii.
const float ANGER_SLANT = 0.8;
// At full joy, where the lower lid's ends rise to, and how much higher its middle arches,
// in eye radii.
const float JOY_LID = -0.35;
const float JOY_ARCH = 0.75;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z += lift;
	POSITION = PROJECTION_MATRIX * view;
}

// 1 inside a circle of radius [param radius] at distance [param d], 0 outside, blended over
// one pixel ([param px] is the size of a pixel in the same units).
float disc(float d, float radius, float px) {
	return clamp((radius - d) / px + 0.5, 0.0, 1.0) * step(0.001, radius);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	// One screen pixel in eye units: the eye is 2 units across.
	float px = length(vec2(dFdx(UV.x), dFdy(UV.y))) * 2.0 / sqrt(2.0) + 1e-5;

	vec2 centre = look * look_range;
	vec3 col = white_color;
	col = mix(col, iris_color, disc(length(p - centre), iris_size, px));
	float squash = min(pupil_stretch.x, pupil_stretch.y);
	float pupil = disc(
		length((p - centre) / pupil_stretch), pupil_size * pupil_scale, px / squash
	);
	col = mix(col, pupil_color, pupil);
	col = mix(col, vec3(1.0), disc(length(p - centre - shine_offset), shine_size, px));
	float second = disc(length(p - centre + shine_offset * 0.8), second_shine_size, px);
	col = mix(col, vec3(1.0), second * 0.8);

	// The lid's edge sags a little in the middle as it comes down.
	float edge = mix(-1.05, 1.05, open) - 0.15 * (1.0 - open) * (1.0 - p.x * p.x);
	// In anger it slants down toward the face's middle: 0 at the outer side, 1 at the inner.
	float inner = abs(inner_side) > 0.5 ? (p.x * inner_side + 1.0) * 0.5 : 0.5;
	edge -= anger * ANGER_SLANT * inner;
	float lid = clamp((p.y - edge) / px + 0.5, 0.0, 1.0);
	float lid_line = disc(abs(p.y - edge), 0.05 + 0.08 * anger, px) * step(open, 0.98);
	col = mix(col, lid_color, lid);
	col = mix(col, outline_color, lid_line);
	// Joyful, a lower lid rises over the eye's bottom, arching up in the middle.
	float arch = abs(inner_side) > 0.5 ? JOY_ARCH * (1.0 - p.x * p.x) : JOY_ARCH * 0.5;
	float lower_edge = mix(-1.05, JOY_LID, joy) + arch * joy;
	float lower = clamp((lower_edge - p.y) / px + 0.5, 0.0, 1.0);
	float lower_line = disc(abs(p.y - lower_edge), 0.1, px) * step(0.02, joy);
	col = mix(col, lid_color, lower);
	col = mix(col, outline_color, lower_line);
	// Shut, the lid's edge shows as a curved line across the eye, sagging in the middle.
	float shut = 1.0 - smoothstep(0.0, 0.15, open);
	float crease = -0.05 - 0.3 * (1.0 - p.x * p.x);
	float crease_line = disc(abs(p.y - crease), 0.12, px) * disc(abs(p.x), 0.75, px);
	col = mix(col, outline_color, crease_line * shut);

	col = mix(col, outline_color, (1.0 - disc(r, 1.0 - outline_width, px)) * step(0.001, outline_width));
	ALBEDO = col;
	ALPHA = disc(r, 1.0 - px * 0.5, px);
}
