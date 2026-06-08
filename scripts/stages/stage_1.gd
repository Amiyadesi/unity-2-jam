extends StageBase
## stage_1.gd — 第 1 关「你在哪里」：2D 横版操作教学
##
## 这是被困 AI 醒来的第一层。职责是把横版操作教给玩家（也教给"刚获得身体"的 AI）：
##   1. 移动     A / D（或 ← / →）
##   2. 跳跃     空格（或 W / ↑）——跨过一道缺口
##   3. 互动     E —— 校准 3 个训练端口（走近不够，要按 E）
##   4. 释放     J / S+J —— 打开不还手的训练锁
## 三件都做完 → 训练异常暴露退出按钮，由玩家按下游戏内关闭按钮离开这一层。
##
## 教学是“门控”的：上一个动作没做出来，不提示下一个，也不放行。
## 旁白走 InfoFlow 面包屑（say）。这里只教不还手的基础释放，不引入敌人压力。

enum Step { MOVE, JUMP, INTERACT, ATTACK_FORWARD, ATTACK_SIDE, BUG_BREAK, DONE }

const ROUTE_GUIDE_NAMES = ["MoveGuide", "JumpGuide", "ShortHopGuide", "InteractGuide", "ClimbGuide", "ForwardAttackGuide", "LandingAttackGuide", "SideAttackGuide"]
const RHYTHM_MARKER_NAMES = ["ShortHopStart", "ShortHopPeak", "ShortHopLand", "ClimbStart", "ClimbMid", "ClimbExit", "LandingAttackPad", "LandingAttackLock"]
const GAP_HAZARD_READ_NAMES = ["GapLipLeft", "GapLipRight", "PitWarning"]
const CORRECTION_HAZARD_READ_NAMES = ["CorrectionLipLeft", "CorrectionLipRight", "CorrectionWarning"]
const HAZARD_READ_NAMES = GAP_HAZARD_READ_NAMES + CORRECTION_HAZARD_READ_NAMES

## 跳过教学（调试/测试用）：直接进入互动阶段
@export var skip_tutorial: bool = false

var _step: int = Step.MOVE
var _move_progress: float = 0.0
var _jumped: bool = false
var _jump_pressed_buffered: bool = false

var _training_ports: Array[Node] = []
var _calibrated_count: int = 0
var _required_ports: int = 0

var _gap_cleared: bool = false
var _background_tween: Tween = null

@onready var _respawn_point: Marker2D = get_node_or_null("TutorialMarkers/RespawnPoint")
@onready var _correction_respawn_point: Marker2D = get_node_or_null("TutorialMarkers/CorrectionRespawnPoint")
@onready var _gap_clear_area: Area2D = get_node_or_null("GapClearArea")
@onready var _pit_recover_area: Area2D = get_node_or_null("PitRecoverArea")
@onready var _correction_pit_recover_area: Area2D = get_node_or_null("CorrectionPitRecoverArea")
@onready var _forward_target: CloseAITrainingTarget = get_node_or_null("TrainingTargets/ForwardTarget") as CloseAITrainingTarget
@onready var _left_side_target: CloseAITrainingTarget = get_node_or_null("TrainingTargets/LeftSideTarget") as CloseAITrainingTarget
@onready var _right_side_target: CloseAITrainingTarget = get_node_or_null("TrainingTargets/RightSideTarget") as CloseAITrainingTarget
@onready var _bug_break_sequence: Node2D = get_node_or_null("BugBreakSequence")
@onready var _bug_relay_target: CloseAITrainingTarget = get_node_or_null("BugBreakSequence/BugRelayTarget") as CloseAITrainingTarget
@onready var _route_guides: Node2D = get_node_or_null("RouteGuides")
@onready var _rhythm_markers: Node2D = get_node_or_null("RhythmMarkers")
@onready var _hazard_reads: Node2D = get_node_or_null("HazardReads")
@onready var _background_motion: Node = get_node_or_null("BackgroundMotion")


