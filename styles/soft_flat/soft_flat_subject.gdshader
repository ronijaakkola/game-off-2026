// Soft flat look for objects: three soft light bands, a colour gradient that darkens
// toward the ground, and an optional second colour on upward-facing surfaces. The faceted
// variant also turns on flat normals and bands of a stripe colour across the object.
shader_type spatial;
render_mode specular_disabled;

#include "res://styles/soft_flat/soft_flat_light.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.95, 0.94, 0.92);
uniform vec3 bottom_color : source_color = vec3(0.7, 0.73, 0.76);
uniform float gradient_height = 0.8;
uniform float gradient_amount : hint_range(0.0, 1.0) = 0.8;
uniform vec3 top_color : source_color = vec3(0.74, 0.38, 0.38);
uniform float top_amount : hint_range(0.0, 1.0) = 1.0;
// How far up a face must point (object space) to count as top, and how soft the edge is.
uniform float top_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float top_softness : hint_range(0.001, 0.5) = 0.15;
// Light every triangle with its own normal, from screen-space derivatives.
uniform bool flat_normals = false;
// Bands of stripe_color along stripe_direction (object space): stripe_frequency bands per
// unit, each stripe_width of the band wide.
uniform vec3 stripe_color : source_color = vec3(0.95, 0.95, 0.96);
uniform float stripe_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 stripe_direction = vec3(0.0, 1.0, 0.0);
uniform float stripe_frequency = 1.5;
uniform float stripe_width : hint_range(0.0, 1.0) = 0.5;

varying vec3 object_normal;
varying vec3 object_pos;
varying float world_y;

void vertex() {
	object_normal = NORMAL;
	object_pos = VERTEX;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 up_normal = normalize(object_normal);
	if (flat_normals) {
		// The derivative cross product is the face normal up to sign, which depends on the
		// render target's flip, so take the sign from the interpolated normal.
		vec3 view_face = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		NORMAL = dot(view_face, NORMAL) < 0.0 ? -view_face : view_face;
		vec3 object_face = normalize(cross(dFdx(object_pos), dFdy(object_pos)));
		up_normal = dot(object_face, up_normal) < 0.0 ? -object_face : object_face;
	}
	vec3 color = mix(base_color, bottom_color, (1.0 - smoothstep(0.0, gradient_height, world_y)) * gradient_amount);
	float band = dot(object_pos, normalize(stripe_direction)) * stripe_frequency;
	float wave = abs(fract(band) - 0.5) * 2.0;
	float edge_width = max(fwidth(wave), 0.0001);
	float stripe = smoothstep(1.0 - stripe_width - edge_width, 1.0 - stripe_width + edge_width, wave) * stripe_amount;
	color = mix(color, stripe_color, stripe);
	float top = smoothstep(top_threshold - top_softness, top_threshold + top_softness, up_normal.y) * top_amount;
	ALBEDO = mix(color, top_color, top);
}

void light() {
	float shadow = smoothstep(0.1, 0.7, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * soft_ramp(dot(NORMAL, LIGHT)) * shadow * light_strength / PI;
}
