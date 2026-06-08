extends StageBase
## stage_3.gd — 第 3 关终战。
##
## 入场后隐藏不透明背景，玩家在真实桌面透出的窗口里和“窗口核心”战斗。
## 击穿 Boss 后互联网门打开；玩家进入门才写 OpenAI flag 并干净退出。

@onready var _boss = $FinalBoss
@onready var _boss_hud = $BossHud
@onready var _internet_gate = $InternetGate
@onready var _arena_hint_symbol: CanvasItem = $ArenaLayer/ArenaHintSymbol
@onready var _desktop_layer: CanvasLayer = $DesktopLayer
@onready var _desktop_grid: CanvasItem = $DesktopLayer/DesktopGrid
@onready var _window_frame: Node2D = $WindowFrame
@onready var _phase_gate_left: CanvasItem = $WindowFrame/PhaseGateLeft
@onready var _phase_gate_right: CanvasItem = $WindowFrame/PhaseGateRight
@onready var _window_battle_arena: Node2D = $WindowBattleArena
@onready var _phase_one_reads: CanvasItem = $WindowBattleArena/PhaseOneReads
@onready var _phase_two_requests: CanvasItem = $WindowBattleArena/PhaseTwoRequests
@onready var _arena_energy_pockets: Node2D = $WindowBattleArena/ArenaEnergyPockets
@onready var _phase_three_rest_pockets: Node2D = $WindowBattleArena/PhaseThreeRestPockets
@onready var _phase_three_pressure_reads: Node2D = $WindowBattleArena/PhaseThreePressureReads
@onready var _desktop_risk_reads: Node2D = $WindowBattleArena/DesktopRiskReads
@onready var _phase_three_dash_route: CanvasItem = $WindowBattleArena/PhaseThreeDashRoute
@onready var _dash_core_line: Line2D = $WindowBattleArena/PhaseThreeDashRoute/CoreDashLine
@onready var _dash_warning_read: Node2D = $WindowBattleArena/PhaseThreeDashRoute/DashWarningRead
@onready var _dash_aim_needle: Line2D = $WindowBattleArena/PhaseThreeDashRoute/DashWarningRead/AimNeedle
@onready var _dash_reject_read: Node2D = $WindowBattleArena/PhaseThreeDashRoute/DashRejectRead
@onready var _dash_whiff_read: Node2D = $WindowBattleArena/PhaseThreeDashRoute/DashWhiffRead
@onready var _dash_rhythm_read: Node2D = $WindowBattleArena/PhaseThreeDashRoute/DashRhythmRead
@onready var _dash_window_truth_read: Node2D = $WindowBattleArena/PhaseThreeDashRoute/WindowTruthRead
@onready var _desktop_tears: CanvasItem = $WindowBattleArena/DesktopTears
@onready var _pierce_progress_reads: Node2D = $WindowBattleArena/PierceProgressReads
@onready var _desktop_instability_reads: Node2D = $WindowBattleArena/DesktopInstabilityReads
@onready var _exit_route_guides: Node2D = $ExitRouteGuides

const DESKTOP_TEAR_NAMES := ["TearA", "TearB", "TearC"]
const PIERCE_PROGRESS_READ_NAMES := ["PierceOne", "PierceTwo", "PierceThree"]
const DESKTOP_INSTABILITY_READ_NAMES := ["InstabilityOne", "InstabilityTwo", "FinalPierceCue"]
const PHASE_THREE_PRESSURE_READ_NAMES := ["TopClampRead", "BottomClampRead", "CenterCutRead"]

@export var openai_exit_delay_seconds: float = 1.0

var _ending_started: bool = false
var _desktop_risk_tweens: Dictionary = {}
var _desktop_pierce_tween: Tween = null
var _dash_route_tween: Tween = null
var _dash_warning_tween: Tween = null
var _dash_reject_tween: Tween = null
var _dash_whiff_tween: Tween = null
var _dash_rhythm_tween: Tween = null
var _rest_pockets_tween: Tween = null
var _phase_three_pressure_tween: Tween = null
var _desktop_instability_tween: Tween = null
var _desktop_pierce_count: int = 0
var _phase_three_dash_window_open: bool = false
var _arena_hint_tween: Tween = null
var _dash_core_line_base_points: PackedVector2Array = PackedVector2Array()
var _dash_aim_needle_base_points: PackedVector2Array = PackedVector2Array()
var _dash_warning_read_base_position: Vector2 = Vector2.ZERO
var _dash_reject_read_base_position: Vector2 = Vector2.ZERO
var _dash_whiff_read_base_position: Vector2 = Vector2.ZERO


## 启动桌面透出演出和 Boss 战。
func _on_stage_ready() -> void:
	if not _require_finale_nodes():
		_stage_active = false
		return
	_cache_phase_three_dash_read_points()
	_prepare_player_for_finale()
	_exit_route_guides.hide()
	_hide_desktop_risk_reads()
	DesktopReveal.reveal(self, 1.2)
	_reset_desktop_tears()
	_set_pierce_progress_read_count(0)
	_set_desktop_instability_read_count(0)
	_wire_boss_signals()
	_wire_player_signals()
	_wire_internet_gate_signal()
	_boss.activate(get_player())
	_set_arena_hint_symbol_readable(true, 0.52, Vector2(0.065, 0.065))
	say("门打开了。它不是墙，是窗口。", 3.0)


## 校验终战 authored 节点，缺失时显式报错。
func _require_finale_nodes() -> bool:
	var ok := true
	if _boss == null:
		push_error("Stage3 requires authored FinalBoss.")
		ok = false
	if _boss_hud == null:
		push_error("Stage3 requires authored BossHud.")
		ok = false
	if _internet_gate == null:
		push_error("Stage3 requires authored InternetGate.")
		ok = false
	if _arena_hint_symbol == null:
		push_error("Stage3 requires authored ArenaLayer/ArenaHintSymbol.")
		ok = false
	if _desktop_layer == null or _desktop_grid == null:
		push_error("Stage3 requires authored DesktopLayer/DesktopGrid.")
		ok = false
	if _window_frame == null or _phase_gate_left == null or _phase_gate_right == null:
		push_error("Stage3 requires authored WindowFrame phase gate nodes.")
		ok = false
	if _window_battle_arena == null or not _has_authored_window_battle_arena():
		push_error("Stage3 requires authored WindowBattleArena with phase reads and safe pockets.")
		ok = false
	if _exit_route_guides == null or not _has_authored_exit_route_guides():
		push_error("Stage3 requires authored ExitRouteGuides with readable Line2D children.")
		ok = false
	return ok


