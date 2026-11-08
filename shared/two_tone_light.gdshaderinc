// The two-tone light of the planets, the bus and the passenger portraits: a lit side in the
// surface colour itself and a night side multiplied by a tint. The star's colour, energy and
// distance are left out on purpose.
//
// The shaders that include this are unshaded and light themselves from fragment(). A
// light() function would do the same, but in the web build each shader with one takes about
// 1.5 s to compile (ANGLE on Direct3D, measured in Chrome), which the player waits through
// on the loading card or as a freeze mid-game.

// Where the light comes from, in world space: the position of a point light, by default the
// star at the solar system's origin, or with light_is_directional, the direction toward a
// far light.
uniform vec3 light_source = vec3(0.0);
uniform bool light_is_directional = false;
// The night side is the surface colour multiplied by this. In light(), the Compatibility
// renderer used it as stored, skipping the sRGB to linear conversion that source_color asks
// for, and the look was tuned on that: this default is the old (0.5, 0.45, 0.78) as an sRGB
// colour, so it multiplies by those numbers in linear light, as before.
uniform vec3 shadow_color : source_color = vec3(0.735, 0.701, 0.896);

// The colour [param albedo] shows under the light. [param normal] and [param vertex] are
// fragment()'s NORMAL and VERTEX, in view space. The day-night edge blends over one screen
// pixel, so it is as sharp up close as from afar, or over [param softness] when that is wider.
vec3 two_tone_light(vec3 albedo, vec3 normal, vec3 vertex, mat4 inv_view, float softness) {
	vec3 world_normal = normalize(mat3(inv_view) * normal);
	vec3 world_position = (inv_view * vec4(vertex, 1.0)).xyz;
	vec3 to_light = light_is_directional ? light_source : light_source - world_position;
	float ndl = dot(world_normal, normalize(to_light));
	float width = max(fwidth(ndl), softness) + 1e-4;
	return albedo * mix(shadow_color, vec3(1.0), smoothstep(-width, width, ndl));
}
