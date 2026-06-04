@tool
extends RichTextEffectBase
## 鼠标靠近时才显形的隐藏文本。
##
## 调用：`[secret]隐藏文本[]`
## 参数：
## - `radius`：完全显形半径，默认 `22`
## - `softness`：从可见到不可见的过渡带，默认 `10`
## - `min_alpha`：隐藏时最低透明度，默认 `0.0`
## - `max_alpha`：显形时最高透明度，默认 `1.0`
## 示例：`[secret radius=14 softness=6]更难发现的文字[]`

var bbcode := "secret"


func _process_custom_fx(c: CharFXTransform) -> bool:
	var radius := maxf(float(c.env.get("radius", 22.0)), 1.0)
	var softness := maxf(float(c.env.get("softness", 10.0)), 0.001)
	var min_alpha := clampf(float(c.env.get("min_alpha", 0.0)), 0.0, 1.0)
	var max_alpha := clampf(float(c.env.get("max_alpha", 1.0)), min_alpha, 1.0)
	var distance := c.transform.origin.distance_to(get_mouse_pos(c))
	var reveal := 1.0 - smoothstep(radius, radius + softness, distance)
	c.color.a = lerpf(min_alpha, max_alpha, reveal)
	return true
