@tool
extends "res://addons/dialogue_manager/text_effects/dialogue_text_effect_base.gd"
## 轻微抖动效果，适合紧张、故障、害怕等语气。
##
## 调用：`[jit2]我有点慌[]`
## 参数：
## - `scale`：抖动幅度，默认 `1.0`
## - `freq`：抖动频率，默认 `16.0`
## 示例：`[jit2 scale=1.4 freq=10]系统异常[]`
## 自定义：可直接调整脚本中的 `0.33` 或三角函数组合，做出更强或更弱的抖动。

var bbcode := "jit2"

func _process_custom_fx(c: CharFXTransform) -> bool:
	var scale := float(c.env.get("scale", 1.0))
	var frequency := float(c.env.get("freq", 16.0))
	var elapsed := c.elapsed_time
	var phase := fmod((c.relative_index + elapsed) * PI * 1.25, TAU)
	var power := sin(elapsed * frequency + c.range.x) * 0.33
	c.offset.x += sin(phase) * power * scale
	c.offset.y += cos(phase) * power * scale
	return true
