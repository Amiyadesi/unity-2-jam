extends Control
## openai_note.gd — 通关后 OpenAI 外壳，只显示一张纸条。


## 启动 post-game 纸条状态并应用窗口标题。
func _ready() -> void:
	GameFlow.apply_openai_identity()
