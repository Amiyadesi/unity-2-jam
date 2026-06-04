@tool
extends RichTextEffectBase

## Syntax: [wave][]
var bbcode = "www"

func _process_custom_fx(c:CharFXTransform):
	var wave_strength: float = c.env.get("wave", 1.0)
	var frequency: float = c.env.get("freq", 1.0)
	var speed: float = c.env.get("speed", 1.0)
	var font_size := float(_get_label_font_size())
	var phase := c.elapsed_time * 8.0 * speed + c.range.x * 0.55 * frequency
	c.offset.y += sin(phase) * font_size * 0.22 * wave_strength
	c.offset.x += cos(phase * 0.5) * font_size * 0.08 * wave_strength
	return true
