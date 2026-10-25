shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel_position = UV * resolution;
	float cell_size = 110.0;
	float row = floor(pixel_position.y / cell_size);
	float stagger = mod(row, 2.0) * cell_size * 0.5;
	float slant = pixel_position.y * 0.1;
	vec2 local_position = vec2(
		mod(pixel_position.x + stagger + slant, cell_size),
		mod(pixel_position.y, cell_size)
	) - vec2(cell_size * 0.5);

	float reveal_at_column = clamp(reveal * 1.45 - UV.x * 0.4, 0.0, 1.0);
	float radius = cell_size * 0.38 * reveal_at_column;
	vec2 dot_position = vec2(local_position.x * 0.9, local_position.y);
	float inner_radius = max(radius - 1.8, 0.0);
	float outer_radius = radius + 1.8;
	float circle = 1.0 - smoothstep(
		inner_radius * inner_radius,
		outer_radius * outer_radius,
		dot(dot_position, dot_position)
	);
	circle *= smoothstep(0.0, 0.08, reveal_at_column);

	vec3 background_color = mix(vec3(0.86, 0.89, 0.88), vec3(0.9, 0.9, 0.9), UV.x);
	vec3 dot_color = mix(
		vec3(0.02, 0.61, 0.78),
		vec3(0.69, 0.82, 0.56),
		smoothstep(0.0, 0.9, UV.x)
	);
	vec3 pattern_color = mix(background_color, dot_color, circle);
	float fade_to_white = smoothstep(0.52, 0.98, UV.x);
	COLOR = vec4(mix(pattern_color, vec3(1.0), fade_to_white), 1.0);
}
