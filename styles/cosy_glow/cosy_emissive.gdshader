// The lit panel of the machine: a warm vertical gradient with a dark-to-light edge, drawn
// brighter than 1 so glow picks it up. Unshaded: it is the light source.
shader_type spatial;
render_mode unshaded;

uniform vec3 color_top : source_color = vec3(1.0, 0.72, 0.5);
uniform vec3 color_bottom : source_color = vec3(1.0, 0.42, 0.25);
uniform float energy = 1.5;
uniform float edge_darken : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec3 col = mix(color_top, color_bottom, UV.y);
	vec2 edge = abs(UV - 0.5) * 2.0;
	float vignette = 1.0 - edge_darken * smoothstep(0.55, 1.0, max(edge.x, edge.y));
	float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	ALBEDO = col * vignette * energy + dither / 1024.0;
}
