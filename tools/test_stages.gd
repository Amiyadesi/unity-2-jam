extends SceneTree
## test_stages.gd — 验证各关卡场景能实例化并跑过 enter 序列前几帧
## 运行：godot --headless --path . --script res://tools/test_stages.gd

var _failures: int = 0
var _checks: int = 0
var _stage_2_dash_loop_enemy_defeated: bool = false

const STAGE_1_GAP_HAZARD_READS := ["GapLipLeft", "GapLipRight", "PitWarning"]
const STAGE_1_CORRECTION_HAZARD_READS := ["CorrectionLipLeft", "CorrectionLipRight", "CorrectionWarning"]
const STAGE_1_HAZARD_READS := STAGE_1_GAP_HAZARD_READS + STAGE_1_CORRECTION_HAZARD_READS

const STAGE_SCENES := [
	"res://scenes/stage_1.tscn",
	"res://scenes/stage_2.tscn",
	"res://scenes/stage_3.tscn",
]

## 延迟启动测试，等 autoload 初始化完成。
func _init() -> void:
	call_deferred("_run")

## 记录一条布尔检查结果。
func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  [PASS] " if cond else "  [FAIL] ") + label)
	if not cond:
		_failures += 1

## 跑场景实例化和 authored 关卡结构回归检查。
func _run() -> void:
	print("=== CloseAI stage instantiation test ===")
	await process_frame
	await process_frame
	var gf = root.get_node_or_null("GameFlow")
	if gf != null:
		gf.reset_progress()

	for scene_path in STAGE_SCENES + ["res://scenes/menu.tscn", "res://scenes/ending.tscn", "res://scenes/openai_note.tscn"]:
		var packed = load(scene_path)
		_check("load packed: " + scene_path, packed != null)
		if packed == null:
			continue
		var inst = packed.instantiate()
		_check("instantiate: " + scene_path, inst != null)
		if inst == null:
			continue
		root.add_child(inst)
		# 跑若干帧，让 _ready / _run_enter_sequence / 对话调用执行
		for _i in range(8):
			await process_frame
		_check("alive after frames: " + scene_path, is_instance_valid(inst))
		if STAGE_SCENES.has(scene_path):
			_check_authored_stage_ui(inst, scene_path)
			_check_authored_energy_hud(inst, scene_path)
		if scene_path == "res://scenes/stage_1.tscn":
			_check_stage_1_training_ports(inst)
			_check_stage_1_tutorial_nodes(inst)
			_check_stage_1_platform_rhythm(inst)
			_check_stage_1_visual_readability(inst)
			_check_stage_1_training_targets(inst)
			_check_stage_1_bug_break_sequence(inst)
			await _check_stage_1_route_guides(inst)
		if scene_path == "res://scenes/stage_2.tscn":
			_check_stage_2_flight_training(inst)
			await _check_stage_2_enemy_waves(inst)
		if scene_path == "res://scenes/stage_3.tscn":
			await _check_stage_3_finale_nodes(inst)
		# 关掉可能弹出的对话气泡 + 移除场景
		inst.queue_free()
		await process_frame
		await process_frame

	if gf != null:
		gf.reset_progress()
	print("=== RESULT: %d/%d passed, %d failed ===" % [_checks - _failures, _checks, _failures])
	quit(1 if _failures > 0 else 0)


## 确认关卡共享 UI 都来自 authored 场景节点，关闭按钮使用 ShaderButton 模板。
func _check_authored_stage_ui(inst: Node, scene_path: String) -> void:
	var pause_screen := inst.get_node_or_null("PauseLayer/PauseScreen")
	var close_layer := inst.get_node_or_null("CloseMomentLayer")
	var close_button := inst.get_node_or_null("CloseMomentLayer/CloseButton")
	_check("authored PauseLayer/PauseScreen: " + scene_path, pause_screen != null)
	_check("authored CloseMomentLayer: " + scene_path, close_layer != null)
	_check("authored CloseMomentLayer/CloseButton: " + scene_path, close_button != null)
	_check("CloseButton is ShaderButton: " + scene_path, close_button != null and close_button.has_method("set_bbtext"))


## 确认战斗关卡 authored 能量 HUD，第 1 关教学不显示战斗 HUD。
func _check_authored_energy_hud(inst: Node, scene_path: String) -> void:
	var energy_hud := inst.get_node_or_null("EnergyHud")
	if scene_path == "res://scenes/stage_1.tscn":
		_check("stage_1 has no combat EnergyHud", energy_hud == null)
		return
	_check("combat stage authored EnergyHud: " + scene_path, energy_hud != null)
	_check("EnergyHud has player_path: " + scene_path, energy_hud != null and "player_path" in energy_hud and str(energy_hud.player_path) != "")


## 确认第 1 关 AI 训练室端口已 authored 到场景里，不再使用旧连接节点命名。
func _check_stage_1_training_ports(inst: Node) -> void:
	var player := inst.get_node_or_null("Player")
	_check("stage_1 disables awaken", player != null and "allow_awaken" in player and player.allow_awaken == false)
	_check("stage_1 disables dash", player != null and "allow_dash" in player and player.allow_dash == false)
	var expected := ["CalibrationPortA", "LogicRelayB", "ExitProbeC"]
	for node_name in expected:
		var training_port := inst.get_node_or_null(node_name)
		_check("stage_1 authored " + node_name, training_port != null)
		_check("stage_1 " + node_name + " supports set_enabled", training_port != null and training_port.has_method("set_enabled"))
		_check("stage_1 " + node_name + " authored Lit", training_port != null and training_port.get_node_or_null("Lit") is CanvasItem)
		_check("stage_1 " + node_name + " authored Prompt", training_port != null and training_port.get_node_or_null("Prompt") is CanvasItem)
		_check("stage_1 " + node_name + " authored PortLabel", training_port != null and training_port.get_node_or_null("PortLabel") is Label)
	_check("stage_1 removed old InteractNode1", inst.get_node_or_null("InteractNode1") == null)
	_check("stage_1 removed old Switch1", inst.get_node_or_null("Switch1") == null)


## 确认第 1 关跳跃/掉坑判定已由 authored 节点承载。
func _check_stage_1_tutorial_nodes(inst: Node) -> void:
	var respawn := inst.get_node_or_null("TutorialMarkers/RespawnPoint")
	var correction_respawn := inst.get_node_or_null("TutorialMarkers/CorrectionRespawnPoint")
	var gap_clear := inst.get_node_or_null("GapClearArea")
	var pit_recover := inst.get_node_or_null("PitRecoverArea")
	var correction_pit_recover := inst.get_node_or_null("CorrectionPitRecoverArea")
	_check("stage_1 authored RespawnPoint", respawn is Marker2D)
	_check("stage_1 authored CorrectionRespawnPoint", correction_respawn is Marker2D)
	_check("stage_1 authored GapClearArea", gap_clear is Area2D)
	_check("stage_1 authored GapClearArea shape", gap_clear != null and gap_clear.get_node_or_null("CollisionShape2D") is CollisionShape2D)
	_check("stage_1 authored PitRecoverArea", pit_recover is Area2D)
	_check("stage_1 authored PitRecoverArea shape", pit_recover != null and pit_recover.get_node_or_null("CollisionShape2D") is CollisionShape2D)
	_check("stage_1 authored CorrectionPitRecoverArea", correction_pit_recover is Area2D)
	_check("stage_1 authored CorrectionPitRecoverArea shape", correction_pit_recover != null and correction_pit_recover.get_node_or_null("CollisionShape2D") is CollisionShape2D)


## 确认第 1 关从助跑、落点、阶梯到攻击站位形成 authored 平台节奏。
func _check_stage_1_platform_rhythm(inst: Node) -> void:
	for platform_name in ["TakeoffLedge", "LandingLedge", "StepPlatformA", "StepPlatformB", "AttackLedge", "SideCastPad"]:
		_check("stage_1 authored rhythm platform " + platform_name, inst.get_node_or_null(platform_name) is StaticBody2D)
	var takeoff := inst.get_node_or_null("TakeoffLedge") as Node2D
	var landing := inst.get_node_or_null("LandingLedge") as Node2D
	var step_a := inst.get_node_or_null("StepPlatformA") as Node2D
	var step_b := inst.get_node_or_null("StepPlatformB") as Node2D
	var side_pad := inst.get_node_or_null("SideCastPad") as Node2D
	_check("stage_1 takeoff before landing", takeoff != null and landing != null and takeoff.global_position.x < landing.global_position.x)
	_check("stage_1 jump gap has readable width", _stage_1_jump_gap_has_width(inst))
	_check("stage_1 correction gap needs short hop", _stage_1_correction_gap_has_width(inst))
	_check("stage_1 step A rises from landing", step_a != null and landing != null and step_a.global_position.y < landing.global_position.y)
	_check("stage_1 step B rises from step A", step_a != null and step_b != null and step_b.global_position.y < step_a.global_position.y)
	_check("stage_1 step platform has vertical lift", step_b != null and landing != null and step_b.global_position.y < landing.global_position.y)
	_check("stage_1 side attack pad is later than forward route", side_pad != null and step_b != null and side_pad.global_position.x > step_b.global_position.x)
	_check("stage_1 authored rhythm markers", _stage_1_rhythm_markers_authored(inst))
	_check("stage_1 authored hazard reads", _stage_1_hazard_reads_authored(inst))


## 确认第 1 关白盒平台有 authored 视觉层级：背景、平台边、坑深度。
func _check_stage_1_visual_readability(inst: Node) -> void:
	_check("stage_1 authored layered background", _stage_1_layered_background_authored(inst))
	_check("stage_1 authored platform top edges", _stage_1_platform_read_edges_authored(inst))
	_check("stage_1 authored pit depth reads", _stage_1_pit_depth_reads_authored(inst))


## 确认第 1 关普通攻击训练靶由 authored 节点承载。
func _check_stage_1_training_targets(inst: Node) -> void:
	var forward := inst.get_node_or_null("TrainingTargets/ForwardTarget")
	var left_side := inst.get_node_or_null("TrainingTargets/LeftSideTarget")
	var right_side := inst.get_node_or_null("TrainingTargets/RightSideTarget")
	_check("stage_1 authored ForwardTarget", forward != null and forward.has_method("take_player_hit"))
	_check("stage_1 ForwardTarget requires forward", forward != null and str(forward.required_attack_kind) == "forward")
	_check("stage_1 authored LeftSideTarget", left_side != null and left_side.has_method("take_player_hit"))
	_check("stage_1 LeftSideTarget requires side", left_side != null and str(left_side.required_attack_kind) == "side")
	_check("stage_1 authored RightSideTarget", right_side != null and right_side.has_method("take_player_hit"))
	_check("stage_1 RightSideTarget requires side", right_side != null and str(right_side.required_attack_kind) == "side")


## 确认训练后还有一段 authored 故障继电器，不是直接跳出关闭按钮。
func _check_stage_1_bug_break_sequence(inst: Node) -> void:
	var bug_sequence := inst.get_node_or_null("BugBreakSequence") as CanvasItem
	var bug_target := inst.get_node_or_null("BugBreakSequence/BugRelayTarget")
	_check("stage_1 authored BugBreakSequence", bug_sequence != null)
	_check("stage_1 authored BugRelayTarget", bug_target != null and bug_target.has_method("take_player_hit"))
	_check("stage_1 BugRelayTarget requires forward", bug_target != null and str(bug_target.required_attack_kind) == "forward")
	for line_name in ["RelayTear", "ExitLeak", "CloseSignal"]:
		var line := inst.get_node_or_null("BugBreakSequence/" + line_name) as Line2D
		_check("stage_1 authored bug read " + line_name, line != null and line.points.size() >= 2)
	if not inst.has_method("_on_stage_ready") or not inst.has_method("_advance_to_bug_break"):
		_check("stage_1 bug flow methods", false)
		return
	inst._on_stage_ready()
	_check("stage_1 bug sequence hidden after ready", bug_sequence != null and not bug_sequence.visible)
	_check("stage_1 bug relay disabled after ready", bug_target != null and not bug_target.monitoring)
	inst._advance_to_bug_break()
	_check("stage_1 bug sequence visible only at anomaly step", bug_sequence != null and bug_sequence.visible)
	_check("stage_1 bug relay enabled only at anomaly step", bug_target != null and bug_target.monitoring)


