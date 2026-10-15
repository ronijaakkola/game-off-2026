// Full-screen vignette: darkens and tints the corners. One cheap canvas pass.
shader_type canvas_item;

uniform vec3 color : source_color = vec3(0.08, 0.2, 0.25);
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float inner = 0.35;
uniform float outer = 0.95;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.25, 1.0);
	COLOR = vec4(color, smoothstep(inner, outer, length(p)) * strength);
}
