shader_type spatial;
// A cartoon sweat drop drawn on a quad: a round bulb at the bottom narrowing to a point at
// the top, in a pale blue with a dark outline and a white shine on the bulb's upper left.
// Every edge blends over one screen pixel, so it stays crisp at any size.
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;

uniform vec3 drop_color : source_color = vec3(0.6, 0.86, 1.0);
uniform vec3 shine_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 outline_color : source_color = vec3(0.1, 0.08, 0.2);
// The bulb's radius, the tip's, and how far the tip is above the bulb's middle, in halves
// of the quad's width; the quad is taller than it is wide by height_share.
uniform float bulb = 0.62;
uniform float tip = 0.06;
uniform float reach = 1.5;
uniform float height_share = 1.4;
// The outline's width, in halves of the quad's width.
uniform float outline_width = 0.16;

// Distance from p to a capsule whose bottom circle of radius r1 sits at the origin and
// whose top circle of radius r2 sits h above it.
float uneven_capsule(vec2 p, float r1, float r2, float h) {
	p.x = abs(p.x);
	float b = (r1 - r2) / h;
	float a = sqrt(1.0 - b * b);
	float k = dot(p, vec2(-b, a));
	if (k < 0.0) {
		return length(p) - r1;
	}
	if (k > a * h) {
		return length(p - vec2(0.0, h)) - r2;
	}
	return dot(p, vec2(a, b)) - r1;
}

void fragment() {
	// Up is +y, in halves of the quad's width.
	vec2 p = vec2(UV.x * 2.0 - 1.0, (1.0 - UV.y * 2.0) * height_share);
	vec2 centre = vec2(0.0, -height_share + bulb + outline_width);
	float d = uneven_capsule(p - centre, bulb - outline_width, tip, reach);
	float aa = fwidth(d);
	float fill = 1.0 - smoothstep(-aa, 0.0, d);
	float shape = 1.0 - smoothstep(outline_width - aa, outline_width, d);
	vec2 shine = (p - centre - vec2(-0.2, 0.18)) / vec2(0.12, 0.2);
	float s = length(shine) - 1.0;
	float lit = 1.0 - smoothstep(-fwidth(s), 0.0, s);
	ALBEDO = mix(outline_color, mix(drop_color, shine_color, lit), fill);
	ALPHA = shape;
}
