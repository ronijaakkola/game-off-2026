// Soft painterly surface: a vertical colour gradient, blotchy grain, a wide soft light
// ramp (half-lambert pushed through a smoothstep) and a faint glowing rim.
// Written for Compatibility: no depth texture, no screen texture, no SDFGI.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 base_color : source_color = vec3(0.9, 0.55, 0.4);
// Authored colours: read the base colour from albedo_tex at the mesh's own UV (a Kenney
// colormap, say) instead of using base_color.
uniform bool use_albedo_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.25;
uniform float gradient_height = 1.0;
uniform sampler2D grain_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float grain_scale = 1.2;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.18;
uniform float ramp_low : hint_range(0.0, 1.0) = 0.3;
uniform float ramp_high : hint_range(0.0, 1.0) = 0.85;
uniform vec3 rim_color : source_color = vec3(1.0, 0.8, 0.6);
uniform float rim_power = 3.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.25;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grain_uv = (world_pos.xz + world_pos.y * vec2(0.37, 0.61)) * grain_scale;
	float grain = texture(grain_tex, grain_uv).r;
	float height = clamp(world_pos.y / gradient_height, 0.0, 1.0);
	vec3 base = use_albedo_tex ? texture(albedo_tex, UV).rgb : base_color;
	vec3 col = base * mix(1.0 - gradient_strength, 1.0 + gradient_strength * 0.5, height);
	col *= 1.0 + (grain - 0.5) * 2.0 * grain_strength;
	// One level of dither: there is no debanding on the web, and gradients band.
	float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	ALBEDO = col + dither / 1024.0;
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color * rim * rim_strength + emission_color * emission_energy;
}

void light() {
	float wrapped = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float soft = smoothstep(ramp_low, ramp_high, wrapped);
	DIFFUSE_LIGHT += LIGHT_COLOR * soft * ATTENUATION / PI;
}
