shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// The field's grid drawn as drifting smoke on a flat plane: soft lines on the cell edges
// that wobble and thin out with noise, fade out past the field's edge, and a faint glow
// over the ship's row and column and the line being dragged.
// Additive and unshaded, so it only adds light over the space sky behind it.
// The plane is centred on the field; positions are in grid units, 0 to cells on each axis.

uniform float cells = 8.0;
uniform float cell_size = 1.0;
uniform vec3 line_color : source_color = vec3(0.42, 0.66, 1.0);
uniform float line_strength : hint_range(0.0, 2.0) = 0.42;
// Half-width of a line, in cells, before the smoke thickens or thins it.
uniform float line_width : hint_range(0.005, 0.2) = 0.026;
// How far the smoke bends a line off its cell edge, in cells.
uniform float wobble : hint_range(0.0, 0.3) = 0.045;
uniform float smoke_scale = 0.9;
// How fast the large swirls that bend the lines drift, in grid units per second.
uniform float smoke_speed = 0.1;
// How fast the dense and thin stretches flow along the lines.
uniform float wisp_speed = 0.35;
// A slow ripple along each line, in cells, so the lines breathe even where the smoke is still.
uniform float sway : hint_range(0.0, 0.05) = 0.012;
uniform float sway_speed = 0.7;
uniform vec3 lane_color : source_color = vec3(0.3, 0.5, 0.9);
uniform float lane_strength : hint_range(0.0, 1.0) = 0.14;
uniform float drag_strength : hint_range(0.0, 1.0) = 0.22;
// The ship's cell (column, row). Its row and column glow.
uniform vec2 ship_cell = vec2(-100.0);
// x: 1 while a line is dragged, y: 1 for a row, 0 for a column, z: its index.
uniform vec3 drag_line = vec3(0.0);

varying vec3 world_position;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * value_noise(p);
		// Rotate each octave so the value noise's lattice doesn't line up with the grid.
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.02;
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = world_position.xz / cell_size + cells * 0.5;
	vec2 drift = vec2(TIME * smoke_speed, -TIME * smoke_speed * 0.7);
	// Slow, large swirls bend the lines and set their thickness; finer wisps break them up.
	float smoke = fbm(grid * smoke_scale + drift);
	float swirl = fbm(grid * smoke_scale + drift * 0.8 + 3.1);
	vec2 flow = vec2(-TIME * wisp_speed, TIME * wisp_speed * 0.8);
	float wisps = fbm(grid * smoke_scale * 1.8 + flow + 7.3);

	// Distance to the nearest cell edge, after the smoke bends it and the ripple sways it.
	vec2 bent = grid + (vec2(smoke, swirl) - 0.5) * 2.0 * wobble;
	bent += sway * vec2(
			sin(grid.y * 2.1 + TIME * sway_speed),
			sin(grid.x * 2.3 - TIME * sway_speed * 1.1));
	vec2 to_edge = abs(fract(bent + 0.5) - 0.5);
	float distance_to_line = min(to_edge.x, to_edge.y);
	float width = line_width * (0.5 + smoke);
	float line = exp(-pow(distance_to_line / width, 2.0));
	// Patchy: some stretches of line are dense smoke, others nearly gone.
	line *= 0.25 + 0.75 * smoothstep(0.25, 0.7, wisps);
	// A wide, faint haze around each line, so it reads as smoke rather than a stroke.
	line += 0.12 * exp(-pow(distance_to_line / (width * 5.0), 2.0)) * smoothstep(0.3, 0.8, smoke);

	// Fade out past the field's edge, into open space.
	vec2 from_centre = abs(grid - cells * 0.5);
	float past_edge = max(from_centre.x, from_centre.y) - cells * 0.5;
	float fade = 1.0 - smoothstep(-0.2, 0.45, past_edge);

	vec3 colour = line_color * line * line_strength;

	vec2 cell = floor(grid);
	bool inside = past_edge < 0.0;
	bool lane = inside && (cell.x == ship_cell.x || cell.y == ship_cell.y);
	bool dragged = inside && drag_line.x > 0.5
			&& ((drag_line.y > 0.5 && cell.y == drag_line.z) || (drag_line.y < 0.5 && cell.x == drag_line.z));
	if (dragged) {
		colour += lane_color * drag_strength * (0.5 + smoke);
	} else if (lane) {
		colour += lane_color * lane_strength * (0.5 + smoke);
	}

	// No debanding on the web: dither one 8-bit step.
	colour += (hash12(FRAGCOORD.xy) - 0.5) / 255.0;
	ALBEDO = max(colour * fade, vec3(0.0));
}
