@tool
extends RichTextEffect
class_name DialogueTextEffectBase
## 通用对话文本特效基类。
##
## 作用：
## 1. 从效果实例上挂载的 `rt` 元数据中取回所属的 `DialogueLabel`
## 2. 为各个效果提供统一的字号读取入口，避免效果脚本直接依赖更重的标签实现
##
## 如果你要新增自定义效果，推荐继承这个基类，并在 `DialogueLabel.SUPPORTED_EFFECT_SCRIPTS`
## 中注册新的标签名 → 脚本路径映射。

func get_dialogue_label() -> RichTextLabel:
	if not has_meta(&"rt"):
		return null
	var label := instance_from_id(get_meta(&"rt"))
	return label if label is RichTextLabel else null


func get_effect_font_size(default_size: float = 16.0) -> float:
	var label := get_dialogue_label()
	if label == null:
		return default_size
	if label.has_method("get_effect_font_size"):
		return float(label.call("get_effect_font_size"))
	var theme_size := label.get_theme_font_size(&"normal_font_size")
	if theme_size > 0:
		return float(theme_size)
	return default_size
