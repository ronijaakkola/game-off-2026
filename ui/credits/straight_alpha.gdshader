shader_type canvas_item;
// Shows a see-through viewport's render, whose colours come multiplied by their alpha, with
// plain blending: a photo drawn that way fades with what it sits in, where one drawn with
// premultiplied blending keeps its full colour and flashes white.

void fragment() {
	vec4 render = texture(TEXTURE, UV);
	// COLOR comes in as the render times what the photo sits in fades it by, so its alpha is
	// kept: writing the render's own alpha would leave the photo whole while the rest fades.
	COLOR = vec4(render.rgb / max(render.a, 0.001), COLOR.a);
}
