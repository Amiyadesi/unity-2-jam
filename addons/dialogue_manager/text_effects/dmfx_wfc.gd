@tool
extends RichTextEffectBase
## 乱码收敛效果，适合终端、解码、故障文本。
##
## 调用：`[wfc]系统文本[]`
## 参数：
## - `speed`：字符跳变速度，默认 `10`
## - `noise`：乱码持续强度，默认 `1.0`
## - `dim`：乱码阶段压暗幅度，默认 `0.45`
## - `glyphs`：乱码字符池，默认 `"01"`
## 示例：`[wfc speed=14 noise=1.3 dim=0.3]BOOT[]`

var bbcode := "wfc"

const SPACE := " "
const DEFAULT_GLYPHS := "01"


func _process_custom_fx(c: CharFXTransform) -> bool:
	var animation_alpha := get_animation_delta(c)
	var speed := maxf(float(c.env.get("speed", 10.0)), 0.1)
	var noise := maxf(float(c.env.get("noise", 1.0)), 0.0)
	var dim := clampf(float(c.env.get("dim", 0.45)), 0.0, 1.0)
	var glyphs := str(c.env.get("glyphs", DEFAULT_GLYPHS))
	if glyphs.is_empty():
		glyphs = DEFAULT_GLYPHS

	var scramble_gate := clampf(animation_alpha + rand2(c) * noise, 0.0, 2.0)
	if scramble_gate < 1.0 and get_char(c) != SPACE:
		var glyph_index := int(floor(rand_anim(c, speed, float(glyphs.length())))) % glyphs.length()
		set_char(c, glyphs[glyph_index])
		c.color = c.color.lerp(Color.BLACK, dim)

	c.color.a *= animation_alpha
	send_back_transform(c)
	return true
