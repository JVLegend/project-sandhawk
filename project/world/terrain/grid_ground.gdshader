shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.42, 0.42, 0.42, 1.0);
uniform vec4 line_color : source_color = vec4(0.82, 0.82, 0.82, 1.0);
uniform float minor_grid_density = 20.0;
uniform float major_grid_density = 4.0;

float grid_line(vec2 coord) {
	vec2 wrapped = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord), vec2(0.0001));
	return 1.0 - min(min(wrapped.x, wrapped.y), 1.0);
}

void fragment() {
	vec2 world_uv = UV * minor_grid_density;
	float minor_line = grid_line(world_uv);
	float major_line = grid_line(UV * major_grid_density);
	float grid_mix = clamp(minor_line * 0.18 + major_line * 0.5, 0.0, 1.0);

	ALBEDO = mix(base_color.rgb, line_color.rgb, grid_mix);
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
