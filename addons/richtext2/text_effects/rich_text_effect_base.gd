@tool
extends RichTextEffect
class_name RichTextEffectBase

var label: RichTextLabel
const c1 := 1.70158
const c3 := c1 + .5

#func ease_back(x):
	#return c3 * x * x * x - c1 * x * x

func ease_back_in(t: float, s: float = 1.70158) -> float:
	return t * t * ((s + 1) * t - s)

func ease_back_out(t: float, s: float = 1.70158) -> float:
	t -= 1
	return t * t * ((s + 1) * t + s) + 1

func ease_back_in_out(t: float, s: float = 1.70158) -> float:
	s *= 1.525
	if t < 0.5:
		t *= 2
		return 0.5 * (t * t * ((s + 1) * t - s))
	t -= 1
	t *= 2
	return 0.5 * (t * t * ((s + 1) * t + s) + 2)

func ease_back(t: float, s: float = 1.70158) -> float:
	t -= 1
	return t * t * ((s + 1) * t + s) + 1

func get_label() -> RichTextLabel:
	if not is_instance_valid(label):
		if not has_meta(&"rt"):
			return null
		var resolved := instance_from_id(get_meta(&"rt"))
		if resolved is RichTextLabel:
			label = resolved
		else:
			label = null
	return label

func get_label2() -> RichTextLabel:
	return get_label()

func get_label_animated() -> RichTextLabel:
	return get_label()

func _get_label_font_size(default_size: int = 16) -> int:
	var lb := get_label()
	if lb == null:
		return default_size
	var custom_size := lb.get("font_size")
	if typeof(custom_size) in [TYPE_INT, TYPE_FLOAT]:
		return int(round(float(custom_size)))
	if lb.has_method("get_effect_font_size"):
		return int(round(float(lb.call("get_effect_font_size"))))
	var theme_size := lb.get_theme_font_size(&"normal_font_size")
	if theme_size > 0:
		return theme_size
	return default_size

func get_mouse_pos(c: CharFXTransform) -> Vector2:
	var lb := get_label()
	if lb == null or lb.get_tree() == null:
		return c.transform.origin
	var frame := lb.get_tree().get_frame()
	if frame != lb.get_meta(&"frame", 0):
		var mp := lb.get_local_mouse_position()
		lb.set_meta(&"mouse_position", mp)
		lb.set_meta(&"frame", frame)
		return mp
	return lb.get_meta(&"mouse_position", Vector2.ZERO)

func get_text() -> String:
	var lb := get_label()
	if lb != null:
		return lb.get_parsed_text()
	return str(get_meta(&"text", ""))

func get_char(c: CharFXTransform) -> String:
	var text := get_text()
	if c.range.x < 0 or c.range.x >= text.length():
		return ""
	return text[c.range.x]

func set_char(c: CharFXTransform, new_char: String):
	if new_char.is_empty():
		return
	var text_server := TextServerManager.get_primary_interface()
	c.glyph_index = text_server.font_get_glyph_index(c.font, _get_label_font_size(), new_char.unicode_at(0), 0)

func get_char_size(c: CharFXTransform) -> Vector2:
	var lb := get_label()
	if lb != null and lb.has_method("get_effect_character_size"):
		return lb.call("get_effect_character_size", get_char(c))
	var font: Font = null
	if lb != null:
		if lb.has_method("get_normal_font"):
			font = lb.call("get_normal_font")
		else:
			font = lb.get_theme_font(&"normal_font")
	if font == null:
		var fallback := float(_get_label_font_size())
		return Vector2(fallback, fallback)
	return font.get_string_size(get_char(c), HORIZONTAL_ALIGNMENT_LEFT, -1, _get_label_font_size())

func _get_character_random_value(index: int) -> int:
	var lb := get_label()
	if lb != null and lb.has_method("_get_character_random"):
		return int(lb.call("_get_character_random", index))
	return abs(int(hash("%s:%s" % [get_text(), index])))

func rand2(c: CharFXTransform, wrap := 1.0) -> float:
	return fmod(c.relative_index * .25 + _get_character_random_value(c.range.x) * .03, wrap)

func rand(c: CharFXTransform, wrap := 1.0) -> float:
	return fmod(c.relative_index * .25 + _get_character_random_value(c.range.x) * .01, wrap)

func rand_anim(c: CharFXTransform, anim_speed := 1.0, wrap := 1.0) -> float:
	return fmod(c.elapsed_time * anim_speed + c.relative_index * .25 + _get_character_random_value(c.range.x) * .01, wrap)

func get_rand(c: CharFXTransform) -> int:
	return _get_character_random_value(c.range.x)

# Only works for RichTextAnimation effects.
func get_animation_delta(c: CharFXTransform) -> float:
	var lb := get_label_animated()
	if lb == null or not lb.has_method("_get_character_alpha"):
		return 1.0
	return float(lb.call("_get_character_alpha", c.range.x))

func is_animation_fading_out() -> bool:
	var lb := get_label_animated()
	if lb == null:
		return false
	return bool(lb.get("fade_out"))

# Returns the last characters transformation so we can use it for end of text animations.
func send_back_transform(c: CharFXTransform):
	var lb := get_label_animated()
	if lb == null:
		return
	var transforms = lb.get("_transforms")
	var char_size = lb.get("_char_size")
	if not (transforms is Array and char_size is Array):
		return
	var index := c.relative_index
	if index > 0 and index < len(transforms):
		var ts := TextServerManager.get_primary_interface()
		var font_size := _get_label_font_size()
		var off_x := ts.font_get_glyph_size(c.font, Vector2i(font_size, 0), c.glyph_index).x
		var off_y := ts.font_get_ascent(c.font, font_size) - ts.font_get_descent(c.font, font_size)
		char_size[index] = Vector2(off_x, off_y)
		transforms[index] = c.transform
		lb.set("_char_size", char_size)
		lb.set("_transforms", transforms)