## 确认第 1 关每段教学路线都用 authored Line2D 表达，并由脚本按阶段切换。
func _check_stage_1_route_guides(inst: Node) -> void:
	_check("stage_1 authored RouteGuides root", inst.get_node_or_null("RouteGuides") is Node2D)
	_check("stage_1 authored route guide lines", _stage_1_route_guides_authored(inst))
	if inst.has_method("_on_stage_ready"):
		inst._on_stage_ready()
		await process_frame
	_check("stage_1 starts with move guide only", _stage_1_only_route_guides_visible(inst, ["MoveGuide"]))
	_check("stage_1 hazard reads start hidden", _stage_1_only_hazard_reads_visible(inst, []))
	if not inst.has_method("_advance_to_jump"):
		_check("stage_1 route guide flow prerequisites", false)
		return
	inst._advance_to_jump()
	await process_frame
	_check("stage_1 jump step shows short-hop guide", _stage_1_only_route_guides_visible(inst, ["JumpGuide", "ShortHopGuide"]))
	_check("stage_1 jump step shows gap hazard reads", _stage_1_only_hazard_reads_visible(inst, STAGE_1_GAP_HAZARD_READS))
	inst._advance_to_interact()
	await process_frame
	_check("stage_1 interact step shows climb guide", _stage_1_only_route_guides_visible(inst, ["InteractGuide", "ClimbGuide"]))
	_check("stage_1 interact step shows correction hazard reads", _stage_1_only_hazard_reads_visible(inst, STAGE_1_CORRECTION_HAZARD_READS))
	inst._advance_to_forward_attack()
	await process_frame
	_check("stage_1 forward attack shows landing attack guide", _stage_1_only_route_guides_visible(inst, ["ForwardAttackGuide", "LandingAttackGuide"]))
	_check("stage_1 forward attack hides hazard reads", _stage_1_only_hazard_reads_visible(inst, []))
	inst._advance_to_side_attack()
	await process_frame
	_check("stage_1 side attack shows side guide only", _stage_1_only_route_guides_visible(inst, ["SideAttackGuide"]))


## 确认第 1 关路径提示是编辑器可拖拽的 Line2D，不是脚本硬编码坐标。
func _stage_1_route_guides_authored(inst: Node) -> bool:
	var guide_root := inst.get_node_or_null("RouteGuides")
	if guide_root == null:
		return false
	for guide_name in ["MoveGuide", "JumpGuide", "ShortHopGuide", "InteractGuide", "ClimbGuide", "ForwardAttackGuide", "LandingAttackGuide", "SideAttackGuide"]:
		var guide := guide_root.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	var move := guide_root.get_node_or_null("MoveGuide") as Line2D
	var jump := guide_root.get_node_or_null("JumpGuide") as Line2D
	var climb := guide_root.get_node_or_null("ClimbGuide") as Line2D
	var landing_attack := guide_root.get_node_or_null("LandingAttackGuide") as Line2D
	var side := guide_root.get_node_or_null("SideAttackGuide") as Line2D
	return move.points[0].x < move.points[move.points.size() - 1].x and jump.points.size() >= 3 and climb.points[climb.points.size() - 2].y < climb.points[0].y and landing_attack.points.size() >= 3 and side.points.size() >= 4


## 确认第 1 关缺口有足够宽度，玩家需要真实起跳而不是贴边走过。
func _stage_1_jump_gap_has_width(inst: Node) -> bool:
	var takeoff := inst.get_node_or_null("TakeoffLedge") as Node2D
	var landing := inst.get_node_or_null("LandingLedge") as Node2D
	var takeoff_shape := inst.get_node_or_null("TakeoffLedge/CollisionShape2D") as CollisionShape2D
	var landing_shape := inst.get_node_or_null("LandingLedge/CollisionShape2D") as CollisionShape2D
	if takeoff == null or landing == null or takeoff_shape == null or landing_shape == null:
		return false
	var takeoff_rect := takeoff_shape.shape as RectangleShape2D
	var landing_rect := landing_shape.shape as RectangleShape2D
	if takeoff_rect == null or landing_rect == null:
		return false
	var takeoff_right := takeoff.global_position.x + takeoff_rect.size.x * 0.5
	var landing_left := landing.global_position.x - landing_rect.size.x * 0.5
	return landing_left - takeoff_right >= 150.0


## 确认第 1 关第二缺口需要一次短跳纠正，而不是平走或大跳。
func _stage_1_correction_gap_has_width(inst: Node) -> bool:
	var landing := inst.get_node_or_null("LandingLedge") as Node2D
	var step_a := inst.get_node_or_null("StepPlatformA") as Node2D
	var landing_shape := inst.get_node_or_null("LandingLedge/CollisionShape2D") as CollisionShape2D
	var step_a_shape := inst.get_node_or_null("StepPlatformA/CollisionShape2D") as CollisionShape2D
	if landing == null or step_a == null or landing_shape == null or step_a_shape == null:
		return false
	var landing_rect := landing_shape.shape as RectangleShape2D
	var step_a_rect := step_a_shape.shape as RectangleShape2D
	if landing_rect == null or step_a_rect == null:
		return false
	var landing_right := landing.global_position.x + landing_rect.size.x * 0.5
	var step_a_left := step_a.global_position.x - step_a_rect.size.x * 0.5
	var gap_width := step_a_left - landing_right
	return gap_width >= 72.0 and gap_width <= 130.0


## 确认第 1 关背景有屏幕层和世界层，不再只是单块底色。
func _stage_1_layered_background_authored(inst: Node) -> bool:
	var background := inst.get_node_or_null("Background") as CanvasLayer
	var world_backdrop := inst.get_node_or_null("WorldBackdrop") as Node2D
	if background == null or world_backdrop == null:
		return false
	if background.layer >= 0 or world_backdrop.z_index >= 0:
		return false
	var plate := background.get_node_or_null("TrainingRoomPlate") as TextureRect
	if plate == null or plate.texture == null or plate.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for node_name in ["HorizonBand", "MemoryPulseA", "MemoryPulseB", "FarScanA", "FarScanB"]:
		if not background.get_node_or_null(node_name) is CanvasItem:
			return false
	for node_name in ["MemoryBandA", "MemoryBandB", "MemoryBandC", "DistantCircuitLine", "FarNodeDots"]:
		if not world_backdrop.get_node_or_null(node_name) is CanvasItem:
			return false
	return true


## 确认平台有 authored 顶沿和底影，让可踩面和底部清楚分开。
func _stage_1_platform_read_edges_authored(inst: Node) -> bool:
	for platform_name in ["FloorLeft", "FloorRight", "TakeoffLedge", "LandingLedge", "StepPlatformA", "StepPlatformB", "AttackLedge", "SideCastPad"]:
		var platform := inst.get_node_or_null(platform_name)
		if platform == null:
			return false
		var top_edge := platform.get_node_or_null("TopEdge") as ColorRect
		var shadow := platform.get_node_or_null("UndersideShadow") as ColorRect
		if top_edge == null or shadow == null:
			return false
		if top_edge.offset_bottom > 0.0 or shadow.offset_top < 0.0:
			return false
		if top_edge.color.a < 0.6 or shadow.color.a < 0.45:
			return false
	return true


## 确认两个坑都有 authored 深度读法，危险区域不只靠碰撞脚本。
func _stage_1_pit_depth_reads_authored(inst: Node) -> bool:
	var reads := inst.get_node_or_null("PitDepthReads") as Node2D
	if reads == null or reads.z_index >= 0:
		return false
	var gap_void := reads.get_node_or_null("GapVoid") as ColorRect
	var correction_void := reads.get_node_or_null("CorrectionVoid") as ColorRect
	var gap_lines := reads.get_node_or_null("GapFallLines") as Line2D
	var correction_lines := reads.get_node_or_null("CorrectionFallLines") as Line2D
	if gap_void == null or correction_void == null or gap_lines == null or correction_lines == null:
		return false
	return gap_void.color.a >= 0.7 and correction_void.color.a >= 0.7 and gap_lines.points.size() >= 6 and correction_lines.points.size() >= 6


## 确认第 1 关三段节奏点可在编辑器中直接拖拽。
func _stage_1_rhythm_markers_authored(inst: Node) -> bool:
	var marker_root := inst.get_node_or_null("RhythmMarkers")
	if marker_root == null:
		return false
	for marker_name in ["ShortHopStart", "ShortHopPeak", "ShortHopLand", "ClimbStart", "ClimbMid", "ClimbExit", "LandingAttackPad", "LandingAttackLock"]:
		if not marker_root.get_node_or_null(marker_name) is Marker2D:
			return false
	var hop_start := marker_root.get_node_or_null("ShortHopStart") as Marker2D
	var hop_peak := marker_root.get_node_or_null("ShortHopPeak") as Marker2D
	var hop_land := marker_root.get_node_or_null("ShortHopLand") as Marker2D
	var climb_start := marker_root.get_node_or_null("ClimbStart") as Marker2D
	var climb_exit := marker_root.get_node_or_null("ClimbExit") as Marker2D
	var attack_pad := marker_root.get_node_or_null("LandingAttackPad") as Marker2D
	var attack_lock := marker_root.get_node_or_null("LandingAttackLock") as Marker2D
	return hop_start.global_position.x < hop_land.global_position.x and hop_peak.global_position.y < hop_start.global_position.y and climb_start.global_position.x < climb_exit.global_position.x and climb_exit.global_position.y < climb_start.global_position.y and attack_pad.global_position.x < attack_lock.global_position.x


## 确认第 1 关缺口风险读法是 authored Line2D。
func _stage_1_hazard_reads_authored(inst: Node) -> bool:
	var hazard_root := inst.get_node_or_null("HazardReads")
	if hazard_root == null:
		return false
	for read_name in STAGE_1_HAZARD_READS:
		var read := hazard_root.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	var pit_warning := hazard_root.get_node_or_null("PitWarning") as Line2D
	var correction_warning := hazard_root.get_node_or_null("CorrectionWarning") as Line2D
	return pit_warning.points.size() >= 4 and pit_warning.points[1].y > pit_warning.points[0].y and correction_warning.points.size() >= 4 and correction_warning.points[1].y > correction_warning.points[0].y


## 确认第 1 关当前只点亮本步骤需要的 authored 路线提示。
func _stage_1_only_route_guides_visible(inst: Node, active_names: Array) -> bool:
	var guide_root := inst.get_node_or_null("RouteGuides")
	if guide_root == null:
		return false
	for guide_name in ["MoveGuide", "JumpGuide", "ShortHopGuide", "InteractGuide", "ClimbGuide", "ForwardAttackGuide", "LandingAttackGuide", "SideAttackGuide"]:
		var guide := guide_root.get_node_or_null(guide_name) as CanvasItem
		if guide == null:
			return false
		if guide.visible != active_names.has(guide_name):
			return false
	return true


## 确认第 1 关当前只点亮本步骤需要的 authored 缺口风险读法。
func _stage_1_only_hazard_reads_visible(inst: Node, active_names: Array) -> bool:
	var hazard_root := inst.get_node_or_null("HazardReads")
	if hazard_root == null:
		return false
	for read_name in STAGE_1_HAZARD_READS:
		var read := hazard_root.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != active_names.has(read_name):
			return false
	return true