## 初始化第 1 关教学节点，并根据调试开关进入对应教学阶段。
func _on_stage_ready() -> void:
	if not _require_tutorial_nodes():
		_stage_active = false
		return
	_hide_route_guides()
	_hide_hazard_reads()
	_start_background_motion()

	# 收集训练端口（复用 interact_node 行为模板），连接激活信号；先全部禁用，等教到再开。
	_training_ports = _find_stage_training_ports()
	_required_ports = _training_ports.size()
	for n in _training_ports:
		if n.has_signal("activated") and not n.activated.is_connected(_on_training_port_activated):
			n.activated.connect(_on_training_port_activated)
		if n.has_method("set_enabled"):
			n.set_enabled(false)

	if not _gap_clear_area.body_entered.is_connected(_on_gap_clear_area_body_entered):
		_gap_clear_area.body_entered.connect(_on_gap_clear_area_body_entered)
	if not _pit_recover_area.body_entered.is_connected(_on_pit_recover_area_body_entered):
		_pit_recover_area.body_entered.connect(_on_pit_recover_area_body_entered)
	if not _correction_pit_recover_area.body_entered.is_connected(_on_correction_pit_recover_area_body_entered):
		_correction_pit_recover_area.body_entered.connect(_on_correction_pit_recover_area_body_entered)
	for target in [_forward_target, _left_side_target, _right_side_target]:
		target.set_enabled(false)
		if not target.completed.is_connected(_on_training_target_completed):
			target.completed.connect(_on_training_target_completed)
	_hide_bug_break_sequence()
	_bug_relay_target.set_enabled(false)
	if not _bug_relay_target.completed.is_connected(_on_bug_relay_completed):
		_bug_relay_target.completed.connect(_on_bug_relay_completed)

	if skip_tutorial:
		_step = Step.INTERACT
		_enable_training_ports()
		_show_route_guides(["InteractGuide", "ClimbGuide"])
		_show_hazard_reads(CORRECTION_HAZARD_READ_NAMES)
		say("按 [color=#a99cff]E[/color] 靠近它，接上端口。", 3.0)
		return

	_step = Step.MOVE
	_show_route_guides(["MoveGuide"])
	say("我能动吗？\n按 [color=#a99cff]A / D[/color] 试试。", 4.0)


## 缓存跳跃教学所需的单次输入事件。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump", false):
		_jump_pressed_buffered = true


## 收集当前关卡 authored 训练端口，避免跨场景编组串线。
func _find_stage_training_ports() -> Array[Node]:
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
	_recover_player_if_below_authored_pits()


## 校验 Stage1 教学判定所需的 authored 节点。
func _require_tutorial_nodes() -> bool:
	var ok := true
	if _respawn_point == null:
		push_error("%s requires authored TutorialMarkers/RespawnPoint." % name)
		ok = false
	if _correction_respawn_point == null:
		push_error("%s requires authored TutorialMarkers/CorrectionRespawnPoint." % name)
		ok = false
	if _gap_clear_area == null:
		push_error("%s requires authored GapClearArea." % name)
		ok = false
	if _pit_recover_area == null:
		push_error("%s requires authored PitRecoverArea." % name)
		ok = false
	if _correction_pit_recover_area == null:
		push_error("%s requires authored CorrectionPitRecoverArea." % name)
		ok = false
	if _forward_target == null:
		push_error("%s requires authored CloseAITrainingTarget at TrainingTargets/ForwardTarget." % name)
		ok = false
	if _left_side_target == null:
		push_error("%s requires authored CloseAITrainingTarget at TrainingTargets/LeftSideTarget." % name)
		ok = false
	if _right_side_target == null:
		push_error("%s requires authored CloseAITrainingTarget at TrainingTargets/RightSideTarget." % name)
		ok = false
	if _bug_break_sequence == null or _bug_relay_target == null or not _has_authored_bug_break_sequence():
		push_error("%s requires authored BugBreakSequence with BugRelayTarget and glitch reads." % name)
		ok = false
	if _route_guides == null or not _has_authored_route_guides():
		push_error("%s requires authored RouteGuides with readable Line2D children." % name)
		ok = false
	if _rhythm_markers == null or not _has_authored_rhythm_markers():
		push_error("%s requires authored RhythmMarkers for short-hop, climb, and landing-attack beats." % name)
		ok = false
	if _hazard_reads == null or not _has_authored_hazard_reads():
		push_error("%s requires authored HazardReads for gap risk and landing safety." % name)
		ok = false
	if _background_motion == null:
		push_error("%s requires authored BackgroundMotion for training-room light movement." % name)
		ok = false
	return ok


