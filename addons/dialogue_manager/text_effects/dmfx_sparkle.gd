@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 闪烁发光效果。
##
## 调用：`[sparkle]需要强调的文字[]`
## 参数：无（如需更强/更弱效果，请直接调整脚本中的色相与亮度振幅）。
## 自定义：
## - 修改 `4.0` 可改变闪烁速度
## - 修改 `.033` / `.25` 可改变色相与亮度波动强度

var bbcode := "sparkle"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var saturation_gap := 1.0 - c.color.s
	c.color.h = wrapf(c.color.h + sin(-c.elapsed_time * 4.0 + c.glyph_index * 2.0) * saturation_gap * 0.033, 0.0, 1.0)
	c.color.v = clampf(c.color.v + sin(c.elapsed_time * 4.0 + c.glyph_index) * 0.25, 0.0, 1.0)
	return true
