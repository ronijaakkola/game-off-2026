shader_type spatial;
// A cartoon anger mark drawn on a quad: four short curved strokes, one in each corner,
// each bowed in toward the middle with a gap between them, in a red with a dark outline.
// It shows anger without tinting the skin, which keeps the race's colour. Every edge
// blends over one screen pixel, so it stays crisp at any size.
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_test_disabled;

uniform vec3 mark_color : source_color = vec3(0.95, 0.18, 0.24);
uniform vec3 outline_color : source_color = vec3(0.1, 0.08, 0.2);
// Each stroke is an arc round a point toward its corner: where that point is, from the
// middle, and the arc's radius, both in halves of the quad.
uniform float arc_centre = 0.76;
uniform float arc_radius = 0.52;
// The stroke's half width, and the outline's width round it, in halves of the quad.
uniform float stroke = 0.14;
uniform float outline_width = 0.09;

// Distance from q to the arc of the circle round c with radius r between the angles
// pointing -x and -y from c: the quarter that bows toward the middle.
float arc_distance(vec2 q, vec2 c, float r) {
	vec2 d = q - c;
	if (d.x < 0.0 && d.y < 0.0) {
		return abs(length(d) - r);
	}
	vec2 end_a = c + vec2(-r, 0.0);
	vec2 end_b = c + vec2(0.0, -r);
	return min(length(q - end_a), length(q - end_b));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = arc_distance(abs(p), vec2(arc_centre), arc_radius);
	float aa = fwidth(d);
	float fill = 1.0 - smoothstep(stroke - aa, stroke, d);
	float shape = 1.0 - smoothstep(stroke + outline_width - aa, stroke + outline_width, d);
	ALBEDO = mix(outline_color, mark_color, fill);
	ALPHA = shape;
}
