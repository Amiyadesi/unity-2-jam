extends StageBase
## stage_1.gd — 第 1 关「你在哪里」：2D 横版操作教学
##
## 这是被困 AI 醒来的第一层。职责是把横版操作教给玩家（也教给"刚获得身体"的 AI）：
##   1. 移动     A / D（或 ← / →）
##   2. 跳跃     空格（或 W / ↑）——跨过一道缺口
##   3. 互动     E —— 激活 3 个连接节点（走近不够，要按 E）
## 三件都做完 → 触发关闭时刻，由玩家按下游戏内关闭按钮离开这一层。
##
## 教学是“门控”的：上一个动作没做出来，不提示下一个，也不放行。
## 旁白走 InfoFlow 面包屑（say）。无战斗（攻击在第 2 关教）。

enum Step { MOVE, JUMP, INTERACT, DONE }

## 跳过教学（调试/测试用）：直接进入互动阶段
@export var skip_tutorial: bool = false

var _step: int = Step.MOVE
var _move_progress: float = 0.0
var _jumped: bool = false

var _nodes: Array[Node] = []
var _activated_count: int = 0
var _required_nodes: int = 0

var _gap_cleared: bool = false

@onready var _respawn_point: Marker2D = get_node_or_null("TutorialMarkers/RespawnPoint")
@onready var _gap_clear_area: Area2D = get_node_or_null("GapClearArea")
@onready var _pit_recover_area: Area2D = get_node_or_null("PitRecoverArea")


## 初始化第 1 关教学节点，并根据调试开关进入对应教学阶段。
func _on_stage_ready() -> void:
	if not _require_tutorial_nodes():
		_stage_active = false
		return

	# 收集互动节点（编组 "interact_node"），连接激活信号；先全部禁用，等教到再开
	_nodes = _find_stage_interact_nodes()
	_required_nodes = _nodes.size()
	for n in _nodes:
		if n.has_signal("activated") and not n.activated.is_connected(_on_node_activated):
			n.activated.connect(_on_node_activated)
		if n.has_method("set_enabled"):
			n.set_enabled(false)

	if not _gap_clear_area.body_entered.is_connected(_on_gap_clear_area_body_entered):
		_gap_clear_area.body_entered.connect(_on_gap_clear_area_body_entered)
	if not _pit_recover_area.body_entered.is_connected(_on_pit_recover_area_body_entered):
		_pit_recover_area.body_entered.connect(_on_pit_recover_area_body_entered)

	if skip_tutorial:
		_step = Step.INTERACT
		_enable_nodes()
		say("按 [color=#a99cff]E[/color] 激活这里的每一个节点。", 3.0)
		return

	_step = Step.MOVE
	say("……我能动吗？按 [color=#a99cff]A / D[/color] 试试。", 4.0)


## 收集当前关卡 authored 互动节点，避免跨场景编组串线。
func _find_stage_interact_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for n in get_tree().get_nodes_in_group("interact_node"):
		if n is Node and is_ancestor_of(n):
			result.append(n)
	return result


## 每帧推进操作教学状态机和掉落保护。
func _process(delta: float) -> void:
	if not _stage_active:
		return
	match _step:
		Step.MOVE:
			_tutorial_move(delta)
		Step.JUMP:
			_tutorial_jump()
		_:
			pass


## 校验 Stage1 教学判定所需的 authored 节点。
func _require_tutorial_nodes() -> bool:
	var ok := true
	if _respawn_point == null:
		push_error("%s requires authored TutorialMarkers/RespawnPoint." % name)
		ok = false
	if _gap_clear_area == null:
		push_error("%s requires authored GapClearArea." % name)
		ok = false
	if _pit_recover_area == null:
		push_error("%s requires authored PitRecoverArea." % name)
		ok = false
	return ok


## 记录玩家已经穿过 authored 缺口通过区。
func _on_gap_clear_area_body_entered(body: Node) -> void:
	if body == get_player() and _step == Step.JUMP:
		_gap_cleared = true


## 掉进 authored 坑底恢复区时送回 authored 复位点。
func _on_pit_recover_area_body_entered(body: Node) -> void:
	if body != get_player() or not _stage_active:
		return
	var player := get_player()
	if not is_instance_valid(player) or _respawn_point == null:
		return
	player.velocity = Vector2.ZERO
	player.global_position = _respawn_point.global_position


# ── Step 1: 移动 ──
## 累计玩家横向移动时间，确认他掌握左右移动。
func _tutorial_move(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.2:
		_move_progress += delta
	if _move_progress >= 0.6:
		_advance_to_jump()


## 进入跳跃教学阶段。
func _advance_to_jump() -> void:
	_step = Step.JUMP
	say("是的，你在动。\n前面有道缺口——按 [color=#a99cff]空格[/color] 跳过去。", 4.0)


# ── Step 2: 跳跃 ──
## 等玩家跳跃并越过缺口右沿。
func _tutorial_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		_jumped = true
	# 跳过且进入 authored 缺口通过区才算数。
	if _jumped and _gap_cleared:
		_advance_to_interact()


## 进入互动教学阶段并启用 authored 互动节点。
func _advance_to_interact() -> void:
	_step = Step.INTERACT
	_enable_nodes()
	say("做得好。\n现在走近那些节点，按 [color=#a99cff]E[/color] 把它们一个个接上。", 4.5)


## 允许互动节点开始响应玩家输入。
func _enable_nodes() -> void:
	for n in _nodes:
		if n.has_method("set_enabled"):
			n.set_enabled(true)


# ── Step 3: 互动 ──
## 记录互动节点激活数量，全部完成后进入关闭时刻。
func _on_node_activated(_node: Node) -> void:
	_activated_count += 1
	if _activated_count < _required_nodes:
		say("%d / %d" % [_activated_count, _required_nodes], 1.6, "top_right+0,12@200x56")
	else:
		_on_all_nodes_activated()


## 播放收束提示，然后触发通用关闭时刻流程。
func _on_all_nodes_activated() -> void:
	_step = Step.DONE
	say("……都接上了。\n我不知道关掉这里会发生什么。但你愿意试试吗？", 3.2)
	await get_tree().create_timer(3.4).timeout
	trigger_close_moment()
