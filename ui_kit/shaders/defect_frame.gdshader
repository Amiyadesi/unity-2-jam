shader_type canvas_item;
render_mode blend_add;

uniform vec4 frame_color : source_color = vec4(0.98, 0.78, 0.42, 0.46);
uniform float intensity = 0.72;
uniform float border_width = 0.012;
uniform float gap_density = 22.0;

void fragment() {
	float d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge = 1.0 - smoothstep(border_width, border_width + 0.006, d);
	float dash = smoothstep(0.18, 0.96, fract((UV.x + UV.y * 0.7) * gap_density + TIME * 0.18));
	float pulse = 0.74 + sin(TIME * 1.7 + UV.y * 11.0) * 0.12;
	COLOR = vec4(frame_color.rgb, frame_color.a * edge * dash * pulse * intensity);
}
