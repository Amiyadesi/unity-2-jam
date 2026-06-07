extends Node2D
class_name StageBase
## stage_base.gd — CloseAI 关卡基类（反转版）
##
## 所有关卡共享的"关闭时刻"编排。子类只需：
##  - 在场景里摆好平台、Player、CloseMomentTrigger(Area2D)
##  - 通过导出变量设定本关编号
##  - 可重写 _on_stage_ready() 做关卡专属逻辑（谜题、战斗）
##
## 标准流程：
##  enter:
##    1. 冻结玩家
##    2. 若上次脏关闭/强杀恢复 → 先播 dirty_return 台词（被嘲讽过的玩家回来）
##    3. 播放 start 问候对话
##    4. 解冻，玩家自由探索/解谜/战斗
##  玩家抵达 CloseMomentTrigger 或子类主动触发:
##    5. 冻结玩家，播放 close_moment 对话
##    6. 显示场景内 CloseButton，等待玩家亲手按下
##    7. 调 GameFlow.reach_close_moment(stage_index)：推进进度 + 干净退出
##
## 关卡"完成" = 玩家在游戏内按下关闭按钮。系统窗口关闭仍会被拦截。

@export var stage_index: int = 1
@export var play_intro_dialogue: bool = true
@export var stage_music: AudioStream = null

@onready var _player: CloseAIPlayer = $Player
@onready var _close_trigger: Area2D = get_node_or_null("CloseMomentTrigger")
@onready var _pause_screen: Control = get_node_or_null("PauseLayer/PauseScreen")
@onready var _close_moment_layer: CanvasLayer = get_node_or_null("CloseMomentLayer")
@onready var _close_button: Button = get_node_or_null("CloseMomentLayer/CloseButton")
@onready var _close_curtain: CanvasItem = get_node_or_null("CloseMomentLayer/CloseCurtain")
@onready var _close_shutter_top: CanvasItem = get_node_or_null("CloseMomentLayer/CloseShutterTop")
@onready var _close_shutter_bottom: CanvasItem = get_node_or_null("CloseMomentLayer/CloseShutterBottom")
@onready var _close_scanline: CanvasItem = get_node_or_null("CloseMomentLayer/CloseScanLine")

var _close_moment_started: bool = false
var _stage_active: bool = false
var _close_button_pressed: bool = false


## 初始化 authored 关卡节点并启动入场流程。
func _ready() -> void:
	if not _require_authored_stage_nodes():
		return
	if is_instance_valid(_player):
		_player.set_frozen(true)
	if _close_trigger != null:
		_close_trigger.body_entered.connect(_on_close_trigger_entered)
	if _close_button != null:
		_close_button.pressed.connect(_on_close_button_pressed)
		_close_button.disabled = true
	if _close_moment_layer != null:
		_close_moment_layer.hide()
	_reset_close_animation_nodes()
	GameFlow.set_current_stage(stage_index)
	_run_enter_sequence.call_deferred()


## 校验每个关卡必须 authored 的共享 UI 节点。
func _require_authored_stage_nodes() -> bool:
	var ok := true
	if _pause_screen == null:
		push_error("%s requires authored PauseLayer/PauseScreen." % name)
		ok = false
	if _close_moment_layer == null:
		push_error("%s requires authored CloseMomentLayer." % name)
		ok = false
	if _close_button == null:
		push_error("%s requires authored CloseMomentLayer/CloseButton." % name)
		ok = false
	if _close_curtain == null or _close_shutter_top == null or _close_shutter_bottom == null or _close_scanline == null:
		push_error("%s requires authored CloseMomentLayer close animation nodes." % name)
		ok = false
	if _player == null:
		push_error("%s requires authored Player node." % name)
		ok = false
	return ok


## 播放入场对话后交还玩家控制。
func _run_enter_sequence() -> void:
	if stage_music != null:
		SoundManager.music.play(stage_music, 0.0, 0.0, 1.5)

	# 脏关闭/强杀恢复：AI 提到上次玩家想逃但没用
	if GameFlow.entered_with_unclean_exit and GameFlow.has_dialogue_title(stage_index, "dirty_return"):
		await GameFlow.play_dialogue(stage_index, "dirty_return")

	if play_intro_dialogue:
		await GameFlow.play_dialogue(stage_index, "start")

	if is_instance_valid(_player):
		_player.set_frozen(false)
	_stage_active = true
	_on_stage_ready()


