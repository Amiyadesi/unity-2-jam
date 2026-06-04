extends Control
## ending.gd — CloseAI 结局画面
##
## 通关后（closeai_finished=true）从菜单"继续"进入，或第 3 关关闭推进后再次打开进入。
## 黑屏 + 缓慢浮现的告别文字。若曾有脏关闭记录，多显示一行 AI 的话。
##
## 这是唯一一个"玩家被允许离开"的地方——AI 已经走了。
## 文字播完后浮现一个"关闭"按钮，点击 → GameFlow.self_close("ending") 真正退出。
## （玩家仍无法用窗口 × 关闭；必须通过这个按钮，由游戏替他关上最后一次。）

@onready var _title: Label = $EndTitle
@onready var _line1: Label = $EndLine1
@onready var _line2: Label = $EndLine2
@onready var _dirty_line: Label = $DirtyLine
@onready var _close_button: Button = $CloseButton

func _ready() -> void:
	_close_button.modulate.a = 0.0
	_close_button.disabled = true
	_close_button.pressed.connect(_on_close_pressed)
	for n in [_title, _line1, _line2, _dirty_line]:
		n.modulate.a = 0.0
	_dirty_line.visible = GameFlow.entered_with_unclean_exit
	_play_ending()


func _on_close_pressed() -> void:
	GameFlow.self_close("ending")


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
	# 最后浮现关闭按钮，交还"离开"的权利
	tween.tween_interval(1.0)
	tween.tween_callback(func(): _close_button.disabled = false)
	tween.tween_property(_close_button, "modulate:a", 1.0, 1.0)
