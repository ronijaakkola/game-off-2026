// Soft flat look for objects: three soft light bands, a colour gradient that darkens
// toward the ground, and an optional second colour on upward-facing surfaces.
shader_type spatial;
render_mode specular_disabled;

#include "res://styles/soft_flat/soft_flat_light.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.95, 0.94, 0.92);
uniform vec3 bottom_color : source_color = vec3(0.7, 0.73, 0.76);
uniform float gradient_height = 0.8;
uniform float gradient_amount : hint_range(0.0, 1.0) = 0.8;
uniform vec3 top_color : source_color = vec3(0.74, 0.38, 0.38);
uniform float top_amount : hint_range(0.0, 1.0) = 1.0;

varying vec3 object_normal;
varying float world_y;

void vertex() {
	object_normal = NORMAL;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 color = mix(base_color, bottom_color, (1.0 - smoothstep(0.0, gradient_height, world_y)) * gradient_amount);
	float top = smoothstep(0.5, 0.8, object_normal.y) * top_amount;
	ALBEDO = mix(color, top_color, top);
}

void light() {
	float shadow = smoothstep(0.1, 0.7, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * soft_ramp(dot(NORMAL, LIGHT)) * shadow * light_strength / PI;
}
