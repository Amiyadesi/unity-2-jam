@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 静态偏移效果，适合注释、小字、耳语、错位排版。
##
## 调用：
## - `[off off=6]上浮注释[]`
## - `[off x=8 y=-3]右移并上浮[]`
## 参数：
## - `off`：单值时只影响 Y 偏移
## - `x` / `y`：分别控制水平 / 垂直偏移
## 自定义：如需更多排版能力，可在这里加入旋转、透明度或字号联动逻辑。

var bbcode := "off"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var offset_value := c.env.get("off", null)
	if offset_value != null:
		match typeof(offset_value):
			TYPE_FLOAT, TYPE_INT:
				c.offset.y += float(offset_value)
			TYPE_VECTOR2:
				c.offset += offset_value
			TYPE_ARRAY:
				if offset_value.size() >= 2:
					c.offset += Vector2(float(offset_value[0]), float(offset_value[1]))
			_:
				pass
		return true

	var x := float(c.env.get("x", 0.0))
	var y := float(c.env.get("y", 0.0))
	c.offset += Vector2(x, y)
	return true