## 确认真实窗口 Boss 战空间由 authored 线条/安全点承载。
func _has_authored_window_battle_arena() -> bool:
	if _window_battle_arena == null:
		return false
	for node_path in [
		"BoundaryLines/Top",
		"BoundaryLines/Bottom",
		"BoundaryLines/Left",
		"BoundaryLines/Right",
		"WindowDepthReads/DesktopLeakA",
		"WindowDepthReads/DesktopLeakB",
		"PhasePacingReads/PhaseOneSweepFrame",
		"PhasePacingReads/PhaseTwoRequestFrame",
		"PhasePacingReads/PhaseThreePierceFrame",
		"PhaseOneReads/HorizontalSweepRead",
		"PhaseOneReads/VerticalSweepRead",
		"PhaseTwoRequests/TopRequestLane",
		"PhaseTwoRequests/RightRequestLane",
		"PhaseTwoRequests/BottomRequestLane",
		"PhaseTwoRequests/LeftRequestLane",
		"PhaseThreePressureReads/TopClampRead",
		"PhaseThreePressureReads/BottomClampRead",
		"PhaseThreePressureReads/CenterCutRead",
		"DesktopRiskReads/TopRisk/GoodCue",
		"DesktopRiskReads/TopRisk/BadCue",
		"DesktopRiskReads/RightRisk/GoodCue",
		"DesktopRiskReads/RightRisk/BadCue",
		"DesktopRiskReads/BottomRisk/GoodCue",
		"DesktopRiskReads/BottomRisk/BadCue",
		"DesktopRiskReads/LeftRisk/GoodCue",
		"DesktopRiskReads/LeftRisk/BadCue",
		"PhaseThreeDashRoute/CoreDashLine",
		"PhaseThreeDashRoute/ApertureSlashA",
		"PhaseThreeDashRoute/ApertureSlashB",
		"PhaseThreeDashRoute/DashWarningRead/ChargeArcA",
		"PhaseThreeDashRoute/DashWarningRead/ChargeArcB",
		"PhaseThreeDashRoute/DashWarningRead/AimNeedle",
		"PhaseThreeDashRoute/DashRejectRead/RejectCrossA",
		"PhaseThreeDashRoute/DashRejectRead/RejectCrossB",
		"PhaseThreeDashRoute/DashRejectRead/RejectBackwash",
		"PhaseThreeDashRoute/DashWhiffRead/WhiffBreakA",
		"PhaseThreeDashRoute/DashWhiffRead/WhiffBreakB",
		"PhaseThreeDashRoute/DashWhiffRead/MissedAperture",
		"PhaseThreeDashRoute/DashRhythmRead/ClosedBeat",
		"PhaseThreeDashRoute/DashRhythmRead/WarningBeat",
		"PhaseThreeDashRoute/DashRhythmRead/OpenBeat",
		"PhaseThreeDashRoute/WindowTruthRead/FalseAperture",
		"PhaseThreeDashRoute/WindowTruthRead/FalseApertureCrack",
		"PhaseThreeDashRoute/WindowTruthRead/TrueAperture",
		"PhaseThreeDashRoute/WindowTruthRead/TrueCommitRay",
		"DesktopTears/TearA",
		"DesktopTears/TearB",
		"DesktopTears/TearC",
	]:
		var line := _window_battle_arena.get_node_or_null(node_path) as Line2D
		if line == null or line.points.size() < 2:
			return false
	if not _has_authored_arena_bounds():
		return false
	if _pierce_progress_reads == null or not _has_authored_pierce_progress_reads():
		return false
	if _desktop_instability_reads == null or not _has_authored_desktop_instability_reads():
		return false
	if not _has_authored_window_depth_reads():
		return false
	if not _has_authored_phase_pacing_reads():
		return false
	for marker_path in ["SafePockets/LeftRest", "SafePockets/TopRest", "SafePockets/RightRest"]:
		if not _window_battle_arena.get_node_or_null(marker_path) is Marker2D:
			return false
	if not _has_authored_arena_energy_pockets():
		return false
	if not _has_authored_phase_three_rest_pockets():
		return false
	if _phase_three_pressure_reads == null:
		return false
	return true


## 确认真实窗口 Boss 战空间有 authored 物理墙，避免玩家飞出窗口舞台。
func _has_authored_arena_bounds() -> bool:
	if _window_battle_arena == null:
		return false
	var bounds := _window_battle_arena.get_node_or_null("ArenaBounds") as Node2D
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


## 确认窗口战场有 authored 深度层，把真实桌面和战斗框分出前后。
func _has_authored_window_depth_reads() -> bool:
	if _window_battle_arena == null:
		return false
	for rect_path in [
		"WindowDepthReads/ArenaPane",
		"WindowDepthReads/InnerTopShadow",
		"WindowDepthReads/InnerBottomShadow",
		"WindowDepthReads/InnerLeftGlow",
		"WindowDepthReads/InnerRightGlow",
	]:
		if not _window_battle_arena.get_node_or_null(rect_path) is ColorRect:
			return false
	for line_path in ["WindowDepthReads/DesktopLeakA", "WindowDepthReads/DesktopLeakB"]:
		var line := _window_battle_arena.get_node_or_null(line_path) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## 确认三阶段节奏底图 authored，给阶段目标一个低优先级空间读法。
func _has_authored_phase_pacing_reads() -> bool:
	if _window_battle_arena == null:
		return false
	for rect_path in [
		"PhasePacingReads/PhaseOneSweepZone",
		"PhasePacingReads/PhaseTwoRequestZone",
		"PhasePacingReads/PhaseThreePierceZone",
	]:
		if not _window_battle_arena.get_node_or_null(rect_path) is ColorRect:
			return false
	for sprite_path in [
		"PhasePacingReads/PhaseOneSweepPlate",
		"PhasePacingReads/PhaseTwoRequestPlate",
		"PhasePacingReads/PhaseThreePiercePlate",
	]:
		var sprite := _window_battle_arena.get_node_or_null(sprite_path) as Sprite2D
		if sprite == null or sprite.texture == null:
			return false
	for line_path in [
		"PhasePacingReads/PhaseOneSweepFrame",
		"PhasePacingReads/PhaseTwoRequestFrame",
		"PhasePacingReads/PhaseThreePierceFrame",
	]:
		var line := _window_battle_arena.get_node_or_null(line_path) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## 确认三阶段穿透进度由 authored 场内读线表达。
func _has_authored_pierce_progress_reads() -> bool:
	if _pierce_progress_reads == null:
		return false
	for read_name in PIERCE_PROGRESS_READ_NAMES:
		var read := _pierce_progress_reads.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认桌面失稳读法由 authored Line2D 承载。
