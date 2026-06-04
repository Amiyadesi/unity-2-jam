@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 幽声漂移效果，适合心声、回忆、梦境、远处传来的台词。
##
## 调用：`[ghost]像从雾里传来的声音[]`
## 参数：
## - `drift`：横向漂移幅度，默认 `1.0`
## - `speed`：漂移速度，默认 `1.1`
## - `fade`：透明度起伏，默认 `0.35`
## - `lift`：上浮幅度（相对字号），默认 `0.025`
## - `tint`：偏冷色混合强度，默认 `0.18`
## 示例：`[ghost drift=1.2 fade=0.45]我一直都记得你。[]`
## 自定义：
## - 想更虚：增大 `fade`
## - 想更飘：增大 `drift` 和 `lift`
## - 想少一点冷色：减小 `tint`

var bbcode := "ghost"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var drift := float(c.env.get("drift", 1.0))
	var speed := float(c.env.get("speed", 1.1))
	var fade := clampf(float(c.env.get("fade", 0.35)), 0.0, 0.95)
	var lift := float(c.env.get("lift", 0.025))
	var tint := clampf(float(c.env.get("tint", 0.18)), 0.0, 1.0)
	var font_size := get_effect_font_size()
	var phase := c.elapsed_time * speed * 3.0 + c.relative_index * 0.55
	var shimmer := (sin(phase * 0.6) + 1.0) * 0.5
	c.offset.x += sin(phase) * font_size * 0.018 * drift
	c.offset.y -= abs(cos(phase * 0.8)) * font_size * lift
	c.color = c.color.lerp(Color(0.86, 0.92, 1.0, c.color.a), tint)
	c.color.a *= 1.0 - fade + shimmer * fade
	return true
