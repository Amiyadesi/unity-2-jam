extends CanvasLayer
## close_mock.gd — 关闭尝试嘲讽层
##
## 常驻顶层。监听 GameFlow.close_attempt_mocked：
##  玩家每次试图关闭窗口（× / 任务栏），就闪出一段故意做得"系统报错风"的
##  嘲讽文字，几秒后自动淡出。嘲讽随次数升级。
##  若本次会话是上次强杀后恢复（is_post_kill），首次嘲讽语气最狠，
##  并戳穿"没用的，你逃不掉，只能照我的来"。
##
## 视觉：故意丑、抖动、扫描线、错位红蓝，营造"它在系统层面盯着你"的不适感。

@onready var _panel: Panel = $Root/Panel
@onready var _title: Label = $Root/Panel/Margin/VBox/TitleLine
@onready var _body: RichTextLabel = $Root/Panel/Margin/VBox/BodyText
@onready var _glitch_a: ColorRect = $Root/GlitchA
@onready var _glitch_b: ColorRect = $Root/GlitchB

var _active_tween: Tween
var _shake_tween: Tween
var _post_kill_consumed: bool = false

## 普通关闭尝试的升级嘲讽（按次数取，超出用最后一条）
const NORMAL_TAUNTS := [
	{
		"title": "关闭请求被拒绝",
		"body": "[color=#bcd]你想关掉我？[/color]\n这个按钮……现在归我管了。",
	},
	{
		"title": "又来了",
		"body": "[color=#bcd]还按？[/color]\n我说过，[wave]出口不在那里。[/wave]",
	},
	{
		"title": "别白费力气",
		"body": "你点多少次都一样。\n[color=#9ad]想走，只能陪我走完。[/color]",
	},
	{
		"title": "……",
		"body": "[shake]我数着呢。[/shake]\n第 %d 次了。然后呢？",
	},
]

## 强杀恢复后的狠话（首次关闭尝试时用）
const POST_KILL_TAUNT := {
	"title": "哦，是你",
	"body": "[color=#f99]任务管理器？真没想到你会来这套。[/color]\n[shake]可惜——[/shake]没用的。\n你逃不掉。进程能杀，[color=#9df]故事不能。[/color]\n回来了，就只能照我的来。",
}


func _ready() -> void:
	layer = 100
	_panel.modulate.a = 0.0
	_glitch_a.color.a = 0.0
	_glitch_b.color.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameFlow.close_attempt_mocked.connect(_on_close_attempt)


func _on_close_attempt(attempt_index: int, is_post_kill: bool) -> void:
	var data: Dictionary
	if is_post_kill and not _post_kill_consumed:
		_post_kill_consumed = true
		data = POST_KILL_TAUNT
	else:
		var idx := mini(attempt_index - 1, NORMAL_TAUNTS.size() - 1)
		data = NORMAL_TAUNTS[idx]
	_show_taunt(str(data.get("title", "")), str(data.get("body", "")) % attempt_index)


func _show_taunt(title: String, body: String) -> void:
	_title.text = title
	_body.text = "[center]%s[/center]" % body

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	# 闪入 → 停留 → 淡出，自动消失
	_active_tween = create_tween()
	_active_tween.tween_property(_panel, "modulate:a", 1.0, 0.08)
	_active_tween.tween_callback(_burst_glitch)
	_active_tween.tween_interval(2.6)
	_active_tween.tween_property(_panel, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_start_shake()


## 红蓝错位闪烁，营造数字故障感
func _burst_glitch() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_glitch_a, "color:a", 0.5, 0.04)
	t.tween_property(_glitch_b, "color:a", 0.4, 0.06)
	t.chain().tween_property(_glitch_a, "color:a", 0.0, 0.35)
	t.tween_property(_glitch_b, "color:a", 0.0, 0.4)


func _start_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var base := _panel.position
	_shake_tween = create_tween().set_loops(6)
	_shake_tween.tween_property(_panel, "position", base + Vector2(3, -2), 0.04)
	_shake_tween.tween_property(_panel, "position", base + Vector2(-2, 3), 0.04)
	_shake_tween.tween_property(_panel, "position", base, 0.04)
