shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.027, 0.035, 0.075);
uniform vec3 cyan_color : source_color = vec3(0.0, 0.941, 1.0);
uniform vec3 red_color : source_color = vec3(1.0, 0.0, 0.333);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz;
	vec2 deriv = max(fwidth(coord), vec2(0.002));
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / deriv;
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);

	bool is_major = (abs(coord.x) < 0.06 || abs(coord.y) < 0.06 || abs(abs(coord.x) - 25.0) < 0.08 || abs(abs(coord.y) - 25.0) < 0.08);
	vec3 line_col = is_major ? red_color : cyan_color;
	float blend_strength = is_major ? 0.85 : 0.42;

	ALBEDO = mix(base_color, line_col, line * blend_strength);
	EMISSION = line_col * line * (is_major ? 1.1 : 0.45);
	ROUGHNESS = 0.65;
	METALLIC = 0.2;
}