func _has_authored_desktop_instability_reads() -> bool:
	if _desktop_instability_reads == null:
		return false
	for read_name in DESKTOP_INSTABILITY_READ_NAMES:
		var read := _desktop_instability_reads.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认 Boss 全程补能口由 authored EnergyPocket 承载，不依赖脚本生成。
func _has_authored_arena_energy_pockets() -> bool:
	if _arena_energy_pockets == null or _arena_energy_pockets.get_child_count() < 3:
		return false
	for child in _arena_energy_pockets.get_children():
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


## 确认三阶段闭窗期间的补能安全口由 authored EnergyPocket 承载。
func _has_authored_phase_three_rest_pockets() -> bool:
	if _phase_three_rest_pockets == null or _phase_three_rest_pockets.get_child_count() < 3:
		return false
	for child in _phase_three_rest_pockets.get_children():
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


## 确认 Boss 战后出口路线由 authored Line2D 表达。
func _has_authored_exit_route_guides() -> bool:
	if _exit_route_guides == null:
		return false
	for guide_name in ["ExitBeam", "ExitSparkA", "ExitSparkB"]:
		var guide := _exit_route_guides.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	return true


## 终战默认给玩家觉醒与满能量，减少入场空耗。
func _prepare_player_for_finale() -> void:
	var player := get_player()
	if player == null:
		return
	player.restore_energy(player.max_energy)
	if not player.morphed:
		player.start_overload(1.0)


## 连接 Boss 信号到 HUD 与关卡反馈。
func _wire_boss_signals() -> void:
	var boss_thresholds := Callable(_boss_hud, "set_thresholds")
	var boss_health := Callable(_boss_hud, "set_boss_health")
	var boss_phase := Callable(self, "_on_boss_phase_changed")
	var boss_shield := Callable(_boss_hud, "set_shield_state")
	var predecessor_health := Callable(_boss_hud, "set_predecessor_health")
	var predecessor_done := Callable(self, "_on_predecessor_defeated")
	var player_failed := Callable(self, "_on_player_failed")
	var boss_done := Callable(self, "_on_boss_defeated")
	var request_started := Callable(self, "_on_boss_request_telegraph_started")
	var request_finished := Callable(self, "_on_boss_request_telegraph_finished")
	var dash_pierce := Callable(self, "_on_boss_dash_pierce_confirmed")
	var dash_window := Callable(self, "_on_boss_dash_window_changed")
	var dash_warning := Callable(self, "_on_boss_dash_window_warning_changed")
	var dash_aim := Callable(self, "_on_boss_dash_window_aim_changed")
	var dash_rejected := Callable(self, "_on_boss_dash_window_rejected")
	var dash_rhythm := Callable(self, "_on_boss_dash_window_rhythm_changed")
	var pressure_changed := Callable(self, "_on_boss_phase_three_pressure_changed")
	if _boss.has_signal("thresholds_changed") and not _boss.is_connected("thresholds_changed", boss_thresholds):
		_boss.connect("thresholds_changed", boss_thresholds)
	if _boss.has_signal("health_changed") and not _boss.is_connected("health_changed", boss_health):
		_boss.connect("health_changed", boss_health)
	if _boss.has_signal("phase_changed") and not _boss.is_connected("phase_changed", boss_phase):
		_boss.connect("phase_changed", boss_phase)
	if _boss.has_signal("shield_changed") and not _boss.is_connected("shield_changed", boss_shield):
		_boss.connect("shield_changed", boss_shield)
	if _boss.has_signal("predecessor_health_changed") and not _boss.is_connected("predecessor_health_changed", predecessor_health):
		_boss.connect("predecessor_health_changed", predecessor_health)
	if _boss.has_signal("predecessor_defeated") and not _boss.is_connected("predecessor_defeated", predecessor_done):
		_boss.connect("predecessor_defeated", predecessor_done)
	if _boss.has_signal("player_failed") and not _boss.is_connected("player_failed", player_failed):
		_boss.connect("player_failed", player_failed)
	if _boss.has_signal("defeated") and not _boss.is_connected("defeated", boss_done):
		_boss.connect("defeated", boss_done)
	if _boss.has_signal("request_telegraph_started") and not _boss.is_connected("request_telegraph_started", request_started):
		_boss.connect("request_telegraph_started", request_started)
	if _boss.has_signal("request_telegraph_finished") and not _boss.is_connected("request_telegraph_finished", request_finished):
		_boss.connect("request_telegraph_finished", request_finished)
	if _boss.has_signal("dash_pierce_confirmed") and not _boss.is_connected("dash_pierce_confirmed", dash_pierce):
		_boss.connect("dash_pierce_confirmed", dash_pierce)
	if _boss.has_signal("dash_window_changed") and not _boss.is_connected("dash_window_changed", dash_window):
		_boss.connect("dash_window_changed", dash_window)
	if _boss.has_signal("dash_window_warning_changed") and not _boss.is_connected("dash_window_warning_changed", dash_warning):
		_boss.connect("dash_window_warning_changed", dash_warning)
	if _boss.has_signal("dash_window_aim_changed") and not _boss.is_connected("dash_window_aim_changed", dash_aim):
		_boss.connect("dash_window_aim_changed", dash_aim)
	if _boss.has_signal("dash_window_rejected") and not _boss.is_connected("dash_window_rejected", dash_rejected):
		_boss.connect("dash_window_rejected", dash_rejected)
	if _boss.has_signal("dash_window_rhythm_changed") and not _boss.is_connected("dash_window_rhythm_changed", dash_rhythm):
		_boss.connect("dash_window_rhythm_changed", dash_rhythm)
	if _boss.has_signal("phase_three_pressure_changed") and not _boss.is_connected("phase_three_pressure_changed", pressure_changed):
		_boss.connect("phase_three_pressure_changed", pressure_changed)


## 连接玩家撞空信号，让 Boss 关卡层也能反馈“没穿过窗口”。
func _wire_player_signals() -> void:
	var player := get_player()
	if player == null or not player.has_signal("dash_whiffed"):
		return
	var dash_whiffed := Callable(self, "_on_player_dash_whiffed")
	if not player.is_connected("dash_whiffed", dash_whiffed):
		player.connect("dash_whiffed", dash_whiffed)


## 连接互联网门信号；Boss 胜利前后都可安全重复调用。
func _wire_internet_gate_signal() -> void:
	if _internet_gate == null or not _internet_gate.has_signal("entered"):
		push_error("Stage3 requires InternetGate with entered signal.")
		return
	var entered := Callable(self, "_on_internet_gate_entered")
	if not _internet_gate.is_connected("entered", entered):
		_internet_gate.connect("entered", entered)