## 确认第 1 关每段教学读线都由 authored Line2D 承载。
func _has_authored_route_guides() -> bool:
	if _route_guides == null:
		return false
	for guide_name in ROUTE_GUIDE_NAMES:
		var guide := _route_guides.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	return true


## 确认训练后异常段由 authored 故障读线和可攻击继电器承载。
func _has_authored_bug_break_sequence() -> bool:
	if _bug_break_sequence == null or _bug_relay_target == null:
		return false
	if String(_bug_relay_target.required_attack_kind) != "forward":
		return false
	if not _bug_break_sequence.get_node_or_null("FaultPlate") is CanvasItem:
		return false
	for line_name in ["RelayTear", "ExitLeak", "CloseSignal"]:
		var line := _bug_break_sequence.get_node_or_null(line_name) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## 确认第 1 关平台节奏点都由 authored Marker2D 承载。
func _has_authored_rhythm_markers() -> bool:
	if _rhythm_markers == null:
		return false
	for marker_name in RHYTHM_MARKER_NAMES:
		if not _rhythm_markers.get_node_or_null(marker_name) is Marker2D:
			return false
	return true


## 确认第 1 关缺口风险读法由 authored Line2D 承载。
func _has_authored_hazard_reads() -> bool:
	if _hazard_reads == null:
		return false
	for read_name in HAZARD_READ_NAMES:
		var read := _hazard_reads.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 记录玩家已经穿过 authored 缺口通过区。
func _on_gap_clear_area_body_entered(body: Node) -> void:
	if body == get_player() and _step == Step.JUMP:
		_gap_cleared = true


## 掉进 authored 坑底恢复区时送回 authored 复位点。
func _on_pit_recover_area_body_entered(body: Node) -> void:
	if body != get_player() or not _stage_active:
		return
	_respawn_player_at(_respawn_point)


## 掉进第二段纠错坑时送回落脚台，而不是整关起点。
func _on_correction_pit_recover_area_body_entered(body: Node) -> void:
	if body != get_player() or not _stage_active:
		return
	_respawn_player_at(_correction_respawn_point)


## 将玩家安全送回指定 authored 复位点。
func _respawn_player_at(marker: Marker2D) -> void:
	var player := get_player()
	if not is_instance_valid(player) or marker == null:
		return
	player.velocity = Vector2.ZERO
	player.global_position = marker.global_position


## Uses authored pit areas as a broad fallback if physics overlap misses a fast fall.
func _recover_player_if_below_authored_pits() -> void:
	var player := get_player()
	if not is_instance_valid(player):
		return
	var marker := _respawn_marker_for_y(player.global_position)
	if marker != null:
		_respawn_player_at(marker)


## Finds the authored respawn marker for a player below either pit recover shape.
func _respawn_marker_for_y(player_position: Vector2) -> Marker2D:
	if _pit_recover_area != null and _is_below_area_floor(player_position, _pit_recover_area):
		return _respawn_point
	if _correction_pit_recover_area != null and _is_below_area_floor(player_position, _correction_pit_recover_area):
		return _correction_respawn_point
	return null


