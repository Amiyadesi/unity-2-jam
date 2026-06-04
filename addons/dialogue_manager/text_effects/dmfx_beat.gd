@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 脉冲强调效果，适合重点词、心跳、冲击感。
##
## 调用：`[beat]重点台词[]`
## 参数：
## - `scale`：向上脉冲幅度（相对字号），默认 `0.12`
## - `speed`：脉冲速度，默认 `2.0`
## - `tint`：变亮强度，默认 `0.55`
## 示例：`[beat scale=0.2 speed=3.0 tint=0.8]危险[]`
## 自定义：
## - 想更“跳”：增大 `scale`
## - 想更亮：增大 `tint`
## - 想更急促：增大 `speed`

var bbcode := "beat"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var scale := float(c.env.get("scale", 0.12))
	var speed := float(c.env.get("speed", 2.0))
	var tint := clampf(float(c.env.get("tint", 0.55)), 0.0, 1.0)
	var pulse := pow(maxf(sin(c.elapsed_time * speed), 0.0), 2.0)
	c.offset.y -= pulse * get_effect_font_size() * scale
	c.color = c.color.lerp(Color.WHITE, pulse * tint)
	return true
