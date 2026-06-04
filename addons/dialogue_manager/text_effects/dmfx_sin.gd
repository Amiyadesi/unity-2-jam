@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 正弦浮动效果，适合梦境、空灵、回声、记忆类对白。
##
## 调用：`[sin]像漂浮一样的句子[]`
## 参数：
## - `sin`：上下浮动强度，默认 `1.0`
## - `freq`：字符间相位差，默认 `1.0`
## - `speed`：动画速度，默认 `1.0`
## 示例：`[sin sin=1.4 freq=1.6 speed=0.8]梦里见[]`
## 自定义：
## - 想整体更柔和：减小 `0.05`
## - 想整体更明显：增大 `sin` 参数或脚本中的基准振幅

var bbcode := "sin"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var amplitude := float(c.env.get("sin", 1.0))
	var frequency := float(c.env.get("freq", 1.0))
	var speed := float(c.env.get("speed", 1.0))
	var font_size := get_effect_font_size()
	c.offset.y += sin(c.elapsed_time * 12.0 * speed + c.range.x * frequency) * font_size * 0.05 * amplitude
	return true
