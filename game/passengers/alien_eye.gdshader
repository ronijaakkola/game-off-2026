shader_type spatial;
// A flat cartoon eye drawn on a quad: an eyeball with an optional outline, an optional
// iris, a pupil that looks around, shines, and an upper lid in the skin colour that
// closes over it, showing a curved line once shut. An eye in the middle of the face (a
// single eye) also draws a brow above it in anger and blushing cheeks below it in joy.
// Every edge blends over one screen pixel, so it stays crisp and smooth at any size. An
// AlienEyeStyle sets everything but look, open and lid_color.
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
// frown, and its edge thickens into a brow. A single eye's lid can't slant that way, so a
// brow comes down over it in a V instead.
uniform float anger : hint_range(0.0, 1.0) = 0.0;
// Which way along x the face's middle is from this eye: 1 to the right, -1 to the left,
// 0 for an eye in the middle, whose lids don't curve: any curve cut into one eye in the
// middle of the face reads as a mouth, so its anger and joy show around it instead.
uniform float inner_side = 0.0;
// How joyful they look, from 0 to 1: a lower lid rises in an arch, so the eye smiles into
// a crescent, as in ^ ^. A single eye turns starry instead, and its cheeks blush.
uniform float joy : hint_range(0.0, 1.0) = 0.0;
// Scales the pupil, such as smaller in anger.
uniform float pupil_scale = 1.0;
// How far toward the camera the eye draws, in metres, so a flat disc on a curved head
// isn't cut by the skin around it.
uniform float lift = 0.05;
// How far the quad reaches from the eye's centre, in eye radii. An eye in the middle of
// the face draws its brow and blush around it, so its quad reaches past the eye.
uniform float reach = 1.0;
// The blush's colour, on the cheeks of a joyful eye in the middle of the face.
uniform vec3 blush_color : source_color = vec3(0.93, 0.2, 0.5);

// How far the lid's inner end drops at full anger, in eye radii.
const float ANGER_SLANT = 0.8;
// At full joy, where the lower lid's ends rise to, and how much higher its middle arches,
// in eye radii.
const float JOY_LID = -0.35;
const float JOY_ARCH = 0.75;

