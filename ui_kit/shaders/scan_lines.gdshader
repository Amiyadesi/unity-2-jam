shader_type canvas_item;
render_mode blend_add;

uniform vec4 line_color : source_color = vec4(0.96, 0.72, 0.32, 0.26);
uniform float intensity = 0.72;
uniform float scan_density = 118.0;
uniform float scan_speed = 0.11;
uniform float block_density = 19.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float scan = smoothstep(0.965, 1.0, fract(UV.y * scan_density + TIME * scan_speed));
	float block_row = floor(UV.y * block_density);
	float glitch = step(0.974, hash(block_row + floor(TIME * 3.0) * 17.0));
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float alpha = (scan * 0.55 + glitch * 0.24) * edge * intensity;
	COLOR = vec4(line_color.rgb, line_color.a * alpha);
}