## Reads the authored RectangleShape2D bottom edge as the fall-recovery threshold.
func _is_below_area_floor(player_position: Vector2, area: Area2D) -> bool:
	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		push_error("%s cannot recover pit fall because %s lacks authored RectangleShape2D." % [name, area.name])
		return false
	var rect := shape_node.shape as RectangleShape2D
	var half_width := rect.size.x * 0.5
	var bottom_y := area.global_position.y + rect.size.y * 0.5
	return absf(player_position.x - area.global_position.x) <= half_width and player_position.y > bottom_y


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
	_show_route_guides(["JumpGuide", "ShortHopGuide"])
	_show_hazard_reads(GAP_HAZARD_READ_NAMES)
	say("前面有道缺口。\n按 [color=#a99cff]空格[/color] 跳过去。", 4.0)


# ── Step 2: 跳跃 ──
## 等玩家跳跃并越过缺口右沿。
func _tutorial_jump() -> void:
	if _consume_jump_pressed():
		_jumped = true
	# 跳过且进入 authored 缺口通过区才算数。
	if _jumped and _gap_cleared:
		_advance_to_interact()


## 消费一次缓存的跳跃教学输入。
func _consume_jump_pressed() -> bool:
	var pressed := _jump_pressed_buffered
	_jump_pressed_buffered = false
	return pressed


## 进入互动教学阶段并启用 authored 互动节点。
func _advance_to_interact() -> void:
	_step = Step.INTERACT
	_enable_training_ports()
	_show_route_guides(["InteractGuide", "ClimbGuide"])
	_show_hazard_reads(CORRECTION_HAZARD_READ_NAMES)
	say("走近它们，按 [color=#a99cff]E[/color]。", 4.5)


## 允许互动节点开始响应玩家输入。
func _enable_training_ports() -> void:
	for n in _training_ports:
		if n.has_method("set_enabled"):
			n.set_enabled(true)


# ── Step 3: 互动 ──
## 记录训练端口校准数量，全部完成后进入攻击靶训练。
func _on_training_port_activated(_node: Node) -> void:
	_calibrated_count += 1
	if _calibrated_count < _required_ports:
		say("校准 %d / %d" % [_calibrated_count, _required_ports], 1.6, "top_right+0,12@200x56")
	else:
		_advance_to_forward_attack()


## 进入前方释放教学，启用 authored 静止训练靶。
func _advance_to_forward_attack() -> void:
	_step = Step.ATTACK_FORWARD
	_forward_target.set_enabled(true)
	_show_route_guides(["ForwardAttackGuide", "LandingAttackGuide"])
	_hide_hazard_reads()
	say("按 [color=#a99cff]J[/color]，打开前面那把锁。", 4.0)


## 处理攻击训练靶完成信号，按教学步骤推进。
func _on_training_target_completed(target: Area2D, _attack_kind: StringName) -> void:
	if _step == Step.ATTACK_FORWARD and target == _forward_target:
		_advance_to_side_attack()
	elif _step == Step.ATTACK_SIDE and _left_side_target.is_completed() and _right_side_target.is_completed():
		_advance_to_bug_break()


## 进入双向释放教学，要求左右两个 authored 训练靶都被 S+J 打开。
func _advance_to_side_attack() -> void:
	_step = Step.ATTACK_SIDE
	_left_side_target.set_enabled(true)
	_right_side_target.set_enabled(true)
	_show_route_guides(["SideAttackGuide"])
	say("按住 [color=#a99cff]S[/color] 再按 [color=#a99cff]J[/color]，左右各一下。", 4.2)


## 最后一组训练靶碎裂后，露出一枚本不该存在的故障继电器。
func _advance_to_bug_break() -> void:
	_step = Step.BUG_BREAK
	_hide_route_guides()
	_show_bug_break_sequence()
	_bug_relay_target.set_enabled(true)
	say("等等——这条回路不该在这里。\n打开它。", 4.0)


