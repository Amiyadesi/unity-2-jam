extends CanvasLayer
## ai_hud.gd — AI 字幕与"关闭提示"显示层（反转版）
##
## 关卡内 AI 的存在感载体（AI 是光点/文字框，无人形）：
##  - 底部字幕条：显示 AI 的短句（show_line）
##  - "关闭时刻"提示：当 GameFlow 发出 close_moment_ready，呼吸式显示
##    "它正在关闭这里……"——告诉玩家：这次是游戏自己在关，不是玩家。
##
## 注意：玩家自己永远关不掉窗口（被全局嘲讽层拦截）。这里的提示只用于
## "游戏自我关闭"的剧情节点表现。

@onready var _subtitle: Label = $SubtitlePanel/Subtitle
@onready var _subtitle_panel: Panel = $SubtitlePanel
@onready var _close_hint: Label = $CloseHint

var _close_hint_tween: Tween

func _ready() -> void:
	_subtitle_panel.modulate.a = 0.0
	_close_hint.modulate.a = 0.0
	if GameFlow.has_signal("close_moment_ready"):
		GameFlow.close_moment_ready.connect(_on_close_moment_ready)


## 显示一行 AI 字幕，hold 秒后自动淡出（hold<=0 则常驻）
func show_line(text: String, hold: float = 3.0) -> void:
	_subtitle.text = text
	var tween := create_tween()
	tween.tween_property(_subtitle_panel, "modulate:a", 1.0, 0.25)
	if hold > 0.0:
		tween.tween_interval(hold)
		tween.tween_property(_subtitle_panel, "modulate:a", 0.0, 0.4)


func hide_line() -> void:
	var tween := create_tween()
	tween.tween_property(_subtitle_panel, "modulate:a", 0.0, 0.3)


# ──────────────────────────────────────────────
# 关闭时刻提示
# ──────────────────────────────────────────────

## 游戏即将自我关闭：呼吸式提示
func _on_close_moment_ready(_stage_index: int) -> void:
	_close_hint.text = "它正在关闭这里……"
	if _close_hint_tween != null and _close_hint_tween.is_valid():
		_close_hint_tween.kill()
	_close_hint_tween = create_tween().set_loops()
	_close_hint_tween.tween_property(_close_hint, "modulate:a", 0.9, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_close_hint_tween.tween_property(_close_hint, "modulate:a", 0.35, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