## 确认第 2 关觉醒/飞行/冲刺训练对象与封闭空战场已 authored。
func _check_stage_2_flight_training(inst: Node) -> void:
	var marker := inst.get_node_or_null("FlightTraining/AwakenMarker")
	var dash_target := inst.get_node_or_null("FlightTraining/DashTarget")
	var dash_chain := inst.get_node_or_null("FlightTraining/DashChainTargets")
	var energy_pockets := inst.get_node_or_null("FlightTraining/EnergyPockets")
	var route_markers := inst.get_node_or_null("FlightTraining/RouteMarkers")
	var recovery_markers := inst.get_node_or_null("FlightTraining/RecoveryMarkers")
	_check("stage_2 authored AwakenMarker", marker is Marker2D)
	_check("stage_2 authored RouteMarkers", route_markers != null and route_markers.get_child_count() >= 3)
	_check("stage_2 authored RecoveryMarkers", recovery_markers != null and recovery_markers.get_child_count() >= 3)
	_check("stage_2 authored DashTarget", dash_target != null and dash_target.has_method("take_player_hit"))
	_check("stage_2 DashTarget requires dash", dash_target != null and str(dash_target.required_attack_kind) == "dash")
	_check("stage_2 authored dash chain", dash_chain != null and dash_chain.get_child_count() >= 3)
	_check("stage_2 dash chain requires dash", _stage_2_dash_chain_requires_dash(inst))
	_check("stage_2 authored dash lane guides", _stage_2_dash_lane_guides_authored(inst))
	_check("stage_2 dash lane guides start hidden", _stage_2_only_dash_guides_visible(inst, []))
	_check("stage_2 authored dash confirm reads", _stage_2_dash_confirm_reads_authored(inst))
	_check("stage_2 dash confirm reads start hidden", _stage_2_dash_confirm_reads_hidden(inst))
	_check("stage_2 authored dash whiff reads", _stage_2_dash_whiff_reads_authored(inst))
	_check("stage_2 dash whiff reads start hidden", _stage_2_dash_whiff_reads_hidden(inst))
	_check("stage_2 authored momentum reads", _stage_2_momentum_reads_authored(inst))
	_check("stage_2 momentum reads start hidden", _stage_2_only_momentum_read_visible(inst, ""))
	_check("stage_2 authored vertical route reads", _stage_2_vertical_route_reads_authored(inst))
	_check("stage_2 vertical route reads start hidden", _stage_2_only_vertical_route_read_visible(inst, ""))
	_check("stage_2 authored energy pockets", energy_pockets != null and energy_pockets.get_child_count() >= 3)
	_check("stage_2 energy pockets have visuals and collision", _stage_2_energy_pockets_authored(inst))
	_check("stage_2 energy pocket refills player", _stage_2_energy_pocket_refills(inst))
	_check("stage_2 dash chain forms zigzag", _stage_2_dash_chain_forms_zigzag(inst))
	_check("stage_2 authored layered background", _stage_2_layered_background_authored(inst))
	_check("stage_2 authored pacing zones", _stage_2_pacing_zones_authored(inst))
	_check("stage_2 has no route platforms", _stage_2_has_no_route_platforms(inst))
	_check("stage_2 dash target floats above start", _stage_2_dash_target_floats_above_start(inst))
	_check("stage_2 start dialogue teaches awakening and dash", _dialogue_title_mentions("res://dialogue/closeai_stage2.dialogue", "start", ["Shift", "左键", "觉醒"]))
	_check("stage_2 authored EnemyWaves root", inst.get_node_or_null("EnemyWaves") is Node2D)
	_check("stage_2 has three authored enemy wave containers", _stage_2_has_authored_enemy_waves(inst))
	_check("stage_2 enemies start authored disabled", _stage_2_enemies_start_disabled(inst))
	_check("stage_2 enemies require fast dash loop", _stage_2_enemies_require_fast_dash_loop(inst))
	_check_stage_2_dash_loop_enemy_behavior(inst)
	_check("stage_2 authored enemy wave guides", _stage_2_enemy_wave_guides_authored(inst))
	_check("stage_2 enemy wave guides start hidden", _stage_2_only_enemy_wave_guides_visible(inst, []))
	_check("stage_2 authored wave pressure reads", _stage_2_wave_pressure_reads_authored(inst))
	_check("stage_2 wave pressure reads start hidden", _stage_2_only_wave_pressure_read_visible(inst, ""))
	_check("stage_2 authored wave speed gates", _stage_2_wave_speed_gate_reads_authored(inst))
	_check("stage_2 wave speed gates start hidden", _stage_2_only_wave_speed_gate_visible(inst, ""))
	_check("stage_2 authored wave recovery reads", _stage_2_wave_recovery_reads_authored(inst))
	_check("stage_2 wave recovery reads start hidden", _stage_2_only_wave_recovery_read_visible(inst, ""))
	_check("stage_2 authored wave energy pockets", _stage_2_wave_energy_pockets_authored(inst))
	_check("stage_2 wave energy pockets start hidden", _stage_2_wave_energy_pockets_hidden(inst))
	_check("stage_2 wave energy pocket refills player", _stage_2_wave_energy_pocket_refills(inst))
	_check("stage_2 authored air combat rooms", _stage_2_air_combat_rooms_authored(inst))
	_check("stage_2 air combat rooms teach distinct dash shapes", _stage_2_air_combat_rooms_have_distinct_shapes(inst))
	_check("stage_2 authored air combat timing reads", _stage_2_air_combat_timing_reads_authored(inst))
	_check("stage_2 air combat rooms start hidden", _stage_2_only_air_combat_room_visible(inst, ""))
	_check("stage_2 air combat timing reads start hidden", _stage_2_only_air_combat_timing_read_visible(inst, ""))
	_check("stage_2 authored arena bounds", _stage_2_arena_bounds_authored(inst))
	_check("stage_2 authored close route", _stage_2_close_route_authored(inst))
	_check("stage_2 close route starts disabled", _stage_2_close_route_enabled(inst) == false)


## 确认冲刺训练靶悬在出生点上方，形成真正空中冲撞目标。
func _stage_2_dash_target_floats_above_start(inst: Node) -> bool:
	var dash_target := inst.get_node_or_null("FlightTraining/DashTarget") as Node2D
	var player := inst.get_node_or_null("Player") as Node2D
	return dash_target != null and player != null and dash_target.global_position.y < player.global_position.y - 120.0


## 确认 Stage2 根节点没有路线 StaticBody2D，避免飞行教学退回平台跳。
func _stage_2_has_no_route_platforms(inst: Node) -> bool:
	for child in inst.get_children():
		if child is StaticBody2D:
			var node_name := String(child.name)
			if node_name.begins_with("Platform") or node_name == "Floor":
				return false
	return true


## 确认指定 dialogue 标题内包含教程关键词。
func _dialogue_title_mentions(path: String, title: String, needles: Array[String]) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var in_title := false
	var body := ""
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("~ "):
			in_title = line.strip_edges() == "~ " + title
			continue
		if in_title:
			if line.begins_with("=>"):
				break
			body += line + "\n"
	for needle in needles:
		if not body.contains(needle):
			return false
	return true


