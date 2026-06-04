@tool
extends RichTextEffectBase

# Syntax: [jump angle=45 scale=1.0][]
var bbcode = "jump"

const SPLITTERS := " .,!?-，。！？、"

var _word_anchor := 0
var _last_index := -1

func _process_custom_fx(c: CharFXTransform):
	var text := get_text()
	var current_char := get_char(c)
	if c.range.x < _last_index or current_char in SPLITTERS:
		_word_anchor = c.range.x
	elif c.range.x > 0 and text[c.range.x - 1] in SPLITTERS:
		_word_anchor = c.range.x
	_last_index = c.range.x
	var angle := deg_to_rad(float(c.env.get("angle", 0.0)))
	var strength := float(c.env.get("scale", 1.0))
	var font_size := float(_get_label_font_size())
	var bounce: float = -abs(sin(-c.elapsed_time * 6.0 + _word_anchor * PI * 0.025))
	bounce *= strength * font_size * 0.125
	c.offset.x += sin(angle) * bounce
	c.offset.y += cos(angle) * bounce
	return true
