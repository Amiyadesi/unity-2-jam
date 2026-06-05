extends Control
## ending.gd — CloseAI 结局画面
##
## 通关后（closeai_finished=true）从菜单"继续"进入，或第 3 关关闭推进后再次打开进入。
## 黑屏 + 缓慢浮现的告别文字。若曾有脏关闭记录，多显示一行 AI 的话。
##
## v2 设计：结局没有按钮。文字播完后，游戏自己在几秒后退出——
## 离开的权利被收回，作为一种反转（前面一直拦着你，最后它自己走了）。

@onready var _title: Label = $EndTitle
@onready var _line1: Label = $EndLine1
@onready var _line2: Label = $EndLine2
@onready var _dirty_line: Label = $DirtyLine

func _ready() -> void:
	for n in [_title, _line1, _line2, _dirty_line]:
		n.modulate.a = 0.0
	_dirty_line.visible = GameFlow.entered_with_unclean_exit
	_play_ending()


func _play_ending() -> void:
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_title, "modulate:a", 1.0, 1.2)
	tween.tween_interval(0.6)
	tween.tween_property(_line1, "modulate:a", 0.9, 1.2)
	tween.tween_interval(0.4)
	tween.tween_property(_line2, "modulate:a", 0.9, 1.2)
	if GameFlow.entered_with_unclean_exit:
		tween.tween_interval(0.8)
		tween.tween_property(_dirty_line, "modulate:a", 0.75, 1.4)
	# 停留片刻后，游戏自己退出（离开的权利收回）
	tween.tween_interval(3.0)
	tween.tween_callback(_quit_self)


func _quit_self() -> void:
	GameFlow.self_close("ending")
