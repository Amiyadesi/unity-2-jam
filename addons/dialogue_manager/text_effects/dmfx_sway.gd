@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 左右摇曳效果，适合醉意、风吹、轻柔尾音。
##
## 调用：`[sway]摇摇晃晃的字[]`
## 参数：
## - `amount`：摆动幅度，默认 `2.0`
## - `speed`：摆动速度，默认 `2.0`
## - `phase`：字符之间的相位差，默认 `0.35`
## 示例：`[sway amount=3.0 speed=1.5]轻轻摇曳[]`
## 自定义：可修改默认 `amount/speed/phase`，或改成基于 `c.offset.y` 的椭圆摆动。

var bbcode := "sway"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var amount := float(c.env.get("amount", 2.0))
	var speed := float(c.env.get("speed", 2.0))
	var phase := float(c.env.get("phase", 0.35))
	c.offset.x += sin(c.elapsed_time * speed + c.range.x * phase) * amount
	return true