// A single eye's brow, in eye radii: where its middle sits at full anger and at none, how
// much higher its ends are at full anger, how thick it is and how far its ends reach, and
// the skin left showing between it and the lid it pushes down.
const float BROW_LOW = 0.84;
const float BROW_HIGH = 0.98;
const float BROW_SLANT = 0.5;
const float BROW_THICKNESS = 0.28;
const float BROW_WIDTH = 0.78;
const float BROW_GAP = 0.14;
// A single eye's joy: how much bigger its pupil gets, how big the star that takes the
// shine's place is with no pupil (with one, it fills the pupil), and where each blushing
// cheek's centre sits and its half size, in eye radii.
const float JOY_PUPIL = 1.35;
const float JOY_STAR = 0.72;
const vec2 BLUSH_CENTRE = vec2(1.0, -0.8);
const vec2 BLUSH_SIZE = vec2(0.45, 0.26);

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
	vec2 p = (UV * 2.0 - 1.0) * reach;
	p.y = -p.y;
	float r = length(p);
	// One screen pixel in eye units: the quad is 2 reaches across.
	float px = length(vec2(dFdx(UV.x), dFdy(UV.y))) * 2.0 * reach / sqrt(2.0) + 1e-5;
	bool centred = abs(inner_side) < 0.5;
	float star_joy = centred ? joy : 0.0;

	vec2 centre = look * look_range;
	vec3 col = white_color;
	col = mix(col, iris_color, disc(length(p - centre), iris_size, px));
	float squash = min(pupil_stretch.x, pupil_stretch.y);
	float pupil = disc(
		length((p - centre) / pupil_stretch),
		pupil_size * pupil_scale * mix(1.0, JOY_PUPIL, star_joy),
		px / squash
	);
	col = mix(col, pupil_color, pupil);
	float shine = disc(length(p - centre - shine_offset), shine_size, px);
	col = mix(col, vec3(1.0), shine * (1.0 - star_joy));
	float second = disc(length(p - centre + shine_offset * 0.8), second_shine_size, px);
	// Starry, a four-pointed sparkle takes the place of the shines, a little nearer the
	// middle than the main one.
	float star_size = pupil_size > 0.0 ? pupil_size * pupil_scale * JOY_PUPIL : JOY_STAR;
	vec2 star_p = abs(p - centre - shine_offset * 0.4) / max(star_size * star_joy, 1e-3);
	float star_d = 1.0 - (sqrt(star_p.x) + sqrt(star_p.y));
	float star = clamp(star_d / fwidth(star_d) + 0.5, 0.0, 1.0) * step(0.02, star_joy);
	col = mix(col, vec3(1.0), star);
	col = mix(col, vec3(1.0), second * 0.8 * (1.0 - star_joy));

	// The lid's edge sags a little in the middle as it comes down.
	float edge = mix(-1.05, 1.05, open) - 0.15 * (1.0 - open) * (1.0 - p.x * p.x);
	// In anger it slants down toward the face's middle: 0 at the outer side, 1 at the inner.
	float inner = centred ? 0.0 : (p.x * inner_side + 1.0) * 0.5;
	edge -= anger * ANGER_SLANT * inner;
	// An eye in the middle of the face shows anger with a brow that comes down over it in a
	// V, pushing the lid down below it, instead of a slanted lid.
	float brow_show = centred ? smoothstep(0.05, 0.3, anger) : 0.0;
	float brow_y = mix(BROW_HIGH, BROW_LOW, anger) + BROW_SLANT * anger * abs(p.x);
	edge = mix(edge, min(edge, brow_y - BROW_THICKNESS * 0.5 - BROW_GAP), brow_show);
	float lid = clamp((p.y - edge) / px + 0.5, 0.0, 1.0);
	float lid_line = disc(abs(p.y - edge), centred ? 0.05 : 0.05 + 0.08 * anger, px);
	lid_line *= step(open, 0.98);
	col = mix(col, lid_color, lid);
	col = mix(col, outline_color, lid_line);
	// Joyful, a lower lid rises over the eye's bottom, arching up in the middle. Not on an
	// eye in the middle of the face, which blushes instead.
	float lower_joy = centred ? 0.0 : joy;
	float arch = JOY_ARCH * (1.0 - p.x * p.x);
	float lower_edge = mix(-1.05, JOY_LID, lower_joy) + arch * lower_joy;
	float lower = clamp((lower_edge - p.y) / px + 0.5, 0.0, 1.0);
	float lower_line = disc(abs(p.y - lower_edge), 0.1, px) * step(0.02, lower_joy);
	col = mix(col, lid_color, lower);
	col = mix(col, outline_color, lower_line);
	// Shut, the lid's edge shows as a curved line across the eye, sagging in the middle.
	float shut = 1.0 - smoothstep(0.0, 0.15, open);
	float crease = -0.05 - 0.3 * (1.0 - p.x * p.x);
	float crease_line = disc(abs(p.y - crease), 0.12, px) * disc(abs(p.x), 0.75, px);
	col = mix(col, outline_color, crease_line * shut);

	col = mix(col, outline_color, (1.0 - disc(r, 1.0 - outline_width, px)) * step(0.001, outline_width));
	float eye = disc(r, 1.0 - px * 0.5, px);

	// Around an eye in the middle of the face: the brow, and blushing cheeks in joy.
	float alpha = eye;
	if (centred) {
		vec2 cheek = vec2(abs(p.x), p.y) - BLUSH_CENTRE;
		float blush = disc(length(cheek / BLUSH_SIZE), 1.0, px / BLUSH_SIZE.y) * joy;
		col = mix(blush_color, col, eye);
		alpha = max(alpha, blush);
		// Distance from the brow's centre line, measured square to its slant.
		float slope = BROW_SLANT * anger;
		float across = abs(p.y - brow_y) / sqrt(1.0 + slope * slope);
		float along = max(abs(p.x) - BROW_WIDTH, 0.0);
		float brow = disc(length(vec2(along, across)), BROW_THICKNESS * 0.5, px) * brow_show;
		col = mix(col, outline_color, brow);
		alpha = max(alpha, brow);
	}
	ALBEDO = col;
	ALPHA = alpha;
}
