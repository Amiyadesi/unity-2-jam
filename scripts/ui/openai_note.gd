extends Control
## openai_note.gd — 通关后 OpenAI 外壳，只显示一张纸条。

@onready var _paper: PanelContainer = $Paper

var _dropped: bool = false


## 启动 post-game 纸条状态并应用窗口标题。
func _ready() -> void:
	GameFlow.apply_openai_identity()
	_paper.gui_input.connect(_on_paper_gui_input)


## 点击纸条后让它脱落，不进入任何游戏内容。
func _on_paper_gui_input(event: InputEvent) -> void:
	if _dropped:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drop_paper()


## 播放纸条向下脱落的 authored 节点动画。
func _drop_paper() -> void:
	_dropped = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport_height := get_viewport_rect().size.y
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_paper, "position:y", viewport_height + 80.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_paper, "rotation", 0.22, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_paper, "modulate:a", 0.0, 0.9)
