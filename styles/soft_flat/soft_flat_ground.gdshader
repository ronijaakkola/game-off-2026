// Soft flat look for the ground: a base green with lighter painted patches. The patch
// edges are roughened by finer noise, like a dry brush, and the roughness fades with
// distance so it doesn't shimmer.
shader_type spatial;
render_mode specular_disabled;

#include "res://styles/soft_flat/soft_flat_light.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.36, 0.56, 0.42);
uniform vec3 patch_color : source_color = vec3(0.5, 0.68, 0.55);
uniform vec3 dark_color : source_color = vec3(0.28, 0.46, 0.35);
uniform float patch_scale = 0.4;
uniform float brush_scale = 8.0;
uniform float brush_strength : hint_range(0.0, 2.0) = 0.8;
uniform float brush_fade_start = 10.0;
uniform float brush_fade_end = 26.0;

varying vec2 world_xz;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world.xz;
}

float fbm(vec2 p) {
	return value_noise(p) * 0.6 + value_noise(p * 2.1 + 7.3) * 0.4;
}

// Turns a soft 0..1 wash into a ragged, dry-brush edge: fine noise decides where along
// the wash's gradient the paint breaks up.
float brush_edge(float wash, float rough) {
	return smoothstep(0.35, 0.65, wash * 1.3 - 0.15 + rough);
}

void fragment() {
	float brush_fade = 1.0 - smoothstep(brush_fade_start, brush_fade_end, length(VERTEX));
	float rough = (value_noise(world_xz * brush_scale) * 0.65 + value_noise(world_xz * brush_scale * 2.7) * 0.35 - 0.5) * brush_strength * brush_fade;
	float light_patch = brush_edge(smoothstep(0.45, 0.75, fbm(world_xz * patch_scale)), rough);
	float dark_patch = brush_edge(smoothstep(0.46, 0.28, fbm(world_xz * patch_scale * 0.6 + 31.0)), rough);
	vec3 color = mix(base_color, patch_color, light_patch);
	ALBEDO = mix(color, dark_color, dark_patch * 0.8);
}

void light() {
	float shadow = smoothstep(0.1, 0.7, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * soft_ramp(dot(NORMAL, LIGHT)) * shadow * light_strength / PI;
}