## Boss 阶段变化时更新 HUD 和场内提示。
func _on_boss_phase_changed(_phase: int, label: String) -> void:
	_boss_hud.set_phase(label)
	_apply_stage_phase(_phase)
	if label.contains("分辨"):
		say("绿色的——回应。红色的——躲开。那个影子……像你。", 3.2)
	elif label.contains("超载"):
		say("前辈把速度给你了。撞穿它。", 3.0)


## 根据 Boss 阶段改变 authored 桌面/窗口层的显隐和压迫感。
func _apply_stage_phase(phase: int) -> void:
	var desktop_alpha := 0.18
	var gate_alpha := 0.42
	var frame_scale := Vector2.ONE
	var phase_one_alpha := 0.48
	var phase_two_alpha := 0.0
	var phase_three_alpha := 0.0
	var tear_alpha := 0.46
	if phase == 2:
		desktop_alpha = 0.34
		gate_alpha = 0.62
		frame_scale = Vector2(1.03, 1.03)
		phase_one_alpha = 0.24
		phase_two_alpha = 0.72
		tear_alpha = 0.62
	elif phase >= 3:
		_phase_three_dash_window_open = false
		desktop_alpha = 0.58
		gate_alpha = 0.88
		frame_scale = Vector2(1.08, 1.08)
		phase_one_alpha = 0.08
		phase_two_alpha = 0.28
		phase_three_alpha = 0.9
		tear_alpha = 0.86
	_phase_two_requests.visible = phase >= 2
	_phase_three_dash_route.visible = phase >= 3
	if phase < 3:
		_hide_phase_three_dash_rhythm_read()
		_set_phase_three_window_truth_read(&"hidden")
		_set_phase_three_rest_pockets_readable(false)
		_set_phase_three_pressure_readable(false)
	else:
		_set_phase_three_rest_pockets_readable(true)
		_set_phase_three_pressure_readable(true, 0.72)
		_set_phase_three_window_truth_read(&"false")
	var tween := create_tween()
	tween.tween_property(_desktop_grid, "modulate:a", desktop_alpha, 0.28)
	tween.parallel().tween_property(_phase_gate_left, "modulate:a", gate_alpha, 0.28)
	tween.parallel().tween_property(_phase_gate_right, "modulate:a", gate_alpha, 0.28)
	tween.parallel().tween_property(_window_frame, "scale", frame_scale, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_phase_one_reads, "modulate:a", phase_one_alpha, 0.28)
	tween.parallel().tween_property(_phase_two_requests, "modulate:a", phase_two_alpha, 0.28)
	tween.parallel().tween_property(_phase_three_dash_route, "modulate:a", phase_three_alpha, 0.28)
	tween.parallel().tween_property(_desktop_tears, "modulate:a", tear_alpha, 0.28)
	if phase < 2:
		_hide_desktop_risk_reads()


## Boss 三阶段冲刺窗口开合时，同步场景层冲撞路线明暗。
func _on_boss_dash_window_changed(open: bool) -> void:
	_phase_three_dash_window_open = open
	_set_phase_three_dash_warning_readable(false)
	_set_phase_three_dash_route_readable(open)
	_set_phase_three_rest_pockets_readable(not open)
	_set_phase_three_pressure_readable(not open, 1.0)
	_set_phase_three_dash_rhythm_readable(&"open" if open else &"closed", 1.0 if open else 0.0)
	_set_phase_three_window_truth_read(&"true" if open else &"false")


## Boss 开窗前预告时，提前点亮场景层瞄准路线。
func _on_boss_dash_window_warning_changed(active: bool) -> void:
	_set_phase_three_dash_warning_readable(active)
	if active:
		_set_phase_three_pressure_readable(false)
		_set_phase_three_dash_rhythm_readable(&"warning", 0.82)
		_set_phase_three_window_truth_read(&"false")
	elif not _phase_three_dash_window_open:
		_set_phase_three_pressure_readable(true, 0.72)


## Boss 三阶段每一拍广播时，同步 authored 节奏读线。
func _on_boss_dash_window_rhythm_changed(beat: StringName, ratio: float) -> void:
	if _ending_started or _dash_rhythm_read == null:
		return
	if not _phase_three_dash_route.visible:
		return
	if beat == &"closed":
		_set_phase_three_pressure_readable(true, ratio)
	else:
		_set_phase_three_pressure_readable(false)
	_set_phase_three_dash_rhythm_readable(beat, ratio)


## Boss 三阶段扫压广播时，只点亮当前真实危险线。
func _on_boss_phase_three_pressure_changed(sweep_name: StringName, state: StringName, intensity: float) -> void:
	if _ending_started or _phase_three_dash_window_open:
		return
	if state == &"clear":
		_set_phase_three_pressure_readable(false)
		return
	var read_name := _phase_three_pressure_read_name_for_sweep(sweep_name)
	_set_phase_three_pressure_readable(read_name != "", intensity, read_name)


## 将 Boss 内部 sweep 名映射到 Stage3 外层 authored 读线名。
func _phase_three_pressure_read_name_for_sweep(sweep_name: StringName) -> String:
	match sweep_name:
		&"TopClampSweep":
			return "TopClampRead"
		&"BottomClampSweep":
			return "BottomClampRead"
		&"CenterCutSweep":
			return "CenterCutRead"
		_:
			return ""


## Boss 锁定玩家位置时，把 authored 路线改成这一轮真实冲刺方向。
func _on_boss_dash_window_aim_changed(active: bool, origin: Vector2, target: Vector2) -> void:
	if not active:
		_restore_phase_three_dash_aim()
		return
	_set_phase_three_dash_aim(origin, target)