## [virtual] 子类重写：关卡专属初始化
func _on_stage_ready() -> void:
	pass


# ──────────────────────────────────────────────
# 关闭时刻
# ──────────────────────────────────────────────

## CloseMomentTrigger 触发后进入关闭时刻。
func _on_close_trigger_entered(body: Node) -> void:
	if _close_moment_started or not _stage_active:
		return
	if body != _player:
		return
	trigger_close_moment()


## 触发本关的"关闭时刻"。可由触发区域或子类（战斗胜利后）主动调用。
func trigger_close_moment() -> void:
	if _close_moment_started:
		return
	_close_moment_started = true
	_begin_close_moment_sequence.call_deferred()


## 播放关闭对白，等待玩家按下场景内关闭按钮。
func _begin_close_moment_sequence() -> void:
	if not _require_authored_stage_nodes():
		return
	if is_instance_valid(_player):
		_player.set_frozen(true)
	# 播放关闭时刻对话
	await GameFlow.play_dialogue(stage_index, "close_moment")
	await _on_close_moment_ready()
	_show_close_button()
	await _wait_for_close_button()
	await _play_close_animation()
	# 玩家亲手按下场景内关闭按钮后推进剧情（下次打开进下一关 / 结局）
	GameFlow.reach_close_moment(stage_index)


## [virtual] 子类重写：关闭时刻对话后、自我关闭前的收尾（变暗、静音等）
func _on_close_moment_ready() -> void:
	pass



## 显示 authored 关闭按钮并交给玩家点击。
func _show_close_button() -> void:
	if _close_moment_layer == null or _close_button == null:
		push_error("%s cannot show close button because authored close UI is missing." % name)
		return
	_close_button_pressed = false
	_close_moment_layer.show()
	_close_button.disabled = false
	_close_button.grab_focus()


## 等待玩家按下场景内关闭按钮。
func _wait_for_close_button() -> void:
	while not _close_button_pressed:
		await get_tree().process_frame


## 记录玩家已经确认关闭这一层。
func _on_close_button_pressed() -> void:
	_close_button_pressed = true
	if _close_button != null:
		_close_button.disabled = true


## 复位 authored 关闭演出节点，保证每关开始都是清屏状态。
func _reset_close_animation_nodes() -> void:
	if _close_curtain != null:
		_close_curtain.modulate.a = 0.0
	if _close_shutter_top != null:
		_close_shutter_top.modulate.a = 0.0
		_close_shutter_top.scale = Vector2.ONE
	if _close_shutter_bottom != null:
		_close_shutter_bottom.modulate.a = 0.0
		_close_shutter_bottom.scale = Vector2.ONE
	if _close_scanline != null:
		_close_scanline.modulate.a = 0.0
		_close_scanline.scale = Vector2(0.05, 1.0)


## 播放本关关闭前的压帘/闪断演出，再交给 GameFlow 真正退出。
func _play_close_animation() -> void:
	if _close_moment_layer == null:
		push_error("%s cannot play close animation because CloseMomentLayer is missing." % name)
		return
	_close_moment_layer.show()
	_reset_close_animation_nodes()
	var tween := create_tween()
	if _close_curtain != null:
		tween.tween_property(_close_curtain, "modulate:a", 0.72, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _close_shutter_top != null:
		tween.parallel().tween_property(_close_shutter_top, "modulate:a", 0.9, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _close_shutter_bottom != null:
		tween.parallel().tween_property(_close_shutter_bottom, "modulate:a", 0.9, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _close_scanline != null:
		tween.parallel().tween_property(_close_scanline, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_close_scanline, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.12)
	if _close_curtain != null:
		tween.tween_property(_close_curtain, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _close_scanline != null:
		tween.parallel().tween_property(_close_scanline, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


# ──────────────────────────────────────────────
# 辅助
# ──────────────────────────────────────────────

## AI 的非阻塞旁白：走 InfoFlow 面包屑信息流（不再用 ai_hud）。
## 子类调用 say("文本") 即可，默认底部居中限时显示。
func say(text: String, seconds: float = 3.0, layout: String = "bottom+0,-40@520x72") -> void:
	InfoFlow.toast(seconds, "", text, layout)

## 返回本关 authored 玩家节点。
func get_player() -> CloseAIPlayer:
	return _player
