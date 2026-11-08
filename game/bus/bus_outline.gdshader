shader_type spatial;
// The bus's border, as round a planet under the pointer: its body grown by `width` on every
// side, drawn only where nothing with two_tone.gdshader is (it writes 1 to the stencil), so
// only a rim past the bus's edge shows, never over its own roof or vents. It grows the body
// box-wise about its middle rather than along its normals: the model is flat-shaded, and
// pushing each face out along its own normal would split the rim at every edge.
render_mode unshaded, shadows_disabled, cull_back, depth_draw_never;
stencil_mode read, compare_not_equal, 1;

uniform vec4 color : source_color = vec4(1.0);
uniform float width = 0.02;
// The body's bounding box, in the mesh's own space.
uniform vec3 box_center = vec3(0.0);
uniform vec3 box_half_size = vec3(1.0);

void vertex() {
	VERTEX = box_center + (VERTEX - box_center) * (box_half_size + width) / box_half_size;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
