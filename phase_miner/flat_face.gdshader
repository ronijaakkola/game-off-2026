shader_type spatial;
render_mode unshaded;

// Flat, matte shading for the field's pieces: every face is one flat colour, picked from
// its direction against a fixed sun. Tops are the full colour, faces turned to the sun a
// shade darker, and faces turned away take one shared, slightly cool shadow tint, kept close
// to the lit colour so the look stays soft and low in contrast. The face direction comes from
// screen-space derivatives of the position, so even a smooth mesh shows crisp facets.
// Unshaded: it ignores the scene's lights, so it needs no shadow map and no ground.

uniform vec3 color : source_color = vec3(0.6, 0.6, 0.7);
// What a face turned away from the sun is multiplied by: a little darker and a little cool.
uniform vec3 shadow_tint : source_color = vec3(0.66, 0.67, 0.76);
// The direction the sunlight comes from, in world space. Up and to the left of the camera.
uniform vec3 sun_direction = vec3(-0.55, 0.8, 0.3);
// Brightness of a lit side face against a lit top face (1.0).
uniform float side_value : hint_range(0.0, 1.0) = 0.88;
// Lit faces this close to edge-on to the sun get a half step between lit and shadow.
uniform float rim_band : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	// The face's normal from how the position changes across the screen, turned to face
	// the camera (which looks down -Z in view space), then into world space.
	vec3 view_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	view_normal *= sign(view_normal.z + 1e-5);
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz);

	float sun = dot(normal, normalize(sun_direction));
	vec3 lit = color * (normal.y > 0.7 ? 1.0 : side_value);
	vec3 shadow = color * shadow_tint;
	vec3 rim = mix(shadow, lit, 0.5);
	ALBEDO = sun <= 0.0 ? shadow : (sun < rim_band ? rim : lit);
}
