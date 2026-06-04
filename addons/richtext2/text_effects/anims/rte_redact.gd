@tool
extends RichTextEffectBase

# Syntax: [redact freq wave][]
var bbcode = "redact"

const SPACE := " "
const BLOCK := "█"
const MID_BLOCK := "▓"

func _process_custom_fx(c: CharFXTransform):
	var a := get_animation_delta(c)
	if get_char(c) != SPACE or c.relative_index % 2 == 0:
		var freq: float = c.env.get("freq", 1.0)
		var scale: float = c.env.get("scale", 1.0)
		var glitch := abs(sin(c.elapsed_time * 10.0 * freq + c.range.x * 0.75))
		set_char(c, MID_BLOCK if glitch < 0.45 else BLOCK)
		c.color = Color(0.0, 0.0, 0.0, maxf(a, 0.25))
		c.offset.y += sin(c.range.x * freq + c.elapsed_time * 3.0) * scale
	else:
		c.color.a *= a
	send_back_transform(c)
	return true
