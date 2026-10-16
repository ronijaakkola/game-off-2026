// Full-screen cross stitch, for the cross-stitch style.
//
// Put a 2x2 QuadMesh under the camera with this material. The screen becomes a sheet of aida
// cloth, a grid of square cells fixed to the screen. Every cell reads the scene under it once
// (the average light of a few taps, plus a depth test against its four neighbours) and decides
// what to stitch: nothing, a light thread, or a dark thread. A stitched cell is drawn as an X.
//
// Bands, from light to dark: cloth, half-filled light thread (a checkerboard of cells), filled
// light thread, dark thread. Silhouettes and the darkest tones are dark thread.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 cloth_color : source_color = vec4(0.965, 0.965, 0.955, 1.0);
uniform vec4 hole_color : source_color = vec4(0.78, 0.8, 0.84, 1.0);
uniform vec4 dark_thread : source_color = vec4(0.17, 0.27, 0.62, 1.0);
uniform vec4 light_thread : source_color = vec4(0.52, 0.6, 0.82, 1.0);

// Cells from the top of the screen to the bottom. The cell size is rounded to whole pixels, so
// stitches stay crisp at any window size and pixel ratio.
uniform float rows : hint_range(30.0, 240.0) = 80.0;

// Tone cut-offs on the scene's brightness (0 to 1, as it is on screen). Brighter than half_fill
// is bare cloth.
uniform float half_fill : hint_range(0.0, 1.0) = 0.8;
uniform float full_fill : hint_range(0.0, 1.0) = 0.7;
uniform float dark_fill : hint_range(0.0, 1.0) = 0.4;

// How far the tone taps spread, in cells. 1 stays inside the cell; more blends in the
// neighbours, which calms single-cell flicker from small details but softens edges.
uniform float tone_spread : hint_range(0.5, 3.0) = 1.0;

// How sharply a cell has to stand out from its farther-away neighbours to get a dark outline
// stitch. Higher keeps only the strongest silhouettes.
uniform float edge_threshold : hint_range(0.01, 1.0) = 0.12;
// No outlines beyond this distance in metres, so the far horizon doesn't get a stitched line.
uniform float edge_max_depth : hint_range(1.0, 200.0) = 40.0;

// Half the width of a strand, in cells.
uniform float strand : hint_range(0.04, 0.3) = 0.13;
// How much each cell's thread varies in brightness, so the work looks hand-made.
uniform float thread_variation : hint_range(0.0, 0.3) = 0.06;

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return -v.z / v.w;
}

float brightness(vec2 uv) {
	return dot(texture(screen_tex, uv).rgb, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 1 inside a thick line segment from a to b, antialiased over aa (in cells).
float capsule(vec2 p, vec2 a, vec2 b, float radius, float aa) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return 1.0 - smoothstep(radius - aa, radius + aa, length(p - a - ab * t));
}

void vertex() {
	// Cover the whole screen whatever the transform is; z 0 is inside both depth ranges.
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	vec2 size = VIEWPORT_SIZE;
	float cell = max(round(size.y / rows), 3.0);
	// The grid is centred on the screen, so its partial cells sit evenly at the borders.
	vec2 origin = (size - cell) * 0.5;
	vec2 g = (SCREEN_UV * size - origin) / cell;
	vec2 id = floor(g);
	vec2 p = g - id;
	vec2 center_uv = (origin + (id + 0.5) * cell) / size;
	vec2 step_uv = vec2(cell) / size;

	// Brightness of the scene under this cell: nine taps over its area.
	float tone = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			tone += brightness(center_uv + vec2(float(i), float(j)) * step_uv * tone_spread / 3.0);
		}
	}
	tone /= 9.0;

	// Outline: a cell that is nearer than a neighbour gets a stitch. 1/depth is a straight
	// line across a flat surface, so the second difference of it is 0 there, and negative
	// where a neighbour drops away behind this cell.
	mat4 inv_proj = INV_PROJECTION_MATRIX;
	float c = view_depth(center_uv, inv_proj);
	float ic = 1.0 / c;
	float lap_x = 1.0 / view_depth(center_uv - vec2(step_uv.x, 0.0), inv_proj)
			+ 1.0 / view_depth(center_uv + vec2(step_uv.x, 0.0), inv_proj) - 2.0 * ic;
	float lap_y = 1.0 / view_depth(center_uv - vec2(0.0, step_uv.y), inv_proj)
			+ 1.0 / view_depth(center_uv + vec2(0.0, step_uv.y), inv_proj) - 2.0 * ic;
	float edge = -min(min(lap_x, lap_y), 0.0) / ic;
	bool outline = edge > edge_threshold && c < edge_max_depth;

	// What to stitch in this cell: 0 nothing, 1 light thread, 2 dark thread.
	float checker = mod(id.x + id.y, 2.0);
	int thread = 0;
	if (outline || tone < dark_fill) {
		thread = 2;
	} else if (tone < full_fill) {
		thread = 1;
	} else if (tone < half_fill && checker < 0.5) {
		thread = 1;
	}

	// Cloth: a faint line along each cell border and a hole at each corner.
	vec3 col = cloth_color.rgb;
	float aa = 0.75 / cell;
	vec2 to_edge = min(p, 1.0 - p);
	col = mix(col, hole_color.rgb, 0.08 * (1.0 - smoothstep(0.0, 0.1, min(to_edge.x, to_edge.y))));
	float hole = 1.0 - smoothstep(0.1 - aa, 0.1 + aa, length(to_edge));
	col = mix(col, hole_color.rgb, hole * 0.8);

	if (thread > 0) {
		vec3 base = thread == 2 ? dark_thread.rgb : light_thread.rgb;
		base *= 1.0 + (hash(id) - 0.5) * 2.0 * thread_variation;
		// Two strands cross corner to corner. The second lies over the first.
		float under = capsule(p, vec2(0.12, 0.12), vec2(0.88, 0.88), strand, aa);
		float over = capsule(p, vec2(0.12, 0.88), vec2(0.88, 0.12), strand, aa);
		col = mix(col, base * 0.82, under);
		col = mix(col, base, over);
	}

	ALBEDO = col;
	ALPHA = 1.0;
}