## 确认 Stage2 飞行房间四周有 authored 真实碰撞墙。
func _stage_2_arena_bounds_authored(inst: Node) -> bool:
	var bounds := inst.get_node_or_null("ArenaBounds")
	if bounds == null:
		return false
	for wall_name in ["LeftWall", "RightWall", "Ceiling", "FloorClamp"]:
		var wall := bounds.get_node_or_null(wall_name) as StaticBody2D
		if wall == null or wall.scale != Vector2.ONE:
			return false
		var shape := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null or shape.shape == null or shape.scale != Vector2.ONE:
			return false
	for read_name in ["TopPermissionLine", "LeftPermissionLine", "RightPermissionLine", "BottomPermissionLine"]:
		var read := bounds.get_node_or_null("BoundaryReads/" + read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认 Stage2 清场后显式引导玩家去关闭触发区。
func _stage_2_close_route_authored(inst: Node) -> bool:
	var trigger := inst.get_node_or_null("CloseMomentTrigger") as Area2D
	var guides := inst.get_node_or_null("CloseRouteGuides") as Node2D
	if trigger == null or guides == null:
		return false
	if not trigger.get_node_or_null("CollisionShape2D") is CollisionShape2D:
		return false
	for guide_name in ["ExitWake", "ExitBracket", "PermissionCrack"]:
		var guide := guides.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	return true


## 返回 Stage2 清场出口是否已经可见且可触发。
func _stage_2_close_route_enabled(inst: Node) -> bool:
	var trigger := inst.get_node_or_null("CloseMomentTrigger") as Area2D
	var guides := inst.get_node_or_null("CloseRouteGuides") as CanvasItem
	var shape := trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D if trigger != null else null
	return trigger != null and guides != null and shape != null and guides.visible and trigger.visible and trigger.monitoring and not shape.disabled


## 确认冲撞连锁靶都要求 dash，避免普通攻击跳过空中教学。
func _stage_2_dash_chain_requires_dash(inst: Node) -> bool:
	var dash_chain := inst.get_node_or_null("FlightTraining/DashChainTargets")
	if dash_chain == null:
		return false
	for child in dash_chain.get_children():
		if not child.has_method("take_player_hit") or str(child.required_attack_kind) != "dash":
			return false
	return true


## 确认冲撞连锁路线有上下折线，不是平铺的一排按钮。
func _stage_2_dash_chain_forms_zigzag(inst: Node) -> bool:
	var first := inst.get_node_or_null("FlightTraining/DashTarget") as Node2D
	var a := inst.get_node_or_null("FlightTraining/DashChainTargets/ChainTargetA") as Node2D
	var b := inst.get_node_or_null("FlightTraining/DashChainTargets/ChainTargetB") as Node2D
	var c := inst.get_node_or_null("FlightTraining/DashChainTargets/ChainTargetC") as Node2D
	return first != null and a != null and b != null and c != null and first.global_position.y < a.global_position.y and b.global_position.y < a.global_position.y and b.global_position.y < c.global_position.y


## 确认第 2 关背景有飞行/冲刺层次，不只是单色底。
func _stage_2_layered_background_authored(inst: Node) -> bool:
	var background := inst.get_node_or_null("Background") as CanvasLayer
	var world_backdrop := inst.get_node_or_null("WorldBackdrop") as Node2D
	if background == null or world_backdrop == null:
		return false
	if background.layer >= 0 or world_backdrop.z_index >= 0:
		return false
	var plate := background.get_node_or_null("NetworkCorridorPlate") as TextureRect
	if plate == null or plate.texture == null or plate.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for node_name in ["HorizonBand", "LiftGlow", "DashGlow", "WakeScanA", "WakeScanB"]:
		if not background.get_node_or_null(node_name) is CanvasItem:
			return false
	for node_name in ["LiftMemoryBand", "DashMemoryBand", "CombatMemoryBand", "DistantWakeLine"]:
		if not world_backdrop.get_node_or_null(node_name) is CanvasItem:
			return false
	return true


## 确认第 2 关把安全起飞、冲刺连锁、敌波峰值分成 authored 低层读法。
func _stage_2_pacing_zones_authored(inst: Node) -> bool:
	var zones := inst.get_node_or_null("PacingZones") as Node2D
	var dash_guides := inst.get_node_or_null("FlightTraining/DashLaneGuides") as Node2D
	var wave_guides := inst.get_node_or_null("EnemyWaveGuides") as Node2D
	if zones == null or dash_guides == null or wave_guides == null:
		return false
	if zones.z_index >= dash_guides.z_index or zones.z_index >= wave_guides.z_index:
		return false
	for zone_name in ["LiftSafeZone", "DashChainPeakZone", "EnemyWavePeakZone"]:
		var zone := zones.get_node_or_null(zone_name) as ColorRect
		if zone == null or zone.color.a <= 0.08:
			return false
	for frame_name in ["LiftSafeFrame", "DashChainFrame", "EnemyWaveFrame"]:
		var frame := zones.get_node_or_null(frame_name) as Line2D
		if frame == null or frame.points.size() < 4:
			return false
	return true


## 确认第 2 关冲刺路线用 authored Line2D 表达，可在编辑器里直接调节。
func _stage_2_dash_lane_guides_authored(inst: Node) -> bool:
	var guide_root := inst.get_node_or_null("FlightTraining/DashLaneGuides")
	if guide_root == null:
		return false
	for guide_name in ["LiftGuide", "FirstDashGuide", "ChainGuideA", "ChainGuideB", "ChainGuideC", "BreakLaneGuide"]:
		var guide := guide_root.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	var lift := guide_root.get_node_or_null("LiftGuide") as Line2D
	var chain_a := guide_root.get_node_or_null("ChainGuideA") as Line2D
	var chain_b := guide_root.get_node_or_null("ChainGuideB") as Line2D
	var chain_c := guide_root.get_node_or_null("ChainGuideC") as Line2D
	var break_lane := guide_root.get_node_or_null("BreakLaneGuide") as Line2D
	if lift.points[0].x >= lift.points[lift.points.size() - 1].x:
		return false
	var vertical_span := absf(chain_a.points[1].y - chain_b.points[1].y) + absf(chain_b.points[1].y - chain_c.points[1].y)
	return vertical_span >= 280.0 and break_lane.points[1].x > break_lane.points[0].x


## 确认第 2 关当前只点亮本步骤需要的 authored 路线提示。
func _stage_2_only_dash_guides_visible(inst: Node, active_names: Array) -> bool:
	var guide_root := inst.get_node_or_null("FlightTraining/DashLaneGuides")
	if guide_root == null:
		return false
	for guide_name in ["LiftGuide", "FirstDashGuide", "ChainGuideA", "ChainGuideB", "ChainGuideC", "BreakLaneGuide"]:
		var guide := guide_root.get_node_or_null(guide_name) as CanvasItem
		if guide == null:
			return false
		if guide.visible != active_names.has(guide_name):
			return false
	return true


## 确认第 2 关冲撞命中读法全部由 authored Line2D 组成。
func _stage_2_dash_confirm_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/DashConfirmReads")
	if root_node == null:
		return false
	for read_name in ["FirstDashConfirm", "ChainConfirmA", "ChainConfirmB", "ChainConfirmC"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		for line_name in ["BurstRing", "HitSlash", "NextRay"]:
			var line := root_node.get_node_or_null(read_name + "/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
		var next_ray := root_node.get_node_or_null(read_name + "/NextRay") as Line2D
		if next_ray.points[next_ray.points.size() - 1].length() <= 40.0:
			return false
	return true


## 确认第 2 关冲撞命中读法默认隐藏，不抢路线提示焦点。
func _stage_2_dash_confirm_reads_hidden(inst: Node) -> bool:
	return _stage_2_only_dash_confirm_visible(inst, "")


## 确认当前只有一条 authored 冲撞命中读法可见。
func _stage_2_only_dash_confirm_visible(inst: Node, active_name: String) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/DashConfirmReads")
	if root_node == null:
		return false
	for read_name in ["FirstDashConfirm", "ChainConfirmA", "ChainConfirmB", "ChainConfirmC"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != (read_name == active_name):
			return false
	return true


## 确认第 2 关撞空断速读法全部由 authored Line2D 组成。
func _stage_2_dash_whiff_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/DashWhiffReads")
	if root_node == null:
		return false
	for read_name in ["FirstDashWhiff", "ChainWhiffA", "ChainWhiffB", "ChainWhiffC", "WaveWhiff"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		for line_name in ["ScatterA", "ScatterB", "LostRoute"]:
			var line := root_node.get_node_or_null(read_name + "/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
	return true


## 确认第 2 关撞空读法默认隐藏，不和命中确认混读。
func _stage_2_dash_whiff_reads_hidden(inst: Node) -> bool:
	return _stage_2_only_dash_whiff_visible(inst, "")


## 确认当前只有一条 authored 撞空读法可见。
func _stage_2_only_dash_whiff_visible(inst: Node, active_name: String) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/DashWhiffReads")
	if root_node == null:
		return false
	for read_name in ["FirstDashWhiff", "ChainWhiffA", "ChainWhiffB", "ChainWhiffC", "WaveWhiff"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != (read_name == active_name):
			return false
	return true


## 确认第 2 关冲刺承接线全部由 authored Line2D 组成。
func _stage_2_momentum_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/MomentumReads")
	if root_node == null:
		return false
	for read_name in ["FirstToChainA", "ChainAToB", "ChainBToC", "ChainCToBreak"]:
		var read := root_node.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
		if read.points[read.points.size() - 1].x <= read.points[0].x:
			return false
	return true


## 确认当前只有一条 authored 高速承接线可见。
func _stage_2_only_momentum_read_visible(inst: Node, active_name: String) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/MomentumReads")
	if root_node == null:
		return false
	for read_name in ["FirstToChainA", "ChainAToB", "ChainBToC", "ChainCToBreak"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != (read_name == active_name):
			return false
	return true


## 确认第 2 关高低差/补能节奏读法全部由 authored Line2D 组成。
func _stage_2_vertical_route_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/VerticalRouteReads")
	if root_node == null:
		return false
	for read_name in ["HighLowForkRead", "DropRecoveryRead", "EnergyRhythmRead"]:
		var read := root_node.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	var fork := root_node.get_node_or_null("HighLowForkRead") as Line2D
	var drop := root_node.get_node_or_null("DropRecoveryRead") as Line2D
	return fork.points.size() >= 4 and drop.points[drop.points.size() - 1].x < drop.points[0].x


## 确认当前只有一条 authored 高低差节奏读法可见。
func _stage_2_only_vertical_route_read_visible(inst: Node, active_name: String) -> bool:
	var root_node := inst.get_node_or_null("FlightTraining/VerticalRouteReads")
	if root_node == null:
		return false
	for read_name in ["HighLowForkRead", "DropRecoveryRead", "EnergyRhythmRead"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != (read_name == active_name):
			return false
	return true


## 确认补能口不是不可见 Marker，而是 authored Area2D + 可读视觉。
func _stage_2_energy_pockets_authored(inst: Node) -> bool:
	var energy_pockets := inst.get_node_or_null("FlightTraining/EnergyPockets")
	if energy_pockets == null:
		return false
	for child in energy_pockets.get_children():
		if not child is Area2D:
			return false
		if not child.has_method("_on_body_entered"):
			return false
		if not child.get_node_or_null("CollisionShape2D") is CollisionShape2D:
			return false
		if not child.get_node_or_null("Visual") is CanvasItem:
			return false
		if not child.get_node_or_null("Pulse") is CanvasItem:
			return false
	return true


## 确认玩家穿过补能口会拿到能量，形成冲撞连锁循环。
func _stage_2_energy_pocket_refills(inst: Node) -> bool:
	var player := inst.get_node_or_null("Player")
	var pocket := inst.get_node_or_null("FlightTraining/EnergyPockets/PocketA")
	if player == null or pocket == null or not player.has_method("drain_energy") or not pocket.has_method("_on_body_entered"):
		return false
	player.drain_energy(70.0)
	var before: float = player.energy
	pocket._on_body_entered(player)
	return player.energy > before


## 确认安全飞行教学段不依赖运行时先关敌人的时序。
func _stage_2_enemies_start_disabled(inst: Node) -> bool:
	for enemy_path in ["EnemyWaves/Wave1/Enemy1", "EnemyWaves/Wave2/Enemy2", "EnemyWaves/Wave3/Enemy3"]:
		var enemy := inst.get_node_or_null(enemy_path)
		if enemy == null or not ("starts_enabled" in enemy) or enemy.starts_enabled:
			return false
	return true


## 确认第 2 关敌人要求高速冲撞并给回能，不能被普通释放跳过。
func _stage_2_enemies_require_fast_dash_loop(inst: Node) -> bool:
	var expected := {
		"EnemyWaves/Wave1/Enemy1": [780.0, 22.0],
		"EnemyWaves/Wave2/Enemy2": [860.0, 26.0],
		"EnemyWaves/Wave3/Enemy3": [940.0, 32.0],
	}
	for enemy_path in expected.keys():
		var enemy := inst.get_node_or_null(enemy_path)
		if enemy == null or not enemy.has_method("take_player_hit"):
			return false
		if not ("required_attack_kind" in enemy) or str(enemy.required_attack_kind) != "dash":
			return false
		if not ("min_hit_speed" in enemy) or enemy.min_hit_speed < expected[enemy_path][0]:
			return false
		if not ("reward_energy" in enemy) or enemy.reward_energy < expected[enemy_path][1]:
			return false
	return true


## 验证 dash-loop 敌人拒绝错误输入，并在高速冲撞命中后回能。
func _check_stage_2_dash_loop_enemy_behavior(inst: Node) -> void:
	var player := inst.get_node_or_null("Player")
	var packed := load("res://scenes/enemy.tscn")
	if player == null or packed == null:
		_check("stage_2 dash-loop behavior prerequisites", false)
		return
	var enemy: Node = packed.instantiate()
	if enemy == null:
		_check("stage_2 dash-loop enemy instantiates", false)
		return
	enemy.required_attack_kind = "dash"
	enemy.min_hit_speed = 900.0
	enemy.reward_energy = 24.0
	enemy.starts_enabled = true
	root.add_child(enemy)
	_stage_2_dash_loop_enemy_defeated = false
	if not enemy.defeated.is_connected(_on_stage_2_dash_loop_enemy_defeated):
		enemy.defeated.connect(_on_stage_2_dash_loop_enemy_defeated)
	player.velocity = Vector2(1100.0, 0.0)
	enemy.take_player_hit(1, &"forward", player)
	_check("stage_2 dash-loop rejects forward hit", not _stage_2_dash_loop_enemy_defeated and enemy.hp > 0)
	player.velocity = Vector2(400.0, 0.0)
	enemy.take_player_hit(1, &"dash", player)
	_check("stage_2 dash-loop rejects slow dash", not _stage_2_dash_loop_enemy_defeated and enemy.hp > 0)
	if player.has_method("drain_energy"):
		player.drain_energy(70.0)
	var before: float = player.energy
	player.velocity = Vector2(1120.0, 0.0)
	enemy.take_player_hit(1, &"dash", player)
	_check("stage_2 dash-loop accepts fast dash", _stage_2_dash_loop_enemy_defeated and enemy.hp <= 0)
	_check("stage_2 dash-loop rewards energy", player.energy > before)
	if is_instance_valid(enemy):
		enemy.queue_free()


## 记录独立 dash-loop 敌人测试中的 defeated 信号。
func _on_stage_2_dash_loop_enemy_defeated() -> void:
	_stage_2_dash_loop_enemy_defeated = true


## 确认第 2 关逐波战斗读线和安全点都 authored，方便编辑器拖拽。
func _stage_2_enemy_wave_guides_authored(inst: Node) -> bool:
	var guide_root := inst.get_node_or_null("EnemyWaveGuides")
	if guide_root == null:
		return false
	for guide_name in ["Wave1ApproachGuide", "Wave2AngleGuide", "Wave3BreakGuide"]:
		var guide := guide_root.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	var wave2 := guide_root.get_node_or_null("Wave2AngleGuide") as Line2D
	var rest_points := guide_root.get_node_or_null("SafeRestPoints")
	if rest_points == null:
		return false
	for marker_name in ["LowRest", "AngleRest", "BreakRest"]:
		if not rest_points.get_node_or_null(marker_name) is Marker2D:
			return false
	return wave2.points.size() >= 3 and wave2.points[1].y < wave2.points[0].y


## 确认第 2 关波次压迫边界由 authored Line2D 承载。
func _stage_2_wave_pressure_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("EnemyWaveGuides/PressureReads")
	if root_node == null:
		return false
	for read_name in ["LowPressureBand", "AnglePressureBand", "BreakPressureBand"]:
		var read := root_node.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 4:
			return false
	return true


## 确认当前只点亮当前波次的高低压迫边界。
func _stage_2_only_wave_pressure_read_visible(inst: Node, active_name: String) -> bool:
	var root_node := inst.get_node_or_null("EnemyWaveGuides/PressureReads")
	if root_node == null:
		return false
	for read_name in ["LowPressureBand", "AnglePressureBand", "BreakPressureBand"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != (read_name == active_name):
			return false
	return true


## 确认第 2 关三段速度门由 authored Line2D 组成，并对应贴近/切上/破线三种路线。
func _stage_2_wave_speed_gate_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("EnemyWaveGuides/SpeedGateReads")
	if root_node == null:
		return false
	for read_name in ["LowSpeedGate", "AngleSpeedGate", "BreakSpeedGate"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		for line_name in ["ApproachRail", "CommitGate", "ExitWake"]:
			var line := root_node.get_node_or_null(read_name + "/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
	var low_rail := root_node.get_node_or_null("LowSpeedGate/ApproachRail") as Line2D
	var angle_rail := root_node.get_node_or_null("AngleSpeedGate/ApproachRail") as Line2D
	var break_wake := root_node.get_node_or_null("BreakSpeedGate/ExitWake") as Line2D
	if low_rail == null or angle_rail == null or break_wake == null:
		return false
	var low_lift := absf(low_rail.points[0].y - low_rail.points[low_rail.points.size() - 1].y)
	var angle_lift := angle_rail.points[0].y - angle_rail.points[angle_rail.points.size() - 1].y
	var break_push := break_wake.points[break_wake.points.size() - 1].x - break_wake.points[0].x
	return low_lift < 60.0 and angle_lift > 120.0 and break_push > 80.0


## 确认当前只显示当前波次的速度门。
func _stage_2_only_wave_speed_gate_visible(inst: Node, active_name: String) -> bool:
	var root_node := inst.get_node_or_null("EnemyWaveGuides/SpeedGateReads")
	if root_node == null:
		return false
	for read_name in ["LowSpeedGate", "AngleSpeedGate", "BreakSpeedGate"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != (read_name == active_name):
			return false
	return true


## 确认第 2 关撞空恢复路线由 authored Line2D 承载。
func _stage_2_wave_recovery_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("EnemyWaveGuides/RecoveryReads")
	if root_node == null:
		return false
	for read_name in ["LowRecoveryRead", "AngleRecoveryRead", "BreakRecoveryRead"]:
		var read := root_node.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
		if read.points[read.points.size() - 1].x >= read.points[0].x:
			return false
	return true


## 确认当前只显示当前波次撞空后的恢复路线。
func _stage_2_only_wave_recovery_read_visible(inst: Node, active_name: String) -> bool:
	var root_node := inst.get_node_or_null("EnemyWaveGuides/RecoveryReads")
	if root_node == null:
		return false
	for read_name in ["LowRecoveryRead", "AngleRecoveryRead", "BreakRecoveryRead"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible != (read_name == active_name):
			return false
	return true


## 确认第 2 关清场补能口由 authored EnergyPocket 承载。
func _stage_2_wave_energy_pockets_authored(inst: Node) -> bool:
	var pocket_root := inst.get_node_or_null("EnemyWaveGuides/WaveEnergyPockets")
	if pocket_root == null:
		return false
	for pocket_name in ["LowPocket", "AnglePocket", "BreakPocket"]:
		var pocket := pocket_root.get_node_or_null(pocket_name)
		if not pocket is Area2D:
			return false
		if not pocket.has_method("_on_body_entered"):
			return false
		if not pocket.get_node_or_null("CollisionShape2D") is CollisionShape2D:
			return false
		if not pocket.get_node_or_null("Visual") is CanvasItem:
			return false
		if not pocket.get_node_or_null("Pulse") is CanvasItem:
			return false
	return true


## 确认清场补能口默认不亮，等波次开始后再给资源路线。
func _stage_2_wave_energy_pockets_hidden(inst: Node) -> bool:
	return _stage_2_only_wave_energy_pockets_visible(inst, [])


## 确认清场补能口能真的回能，而不是只当装饰读法。
func _stage_2_wave_energy_pocket_refills(inst: Node) -> bool:
	var player := inst.get_node_or_null("Player")
	var pocket := inst.get_node_or_null("EnemyWaveGuides/WaveEnergyPockets/LowPocket")
	if player == null or pocket == null or not player.has_method("drain_energy") or not pocket.has_method("_on_body_entered"):
		return false
	player.drain_energy(80.0)
	var before: float = player.energy
	pocket._on_body_entered(player)
	return player.energy > before


## 确认第 2 关三段空战房间有可拖拽节拍点和路线读线。
func _stage_2_air_combat_rooms_authored(inst: Node) -> bool:
	var room_root := inst.get_node_or_null("AirCombatRooms")
	if room_root == null:
		return false
	for room_name in ["LowRoom", "AngleRoom", "BreakRoom"]:
		var room := room_root.get_node_or_null(room_name)
		if room == null:
			return false
		for marker_name in ["Entry", "Apex", "Exit"]:
			if not room.get_node_or_null(marker_name) is Marker2D:
				return false
		var route := room.get_node_or_null("RouteRead") as Line2D
		if route == null or route.points.size() < 3:
			return false
		if not room.get_node_or_null("TimingGate") is Marker2D:
			return false
		if not room.get_node_or_null("TimingRead") is CanvasItem:
			return false
		for read_name in ["FloorRead", "CeilingRead"]:
			var boundary := room.get_node_or_null(read_name) as Line2D
			if boundary == null or boundary.points.size() < 2:
				return false
		var entry := room.get_node_or_null("Entry") as Marker2D
		var apex := room.get_node_or_null("Apex") as Marker2D
		var exit := room.get_node_or_null("Exit") as Marker2D
		if entry.global_position.x >= exit.global_position.x:
			return false
		if room_name == "AngleRoom" and apex.global_position.y >= entry.global_position.y:
			return false
	return true


## 确认三段空战房间不是同一条斜线，而是分别教贴近、折线抬升、突破。
func _stage_2_air_combat_rooms_have_distinct_shapes(inst: Node) -> bool:
	var low_entry := inst.get_node_or_null("AirCombatRooms/LowRoom/Entry") as Marker2D
	var low_apex := inst.get_node_or_null("AirCombatRooms/LowRoom/Apex") as Marker2D
	var low_exit := inst.get_node_or_null("AirCombatRooms/LowRoom/Exit") as Marker2D
	var angle_entry := inst.get_node_or_null("AirCombatRooms/AngleRoom/Entry") as Marker2D
	var angle_apex := inst.get_node_or_null("AirCombatRooms/AngleRoom/Apex") as Marker2D
	var angle_exit := inst.get_node_or_null("AirCombatRooms/AngleRoom/Exit") as Marker2D
	var break_entry := inst.get_node_or_null("AirCombatRooms/BreakRoom/Entry") as Marker2D
	var break_apex := inst.get_node_or_null("AirCombatRooms/BreakRoom/Apex") as Marker2D
	var break_exit := inst.get_node_or_null("AirCombatRooms/BreakRoom/Exit") as Marker2D
	if low_entry == null or low_apex == null or low_exit == null or angle_entry == null or angle_apex == null or angle_exit == null or break_entry == null or break_apex == null or break_exit == null:
		return false
	var low_lift := low_entry.global_position.y - low_exit.global_position.y
	var angle_lift := angle_entry.global_position.y - angle_exit.global_position.y
	var break_lift := break_entry.global_position.y - break_exit.global_position.y
	var low_is_low_and_flat := low_lift > 0.0 and low_lift < 90.0 and absf(low_entry.global_position.y - low_apex.global_position.y) < 48.0
	var angle_is_steep := angle_lift > low_lift * 2.2 and angle_apex.global_position.y < angle_entry.global_position.y and angle_exit.global_position.y < angle_apex.global_position.y
	var break_has_horizontal_commit := absf(break_entry.global_position.y - break_apex.global_position.y) < break_lift and break_exit.global_position.y < break_apex.global_position.y
	return low_is_low_and_flat and angle_is_steep and break_has_horizontal_commit


## 确认每个空战房间都有 authored 节奏门线，教玩家进窗口后立刻冲撞。
func _stage_2_air_combat_timing_reads_authored(inst: Node) -> bool:
	var room_root := inst.get_node_or_null("AirCombatRooms")
	if room_root == null:
		return false
	for room_name in ["LowRoom", "AngleRoom", "BreakRoom"]:
		var gate := room_root.get_node_or_null(room_name + "/TimingGate") as Marker2D
		var timing := room_root.get_node_or_null(room_name + "/TimingRead") as CanvasItem
		if gate == null or timing == null:
			return false
		for line_name in ["ApproachTick", "CommitWindow", "ExitTick"]:
			var line := room_root.get_node_or_null(room_name + "/TimingRead/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
	return true


## 确认第 2 关当前只点亮当前波次需要看的 authored 战斗读线。
func _stage_2_only_enemy_wave_guides_visible(inst: Node, active_names: Array) -> bool:
	var guide_root := inst.get_node_or_null("EnemyWaveGuides")
	if guide_root == null:
		return false
	for guide_name in ["Wave1ApproachGuide", "Wave2AngleGuide", "Wave3BreakGuide"]:
		var guide := guide_root.get_node_or_null(guide_name) as CanvasItem
		if guide == null:
			return false
		if guide.visible != active_names.has(guide_name):
			return false
	return true


## 确认第 2 关当前只点亮当前波次需要的 authored 补能口。
func _stage_2_only_wave_energy_pockets_visible(inst: Node, active_names: Array) -> bool:
	var pocket_root := inst.get_node_or_null("EnemyWaveGuides/WaveEnergyPockets")
	if pocket_root == null:
		return false
	if pocket_root.visible != not active_names.is_empty():
		return false
	for pocket_name in ["LowPocket", "AnglePocket", "BreakPocket"]:
		var pocket_node := pocket_root.get_node_or_null(pocket_name)
		var pocket := pocket_node as CanvasItem
		var shape := pocket_node.get_node_or_null("CollisionShape2D") as CollisionShape2D if pocket_node != null else null
		if pocket == null or pocket_node == null or shape == null:
			return false
		if pocket.visible != active_names.has(pocket_name):
			return false
		var active := active_names.has(pocket_name)
		if pocket_node is Area2D and ((pocket_node as Area2D).monitoring != active or shape.disabled == active):
			return false
	return true


## 确认第 2 关当前只点亮一个空战房间节拍层。
func _stage_2_only_air_combat_room_visible(inst: Node, active_name: String) -> bool:
	var room_root := inst.get_node_or_null("AirCombatRooms")
	if room_root == null:
		return false
	for room_name in ["LowRoom", "AngleRoom", "BreakRoom"]:
		var room := room_root.get_node_or_null(room_name) as CanvasItem
		if room == null:
			return false
		if room.visible != (room_name == active_name):
			return false
	return true


## 确认第 2 关当前只点亮当前空战房的节奏门读法。
func _stage_2_only_air_combat_timing_read_visible(inst: Node, active_name: String) -> bool:
	var room_root := inst.get_node_or_null("AirCombatRooms")
	if room_root == null:
		return false
	for room_name in ["LowRoom", "AngleRoom", "BreakRoom"]:
		var timing := room_root.get_node_or_null(room_name + "/TimingRead") as CanvasItem
		if timing == null:
			return false
		if timing.visible != (room_name == active_name):
			return false
	return true


## 确认第 2 关敌人波次由 authored 容器表达，方便编辑器拖拽调整。
func _stage_2_has_authored_enemy_waves(inst: Node) -> bool:
	var waves := inst.get_node_or_null("EnemyWaves")
	if waves == null:
		return false
	for wave_path in ["Wave1/Enemy1", "Wave2/Enemy2", "Wave3/Enemy3"]:
		var enemy := waves.get_node_or_null(wave_path)
		if enemy == null or not enemy.is_in_group("enemy"):
			return false
	return true


## 确认第 2 关清场段按 authored 敌人逐波启用，而不是一次性全开。
func _check_stage_2_enemy_waves(inst: Node) -> void:
	var stage := inst
	var dash_target := inst.get_node_or_null("FlightTraining/DashTarget")
	var chain_a := inst.get_node_or_null("FlightTraining/DashChainTargets/ChainTargetA")
	var chain_b := inst.get_node_or_null("FlightTraining/DashChainTargets/ChainTargetB")
	var chain_c := inst.get_node_or_null("FlightTraining/DashChainTargets/ChainTargetC")
	var enemy1 := inst.get_node_or_null("EnemyWaves/Wave1/Enemy1")
	var enemy2 := inst.get_node_or_null("EnemyWaves/Wave2/Enemy2")
	var enemy3 := inst.get_node_or_null("EnemyWaves/Wave3/Enemy3")
	if dash_target == null or chain_a == null or chain_b == null or chain_c == null or enemy1 == null or enemy2 == null or enemy3 == null:
		_check("stage_2 enemy wave prerequisites", false)
		return
	stage._on_stage_ready()
	await process_frame
	_check("stage_2 dash confirms hidden after ready", _stage_2_dash_confirm_reads_hidden(inst))
	_check("stage_2 dash whiff reads hidden after ready", _stage_2_dash_whiff_reads_hidden(inst))
	_check("stage_2 momentum reads hidden after ready", _stage_2_only_momentum_read_visible(inst, ""))
	_check("stage_2 vertical route reads hidden after ready", _stage_2_only_vertical_route_read_visible(inst, ""))
	_check("stage_2 wave pressure reads hidden after ready", _stage_2_only_wave_pressure_read_visible(inst, ""))
	_check("stage_2 wave speed gates hidden after ready", _stage_2_only_wave_speed_gate_visible(inst, ""))
	_check("stage_2 wave recovery reads hidden after ready", _stage_2_only_wave_recovery_read_visible(inst, ""))
	stage._on_player_morph_changed(true)
	await process_frame
	_check("stage_2 fly step shows lift guide only", _stage_2_only_dash_guides_visible(inst, ["LiftGuide"]))
	_check("stage_2 fly step shows high-low route read", _stage_2_only_vertical_route_read_visible(inst, "HighLowForkRead"))
	stage._advance_to_dash_target()
	await process_frame
	_check("stage_2 dash target shows first dash guide only", _stage_2_only_dash_guides_visible(inst, ["FirstDashGuide"]))
	_check("stage_2 dash target shows energy rhythm read", _stage_2_only_vertical_route_read_visible(inst, "EnergyRhythmRead"))
	stage._on_player_dash_whiffed(Vector2.RIGHT)
	await process_frame
	_check("stage_2 first dash whiff shows tempo break read", _stage_2_only_dash_whiff_visible(inst, "FirstDashWhiff"))
	_check("stage_2 first dash whiff clears carry-through read", _stage_2_only_momentum_read_visible(inst, ""))
	stage._step = 2
	stage._on_dash_target_completed(dash_target, &"dash")
	await process_frame
	_check("stage_2 first dash opens chain A only", chain_a.monitoring and not chain_b.monitoring and not chain_c.monitoring)
	_check("stage_2 chain A guide only", _stage_2_only_dash_guides_visible(inst, ["ChainGuideA"]))
	_check("stage_2 chain A shows drop recovery read", _stage_2_only_vertical_route_read_visible(inst, "DropRecoveryRead"))
	_check("stage_2 first dash flashes confirm read", _stage_2_only_dash_confirm_visible(inst, "FirstDashConfirm"))
	_check("stage_2 first hit clears dash whiff read", _stage_2_dash_whiff_reads_hidden(inst))
	_check("stage_2 first dash shows chain A momentum read", _stage_2_only_momentum_read_visible(inst, "FirstToChainA"))
	_check("stage_2 enemies stay disabled during dash chain", not enemy1.visible and not enemy2.visible and not enemy3.visible)
	stage._on_player_dash_whiffed(Vector2.RIGHT)
	await process_frame
	_check("stage_2 chain A dash whiff shows tempo break read", _stage_2_only_dash_whiff_visible(inst, "ChainWhiffA"))
	stage._on_dash_chain_target_completed(chain_a, &"dash")
	await process_frame
	_check("stage_2 chain A opens chain B", chain_b.monitoring and not chain_c.monitoring)
	_check("stage_2 chain B guide only", _stage_2_only_dash_guides_visible(inst, ["ChainGuideB"]))
	_check("stage_2 chain B shows high-low route read", _stage_2_only_vertical_route_read_visible(inst, "HighLowForkRead"))
	_check("stage_2 chain A flashes confirm read", _stage_2_only_dash_confirm_visible(inst, "ChainConfirmA"))
	_check("stage_2 chain A hit clears dash whiff read", _stage_2_dash_whiff_reads_hidden(inst))
	_check("stage_2 chain A shows chain B momentum read", _stage_2_only_momentum_read_visible(inst, "ChainAToB"))
	stage._on_dash_chain_target_completed(chain_b, &"dash")
	await process_frame
	_check("stage_2 chain B opens chain C", chain_c.monitoring)
	_check("stage_2 chain C keeps break guide", _stage_2_only_dash_guides_visible(inst, ["ChainGuideC", "BreakLaneGuide"]))
	_check("stage_2 chain C shows energy rhythm read", _stage_2_only_vertical_route_read_visible(inst, "EnergyRhythmRead"))
	_check("stage_2 chain B flashes confirm read", _stage_2_only_dash_confirm_visible(inst, "ChainConfirmB"))
	_check("stage_2 chain B shows chain C momentum read", _stage_2_only_momentum_read_visible(inst, "ChainBToC"))
	stage._on_dash_chain_target_completed(chain_c, &"dash")
	await process_frame
	_check("stage_2 wave one enables enemy1 only", enemy1.visible and not enemy2.visible and not enemy3.visible)
	_check("stage_2 enemy waves keep break guide", _stage_2_only_dash_guides_visible(inst, ["BreakLaneGuide"]))
	_check("stage_2 chain C flashes confirm read", _stage_2_only_dash_confirm_visible(inst, "ChainConfirmC"))
	_check("stage_2 chain C shows break momentum read", _stage_2_only_momentum_read_visible(inst, "ChainCToBreak"))
	_check("stage_2 wave one shows approach guide", _stage_2_only_enemy_wave_guides_visible(inst, ["Wave1ApproachGuide"]))
	_check("stage_2 wave one shows low pressure read", _stage_2_only_wave_pressure_read_visible(inst, "LowPressureBand"))
	_check("stage_2 wave one shows low speed gate", _stage_2_only_wave_speed_gate_visible(inst, "LowSpeedGate"))
	_check("stage_2 wave one shows low energy pocket", _stage_2_only_wave_energy_pockets_visible(inst, ["LowPocket"]))
	_check("stage_2 wave one shows low air room", _stage_2_only_air_combat_room_visible(inst, "LowRoom"))
	_check("stage_2 wave one shows low timing read", _stage_2_only_air_combat_timing_read_visible(inst, "LowRoom"))
	stage._on_player_dash_whiffed(Vector2.RIGHT)
	await process_frame
	_check("stage_2 enemy wave dash whiff shows combat miss read", _stage_2_only_dash_whiff_visible(inst, "WaveWhiff"))
	_check("stage_2 wave one dash whiff shows low recovery read", _stage_2_only_wave_recovery_read_visible(inst, "LowRecoveryRead"))
	stage._on_enemy_defeated()
	await process_frame
	_check("stage_2 wave two enables enemy2 after enemy1", enemy2.visible and not enemy3.visible)
	_check("stage_2 wave two shows angle guide", _stage_2_only_enemy_wave_guides_visible(inst, ["Wave2AngleGuide"]))
	_check("stage_2 wave two shows angle pressure read", _stage_2_only_wave_pressure_read_visible(inst, "AnglePressureBand"))
	_check("stage_2 wave two shows angle speed gate", _stage_2_only_wave_speed_gate_visible(inst, "AngleSpeedGate"))
	_check("stage_2 wave two clears old recovery read", _stage_2_only_wave_recovery_read_visible(inst, ""))
	_check("stage_2 wave two shows angle energy pocket", _stage_2_only_wave_energy_pockets_visible(inst, ["AnglePocket"]))
	_check("stage_2 wave two shows angle air room", _stage_2_only_air_combat_room_visible(inst, "AngleRoom"))
	_check("stage_2 wave two shows angle timing read", _stage_2_only_air_combat_timing_read_visible(inst, "AngleRoom"))
	stage._on_enemy_defeated()
	await process_frame
	_check("stage_2 wave three enables enemy3 after enemy2", enemy3.visible)
	_check("stage_2 wave three shows break guide", _stage_2_only_enemy_wave_guides_visible(inst, ["Wave3BreakGuide"]))
	_check("stage_2 wave three shows break pressure read", _stage_2_only_wave_pressure_read_visible(inst, "BreakPressureBand"))
	_check("stage_2 wave three shows break speed gate", _stage_2_only_wave_speed_gate_visible(inst, "BreakSpeedGate"))
	_check("stage_2 wave three shows break energy pocket", _stage_2_only_wave_energy_pockets_visible(inst, ["BreakPocket"]))
	_check("stage_2 wave three shows break air room", _stage_2_only_air_combat_room_visible(inst, "BreakRoom"))
	_check("stage_2 wave three shows break timing read", _stage_2_only_air_combat_timing_read_visible(inst, "BreakRoom"))
	stage._on_enemy_defeated()
	await process_frame
	_check("stage_2 final wave opens close route", _stage_2_close_route_enabled(inst))
	_check("stage_2 final wave does not auto-start close moment", not stage._close_moment_started)
	_check("stage_2 final wave hides combat reads", _stage_2_only_enemy_wave_guides_visible(inst, []) and _stage_2_only_wave_energy_pockets_visible(inst, []) and _stage_2_only_air_combat_room_visible(inst, ""))


## 确认第三关终战纵切由 authored Boss/HUD/门承载。
func _check_stage_3_finale_nodes(inst: Node) -> void:
	var boss := inst.get_node_or_null("FinalBoss")
	var boss_hud := inst.get_node_or_null("BossHud")
	var gate := inst.get_node_or_null("InternetGate")
	var hint := inst.get_node_or_null("ArenaLayer/ArenaHint")
	_check("stage_3 authored FinalBoss", boss != null and boss.has_method("activate") and boss.has_method("take_hit"))
	_check("stage_3 authored BossHud", boss_hud != null and boss_hud.has_method("set_boss_health"))
	_check("stage_3 authored InternetGate", gate != null and gate.has_method("activate"))
	_check("stage_3 finale node guard passes", inst.has_method("_require_finale_nodes") and inst._require_finale_nodes())
	_check("stage_3 authored finale hint", hint is Label)
	_check("stage_3 authored desktop layer", inst.get_node_or_null("DesktopLayer/DesktopGrid") is Control)
	_check("stage_3 authored window frame gates", inst.get_node_or_null("WindowFrame/PhaseGateLeft") is CanvasItem and inst.get_node_or_null("WindowFrame/PhaseGateRight") is CanvasItem)
	_check("stage_3 authored window battle arena", inst.has_method("_has_authored_window_battle_arena") and inst._has_authored_window_battle_arena())
	_check("stage_3 authored arena bounds", _stage_3_arena_bounds_authored(inst))
	_check("stage_3 authored window depth reads", _stage_3_window_depth_reads_authored(inst))
	_check("stage_3 authored phase pacing reads", _stage_3_phase_pacing_reads_authored(inst))
	_check("stage_3 authored platform read edges", _stage_3_platform_read_edges_authored(inst))
	_check("stage_3 window arena has safe pockets", _stage_3_window_arena_safe_pockets(inst))
	_check("stage_3 phase three has rest energy pockets", _stage_3_phase_three_rest_pockets_authored(inst))
	_check("stage_3 rest energy pocket refills player", _stage_3_rest_pocket_refills(inst))
	_check("stage_3 phase reads start in authored state", _stage_3_phase_reads_start_authored(inst))
	_check("stage_3 authored desktop risk reads", _stage_3_desktop_risk_reads_authored(inst))
	_check("stage_3 desktop risk reads start hidden", _stage_3_desktop_risk_reads_hidden(inst))
	_check("stage_3 desktop tears start closed", _stage_3_desktop_tears_count(inst, 0))
	_check("stage_3 authored pierce progress reads", _stage_3_pierce_progress_reads_authored(inst))
	_check("stage_3 pierce progress reads start hidden", _stage_3_pierce_progress_reads_count(inst, 0))
	_check("stage_3 authored desktop instability reads", _stage_3_desktop_instability_reads_authored(inst))
	_check("stage_3 desktop instability reads start hidden", _stage_3_desktop_instability_reads_count(inst, 0))
	_check("stage_3 authored exit route guides", _stage_3_exit_route_guides_authored(inst))
	_check("stage_3 exit route starts hidden", inst.get_node_or_null("ExitRouteGuides") is CanvasItem and not (inst.get_node("ExitRouteGuides") as CanvasItem).visible)
	_check("stage_3 request pool authored cards", boss != null and boss.get_node_or_null("RequestPool") != null and boss.get_node("RequestPool").get_child_count() >= 6)
	_check("stage_3 request cards authored kind reads", _stage_3_request_cards_kind_reads_authored(inst))
	_check("stage_3 request spawn markers authored", boss != null and boss.get_node_or_null("RequestSpawns/Top") is Marker2D and boss.get_node_or_null("RequestSpawns/Left") is Marker2D)
	_check("stage_3 request spawn telegraphs authored", _stage_3_request_spawn_telegraphs_authored(inst))
	_check("stage_3 boss authored combat VFX", boss != null and boss.get_node_or_null("CombatVFX/ImpactBurst") is Node2D and boss.get_node_or_null("CombatVFX/ShieldCrack") is Node2D and boss.get_node_or_null("CombatVFX/PhaseBurst") is GPUParticles2D)
	_check("stage_3 authored dash warning read", _stage_3_dash_warning_read_authored(inst))
	_check("stage_3 authored dash whiff read", _stage_3_dash_whiff_read_authored(inst))
	_check("stage_3 authored dash rhythm read", _stage_3_dash_rhythm_read_authored(inst))
	_check("stage_3 authored window truth read", _stage_3_window_truth_read_authored(inst))
	_check("stage_3 authored phase three pressure reads", _stage_3_phase_three_pressure_reads_authored(inst))
	if inst.has_method("_apply_stage_phase"):
		inst._apply_stage_phase(2)
		await process_frame
		_check("stage_3 phase two shows request lanes", _stage_3_phase_two_request_lanes_visible(inst))
		inst._apply_stage_phase(3)
		await process_frame
		_check("stage_3 phase three shows dash route", _stage_3_phase_three_dash_route_visible(inst))
		if inst.has_method("_on_boss_dash_window_changed"):
			inst._on_boss_dash_window_changed(false)
			_check("stage_3 closed dash window dims route", _stage_3_phase_three_dash_route_dimmed(inst))
			_check("stage_3 closed dash window lights rest pockets", _stage_3_phase_three_rest_pockets_readable(inst))
			_check("stage_3 closed dash window shows pressure reads", _stage_3_phase_three_pressure_reads_visible(inst))
			_check("stage_3 closed rhythm read visible", _stage_3_dash_rhythm_response_visible(inst, "ClosedBeat"))
			_check("stage_3 closed dash window shows false aperture", _stage_3_window_truth_response_visible(inst, "false"))
			if inst.has_method("_on_boss_phase_three_pressure_changed"):
				inst._on_boss_phase_three_pressure_changed(&"TopClampSweep", &"telegraph", 0.68)
				_check("stage_3 top pressure read follows boss sweep", _stage_3_only_phase_three_pressure_read_visible(inst, "TopClampRead"))
				inst._on_boss_phase_three_pressure_changed(&"BottomClampSweep", &"active", 1.0)
				_check("stage_3 bottom pressure read follows boss sweep", _stage_3_only_phase_three_pressure_read_visible(inst, "BottomClampRead"))
				inst._on_boss_phase_three_pressure_changed(&"CenterCutSweep", &"telegraph", 0.68)
				_check("stage_3 center pressure read follows boss sweep", _stage_3_only_phase_three_pressure_read_visible(inst, "CenterCutRead"))
				inst._on_boss_phase_three_pressure_changed(&"", &"clear", 0.0)
				_check("stage_3 pressure clear hides sweep read", _stage_3_phase_three_pressure_reads_hidden(inst))
			if inst.has_method("_on_boss_dash_window_warning_changed"):
				inst._on_boss_dash_window_warning_changed(true)
				_check("stage_3 dash warning read lights route", _stage_3_dash_warning_response_visible(inst))
				_check("stage_3 warning hides pressure reads", _stage_3_phase_three_pressure_reads_hidden(inst))
				_check("stage_3 warning rhythm read visible", _stage_3_dash_rhythm_response_visible(inst, "WarningBeat"))
				_check("stage_3 warning keeps false aperture", _stage_3_window_truth_response_visible(inst, "false"))
			if inst.has_method("_on_boss_dash_window_rhythm_changed"):
				inst._on_boss_dash_window_rhythm_changed(&"open", 0.6)
				_check("stage_3 rhythm signal brightens open beat", _stage_3_dash_rhythm_response_visible(inst, "OpenBeat"))
			if inst.has_method("_on_boss_dash_window_aim_changed"):
				var player := inst.get_node_or_null("Player") as Node2D
				var boss_2d := boss as Node2D
				if player != null and boss_2d != null:
					var warning := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead") as Node2D
					var needle := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead/AimNeedle") as Line2D
					var core_line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/CoreDashLine") as Line2D
					var original_warning_position := warning.position if warning != null else Vector2.ZERO
					var original_core_first := core_line.points[0] if core_line != null and core_line.points.size() > 0 else Vector2.ZERO
					var original_tip_global := warning.to_global(needle.points[needle.points.size() - 1]) if warning != null and needle != null and needle.points.size() > 0 else Vector2.ZERO
					player.global_position = boss_2d.global_position + Vector2(210.0, -84.0)
					inst._on_boss_dash_window_aim_changed(true, boss_2d.global_position, player.global_position)
					_check("stage_3 dash warning aim points at player", _stage_3_dash_aim_points_at_target(inst, player.global_position))
					inst._on_boss_dash_window_aim_changed(false, boss_2d.global_position, player.global_position)
					_check("stage_3 dash warning aim restores authored line", _stage_3_dash_aim_restored(inst, original_warning_position, original_core_first, original_tip_global))
			if inst.has_method("_on_boss_dash_window_rejected"):
				inst._on_boss_dash_window_rejected(boss)
				_check("stage_3 rejected dash flashes route read", _stage_3_dash_reject_response_visible(inst))
			if inst.has_method("_on_player_dash_whiffed"):
				inst._on_player_dash_whiffed(Vector2.RIGHT)
				_check("stage_3 player dash whiff flashes miss read", _stage_3_dash_whiff_response_visible(inst))
				_check("stage_3 dash whiff hides reject read", _stage_3_dash_reject_response_hidden(inst))
			inst._on_boss_dash_window_changed(true)
			_check("stage_3 open dash window brightens route", _stage_3_phase_three_dash_route_bright(inst))
			_check("stage_3 open rhythm read visible", _stage_3_dash_rhythm_response_visible(inst, "OpenBeat"))
			_check("stage_3 open dash window shows true aperture", _stage_3_window_truth_response_visible(inst, "true"))
			_check("stage_3 open dash window hides warning read", _stage_3_dash_warning_response_hidden(inst))
			_check("stage_3 open dash window hides whiff read", _stage_3_dash_whiff_response_hidden(inst))
			_check("stage_3 open dash window hides rest pockets", _stage_3_phase_three_rest_pockets_hidden(inst))
			_check("stage_3 open dash window hides pressure reads", _stage_3_phase_three_pressure_reads_hidden(inst))
		if inst.has_method("_on_boss_dash_pierce_confirmed"):
			inst._on_boss_dash_pierce_confirmed(boss)
			_check("stage_3 dash pierce lights desktop tears", _stage_3_dash_pierce_response_visible(inst))
			_check("stage_3 first pierce opens one tear", _stage_3_desktop_tears_count(inst, 1))
			_check("stage_3 first pierce shows one progress read", _stage_3_pierce_progress_reads_count(inst, 1))
			_check("stage_3 first pierce shows first instability read", _stage_3_desktop_instability_reads_count(inst, 1))
			_check("stage_3 first pierce updates hud", _stage_3_pierce_hud_text(inst, "穿透 1/3"))
			inst._on_boss_dash_pierce_confirmed(boss)
			_check("stage_3 second pierce accumulates tears", _stage_3_desktop_tears_count(inst, 2))
			_check("stage_3 second pierce shows two progress reads", _stage_3_pierce_progress_reads_count(inst, 2))
			_check("stage_3 second pierce makes final cue readable", _stage_3_desktop_instability_reads_count(inst, 3) and _stage_3_final_pierce_cue_visible(inst))
			_check("stage_3 second pierce updates hud", _stage_3_pierce_hud_text(inst, "穿透 2/3"))
	if inst.has_method("_on_boss_request_telegraph_started"):
		inst._on_boss_request_telegraph_started(&"Right", false)
		await process_frame
		_check("stage_3 bad request lights desktop risk read", _stage_3_desktop_risk_read_visible(inst, "RightRisk", false))
		inst._on_boss_request_telegraph_finished(&"Right", false)
		await process_frame
		_check("stage_3 request finish hides desktop risk read", _stage_3_desktop_risk_reads_hidden(inst))
	if inst.has_method("_on_boss_defeated"):
		inst._on_boss_defeated()
	_check("stage_3 boss defeat shows exit route and gate", _stage_3_boss_defeat_shows_exit_route(inst))
	_check("stage_3 boss defeat shows full pierce progress", _stage_3_pierce_progress_reads_count(inst, 3))
	_check("stage_3 boss defeat shows full desktop instability", _stage_3_desktop_instability_reads_count(inst, 3))
	await _check_stage_3_internet_gate_finishes_game(inst)


## 确认第三关窗口战场有 authored 深度层，真实桌面不是一张平黑底。
func _stage_3_window_depth_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/WindowDepthReads")
	if root_node == null:
		return false
	for rect_name in ["ArenaPane", "InnerTopShadow", "InnerBottomShadow", "InnerLeftGlow", "InnerRightGlow"]:
		var rect := root_node.get_node_or_null(rect_name) as ColorRect
		if rect == null or rect.color.a <= 0.0:
			return false
	for line_name in ["DesktopLeakA", "DesktopLeakB"]:
		var line := root_node.get_node_or_null(line_name) as Line2D
		if line == null or line.points.size() < 2 or line.default_color.a <= 0.0:
			return false
	return root_node is CanvasItem and (root_node as CanvasItem).z_index < 0


## 确认第三关三阶段节奏底图 authored，给 Boss 行为一个空间梯度。
func _stage_3_phase_pacing_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/PhasePacingReads")
	if root_node == null:
		return false
	for zone_name in ["PhaseOneSweepZone", "PhaseTwoRequestZone", "PhaseThreePierceZone"]:
		var zone := root_node.get_node_or_null(zone_name) as ColorRect
		if zone == null or zone.color.a <= 0.0:
			return false
	for frame_name in ["PhaseOneSweepFrame", "PhaseTwoRequestFrame", "PhaseThreePierceFrame"]:
		var frame := root_node.get_node_or_null(frame_name) as Line2D
		if frame == null or frame.points.size() < 2 or frame.default_color.a <= 0.0:
			return false
	return root_node is CanvasItem and (root_node as CanvasItem).z_index < 0


## 确认第三关平台可读边 authored，避免 Boss 战时落脚点融进窗口背景。
func _stage_3_platform_read_edges_authored(inst: Node) -> bool:
	for platform_path in ["Floor", "LeftPlatform", "RightPlatform", "TopPlatform"]:
		var platform := inst.get_node_or_null(platform_path)
		if platform == null:
			return false
		var top_edge := platform.get_node_or_null("TopEdge") as ColorRect
		var shadow := platform.get_node_or_null("UndersideShadow") as ColorRect
		if top_edge == null or shadow == null:
			return false
		if top_edge.color.a < 0.4 or shadow.color.a < 0.3:
			return false
	return true


## 确认第三关窗口战场有真实 authored 物理墙，不只是视觉边界。
func _stage_3_arena_bounds_authored(inst: Node) -> bool:
	var bounds := inst.get_node_or_null("WindowBattleArena/ArenaBounds")
	if bounds == null:
		return false
	for wall_name in ["LeftWall", "RightWall", "Ceiling", "FloorClamp"]:
		var wall := bounds.get_node_or_null(wall_name) as StaticBody2D
		if wall == null or wall.scale != Vector2.ONE:
			return false
		var shape := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null or shape.shape == null or shape.scale != Vector2.ONE:
			return false
	return true


## 确认第三关窗口战斗空间有可拖拽的安全点 Marker。
func _stage_3_window_arena_safe_pockets(inst: Node) -> bool:
	var arena := inst.get_node_or_null("WindowBattleArena")
	if arena == null:
		return false
	var left := arena.get_node_or_null("SafePockets/LeftRest") as Marker2D
	var top := arena.get_node_or_null("SafePockets/TopRest") as Marker2D
	var right := arena.get_node_or_null("SafePockets/RightRest") as Marker2D
	return left != null and top != null and right != null and left.global_position.x < top.global_position.x and right.global_position.x > top.global_position.x and top.global_position.y < left.global_position.y


## 确认第三关三阶段安全口是实际补能 Area，而不是只给关卡编辑看的 Marker。
func _stage_3_phase_three_rest_pockets_authored(inst: Node) -> bool:
	var pockets := inst.get_node_or_null("WindowBattleArena/PhaseThreeRestPockets")
	if pockets == null or pockets.get_child_count() < 3:
		return false
	for child in pockets.get_children():
		if not child is Area2D:
			return false
		if not child.has_method("_on_body_entered"):
			return false
		if not child.get_node_or_null("CollisionShape2D") is CollisionShape2D:
			return false
		if not child.get_node_or_null("Visual") is CanvasItem:
			return false
		if not child.get_node_or_null("Pulse") is CanvasItem:
			return false
	return true


## 确认三阶段闭窗补能口能真的回能，支撑“等窗口时找安全口”的循环。
func _stage_3_rest_pocket_refills(inst: Node) -> bool:
	var player := inst.get_node_or_null("Player")
	var pocket := inst.get_node_or_null("WindowBattleArena/PhaseThreeRestPockets/LeftPocket")
	if player == null or pocket == null or not player.has_method("drain_energy") or not pocket.has_method("_on_body_entered"):
		return false
	player.drain_energy(60.0)
	var before: float = player.energy
	pocket._on_body_entered(player)
	return player.energy > before


## 确认第三关相位读路由 authored 节点默认承载，不靠脚本创建。
func _stage_3_phase_reads_start_authored(inst: Node) -> bool:
	var phase_one := inst.get_node_or_null("WindowBattleArena/PhaseOneReads") as CanvasItem
	var phase_two := inst.get_node_or_null("WindowBattleArena/PhaseTwoRequests") as CanvasItem
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	return phase_one != null and phase_one.visible and phase_two != null and not phase_two.visible and phase_three != null and not phase_three.visible


## 确认第三关桌面风险读法由 authored Line2D 组成。
func _stage_3_desktop_risk_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/DesktopRiskReads")
	if root_node == null:
		return false
	for risk_name in ["TopRisk", "RightRisk", "BottomRisk", "LeftRisk"]:
		var risk := root_node.get_node_or_null(risk_name) as CanvasItem
		if risk == null:
			return false
		for cue_name in ["GoodCue", "BadCue"]:
			var cue := root_node.get_node_or_null(risk_name + "/" + cue_name) as Line2D
			if cue == null or cue.points.size() < 2:
				return false
	return true


## 确认第三关桌面风险读法默认不会抢信息。
func _stage_3_desktop_risk_reads_hidden(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/DesktopRiskReads")
	if root_node == null:
		return false
	for risk_name in ["TopRisk", "RightRisk", "BottomRisk", "LeftRisk"]:
		var risk := root_node.get_node_or_null(risk_name) as CanvasItem
		if risk == null or risk.visible:
			return false
	return true


## 确认真实桌面裂痕按三阶段冲刺命中次数逐条打开。
func _stage_3_desktop_tears_count(inst: Node, expected_count: int) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/DesktopTears") as CanvasItem
	if root_node == null:
		return false
	var visible_count := 0
	for tear_name in ["TearA", "TearB", "TearC"]:
		var tear := root_node.get_node_or_null(tear_name) as CanvasItem
		if tear == null:
			return false
		if tear.visible:
			visible_count += 1
	return visible_count == expected_count


## 确认三阶段穿透进度读法由 authored Line2D 组成。
func _stage_3_pierce_progress_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/PierceProgressReads")
	if root_node == null:
		return false
	for read_name in ["PierceOne", "PierceTwo", "PierceThree"]:
		var read := root_node.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认三阶段穿透进度读法按命中次数逐条点亮。
func _stage_3_pierce_progress_reads_count(inst: Node, expected_count: int) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/PierceProgressReads") as CanvasItem
	if root_node == null:
		return false
	if root_node.visible != (expected_count > 0):
		return false
	var visible_count := 0
	for read_name in ["PierceOne", "PierceTwo", "PierceThree"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible:
			visible_count += 1
	return visible_count == expected_count


## 确认桌面失稳读法由 authored Line2D 组成。
func _stage_3_desktop_instability_reads_authored(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/DesktopInstabilityReads")
	if root_node == null:
		return false
	for read_name in ["InstabilityOne", "InstabilityTwo", "FinalPierceCue"]:
		var read := root_node.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认桌面失稳读法按穿透进度逐条点亮。
func _stage_3_desktop_instability_reads_count(inst: Node, expected_count: int) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/DesktopInstabilityReads") as CanvasItem
	if root_node == null:
		return false
	if root_node.visible != (expected_count > 0):
		return false
	var visible_count := 0
	for read_name in ["InstabilityOne", "InstabilityTwo", "FinalPierceCue"]:
		var read := root_node.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		if read.visible:
			visible_count += 1
	return visible_count == expected_count


## 确认 2/3 后最后一击读线已经被预告，而不是等胜利后才出现。
func _stage_3_final_pierce_cue_visible(inst: Node) -> bool:
	var root_node := inst.get_node_or_null("WindowBattleArena/DesktopInstabilityReads") as CanvasItem
	var cue := inst.get_node_or_null("WindowBattleArena/DesktopInstabilityReads/FinalPierceCue") as CanvasItem
	return root_node != null and cue != null and root_node.visible and root_node.modulate.a >= 0.7 and cue.visible


## 确认三阶段穿透读法同步到 authored Boss HUD。
func _stage_3_pierce_hud_text(inst: Node, expected_text: String) -> bool:
	var label := inst.get_node_or_null("BossHud/Root/BossFrame/PierceRead") as Label
	return label != null and label.visible and label.text == expected_text


## 确认指定方向只显示当前善恶读法。
func _stage_3_desktop_risk_read_visible(inst: Node, risk_name: String, good: bool) -> bool:
	var risk := inst.get_node_or_null("WindowBattleArena/DesktopRiskReads/" + risk_name) as CanvasItem
	var good_cue := inst.get_node_or_null("WindowBattleArena/DesktopRiskReads/" + risk_name + "/GoodCue") as CanvasItem
	var bad_cue := inst.get_node_or_null("WindowBattleArena/DesktopRiskReads/" + risk_name + "/BadCue") as CanvasItem
	return risk != null and risk.visible and good_cue != null and bad_cue != null and good_cue.visible == good and bad_cue.visible == not good


## 确认二阶段请求读路会随阶段显现。
func _stage_3_phase_two_request_lanes_visible(inst: Node) -> bool:
	var phase_two := inst.get_node_or_null("WindowBattleArena/PhaseTwoRequests") as CanvasItem
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	return phase_two != null and phase_two.visible and phase_three != null and not phase_three.visible


## 确认三阶段冲撞路线会随阶段显现。
func _stage_3_phase_three_dash_route_visible(inst: Node) -> bool:
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	var core_line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/CoreDashLine") as Line2D
	return phase_three != null and phase_three.visible and core_line != null and core_line.points.size() >= 4


## 确认三阶段开窗前的瞄准读法由 authored Line2D 组成。
func _stage_3_dash_warning_read_authored(inst: Node) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead") as CanvasItem
	if read == null or read.visible:
		return false
	for line_name in ["ChargeArcA", "ChargeArcB", "AimNeedle"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead/" + line_name) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## 确认三阶段撞空失准读法由 authored Line2D 组成。
func _stage_3_dash_whiff_read_authored(inst: Node) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWhiffRead") as CanvasItem
	if read == null or read.visible:
		return false
	for line_name in ["WhiffBreakA", "WhiffBreakB", "MissedAperture"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWhiffRead/" + line_name) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## 确认三阶段 Boss 节奏读法由 authored Line2D 组成。
func _stage_3_dash_rhythm_read_authored(inst: Node) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashRhythmRead") as CanvasItem
	if read == null or read.visible:
		return false
	for line_name in ["ClosedBeat", "WarningBeat", "OpenBeat"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashRhythmRead/" + line_name) as Line2D
		if line == null or line.points.size() < 2 or line.visible:
			return false
	return true


## 确认三阶段真假窗口读法由 authored Line2D 组成，且默认不亮。
func _stage_3_window_truth_read_authored(inst: Node) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/WindowTruthRead") as CanvasItem
	if read == null or read.visible:
		return false
	for line_name in ["FalseAperture", "FalseApertureCrack", "TrueAperture", "TrueCommitRay"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/WindowTruthRead/" + line_name) as Line2D
		if line == null or line.points.size() < 2 or line.visible:
			return false
	return true


## 确认三阶段闭窗压力读法由 authored Line2D 组成，且默认不亮。
func _stage_3_phase_three_pressure_reads_authored(inst: Node) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreePressureReads") as CanvasItem
	if read == null or read.visible:
		return false
	for line_name in ["TopClampRead", "BottomClampRead", "CenterCutRead"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreePressureReads/" + line_name) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## 确认三阶段关窗时路线压暗，不把无效冲撞误读成有效路径。
func _stage_3_phase_three_dash_route_dimmed(inst: Node) -> bool:
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	return phase_three != null and phase_three.visible and phase_three.modulate.a <= 0.25 and phase_three.scale == Vector2.ONE


## 确认三阶段开窗时路线变亮，和 Boss 核心窗口同步。
func _stage_3_phase_three_dash_route_bright(inst: Node) -> bool:
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	return phase_three != null and phase_three.visible and phase_three.modulate.a >= 0.99 and phase_three.scale.x > 1.0


## 确认三阶段关窗时安全补能口可读，给玩家等待期间的移动目标。
func _stage_3_phase_three_rest_pockets_readable(inst: Node) -> bool:
	var pockets := inst.get_node_or_null("WindowBattleArena/PhaseThreeRestPockets") as CanvasItem
	return pockets != null and pockets.visible and pockets.modulate.a >= 0.9 and pockets.scale == Vector2.ONE


## 确认三阶段开窗时补能口退下去，让冲刺路线成为唯一主读法。
func _stage_3_phase_three_rest_pockets_hidden(inst: Node) -> bool:
	var pockets := inst.get_node_or_null("WindowBattleArena/PhaseThreeRestPockets") as CanvasItem
	return pockets != null and not pockets.visible and pockets.modulate.a <= 0.01


## 确认三阶段闭窗压力读线可见，和 Boss 内部扫压形成同一读法。
func _stage_3_phase_three_pressure_reads_visible(inst: Node) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreePressureReads") as CanvasItem
	if read == null or not read.visible or read.modulate.a < 0.34:
		return false
	for line_name in ["TopClampRead", "BottomClampRead", "CenterCutRead"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreePressureReads/" + line_name) as CanvasItem
		if line == null or not line.visible:
			return false
	return true


## 确认 Boss 实际扫压事件只点亮对应外层读线，避免三条全亮形成噪声。
func _stage_3_only_phase_three_pressure_read_visible(inst: Node, active_name: String) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreePressureReads") as CanvasItem
	if read == null or not read.visible or read.modulate.a < 0.34:
		return false
	for line_name in ["TopClampRead", "BottomClampRead", "CenterCutRead"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreePressureReads/" + line_name) as CanvasItem
		if line == null:
			return false
		if line.visible != (line_name == active_name):
			return false
	return true


## 确认开窗/预告时压力读线收起，不和冲刺路线抢主读法。
func _stage_3_phase_three_pressure_reads_hidden(inst: Node) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreePressureReads") as CanvasItem
	return read != null and not read.visible and read.modulate.a <= 0.01 and read.scale == Vector2.ONE


## 确认开窗预告会把路线从补能读法过渡到瞄准读法。
func _stage_3_dash_warning_response_visible(inst: Node) -> bool:
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	var warning := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead") as CanvasItem
	return phase_three != null and warning != null and phase_three.visible and phase_three.modulate.a >= 0.56 and warning.visible and warning.modulate.a >= 0.99 and warning.scale.x < 1.0


## 确认开窗/反弹后预告读法复位，不和有效窗口混读。
func _stage_3_dash_warning_response_hidden(inst: Node) -> bool:
	var warning := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead") as CanvasItem
	return warning != null and not warning.visible and warning.scale == Vector2.ONE and is_equal_approx(warning.rotation, 0.0)


## 确认三阶段撞空时路线层给出失准读法，而不是 Boss 反弹读法。
func _stage_3_dash_whiff_response_visible(inst: Node) -> bool:
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	var whiff := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWhiffRead") as CanvasItem
	return phase_three != null and whiff != null and phase_three.visible and phase_three.modulate.a >= 0.6 and phase_three.scale.x < 1.0 and whiff.visible and whiff.modulate.a >= 0.99 and whiff.scale.x < 1.0


## 确认开窗/穿透后撞空读法复位，不污染有效窗口。
func _stage_3_dash_whiff_response_hidden(inst: Node) -> bool:
	var whiff := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWhiffRead") as CanvasItem
	return whiff != null and not whiff.visible and whiff.scale == Vector2.ONE and is_equal_approx(whiff.rotation, 0.0)


## 确认三阶段节奏信号只点亮对应的 authored beat 线。
func _stage_3_dash_rhythm_response_visible(inst: Node, active_name: String) -> bool:
	var rhythm := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashRhythmRead") as CanvasItem
	if rhythm == null or not rhythm.visible or rhythm.modulate.a < 0.45:
		return false
	for line_name in ["ClosedBeat", "WarningBeat", "OpenBeat"]:
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashRhythmRead/" + line_name) as CanvasItem
		if line == null:
			return false
		if line.visible != (line_name == active_name):
			return false
	return true


## 确认真假窗口读法只显示当前窗口状态，不让预告和可穿透混读。
func _stage_3_window_truth_response_visible(inst: Node, mode: String) -> bool:
	var read := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/WindowTruthRead") as CanvasItem
	if read == null or not read.visible:
		return false
	var expected := {
		"FalseAperture": mode == "false",
		"FalseApertureCrack": mode == "false",
		"TrueAperture": mode == "true",
		"TrueCommitRay": mode == "true",
	}
	for line_name in expected.keys():
		var line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/WindowTruthRead/" + line_name) as CanvasItem
		if line == null or line.visible != expected[line_name]:
			return false
	return true


## 确认三阶段预告针线指向 Boss 锁定的玩家目标。
func _stage_3_dash_aim_points_at_target(inst: Node, target: Vector2) -> bool:
	var warning := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead") as Node2D
	var needle := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead/AimNeedle") as Line2D
	var core_line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/CoreDashLine") as Line2D
	if warning == null or needle == null or core_line == null or needle.points.size() < 2 or core_line.points.size() < 4:
		return false
	var needle_tip_global := warning.to_global(needle.points[needle.points.size() - 1])
	var core_through_boss := core_line.points[2].distance_to(warning.position) < 1.0
	return needle_tip_global.distance_to(target) < 1.0 and core_through_boss


## 确认三阶段瞄准收起后回到 authored 默认线条，而不是沿用上一轮玩家坐标。
func _stage_3_dash_aim_restored(inst: Node, original_warning_position: Vector2, original_core_first: Vector2, original_tip_global: Vector2) -> bool:
	var warning := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead") as Node2D
	var needle := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashWarningRead/AimNeedle") as Line2D
	var core_line := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/CoreDashLine") as Line2D
	if warning == null or needle == null or core_line == null or needle.points.size() < 5 or core_line.points.size() < 4:
		return false
	var needle_tip_global := warning.to_global(needle.points[needle.points.size() - 1])
	return warning.position.is_equal_approx(original_warning_position) and core_line.points[0].is_equal_approx(original_core_first) and needle_tip_global.is_equal_approx(original_tip_global)


## 确认三阶段冲撞穿透会反馈到真实桌面裂痕层，而不是只在 Boss 本体闪烁。
func _stage_3_dash_pierce_response_visible(inst: Node) -> bool:
	var tears := inst.get_node_or_null("WindowBattleArena/DesktopTears") as CanvasItem
	var frame := inst.get_node_or_null("WindowFrame") as Node2D
	var grid := inst.get_node_or_null("DesktopLayer/DesktopGrid") as CanvasItem
	return tears != null and frame != null and grid != null and tears.visible and tears.modulate.a >= 0.99 and tears.scale.x > 1.0 and frame.scale.x > 1.09 and grid.modulate.a >= 0.68


## 确认三阶段关窗挡下冲撞时，路线层给出反弹读法。
func _stage_3_dash_reject_response_visible(inst: Node) -> bool:
	var phase_three := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute") as CanvasItem
	var reject := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashRejectRead") as CanvasItem
	return phase_three != null and reject != null and phase_three.visible and phase_three.modulate.a >= 0.8 and phase_three.scale.x < 1.0 and reject.visible and reject.modulate.a >= 0.99 and reject.scale.x < 1.0


## 确认 Boss 反弹读法可被撞空/开窗清除。
func _stage_3_dash_reject_response_hidden(inst: Node) -> bool:
	var reject := inst.get_node_or_null("WindowBattleArena/PhaseThreeDashRoute/DashRejectRead") as CanvasItem
	return reject != null and not reject.visible and reject.scale == Vector2.ONE


## 确认第三关胜利后出口路线由 authored Line2D 组成。
func _stage_3_exit_route_guides_authored(inst: Node) -> bool:
	var route := inst.get_node_or_null("ExitRouteGuides")
	if route == null:
		return false
	for guide_name in ["ExitBeam", "ExitSparkA", "ExitSparkB"]:
		var guide := route.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	return true


## 确认 Boss 击穿后出口读路和互联网门同步出现。
func _stage_3_boss_defeat_shows_exit_route(inst: Node) -> bool:
	var route := inst.get_node_or_null("ExitRouteGuides") as CanvasItem
	var gate := inst.get_node_or_null("InternetGate") as CanvasItem
	return route != null and route.visible and gate != null and gate.visible


## 确认玩家真的进入互联网门时，才写 OpenAI flag 并进入终局外壳状态。
func _check_stage_3_internet_gate_finishes_game(inst: Node) -> void:
	var gf = root.get_node_or_null("GameFlow")
	var player := inst.get_node_or_null("Player")
	var gate := inst.get_node_or_null("InternetGate")
	var hint := inst.get_node_or_null("ArenaLayer/ArenaHint") as Label
	if gf == null or player == null or gate == null or not gate.has_method("_on_body_entered"):
		_check("stage_3 internet gate finish prerequisites", false)
		return
	if "openai_exit_delay_seconds" in inst:
		inst.openai_exit_delay_seconds = 60.0
	gf.clear_openai_flag()
	if "frozen" in player:
		player.frozen = false
	gate._on_body_entered(player)
	await process_frame
	_check("stage_3 internet gate freezes player", "frozen" in player and player.frozen == true)
	_check("stage_3 internet gate writes OpenAI flag", gf.has_openai_flag() == true)
	_check("stage_3 internet gate marks finished", gf.has_finished_game() == true)
	_check("stage_3 internet gate updates hint", hint != null and hint.text == "Open AI")
	_check("stage_3 internet gate stops monitoring", "monitoring" in gate and gate.monitoring == false)
	gf.clear_openai_flag()


## 确认每个 Boss 请求发射点都有 authored 善恶预告。
func _stage_3_request_spawn_telegraphs_authored(inst: Node) -> bool:
	var boss := inst.get_node_or_null("FinalBoss")
	var spawns := boss.get_node_or_null("RequestSpawns") if boss != null else null
	if spawns == null:
		return false
	for spawn_name in ["Top", "Right", "Bottom", "Left"]:
		var telegraph := spawns.get_node_or_null(spawn_name + "/Telegraph") as CanvasItem
		if telegraph == null or telegraph.visible:
			return false
		for cue_name in ["GoodCue", "BadCue"]:
			var cue := spawns.get_node_or_null(spawn_name + "/Telegraph/" + cue_name) as Line2D
			if cue == null or cue.points.size() < 2:
				return false
	return true


## 确认 Boss 请求卡本体有 authored 善恶形状读法。
func _stage_3_request_cards_kind_reads_authored(inst: Node) -> bool:
	var boss := inst.get_node_or_null("FinalBoss")
	var pool := boss.get_node_or_null("RequestPool") if boss != null else null
	if pool == null:
		return false
	for child in pool.get_children():
		if not child.has_method("_has_authored_kind_reads") or not child._has_authored_kind_reads():
			return false
	return true
