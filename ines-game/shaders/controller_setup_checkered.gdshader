shader_type canvas_item;

void fragment() {
	vec2 pixel_position = UV / SCREEN_PIXEL_SIZE;
	pixel_position.x += TIME * 2.0;
	vec2 grid = pixel_position / 220.0;
	vec2 tile = floor(grid);
	vec2 local_position = fract(grid);
	float tile_x = mod(tile.x, 2.0);
	float tile_y = mod(tile.y, 2.0);
	float x_pattern = mix(
		1.0 - 2.0 * mod(tile.x + 1.0, 2.0),
		1.0 - 2.0 * tile_x,
		smoothstep(0.0, 0.08, local_position.x)
	);
	float y_pattern = mix(
		1.0 - 2.0 * mod(tile.y + 1.0, 2.0),
		1.0 - 2.0 * tile_y,
		smoothstep(0.0, 0.08, local_position.y)
	);
	float checker = 0.5 + 0.5 * x_pattern * y_pattern;
	vec3 cyan = vec3(0.43, 0.81, 0.88);
	vec3 pale = vec3(0.72, 0.88, 0.81);
	vec3 color = mix(pale, cyan, checker);
	float shimmer = (0.5 + 0.5 * sin(TIME * 0.18 + UV.x * 2.0)) * 0.025;
	COLOR = vec4(mix(color, vec3(1.0), shimmer), 1.0);
}
