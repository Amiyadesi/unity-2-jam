@tool
extends RichTextEffectBase

## Syntax: [focus color][]
var bbcode = "focus"

func _process_custom_fx(c: CharFXTransform):
	var t := get_label_animated()
	var a := 1.0 - get_animation_delta(c)
	var scale = c.env.get("scale", 1.0)
	
	c.color.s = lerp(c.color.s, 0.0, a)
	c.color.a = lerp(c.color.a, 0.0, a)
	var text: String = get_text()
	var r = hash(text[c.range.x]) * 33.33 + c.range.x * 4545.5454 * TAU
	var spread := float(t.get("font_size")) if t != null else 16.0
	c.offset += Vector2(cos(r), sin(r)) * spread * scale * (a * a)
	send_back_transform(c)
	return true
