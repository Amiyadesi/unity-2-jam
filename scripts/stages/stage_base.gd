extends Node2D
class_name StageBase
## stage_base.gd — CloseAI 关卡基类（反转版）
##
## 所有关卡共享的"关闭时刻"编排。子类只需：
##  - 在场景里摆好平台、Player、CloseMomentTrigger(Area2D)、AiHud
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
##    6. 调 GameFlow.reach_close_moment(stage_index)：推进进度 + 游戏自我关闭
##       （玩家无需、也无法自己关；游戏替他关，下次打开进下一关）
##
## 关卡"完成" = 游戏自我关闭。玩家全程无法关闭窗口（被嘲讽）。

@export var stage_index: int = 1
@export var play_intro_dialogue: bool = true

@onready var _player: CloseAIPlayer = $Player
@onready var _hud = $AiHud
@onready var _close_trigger: Area2D = get_node_or_null("CloseMomentTrigger")

var _close_moment_started: bool = false
var _stage_active: bool = false

## 暂停界面（实例化固定模板场景，所有关卡共用）
const PAUSE_SCENE := "res://scenes/pause_screen.tscn"
var _pause_screen: Control


func _ready() -> void:
	if is_instance_valid(_player):
		_player.set_frozen(true)
	if _close_trigger != null:
		_close_trigger.body_entered.connect(_on_close_trigger_entered)
	GameFlow.set_current_stage(stage_index)
	_spawn_pause_screen()
	_run_enter_sequence.call_deferred()


## 实例化固定模板暂停界面到独立 CanvasLayer（headless 跳过）
func _spawn_pause_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not ResourceLoader.exists(PAUSE_SCENE):
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause_screen = load(PAUSE_SCENE).instantiate()
	layer.add_child(_pause_screen)


func _run_enter_sequence() -> void:
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


func _begin_close_moment_sequence() -> void:
	if is_instance_valid(_player):
		_player.set_frozen(true)
	# 播放关闭时刻对话
	await GameFlow.play_dialogue(stage_index, "close_moment")
	_on_close_moment_ready()
	# 游戏自我关闭并推进剧情（玩家下次打开进下一关 / 结局）
	GameFlow.reach_close_moment(stage_index)


## [virtual] 子类重写：关闭时刻对话后、自我关闭前的收尾（变暗、静音等）
func _on_close_moment_ready() -> void:
	pass


# ──────────────────────────────────────────────
# 辅助
# ──────────────────────────────────────────────

func get_hud():
	return _hud

func get_player() -> CloseAIPlayer:
	return _player