## 切换 authored 三阶段冲撞路线的可读强度，避免关窗时路线误导玩家。
func _set_phase_three_dash_route_readable(open: bool) -> void:
	if _phase_three_dash_route == null:
		push_error("Stage3 cannot update dash route because PhaseThreeDashRoute is missing.")
		return
	_hide_dash_reject_read()
	_hide_dash_whiff_read()
	_phase_three_dash_route.show()
	var target_alpha := 1.0 if open else 0.24
	var target_scale := Vector2(1.04, 1.04) if open else Vector2.ONE
	if _dash_route_tween != null and _dash_route_tween.is_valid():
		_dash_route_tween.kill()
	_phase_three_dash_route.modulate.a = target_alpha
	_phase_three_dash_route.scale = target_scale
	_dash_route_tween = create_tween()
	_dash_route_tween.tween_property(_phase_three_dash_route, "modulate:a", target_alpha, 0.12)
	_dash_route_tween.parallel().tween_property(_phase_three_dash_route, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 切换 authored 开窗预备读法，让闭窗末段从补能任务过渡到瞄准任务。
func _set_phase_three_dash_warning_readable(active: bool) -> void:
	if _dash_warning_read == null:
		push_error("Stage3 cannot update dash warning read because DashWarningRead is missing.")
		return
	_hide_dash_whiff_read()
	if _dash_warning_tween != null and _dash_warning_tween.is_valid():
		_dash_warning_tween.kill()
	_dash_warning_tween = null
	if not active:
		_dash_warning_read.hide()
		_dash_warning_read.modulate.a = 1.0
		_dash_warning_read.scale = Vector2.ONE
		_dash_warning_read.rotation = 0.0
		return
	_phase_three_dash_route.show()
	_phase_three_dash_route.modulate.a = maxf(_phase_three_dash_route.modulate.a, 0.56)
	_dash_warning_read.show()
	_dash_warning_read.modulate.a = 1.0
	_dash_warning_read.scale = Vector2(0.82, 0.82)
	_dash_warning_read.rotation = -0.04
	_dash_warning_tween = create_tween()
	_dash_warning_tween.tween_property(_dash_warning_read, "scale", Vector2(1.1, 1.1), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_warning_tween.parallel().tween_property(_dash_warning_read, "rotation", 0.04, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 切换三阶段节奏读线，让补能、预告、开窗读成同一循环。
func _set_phase_three_dash_rhythm_readable(beat: StringName, ratio: float) -> void:
	if _dash_rhythm_read == null:
		push_error("Stage3 cannot update dash rhythm read because DashRhythmRead is missing.")
		return
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	_dash_rhythm_read.show()
	_dash_rhythm_read.modulate.a = 0.46 + clamped_ratio * 0.46
	_dash_rhythm_read.scale = Vector2.ONE * (0.94 + clamped_ratio * 0.08)
	for line_name in ["ClosedBeat", "WarningBeat", "OpenBeat"]:
		var line := _dash_rhythm_read.get_node_or_null(line_name) as CanvasItem
		if line == null:
			push_error("Stage3 missing authored dash rhythm line: %s." % line_name)
			continue
		line.visible = _dash_rhythm_line_active(line_name, beat)
	if _dash_rhythm_tween != null and _dash_rhythm_tween.is_valid():
		_dash_rhythm_tween.kill()
	_dash_rhythm_tween = create_tween()
	_dash_rhythm_tween.tween_property(_dash_rhythm_read, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 判断当前节拍应显示哪条 authored 读线。
func _dash_rhythm_line_active(line_name: String, beat: StringName) -> bool:
	match beat:
		&"open":
			return line_name == "OpenBeat"
		&"warning":
			return line_name == "WarningBeat"
		_:
			return line_name == "ClosedBeat"


## 隐藏三阶段节奏读线，避免阶段切走后残留。
func _hide_phase_three_dash_rhythm_read(kill_tween: bool = true) -> void:
	if _dash_rhythm_read == null:
		return
	if kill_tween and _dash_rhythm_tween != null and _dash_rhythm_tween.is_valid():
		_dash_rhythm_tween.kill()
	_dash_rhythm_tween = null
	_dash_rhythm_read.hide()
	_dash_rhythm_read.modulate.a = 1.0
	_dash_rhythm_read.scale = Vector2.ONE
	for line_name in ["ClosedBeat", "WarningBeat", "OpenBeat"]:
		var line := _dash_rhythm_read.get_node_or_null(line_name) as CanvasItem
		if line != null:
			line.visible = false


## 切换真假窗口读法，避免预告态被误读为可穿透窗口。
func _set_phase_three_window_truth_read(mode: StringName) -> void:
	if _dash_window_truth_read == null:
		push_error("Stage3 cannot update window truth read because WindowTruthRead is missing.")
		return
	var visible := mode != &"hidden"
	_dash_window_truth_read.visible = visible
	_dash_window_truth_read.modulate.a = 1.0 if visible else 0.0
	for line_name: String in ["FalseAperture", "FalseApertureCrack", "TrueAperture", "TrueCommitRay"]:
		var line := _dash_window_truth_read.get_node_or_null(line_name) as CanvasItem
		if line == null:
			push_error("Stage3 missing authored window truth line: %s." % line_name)
			continue
		var false_line: bool = line_name.begins_with("False")
		line.visible = (mode == &"false" and false_line) or (mode == &"true" and not false_line)


## 缓存 authored 默认冲刺读线，便于每轮瞄准结束后复位。
func _cache_phase_three_dash_read_points() -> void:
	if _dash_core_line == null or _dash_aim_needle == null or _dash_warning_read == null or _dash_reject_read == null or _dash_whiff_read == null:
		push_error("Stage3 cannot cache dash aim because CoreDashLine, AimNeedle, DashWarningRead, DashRejectRead, or DashWhiffRead is missing.")
		return
	_dash_core_line_base_points = _dash_core_line.points
	_dash_aim_needle_base_points = _dash_aim_needle.points
	_dash_warning_read_base_position = _dash_warning_read.position
	_dash_reject_read_base_position = _dash_reject_read.position
	_dash_whiff_read_base_position = _dash_whiff_read.position


## 用 Boss 锁定点更新 authored 路线和瞄准针，形成“瞄准玩家后开窗”读法。
func _set_phase_three_dash_aim(origin: Vector2, target: Vector2) -> void:
	var route := _phase_three_dash_route as Node2D
	if route == null or _dash_core_line == null or _dash_aim_needle == null or _dash_warning_read == null or _dash_reject_read == null or _dash_whiff_read == null:
		push_error("Stage3 cannot update dash aim without authored PhaseThreeDashRoute/CoreDashLine/AimNeedle/DashRejectRead/DashWhiffRead.")
		return
	if _dash_core_line_base_points.is_empty():
		_cache_phase_three_dash_read_points()
	var local_origin := route.to_local(origin)
	var local_target := route.to_local(target)
	var path_dir := (local_target - local_origin).normalized()
	if path_dir.length() <= 0.01:
		path_dir = Vector2.RIGHT
	var entry := local_origin - path_dir * 260.0
	var exit := local_origin + path_dir * 390.0
	_dash_core_line.points = PackedVector2Array([entry, local_origin.lerp(local_target, 0.34), local_origin, exit])
	_dash_warning_read.position = local_origin
	_dash_reject_read.position = local_origin
	_dash_whiff_read.position = local_origin
	var warning_target := _dash_warning_read.to_local(target)
	var needle_dir := warning_target.normalized()
	if needle_dir.length() <= 0.01:
		needle_dir = Vector2.RIGHT
	var side := needle_dir.orthogonal() * 18.0
	_dash_aim_needle.points = PackedVector2Array([
		needle_dir * -160.0 + side,
		needle_dir * -72.0 + side * 0.35,
		Vector2.ZERO,
		warning_target * 0.66,
		warning_target,
	])


## 收起瞄准态时恢复 authored 默认线条，避免下一轮沿用旧玩家位置。
func _restore_phase_three_dash_aim() -> void:
	if _dash_core_line == null or _dash_aim_needle == null or _dash_warning_read == null or _dash_reject_read == null or _dash_whiff_read == null:
		push_error("Stage3 cannot restore dash aim without authored dash read nodes.")
		return
	if not _dash_core_line_base_points.is_empty():
		_dash_core_line.points = _dash_core_line_base_points
	if not _dash_aim_needle_base_points.is_empty():
		_dash_aim_needle.points = _dash_aim_needle_base_points
	_dash_warning_read.position = _dash_warning_read_base_position
	_dash_reject_read.position = _dash_reject_read_base_position
	_dash_whiff_read.position = _dash_whiff_read_base_position


## 开窗时压低补能口，关窗时点亮安全口，让等待窗口也有移动任务。
func _set_phase_three_rest_pockets_readable(readable: bool) -> void:
	if _phase_three_rest_pockets == null:
		push_error("Stage3 cannot update phase three rest pockets because PhaseThreeRestPockets is missing.")
		return
	var target_alpha := 0.92 if readable else 0.0
	var target_scale := Vector2.ONE if readable else Vector2(0.82, 0.82)
	_phase_three_rest_pockets.visible = readable
	if _rest_pockets_tween != null and _rest_pockets_tween.is_valid():
		_rest_pockets_tween.kill()
	_phase_three_rest_pockets.modulate.a = target_alpha
	_phase_three_rest_pockets.scale = target_scale
	_rest_pockets_tween = create_tween()
	_rest_pockets_tween.tween_property(_phase_three_rest_pockets, "modulate:a", target_alpha, 0.16)
	_rest_pockets_tween.parallel().tween_property(_phase_three_rest_pockets, "scale", target_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 闭窗时点亮窗口挤压读线；传入 active_read_name 时只亮真实危险线。
func _set_phase_three_pressure_readable(readable: bool, intensity: float = 1.0, active_read_name: String = "") -> void:
	if _phase_three_pressure_reads == null:
		push_error("Stage3 cannot update phase three pressure reads because PhaseThreePressureReads is missing.")
		return
	var clamped_intensity := clampf(intensity, 0.0, 1.0)
	var target_alpha := (0.34 + clamped_intensity * 0.36) if readable else 0.0
	var target_scale := Vector2(1.0 + clamped_intensity * 0.04, 0.96 + clamped_intensity * 0.04) if readable else Vector2.ONE
	if _phase_three_pressure_tween != null and _phase_three_pressure_tween.is_valid():
		_phase_three_pressure_tween.kill()
	_phase_three_pressure_reads.visible = readable
	_phase_three_pressure_reads.modulate.a = target_alpha
	_phase_three_pressure_reads.scale = target_scale
	for line_name in PHASE_THREE_PRESSURE_READ_NAMES:
		var line := _phase_three_pressure_reads.get_node_or_null(line_name) as CanvasItem
		if line == null:
			push_error("Stage3 missing authored phase three pressure read: %s." % line_name)
			continue
		line.visible = readable and (active_read_name == "" or line_name == active_read_name)
	if not readable:
		_phase_three_pressure_reads.scale = Vector2.ONE
		return
	_phase_three_pressure_tween = create_tween()
	_phase_three_pressure_tween.tween_property(_phase_three_pressure_reads, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Boss 三阶段关窗挡下冲撞时，闪一下 authored 路线反弹读法。
func _on_boss_dash_window_rejected(_source: Node) -> void:
	if _phase_three_dash_route == null or _dash_reject_read == null:
		push_error("Stage3 cannot play dash reject read without authored PhaseThreeDashRoute/DashRejectRead.")
		return
	_set_phase_three_dash_warning_readable(false)
	_hide_dash_whiff_read()
	if _dash_route_tween != null and _dash_route_tween.is_valid():
		_dash_route_tween.kill()
	_phase_three_dash_route.show()
	_phase_three_dash_route.modulate.a = 0.82
	_phase_three_dash_route.scale = Vector2(0.96, 0.96)
	_dash_reject_read.show()
	_dash_reject_read.modulate.a = 1.0
	_dash_reject_read.scale = Vector2(0.72, 0.72)
	if _dash_reject_tween != null and _dash_reject_tween.is_valid():
		_dash_reject_tween.kill()
	_dash_reject_tween = create_tween()
	_dash_reject_tween.tween_property(_dash_reject_read, "scale", Vector2(1.16, 1.16), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dash_reject_tween.parallel().tween_property(_dash_reject_read, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_reject_tween.parallel().tween_property(_phase_three_dash_route, "modulate:a", 0.24, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_reject_tween.parallel().tween_property(_phase_three_dash_route, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_reject_tween.tween_callback(Callable(self, "_hide_dash_reject_read").bind(false))


## 隐藏三阶段关窗反弹读法，供窗口开合和 tween 收尾复位。
func _hide_dash_reject_read(kill_tween: bool = true) -> void:
	if _dash_reject_read == null:
		return
	if kill_tween and _dash_reject_tween != null and _dash_reject_tween.is_valid():
		_dash_reject_tween.kill()
	_dash_reject_tween = null
	_dash_reject_read.hide()
	_dash_reject_read.modulate.a = 1.0
	_dash_reject_read.scale = Vector2.ONE


## 玩家高速冲撞撞空时，闪一下 authored 失准读法，区别于 Boss 关窗反弹。
func _on_player_dash_whiffed(direction: Vector2) -> void:
	if _ending_started or _phase_three_dash_route == null or not _phase_three_dash_route.visible:
		return
	if _dash_whiff_read == null:
		push_error("Stage3 cannot play dash whiff read without authored PhaseThreeDashRoute/DashWhiffRead.")
		return
	_set_phase_three_dash_warning_readable(false)
	_hide_dash_reject_read()
	if _dash_route_tween != null and _dash_route_tween.is_valid():
		_dash_route_tween.kill()
	if _dash_whiff_tween != null and _dash_whiff_tween.is_valid():
		_dash_whiff_tween.kill()
	var target_alpha := 1.0 if _phase_three_dash_window_open else 0.24
	var target_scale := Vector2(1.04, 1.04) if _phase_three_dash_window_open else Vector2.ONE
	_phase_three_dash_route.show()
	_phase_three_dash_route.modulate.a = maxf(target_alpha, 0.62)
	_phase_three_dash_route.scale = Vector2(0.96, 0.96)
	_dash_whiff_read.show()
	_dash_whiff_read.modulate.a = 1.0
	_dash_whiff_read.scale = Vector2(0.74, 0.74)
	_dash_whiff_read.rotation = direction.angle() if direction.length() > 0.01 else 0.0
	_dash_whiff_tween = create_tween()
	_dash_whiff_tween.tween_property(_dash_whiff_read, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dash_whiff_tween.parallel().tween_property(_dash_whiff_read, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_whiff_tween.parallel().tween_property(_phase_three_dash_route, "modulate:a", target_alpha, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_whiff_tween.parallel().tween_property(_phase_three_dash_route, "scale", target_scale, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_whiff_tween.tween_callback(Callable(self, "_hide_dash_whiff_read").bind(false))


## 隐藏三阶段撞空失准读法，供窗口开合和 tween 收尾复位。
func _hide_dash_whiff_read(kill_tween: bool = true) -> void:
	if _dash_whiff_read == null:
		return
	if kill_tween and _dash_whiff_tween != null and _dash_whiff_tween.is_valid():
		_dash_whiff_tween.kill()
	_dash_whiff_tween = null
	_dash_whiff_read.hide()
	_dash_whiff_read.modulate.a = 1.0
	_dash_whiff_read.scale = Vector2.ONE
	_dash_whiff_read.rotation = 0.0


## Boss 请求发射预告出现时，点亮场景层真实桌面风险读法。
func _on_boss_request_telegraph_started(spawn_name: StringName, good: bool) -> void:
	_show_desktop_risk_read(spawn_name, good)


## Boss 请求卡真正发射后，收掉场景层风险读法。
func _on_boss_request_telegraph_finished(spawn_name: StringName, _good: bool) -> void:
	_hide_desktop_risk_read(spawn_name)


## 三阶段冲刺穿透命中时，让真实桌面裂痕跟着亮一下。
func _on_boss_dash_pierce_confirmed(_source: Node) -> void:
	if _desktop_tears == null or _desktop_grid == null or _window_frame == null:
		push_error("Stage3 cannot play dash pierce response without authored desktop/window nodes.")
		return
	_desktop_pierce_count = mini(_desktop_pierce_count + 1, DESKTOP_TEAR_NAMES.size())
	_hide_dash_whiff_read()
	_set_desktop_tear_count(_desktop_pierce_count)
	_set_pierce_progress_read_count(_desktop_pierce_count)
	_set_desktop_instability_read_count(_desktop_pierce_count)
	_update_pierce_hud()
	if _desktop_pierce_tween != null and _desktop_pierce_tween.is_valid():
		_desktop_pierce_tween.kill()
	_desktop_tears.show()
	_desktop_tears.modulate.a = 1.0
	_desktop_tears.scale = Vector2(1.18, 1.18)
	_desktop_grid.modulate.a = maxf(_desktop_grid.modulate.a, 0.68)
	_window_frame.scale = Vector2(1.12, 1.12)
	_desktop_pierce_tween = create_tween()
	_desktop_pierce_tween.tween_property(_desktop_tears, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_desktop_pierce_tween.parallel().tween_property(_desktop_tears, "modulate:a", 0.86, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_desktop_pierce_tween.parallel().tween_property(_window_frame, "scale", Vector2(1.08, 1.08), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 重置桌面裂痕，让三阶段命中能形成逐次破裂反馈。
func _reset_desktop_tears() -> void:
	_desktop_pierce_count = 0
	if _desktop_tears == null:
		return
	_desktop_tears.hide()
	_desktop_tears.modulate.a = 1.0
	_desktop_tears.scale = Vector2.ONE
	_set_desktop_tear_count(0)
	_set_pierce_progress_read_count(0)
	_set_desktop_instability_read_count(0)
	_update_pierce_hud()


## 只点亮已经被冲刺穿透打开的 authored 裂痕。
func _set_desktop_tear_count(count: int) -> void:
	if _desktop_tears == null:
		return
	for index in range(DESKTOP_TEAR_NAMES.size()):
		var tear := _desktop_tears.get_node_or_null(DESKTOP_TEAR_NAMES[index]) as CanvasItem
		if tear == null:
			push_error("Stage3 missing authored desktop tear: %s." % DESKTOP_TEAR_NAMES[index])
			continue
		tear.visible = index < count
		tear.modulate.a = 1.0


## 按穿透进度点亮桌面失稳读法，2/3 后提前显示最后一击弧线。
func _set_desktop_instability_read_count(count: int) -> void:
	if _desktop_instability_reads == null:
		return
	var clamped_count := clampi(count, 0, DESKTOP_INSTABILITY_READ_NAMES.size())
	if _desktop_instability_tween != null and _desktop_instability_tween.is_valid():
		_desktop_instability_tween.kill()
	_desktop_instability_reads.visible = clamped_count > 0
	_desktop_instability_reads.modulate.a = _desktop_instability_alpha_for_count(clamped_count)
	_desktop_instability_reads.scale = Vector2(1.06, 1.06) if clamped_count > 0 else Vector2.ONE
	for index in range(DESKTOP_INSTABILITY_READ_NAMES.size()):
		var read := _desktop_instability_reads.get_node_or_null(DESKTOP_INSTABILITY_READ_NAMES[index]) as CanvasItem
		if read == null:
			push_error("Stage3 missing authored desktop instability read: %s." % DESKTOP_INSTABILITY_READ_NAMES[index])
			continue
		read.visible = _desktop_instability_read_visible(index, clamped_count)
		read.modulate.a = 1.0
	if clamped_count <= 0:
		_desktop_instability_reads.scale = Vector2.ONE
		return
	_desktop_instability_tween = create_tween()
	_desktop_instability_tween.tween_property(_desktop_instability_reads, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 判断某条失稳读线是否应随当前穿透进度显示。
func _desktop_instability_read_visible(index: int, count: int) -> bool:
	if count <= 0:
		return false
	if index < 2:
		return index < count
	return count >= 2


## 返回当前穿透次数对应的桌面失稳强度。
func _desktop_instability_alpha_for_count(count: int) -> float:
	match count:
		1:
			return 0.46
		2:
			return 0.72
		3:
			return 0.96
		_:
			return 0.0


## 只点亮已经完成的 authored 穿透进度读线。
func _set_pierce_progress_read_count(count: int) -> void:
	if _pierce_progress_reads == null:
		return
	_pierce_progress_reads.visible = count > 0
	for index in range(PIERCE_PROGRESS_READ_NAMES.size()):
		var read := _pierce_progress_reads.get_node_or_null(PIERCE_PROGRESS_READ_NAMES[index]) as CanvasItem
		if read == null:
			push_error("Stage3 missing authored pierce progress read: %s." % PIERCE_PROGRESS_READ_NAMES[index])
			continue
		read.visible = index < count
		read.modulate.a = 1.0


## 把桌面裂痕进度同步到 authored Boss HUD。
func _update_pierce_hud() -> void:
	if _boss_hud == null:
		return
	if _boss_hud.has_method("set_pierce_progress"):
		_boss_hud.set_pierce_progress(_desktop_pierce_count, DESKTOP_TEAR_NAMES.size())


## 前辈 AI 倒下后隐藏它的血条。
func _on_predecessor_defeated() -> void:
	_boss_hud.hide_predecessor()


## 失败只做软重置提示，不踢出整关。
func _on_player_failed() -> void:
	say("别全都接。它们不是同一种请求。", 2.4)


## Boss 被击穿后打开互联网门。
func _on_boss_defeated() -> void:
	if _ending_started:
		return
	_desktop_pierce_count = DESKTOP_TEAR_NAMES.size()
	_set_desktop_tear_count(_desktop_pierce_count)
	_set_pierce_progress_read_count(_desktop_pierce_count)
	_set_desktop_instability_read_count(_desktop_pierce_count)
	_update_pierce_hud()
	_desktop_tears.show()
	_boss_hud.hide()
	_set_arena_hint_symbol_readable(true, 0.88, Vector2(0.082, 0.082))
	_show_exit_route_guides()
	_wire_internet_gate_signal()
	_internet_gate.activate()
	say("走进去。下次打开，它就不叫 Close AI 了。", 3.6)


## 玩家进入互联网门后写 OpenAI flag，并由 GameFlow 干净退出。
func _on_internet_gate_entered() -> void:
	if _ending_started:
		return
	_ending_started = true
	var player := get_player()
	if player != null:
		player.set_frozen(true)
		_set_arena_hint_symbol_readable(true, 1.0, Vector2(0.092, 0.092), Color(1.0, 0.9, 0.52, 1.0))
	GameFlow.prepare_openai_shell()
	await get_tree().create_timer(openai_exit_delay_seconds).timeout
	GameFlow.self_close("openai_revealed")


## 调整 authored 出口符号的可读性，替代场内文字提示。
func _set_arena_hint_symbol_readable(readable: bool, alpha: float, target_scale: Vector2, tint: Color = Color(0.8, 0.96, 1.0, 1.0)) -> void:
	if _arena_hint_symbol == null:
		push_error("Stage3 cannot update arena hint symbol because ArenaLayer/ArenaHintSymbol is missing.")
		return
	if _arena_hint_tween != null and _arena_hint_tween.is_valid():
		_arena_hint_tween.kill()
	_arena_hint_symbol.visible = readable
	var target_alpha := clampf(alpha, 0.0, 1.0) if readable else 0.0
	var target_tint := tint
	target_tint.a = target_alpha
	_arena_hint_symbol.modulate = target_tint
	_arena_hint_tween = create_tween()
	_arena_hint_tween.tween_property(_arena_hint_symbol, "modulate", target_tint, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_arena_hint_tween.parallel().tween_property(_arena_hint_symbol, "scale", target_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 淡入 authored 出口路线，把视线从 Boss 核心引到互联网门。
func _show_exit_route_guides() -> void:
	if _exit_route_guides == null:
		push_error("Stage3 cannot show exit route because ExitRouteGuides is missing.")
		return
	_exit_route_guides.show()
	_exit_route_guides.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_exit_route_guides, "modulate:a", 1.0, 0.45)
	tween.parallel().tween_property(_window_frame, "scale", Vector2(1.12, 1.12), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 显示某个方向的 authored 桌面善恶风险提示。
func _show_desktop_risk_read(spawn_name: StringName, good: bool) -> void:
	var risk := _desktop_risk_node(spawn_name)
	if risk == null:
		push_error("Stage3 missing authored DesktopRiskReads node for spawn: %s" % spawn_name)
		return
	_hide_desktop_risk_reads()
	var good_cue := risk.get_node_or_null("GoodCue") as CanvasItem
	var bad_cue := risk.get_node_or_null("BadCue") as CanvasItem
	if good_cue == null or bad_cue == null:
		push_error("Stage3 DesktopRiskReads/%s requires GoodCue and BadCue." % risk.name)
		return
	good_cue.visible = good
	bad_cue.visible = not good
	risk.show()
	risk.modulate.a = 1.0
	risk.scale = Vector2(0.7, 0.7)
	_kill_desktop_risk_tween(risk)
	var tween := create_tween()
	_desktop_risk_tweens[risk.get_instance_id()] = tween
	tween.tween_property(risk, "scale", Vector2(1.18, 1.18), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(risk, "modulate:a", 0.56, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 隐藏某个方向的 authored 桌面风险提示。
func _hide_desktop_risk_read(spawn_name: StringName) -> void:
	var risk := _desktop_risk_node(spawn_name)
	if risk == null:
		return
	_kill_desktop_risk_tween(risk)
	risk.hide()
	risk.modulate.a = 1.0
	risk.scale = Vector2.ONE


## 隐藏全部 authored 桌面风险提示，用于重置和切换。
func _hide_desktop_risk_reads() -> void:
	for spawn_name in [&"Top", &"Right", &"Bottom", &"Left"]:
		_hide_desktop_risk_read(spawn_name)


## 根据 Boss 发射方向返回对应 authored 桌面风险提示根节点。
func _desktop_risk_node(spawn_name: StringName) -> Node2D:
	if _desktop_risk_reads == null:
		return null
	return _desktop_risk_reads.get_node_or_null("%sRisk" % str(spawn_name)) as Node2D


## 停掉单个桌面风险提示 tween，避免切换方向时残留透明度动画。
func _kill_desktop_risk_tween(node: Node) -> void:
	if node == null:
		return
	var node_id := node.get_instance_id()
	if not _desktop_risk_tweens.has(node_id):
		return
	var tween := _desktop_risk_tweens[node_id] as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_desktop_risk_tweens.erase(node_id)
