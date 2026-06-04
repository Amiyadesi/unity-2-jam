@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 轻弹跳字效果，适合元气、撒娇、惊呼、可爱语气。
##
## 调用：`[hop]好耶！[]`
## 参数：
## - `strength`：弹跳强度，默认 `1.0`
## - `speed`：弹跳速度，默认 `2.6`
## - `spread`：字符间波峰错开幅度，默认 `0.18`
## - `angle`：弹跳方向角度，默认 `0`（向上）
## 示例：`[hop strength=1.2 speed=2.8]真的可以吗？[]`
## 自定义：
## - 想更活泼：增大 `strength`
## - 想更急促：增大 `speed`
## - 想做斜向弹跳：设置 `angle`

var bbcode := "hop"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var strength := float(c.env.get("strength", 1.0))
	var speed := float(c.env.get("speed", 2.6))
	var spread := float(c.env.get("spread", 0.18))
	var angle := deg_to_rad(float(c.env.get("angle", 0.0)))
	var font_size := get_effect_font_size()
	var wave: float = sin(-c.elapsed_time * speed * 4.0 + c.relative_index * PI * spread)
	var bounce: float = -abs(pow(wave, 3.0)) * font_size * 0.12 * strength
	c.offset.x += sin(angle) * bounce
	c.offset.y += cos(angle) * bounce
	if bounce < -font_size * 0.02:
		c.color = c.color.lerp(Color.WHITE, 0.18)
	return true
