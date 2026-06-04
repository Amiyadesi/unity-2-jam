@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 轻呼吸效果，适合轻声、迟疑、温柔对白。
##
## 调用：`[breathe]慢一点说……[]`
## 参数：
## - `depth`：起伏幅度（相对字号），默认 `0.03`
## - `speed`：呼吸速度，默认 `1.6`
## - `glow`：提亮强度，默认 `0.18`
## - `fade`：透明度波动，默认 `0.08`
## 示例：`[breathe depth=0.04 speed=1.4 glow=0.22]我会慢慢告诉你。[]`
## 自定义：
## - 想更轻柔：减小 `depth` 和 `glow`
## - 想更明显：增大 `depth`
## - 想更绵长：减小 `speed`

var bbcode := "breathe"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var depth := float(c.env.get("depth", 0.03))
	var speed := float(c.env.get("speed", 1.6))
	var glow := clampf(float(c.env.get("glow", 0.18)), 0.0, 1.0)
	var fade := clampf(float(c.env.get("fade", 0.08)), 0.0, 0.9)
	var phase := c.elapsed_time * speed * 2.4 + c.relative_index * 0.18
	var breath := (sin(phase) + 1.0) * 0.5
	var alpha_scale := 1.0 - fade + breath * fade
	c.offset.y -= breath * get_effect_font_size() * depth
	c.color = c.color.lerp(Color.WHITE, breath * glow)
	c.color.a *= alpha_scale
	return true
