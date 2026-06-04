extends CanvasLayer
## ai_hud.gd — AI 信息流（toast 限时通知 + hint 常驻提示 + 关闭时刻提示）
##
## 固定模板原则：所有显示元素都是场景里已摆好的固定节点，脚本只控制其文本/可见/动画，
## 不在脚本里 new 控件。金棕玻璃风，和设置/暂停统一基调。
##
## - show_toast(text, secs)：底部短句限时淡出（AI 旁白/嘲讽）
## - show_hint(text) / hide_hint()：常驻状态提示（如"按 E 互动"）
## - 关闭时刻：监听 GameFlow.close_moment_ready，呼吸式提示"它正在关闭这里……"
##
## 玩家自己永远关不掉窗口（全局嘲讽层拦截）；这里只服务剧情节点表现。

@onready var _toast_panel: Panel = $ToastPanel
@onready var _toast_label: RichTextLabel = $ToastPanel/Margin/ToastText
@onready var _hint_panel: Panel = $HintPanel
@onready var _hint_label: RichTextLabel = $HintPanel/Margin/HintText
@onready var _close_hint: Label = $CloseHint

var _toast_tween: Tween
var _close_hint_tween: Tween


func _ready() -> void:
	_toast_panel.modulate.a = 0.0
	_hint_panel.modulate.a = 0.0
	_close_hint.modulate.a = 0.0
	if GameFlow.has_signal("close_moment_ready"):
		GameFlow.close_moment_ready.connect(_on_close_moment_ready)


# ── Toast：限时旁白 ──

## 兼容旧调用名
func show_line(text: String, hold: float = 3.0) -> void:
	show_toast(text, hold)

func show_toast(text: String, hold: float = 3.0) -> void:
	_toast_label.text = "[center]%s[/center]" % text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
	if hold > 0.0:
		_toast_tween.tween_interval(hold)
		_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.4)

func hide_line() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	create_tween().tween_property(_toast_panel, "modulate:a", 0.0, 0.3)


# ── Hint：常驻提示 ──

func show_hint(text: String) -> void:
	_hint_label.text = text
	create_tween().tween_property(_hint_panel, "modulate:a", 1.0, 0.25)

func hide_hint() -> void:
	create_tween().tween_property(_hint_panel, "modulate:a", 0.0, 0.3)


# ── 关闭时刻提示 ──

func _on_close_moment_ready(_stage_index: int) -> void:
	_close_hint.text = "它正在关闭这里……"
	if _close_hint_tween != null and _close_hint_tween.is_valid():
		_close_hint_tween.kill()
	_close_hint_tween = create_tween().set_loops()
	_close_hint_tween.tween_property(_close_hint, "modulate:a", 0.9, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_close_hint_tween.tween_property(_close_hint, "modulate:a", 0.35, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