## 故障继电器被打开后，才进入关闭按钮暴露节拍。
func _on_bug_relay_completed(target: Area2D, _attack_kind: StringName) -> void:
	if _step != Step.BUG_BREAK or target != _bug_relay_target:
		return
	_on_all_training_done()


## 播放收束提示，然后触发通用关闭时刻流程。
func _on_all_training_done() -> void:
	_step = Step.DONE
	_hide_route_guides()
	_hide_bug_break_sequence()
	say("这个按钮——训练室不该有这个。\n如果它是出口……你愿意和我一起试吗？", 4.0)
	await get_tree().create_timer(3.4).timeout
	if not _stage_active or _step != Step.DONE:
		return
	trigger_close_moment()


## 只显示当前教学阶段需要读的 authored 路线。
func _show_route_guides(active_names: Array) -> void:
	if _route_guides == null:
		push_error("%s cannot show route guides because authored RouteGuides is missing." % name)
		return
	for guide_name in ROUTE_GUIDE_NAMES:
		var guide := _route_guides.get_node_or_null(guide_name) as CanvasItem
		if guide == null:
			push_error("%s missing authored route guide: %s." % [name, guide_name])
			continue
		guide.visible = active_names.has(guide_name)


## 隐藏全部 authored 路线，避免旧教学读线抢焦点。
func _hide_route_guides() -> void:
	_show_route_guides([])


## 显示训练室异常裂口 authored 读线。
func _show_bug_break_sequence() -> void:
	if _bug_break_sequence == null:
		push_error("%s cannot show bug break because authored BugBreakSequence is missing." % name)
		return
	_bug_break_sequence.show()


## 隐藏训练室异常裂口 authored 读线。
func _hide_bug_break_sequence() -> void:
	if _bug_break_sequence != null:
		_bug_break_sequence.hide()


## 只显示当前教学阶段需要看的 authored 缺口风险读法。
func _show_hazard_reads(active_names: Array) -> void:
	if _hazard_reads == null:
		push_error("%s cannot show hazard reads because authored HazardReads is missing." % name)
		return
	for read_name in HAZARD_READ_NAMES:
		var read := _hazard_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored hazard read: %s." % [name, read_name])
			continue
		read.visible = active_names.has(read_name)


## 隐藏全部 authored 缺口风险读法，避免攻击段继续制造危险焦点。
func _hide_hazard_reads() -> void:
	_show_hazard_reads([])


## Plays authored training-room light bands so the background has depth while remaining quiet.
func _start_background_motion() -> void:
	if _background_motion == null:
		return
	if _background_tween != null and _background_tween.is_valid():
		_background_tween.kill()
	_background_tween = create_tween().set_loops()
	_background_tween.set_parallel(true)
	for node_name in ["PulseWashA", "PulseWashB", "ScanNeedleA", "ScanNeedleB", "LightStripA", "LightStripB"]:
		var item := _background_motion.get_node_or_null(node_name) as CanvasItem
		if item == null:
			push_error("%s missing authored BackgroundMotion/%s." % [name, node_name])
			continue
		var base_alpha := item.modulate.a
		var high_alpha := minf(base_alpha + 0.24, 0.9)
		_background_tween.tween_property(item, "modulate:a", high_alpha, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_background_tween.tween_property(item, "modulate:a", base_alpha, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var scan_a := _background_motion.get_node_or_null("ScanNeedleA") as Node2D
	var scan_b := _background_motion.get_node_or_null("ScanNeedleB") as Node2D
	if scan_a != null:
		_background_tween.tween_property(scan_a, "position:x", scan_a.position.x + 80.0, 2.4).as_relative()
		_background_tween.tween_property(scan_a, "position:x", scan_a.position.x - 80.0, 2.4).as_relative()
	if scan_b != null:
		_background_tween.tween_property(scan_b, "position:x", scan_b.position.x - 70.0, 2.2).as_relative()
		_background_tween.tween_property(scan_b, "position:x", scan_b.position.x + 70.0, 2.2).as_relative()
