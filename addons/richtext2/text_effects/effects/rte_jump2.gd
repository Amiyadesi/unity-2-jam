@tool
extends RichTextEffectBase

## Syntax: [jump2 angle=45][]
var bbcode = "jump2"

func _process_custom_fx(c: CharFXTransform):
	var a := deg_to_rad(float(c.env.get("angle", 0.0)))
	var s := sin(-c.elapsed_time * 4.0 + c.relative_index * PI * .125)
	s = -abs(pow(s, 4.0)) * 2.0
	s *= float(c.env.get("size", 1.0)) * float(_get_label_font_size()) * 0.125
	c.offset.x += sin(a) * s
	c.offset.y += cos(a) * s
	return true
