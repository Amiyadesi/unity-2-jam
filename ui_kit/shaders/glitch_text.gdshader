shader_type canvas_item;
// glitch_text.gdshader — 元游戏故障风文字效果（用于标题）。
// 作用在带文字的 Label/TextureRect 上：RGB 分离 + 扫描线 + 偶发水平错位 + 紫色辉光底。
// 文字本身保持引擎渲染（清晰、不糊），故障只是叠加扰动。

uniform vec4 glow_color : source_color = vec4(0.486, 0.357, 1.0, 1.0); // #7c5cff
uniform float rgb_split : hint_range(0.0, 0.02) = 0.004;
uniform float scan_strength : hint_range(0.0, 1.0) = 0.18;
uniform float scan_density = 320.0;
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.5; // 错位强度
uniform float glitch_rate : hint_range(0.5, 12.0) = 3.0; // 每秒刷新几次错位块
uniform float glow_strength : hint_range(0.0, 3.0) = 1.1;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
	vec2 uv = UV;

	// 偶发水平错位：按时间分块，随机某些横条左右抖动
	float block = floor(uv.y * 28.0);
	float t = floor(TIME * glitch_rate);
	float jitter = hash(block + t * 13.0);
	float do_glitch = step(1.0 - glitch_amount * 0.18, jitter);
	uv.x += (jitter - 0.5) * 0.06 * do_glitch;

	// RGB 分离采样
	float ca = rgb_split * (0.6 + 0.8 * do_glitch);
	float r = texture(TEXTURE, uv + vec2(ca, 0.0)).a;
	float g = texture(TEXTURE, uv).a;
	float b = texture(TEXTURE, uv - vec2(ca, 0.0)).a;
	float a = max(r, max(g, b));

	// 基础字色（近白）+ 通道偏移染色
	vec3 col = vec3(0.92, 0.93, 0.97);
	col.r *= 0.7 + 0.3 * r / max(a, 0.001);
	col.b *= 0.7 + 0.3 * b / max(a, 0.001);

	// 紫色辉光：取文字 alpha 的邻域扩散
	float glow = 0.0;
	glow += texture(TEXTURE, uv + vec2(0.006, 0.0)).a;
	glow += texture(TEXTURE, uv - vec2(0.006, 0.0)).a;
	glow += texture(TEXTURE, uv + vec2(0.0, 0.008)).a;
	glow += texture(TEXTURE, uv - vec2(0.0, 0.008)).a;
	glow *= 0.25 * glow_strength;

	// 扫描线
	float scan = 1.0 - scan_strength * (0.5 + 0.5 * sin(uv.y * scan_density));

	vec3 out_rgb = col * scan;
	float out_a = a;
	// 把辉光加到边缘（文字外的微弱紫光）
	vec3 final_rgb = mix(glow_color.rgb, out_rgb, a);
	float final_a = max(out_a, glow * glow_color.a * (1.0 - a));

	COLOR = vec4(final_rgb, final_a) * COLOR.a;
}
