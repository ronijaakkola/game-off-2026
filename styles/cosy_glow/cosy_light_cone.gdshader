// A fake light shaft: an open cone drawn additively, bright at the top, fading with height
// and towards its silhouette so it reads as volume from every side. No depth texture, so it
// is cheap but cuts hard where it meets geometry. Everything behind clip_z is dropped, so
// the cone does not wrap round the machine it comes from: it would paint its back.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.55, 0.3);
uniform float intensity = 0.55;
uniform float top_y = 2.0;
uniform float fall_power = 1.5;
uniform float edge_power = 1.5;
uniform float clip_z = -1.58;

varying float world_y;
varying float world_z;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_y = world.y;
	world_z = world.z;
}

void fragment() {
	if (world_z < clip_z) {
		discard;
	}
	float down = clamp(1.0 - world_y / top_y, 0.0, 1.0);
	float along = pow(1.0 - down, fall_power);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), edge_power);
	ALBEDO = color * (along * edge * intensity);
}
