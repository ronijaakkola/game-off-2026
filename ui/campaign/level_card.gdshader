shader_type canvas_item;
// A level card's picture: its crop of the level's picture, or the card's own colour when it
// has none, with rounded corners. A locked card's is grey and darker.

uniform sampler2D picture : source_color, filter_linear_mipmap;
uniform bool has_picture = false;
// The crop, as x, y, width and height in shares of the picture.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool locked = false;
// The card's size and corner radius in pixels.
uniform vec2 size = vec2(304.0, 360.0);
uniform float radius = 12.0;

// The locked card's dim: the outline's navy at 45 %.
const vec4 LOCKED_DIM = vec4(0.043, 0.035, 0.125, 0.45);

void fragment() {
	vec4 colour = COLOR;
	if (has_picture) {
		colour = vec4(texture(picture, region.xy + UV * region.zw).rgb, 1.0);
	}
	if (locked) {
		float grey = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
		colour.rgb = mix(vec3(grey), LOCKED_DIM.rgb, LOCKED_DIM.a);
	}
	vec2 corner = abs(UV * size - size * 0.5) - (size * 0.5 - radius);
	float distance = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
	colour.a *= clamp(0.5 - distance, 0.0, 1.0);
	COLOR = colour;
}
