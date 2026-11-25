shader_type canvas_item;
// The jump card's picture: a wide band of the next level's picture, or its star system's sky
// colours when it has none, shaded toward the left so the words over it read, brightened by
// `light` while the pointer is on it, with rounded corners.

uniform sampler2D picture : source_color, filter_linear_mipmap;
uniform bool has_picture = false;
// The band, as x, y, width and height in shares of the picture.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// Without a picture: the sky's colour at the left edge and at the right.
uniform vec4 left_color : source_color = vec4(0.11, 0.1, 0.24, 1.0);
uniform vec4 right_color : source_color = vec4(0.17, 0.1, 0.26, 1.0);
// How far the picture is zoomed in about its middle: 1 shows the whole band.
uniform float zoom = 1.0;
// 0 at rest, 1 with the pointer on the card.
uniform float light = 0.0;
// The card's size and corner radius in pixels.
uniform vec2 size = vec2(232.0, 62.0);
uniform float radius = 10.0;

// The outline's navy, laid over the left of the card under the words.
const vec3 SHADE = vec3(0.043, 0.035, 0.125);

void fragment() {
	vec3 colour = mix(left_color.rgb, right_color.rgb, UV.x);
	if (has_picture) {
		colour = texture(picture, region.xy + ((UV - 0.5) / zoom + 0.5) * region.zw).rgb;
	}
	float shade = mix(0.8, 0.05, smoothstep(0.15, 0.9, UV.x)) * (1.0 - 0.3 * light);
	colour = mix(colour, SHADE, shade) + 0.05 * light;
	vec2 corner = abs(UV * size - size * 0.5) - (size * 0.5 - radius);
	float distance = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
	COLOR = vec4(colour, clamp(0.5 - distance, 0.0, 1.0));
}
