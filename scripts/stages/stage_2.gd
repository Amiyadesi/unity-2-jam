extends StageBase
## stage_2.gd — 第 2 关
##
## 觉醒战斗教学：先在安全空间教觉醒/飞行/鼠标冲刺，再组合清除安防进程。
## 核心同第 1 关：完成训练与清场 → 按游戏内关闭按钮 → 继续。旁白走 say()。

enum Step { AWAKEN, FLY_MOVE, DASH_TARGET, DASH_CHAIN, CLEAR_ENEMIES, DONE }

const DASH_GUIDE_NAMES = ["LiftGuide", "FirstDashGuide", "ChainGuideA", "ChainGuideB", "ChainGuideC", "BreakLaneGuide"]
const DASH_CONFIRM_READ_NAMES = ["FirstDashConfirm", "ChainConfirmA", "ChainConfirmB", "ChainConfirmC"]
const DASH_WHIFF_READ_NAMES = ["FirstDashWhiff", "ChainWhiffA", "ChainWhiffB", "ChainWhiffC", "WaveWhiff"]
const MOMENTUM_READ_NAMES = ["FirstToChainA", "ChainAToB", "ChainBToC", "ChainCToBreak"]
const WAVE_GUIDE_NAMES = ["Wave1ApproachGuide", "Wave2AngleGuide", "Wave3BreakGuide"]
const WAVE_POCKET_NAMES = ["LowPocket", "AnglePocket", "BreakPocket"]
const VERTICAL_ROUTE_READ_NAMES = ["HighLowForkRead", "DropRecoveryRead", "EnergyRhythmRead"]
const WAVE_RECOVERY_READ_NAMES = ["LowRecoveryRead", "AngleRecoveryRead", "BreakRecoveryRead"]
const WAVE_PRESSURE_READ_NAMES = ["LowPressureBand", "AnglePressureBand", "BreakPressureBand"]
const WAVE_SPEED_GATE_READ_NAMES = ["LowSpeedGate", "AngleSpeedGate", "BreakSpeedGate"]
const SPEED_GATE_LINE_NAMES = ["ApproachRail", "CommitGate", "ExitWake"]
const AIR_COMBAT_ROOM_NAMES = ["LowRoom", "AngleRoom", "BreakRoom"]
const AIR_COMBAT_TIMING_LINE_NAMES = ["ApproachTick", "CommitWindow", "ExitTick"]
const RECOVERY_MARKER_NAMES = ["ForkHigh", "LowReset", "DropRecover"]
const ROUTE_PLATFORM_PREFIXES = ["Platform", "Floor"]

@export var enemies_to_clear: int = 0  # 0 = 自动统计场景内 enemy 数量
@export var flight_move_seconds_required: float = 0.7
@export var air_room_timing_pulse_seconds: float = 0.18

var _enemies_left: int = 0
var _current_wave_left: int = 0
var _enemy_wave_index: int = 0
var _enemy_waves: Array[Array] = []
var _dash_chain_targets: Array[CloseAITrainingTarget] = []
var _dash_chain_index: int = 0
var _step: int = Step.AWAKEN
var _flight_move_seconds: float = 0.0
var _dash_confirm_tweens: Dictionary = {}
var _dash_whiff_read_tween: Tween = null
var _momentum_read_tween: Tween = null
var _air_room_timing_tween: Tween = null

@onready var _flight_target: CloseAITrainingTarget = get_node_or_null("FlightTraining/DashTarget") as CloseAITrainingTarget
@onready var _dash_chain_root: Node2D = get_node_or_null("FlightTraining/DashChainTargets")
@onready var _awaken_marker: Marker2D = get_node_or_null("FlightTraining/AwakenMarker")
@onready var _route_markers: Node2D = get_node_or_null("FlightTraining/RouteMarkers")
@onready var _recovery_markers: Node2D = get_node_or_null("FlightTraining/RecoveryMarkers")
@onready var _dash_lane_guides: Node2D = get_node_or_null("FlightTraining/DashLaneGuides")
@onready var _dash_confirm_reads: Node2D = get_node_or_null("FlightTraining/DashConfirmReads")
@onready var _dash_whiff_reads: Node2D = get_node_or_null("FlightTraining/DashWhiffReads")
@onready var _momentum_reads: Node2D = get_node_or_null("FlightTraining/MomentumReads")
@onready var _energy_pockets: Node2D = get_node_or_null("FlightTraining/EnergyPockets")
@onready var _vertical_route_reads: Node2D = get_node_or_null("FlightTraining/VerticalRouteReads")
@onready var _enemy_waves_root: Node2D = get_node_or_null("EnemyWaves")
@onready var _enemy_wave_guides: Node2D = get_node_or_null("EnemyWaveGuides")
@onready var _safe_rest_points: Node2D = get_node_or_null("EnemyWaveGuides/SafeRestPoints")
@onready var _wave_energy_pockets: Node2D = get_node_or_null("EnemyWaveGuides/WaveEnergyPockets")
@onready var _wave_recovery_reads: Node2D = get_node_or_null("EnemyWaveGuides/RecoveryReads")
@onready var _wave_pressure_reads: Node2D = get_node_or_null("EnemyWaveGuides/PressureReads")
@onready var _wave_speed_gate_reads: Node2D = get_node_or_null("EnemyWaveGuides/SpeedGateReads")
@onready var _air_combat_rooms: Node2D = get_node_or_null("AirCombatRooms")
@onready var _arena_bounds: Node2D = get_node_or_null("ArenaBounds")
@onready var _close_route_guides: Node2D = get_node_or_null("CloseRouteGuides")

## 关闭时刻前播放 Caretaker 假崩溃，制造"被挽留"节拍。
func _on_close_moment_ready() -> void:
	await GameFlow.play_dialogue(stage_index, "caretaker_interrupt")


## 初始化觉醒飞行训练、冲撞靶链和逐波敌人。
func _on_stage_ready() -> void:
	if not _require_training_nodes():
		_stage_active = false
		return
	var enemies := _find_stage_enemies()
	_enemies_left = enemies.size() if enemies_to_clear <= 0 else enemies_to_clear
	_build_enemy_waves()
	_build_dash_chain_targets()
	_hide_dash_lane_guides()
	_hide_dash_confirm_reads()
	_hide_dash_whiff_reads()
	_hide_momentum_reads()
	_hide_vertical_route_reads()
	_hide_enemy_wave_guides()
	_hide_wave_recovery_reads()
	_hide_wave_pressure_reads()
	_hide_wave_speed_gate_reads()
	_hide_wave_energy_pockets()
	_hide_air_combat_rooms()
	_set_close_route_enabled(false)
	for e in enemies:
		if e.has_signal("defeated") and not e.defeated.is_connected(_on_enemy_defeated):
			e.defeated.connect(_on_enemy_defeated)
		if e.has_method("set_enabled"):
			e.set_enabled(false)
	_flight_target.set_enabled(false)
	if not _flight_target.completed.is_connected(_on_dash_target_completed):
		_flight_target.completed.connect(_on_dash_target_completed)
	for target in _dash_chain_targets:
		target.set_enabled(false)
		if not target.completed.is_connected(_on_dash_chain_target_completed):
			target.completed.connect(_on_dash_chain_target_completed)
	var player := get_player()
	if player.has_signal("morph_changed") and not player.morph_changed.is_connected(_on_player_morph_changed):
		player.morph_changed.connect(_on_player_morph_changed)
	if player.has_signal("dash_whiffed") and not player.dash_whiffed.is_connected(_on_player_dash_whiffed):
		player.dash_whiffed.connect(_on_player_dash_whiffed)
	player.restore_energy(player.max_energy)
	_step = Step.AWAKEN
	say("按 [color=#a99cff]Shift[/color] 觉醒，进入飞行。\n用鼠标瞄准，按 [color=#a99cff]左键[/color] 冲过去。", 5.2)


## 每帧推进 Stage2 飞行移动训练。
func _process(delta: float) -> void:
	if not _stage_active:
		return
	if _step == Step.FLY_MOVE:
		_tutorial_fly_move(delta)


## 校验 Stage2 飞行教学必须 authored 的节点。
func _require_training_nodes() -> bool:
	var ok := true
	if _flight_target == null:
		push_error("%s requires authored CloseAITrainingTarget at FlightTraining/DashTarget." % name)
		ok = false
	if _awaken_marker == null:
		push_error("%s requires authored FlightTraining/AwakenMarker." % name)
		ok = false
	if _route_markers == null or _route_markers.get_child_count() < 3:
		push_error("%s requires authored FlightTraining/RouteMarkers with at least 3 Marker2D nodes." % name)
		ok = false
	if _recovery_markers == null or not _has_authored_recovery_markers():
		push_error("%s requires authored FlightTraining/RecoveryMarkers for fork/reset/drop recovery." % name)
		ok = false
	if not _has_no_route_platforms():
		push_error("%s should teach free flight with ArenaBounds only; remove route platforms from the authored scene." % name)
		ok = false
	if _dash_chain_root == null or not _has_authored_dash_chain_targets():
		push_error("%s requires authored FlightTraining/DashChainTargets with at least 2 dash targets." % name)
		ok = false
	if _dash_lane_guides == null or not _has_authored_dash_lane_guides():
		push_error("%s requires authored FlightTraining/DashLaneGuides Line2D route cues." % name)
		ok = false
	if _dash_confirm_reads == null or not _has_authored_dash_confirm_reads():
		push_error("%s requires authored FlightTraining/DashConfirmReads Line2D hit-confirm cues." % name)
		ok = false
	if _dash_whiff_reads == null or not _has_authored_dash_whiff_reads():
		push_error("%s requires authored FlightTraining/DashWhiffReads Line2D miss/tempo-break cues." % name)
		ok = false
	if _momentum_reads == null or not _has_authored_momentum_reads():
		push_error("%s requires authored FlightTraining/MomentumReads Line2D carry-through cues." % name)
		ok = false
	if _energy_pockets == null or not _has_authored_energy_pockets():
		push_error("%s requires authored FlightTraining/EnergyPockets with at least 2 EnergyPocket nodes." % name)
		ok = false
	if _vertical_route_reads == null or not _has_authored_vertical_route_reads():
		push_error("%s requires authored FlightTraining/VerticalRouteReads route pressure cues." % name)
		ok = false
	if _enemy_waves_root == null:
		push_error("%s requires authored EnemyWaves with child wave containers." % name)
		ok = false
	elif not _has_authored_enemy_waves():
		push_error("%s requires EnemyWaves children with at least one enemy per wave." % name)
		ok = false
	if _enemy_wave_guides == null or not _has_authored_enemy_wave_guides():
		push_error("%s requires authored EnemyWaveGuides with wave Line2D reads and SafeRestPoints." % name)
		ok = false
	if _wave_energy_pockets == null or not _has_authored_wave_energy_pockets():
		push_error("%s requires authored EnemyWaveGuides/WaveEnergyPockets EnergyPocket nodes." % name)
		ok = false
	if _wave_recovery_reads == null or not _has_authored_wave_recovery_reads():
		push_error("%s requires authored EnemyWaveGuides/RecoveryReads Line2D reset cues." % name)
		ok = false
	if _wave_pressure_reads == null or not _has_authored_wave_pressure_reads():
		push_error("%s requires authored EnemyWaveGuides/PressureReads Line2D ceiling/floor pressure cues." % name)
		ok = false
	if _wave_speed_gate_reads == null or not _has_authored_wave_speed_gate_reads():
		push_error("%s requires authored EnemyWaveGuides/SpeedGateReads Line2D speed gates." % name)
		ok = false
	if _air_combat_rooms == null or not _has_authored_air_combat_rooms():
		push_error("%s requires authored AirCombatRooms with room markers and route reads." % name)
		ok = false
	if _arena_bounds == null or not _has_authored_arena_bounds():
		push_error("%s requires authored ArenaBounds with four collision walls." % name)
		ok = false
	if _close_route_guides == null or not _has_authored_close_route():
		push_error("%s requires authored CloseRouteGuides and CloseMomentTrigger exit route." % name)
		ok = false
	return ok


## 收集当前关卡 authored 敌人，避免跨场景编组串线。
func _find_stage_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Node and is_ancestor_of(n):
			result.append(n)
	return result


## 确认冲撞连锁目标都由 authored TrainingTarget 承载。
func _has_authored_dash_chain_targets() -> bool:
	if _dash_chain_root == null or _dash_chain_root.get_child_count() < 2:
		return false
	for child in _dash_chain_root.get_children():
		if not child is CloseAITrainingTarget:
			return false
		if String(child.required_attack_kind) != "dash":
			return false
	return true


## 确认每段飞行/冲刺路线提示都由 authored Line2D 承载。
func _has_authored_dash_lane_guides() -> bool:
	if _dash_lane_guides == null:
		return false
	for guide_name in DASH_GUIDE_NAMES:
		var guide := _dash_lane_guides.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	return true


## 确认每个冲撞命中确认读法都由 authored Line2D 组成。
func _has_authored_dash_confirm_reads() -> bool:
	if _dash_confirm_reads == null:
		return false
	for read_name in DASH_CONFIRM_READ_NAMES:
		var read := _dash_confirm_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		for line_name in ["BurstRing", "HitSlash", "NextRay"]:
			var line := _dash_confirm_reads.get_node_or_null(read_name + "/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
	return true


## 确认每个撞空断速读法都由 authored Line2D 组成。
func _has_authored_dash_whiff_reads() -> bool:
	if _dash_whiff_reads == null:
		return false
	for read_name in DASH_WHIFF_READ_NAMES:
		var read := _dash_whiff_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		for line_name in ["ScatterA", "ScatterB", "LostRoute"]:
			var line := _dash_whiff_reads.get_node_or_null(read_name + "/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
	return true


## 确认冲撞后的连续速度航线由 authored Line2D 承载。
func _has_authored_momentum_reads() -> bool:
	if _momentum_reads == null:
		return false
	for read_name in MOMENTUM_READ_NAMES:
		var read := _momentum_reads.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认飞行补能口是 authored EnergyPocket，而不是不可见 Marker。
func _has_authored_energy_pockets() -> bool:
	if _energy_pockets == null or _energy_pockets.get_child_count() < 2:
		return false
	for child in _energy_pockets.get_children():
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


## 确认垂直路线读法由 authored Line2D 承载，方便后续直接拖拽高低差。
func _has_authored_vertical_route_reads() -> bool:
	if _vertical_route_reads == null:
		return false
	for read_name in VERTICAL_ROUTE_READ_NAMES:
		var read := _vertical_route_reads.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认失败恢复点由 authored Marker2D 承载，方便编辑器直接拖拽调整路线。
func _has_authored_recovery_markers() -> bool:
	if _recovery_markers == null:
		return false
	for marker_name in RECOVERY_MARKER_NAMES:
		if not _recovery_markers.get_node_or_null(marker_name) is Marker2D:
			return false
	return true


## 确认 Stage2 不再用中途落脚平台教学，碰撞只由封闭 ArenaBounds 承担。
func _has_no_route_platforms() -> bool:
	for child in get_children():
		if not child is StaticBody2D:
			continue
		var child_name := String(child.name)
		for prefix in ROUTE_PLATFORM_PREFIXES:
			if child_name.begins_with(prefix):
				return false
	return true


## 确认每个 authored 波次容器都放了至少一个敌人。
func _has_authored_enemy_waves() -> bool:
	if _enemy_waves_root == null or _enemy_waves_root.get_child_count() == 0:
		return false
	for wave_container in _enemy_waves_root.get_children():
		if not wave_container is Node:
			return false
		if _collect_wave_enemies(wave_container).is_empty():
			return false
	return true


## 确认逐波战斗读线和安全休息点都由 authored 节点承载。
func _has_authored_enemy_wave_guides() -> bool:
	if _enemy_wave_guides == null:
		return false
	for guide_name in WAVE_GUIDE_NAMES:
		var guide := _enemy_wave_guides.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	if _safe_rest_points == null:
		return false
	for marker_name in ["LowRest", "AngleRest", "BreakRest"]:
		if not _safe_rest_points.get_node_or_null(marker_name) is Marker2D:
			return false
	return true


## 确认逐波战斗补能口由 authored EnergyPocket 承载。
func _has_authored_wave_energy_pockets() -> bool:
	if _wave_energy_pockets == null:
		return false
	for pocket_name in WAVE_POCKET_NAMES:
		var pocket := _wave_energy_pockets.get_node_or_null(pocket_name)
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


## 确认波次失败恢复读线由 authored Line2D 表达。
func _has_authored_wave_recovery_reads() -> bool:
	if _wave_recovery_reads == null:
		return false
	for read_name in WAVE_RECOVERY_READ_NAMES:
		var read := _wave_recovery_reads.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认波次高低压迫边界由 authored Line2D 表达。
func _has_authored_wave_pressure_reads() -> bool:
	if _wave_pressure_reads == null:
		return false
	for read_name in WAVE_PRESSURE_READ_NAMES:
		var read := _wave_pressure_reads.get_node_or_null(read_name) as Line2D
		if read == null or read.points.size() < 2:
			return false
	return true


## 确认三段空战速度门由 authored Line2D 组成，方便编辑器拖拽节奏窗口。
func _has_authored_wave_speed_gate_reads() -> bool:
	if _wave_speed_gate_reads == null:
		return false
	for read_name in WAVE_SPEED_GATE_READ_NAMES:
		var read := _wave_speed_gate_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			return false
		for line_name in SPEED_GATE_LINE_NAMES:
			var line := _wave_speed_gate_reads.get_node_or_null(read_name + "/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
	return true


## 确认每段空战房间都有可拖拽节拍点和 authored 读线。
func _has_authored_air_combat_rooms() -> bool:
	if _air_combat_rooms == null:
		return false
	for room_name in AIR_COMBAT_ROOM_NAMES:
		var room := _air_combat_rooms.get_node_or_null(room_name) as Node2D
		if room == null:
			return false
		for marker_name in ["Entry", "Apex", "Exit"]:
			if not room.get_node_or_null(marker_name) is Marker2D:
				return false
		var route_read := room.get_node_or_null("RouteRead") as Line2D
		if route_read == null or route_read.points.size() < 3:
			return false
		if not room.get_node_or_null("TimingGate") is Marker2D:
			return false
		var timing_read := room.get_node_or_null("TimingRead") as CanvasItem
		if timing_read == null:
			return false
		for line_name in AIR_COMBAT_TIMING_LINE_NAMES:
			var line := room.get_node_or_null("TimingRead/" + line_name) as Line2D
			if line == null or line.points.size() < 2:
				return false
	return true


## 确认 Stage2 飞行房间有 authored 真实碰撞墙，阻止玩家飞出地图。
func _has_authored_arena_bounds() -> bool:
	if _arena_bounds == null:
		return false
	for wall_name in ["LeftWall", "RightWall", "Ceiling", "FloorClamp"]:
		var wall := _arena_bounds.get_node_or_null(wall_name) as StaticBody2D
		if wall == null:
			return false
		if wall.scale != Vector2.ONE:
			return false
		var shape := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null or shape.shape == null or shape.scale != Vector2.ONE:
			return false
	if not _arena_bounds.get_node_or_null("BoundaryReads") is Node2D:
		return false
	return true


## 确认 Stage2 清场后的关闭路线和触发区都由 authored 节点承载。
func _has_authored_close_route() -> bool:
	if _close_route_guides == null or _close_trigger == null:
		return false
	var trigger_shape := _close_trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if trigger_shape == null or trigger_shape.shape == null:
		return false
	for guide_name in ["ExitWake", "ExitBracket", "PermissionCrack"]:
		var guide := _close_route_guides.get_node_or_null(guide_name) as Line2D
		if guide == null or guide.points.size() < 2:
			return false
	return true


## 从 authored 波次容器里收集敌人子节点。
func _collect_wave_enemies(wave_container: Node) -> Array[Node]:
	var wave: Array[Node] = []
	for child in wave_container.get_children():
		if child is Node and child.is_in_group("enemy"):
			wave.append(child)
	return wave


## 按 EnemyWaves 下的 authored 容器顺序组成逐步清场波次。
func _build_enemy_waves() -> void:
	_enemy_waves.clear()
	if _enemy_waves_root == null:
		return
	for wave_container in _enemy_waves_root.get_children():
		var wave := _collect_wave_enemies(wave_container)
		if not wave.is_empty():
			_enemy_waves.append(wave)


## 按 authored 顺序收集空中冲撞连锁靶。
func _build_dash_chain_targets() -> void:
	_dash_chain_targets.clear()
	if _dash_chain_root == null:
		return
	for child in _dash_chain_root.get_children():
		if child is CloseAITrainingTarget:
			_dash_chain_targets.append(child)


## 敌人清空后提示玩家进入关闭时刻。
func _on_enemy_defeated() -> void:
	if _step != Step.CLEAR_ENEMIES:
		return
	_enemies_left = maxi(_enemies_left - 1, 0)
	_current_wave_left = maxi(_current_wave_left - 1, 0)
	if _enemies_left <= 0:
		_step = Step.DONE
		_hide_dash_lane_guides()
		_hide_vertical_route_reads()
		_hide_enemy_wave_guides()
		_hide_wave_recovery_reads()
		_hide_wave_pressure_reads()
		_hide_wave_speed_gate_reads()
		_hide_wave_energy_pockets()
		_hide_air_combat_rooms()
		_enable_close_route()
		say("安静了。\n裂口在那里——在它改变主意之前，飞过去。", 3.2)
	elif _current_wave_left <= 0:
		_enable_next_enemy_wave()
	else:
		say("这一波还剩 %d 个。" % _current_wave_left, 1.6, "top_right+0,12@220x56")


## 玩家觉醒后进入安全飞行移动教学。
func _on_player_morph_changed(is_morphed: bool) -> void:
	if _step != Step.AWAKEN or not is_morphed:
		return
	_step = Step.FLY_MOVE
	_flight_move_seconds = 0.0
	_show_dash_lane_guides(["LiftGuide"])
	_show_vertical_route_read("HighLowForkRead")
	say("很好。用 [color=#a99cff]WASD[/color] 飞一小段——感受一下。", 3.2)


## 累计飞行移动时间，确认玩家理解八向飞行。
func _tutorial_fly_move(delta: float) -> void:
	var player := get_player()
	if not player.morphed:
		return
	if player.velocity.length() <= 80.0:
		return
	_flight_move_seconds += delta
	if _flight_move_seconds >= flight_move_seconds_required:
		_advance_to_dash_target()


## 进入鼠标方向冲刺教学，启用 authored 冲刺训练靶。
func _advance_to_dash_target() -> void:
	_step = Step.DASH_TARGET
	_flight_target.set_enabled(true)
	get_player().restore_energy(get_player().max_energy)
	_show_dash_lane_guides(["FirstDashGuide"])
	_show_vertical_route_read("EnergyRhythmRead")
	say("把鼠标指向前面那把锁，按 [color=#a99cff]左键[/color] 冲过去。", 4.0)


## 冲刺靶完成后进入组合清场段。
func _on_dash_target_completed(_target: Area2D, _attack_kind: StringName) -> void:
	if _step != Step.DASH_TARGET:
		return
	_step = Step.DASH_CHAIN
	_dash_chain_index = 0
	_show_dash_confirm_for_target(_target)
	get_player().restore_energy(get_player().max_energy)
	_enable_next_dash_chain_target()


## 完成一个空中靶后补能并启用下一个折线靶。
func _on_dash_chain_target_completed(_target: Area2D, _attack_kind: StringName) -> void:
	if _step != Step.DASH_CHAIN:
		return
	_show_dash_confirm_for_target(_target)
	get_player().restore_energy(get_player().max_energy)
	_enable_next_dash_chain_target()


## 启用下一枚 authored 冲撞靶，最后切到敌人波次。
func _enable_next_dash_chain_target() -> void:
	if _dash_chain_index >= _dash_chain_targets.size():
		_start_enemy_clear()
		return
	var target := _dash_chain_targets[_dash_chain_index]
	_dash_chain_index += 1
	target.set_enabled(true)
	match _dash_chain_index:
		1:
			_show_dash_lane_guides(["ChainGuideA"])
			_show_vertical_route_read("DropRecoveryRead")
			say("撞碎它，顺势回能。下一枚在下面，别停。", 3.2)
		2:
			_show_dash_lane_guides(["ChainGuideB"])
			_show_vertical_route_read("HighLowForkRead")
			say("很好，往上折。", 2.6)
		_:
			_show_dash_lane_guides(["ChainGuideC", "BreakLaneGuide"])
			_show_vertical_route_read("EnergyRhythmRead")
			say("最后一枚。沿这条线冲进去。", 2.8)


## 结束教学靶链，进入逐波清场段。
func _start_enemy_clear() -> void:
	_step = Step.CLEAR_ENEMIES
	_enemy_wave_index = 0
	get_player().restore_energy(get_player().max_energy)
	if _enemies_left > 0:
		_show_dash_lane_guides(["BreakLaneGuide"])
		_show_vertical_route_read("EnergyRhythmRead")
		_enable_next_enemy_wave()
	else:
		_step = Step.DONE
		_hide_dash_lane_guides()
		_hide_enemy_wave_guides()
		_hide_wave_speed_gate_reads()
		_hide_wave_energy_pockets()
		_hide_air_combat_rooms()
		_enable_close_route()
		say("没有守卫。沿着裂口飞过去，亲手关掉这一层。", 3.0)


## 清场后点亮 authored 出口航线，并打开玩家可飞入的关闭触发区。
func _enable_close_route() -> void:
	_set_close_route_enabled(true)


## 切换 Stage2 出口航线和触发区，默认禁用，通关后才响应玩家。
func _set_close_route_enabled(enabled: bool) -> void:
	if _close_route_guides != null:
		_close_route_guides.visible = enabled
	if _close_trigger != null:
		_close_trigger.visible = enabled
		_set_area_collision_deferred(_close_trigger, enabled)


## 延迟切换 Area2D 碰撞，允许关卡在命中回调中安全推进下一步。
func _set_area_collision_deferred(area: Area2D, enabled: bool) -> void:
	area.set_deferred("monitoring", enabled)
	var shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", not enabled)


## 启用下一组 authored 敌人，逐步增加空中压力。
func _enable_next_enemy_wave() -> void:
	if _enemy_wave_index >= _enemy_waves.size():
		return
	var wave: Array = _enemy_waves[_enemy_wave_index]
	_enemy_wave_index += 1
	_current_wave_left = wave.size()
	for enemy in wave:
		if enemy != null and enemy.has_method("set_enabled"):
			enemy.set_enabled(true)
	get_player().restore_energy(get_player().max_energy)
	match _enemy_wave_index:
		1:
			_show_enemy_wave_guides(["Wave1ApproachGuide"])
			_show_wave_pressure_read("LowPressureBand")
			_show_wave_speed_gate_read("LowSpeedGate")
			_hide_wave_recovery_reads()
			_show_wave_energy_pockets(["LowPocket"])
			_show_air_combat_room("LowRoom")
			say("第一波——低空贴近，冲过去。", 2.8)
		2:
			_show_enemy_wave_guides(["Wave2AngleGuide"])
			_show_wave_pressure_read("AnglePressureBand")
			_show_wave_speed_gate_read("AngleSpeedGate")
			_hide_wave_recovery_reads()
			_show_wave_energy_pockets(["AnglePocket"])
			_show_air_combat_room("AngleRoom")
			say("第二波——抬高角度，从下面切上去。", 2.8)
		_:
			_show_enemy_wave_guides(["Wave3BreakGuide"])
			_show_wave_pressure_read("BreakPressureBand")
			_show_wave_speed_gate_read("BreakSpeedGate")
			_hide_wave_recovery_reads()
			_show_wave_energy_pockets(["BreakPocket"])
			_show_air_combat_room("BreakRoom")
			say("最后一波——沿突破道撞开。", 2.8)


## 只显示当前教学步骤需要看的 authored 路线段。
func _show_dash_lane_guides(active_names: Array) -> void:
	if _dash_lane_guides == null:
		push_error("%s cannot show dash lane guides because authored guide root is missing." % name)
		return
	for guide_name in DASH_GUIDE_NAMES:
		var guide := _dash_lane_guides.get_node_or_null(guide_name) as CanvasItem
		if guide == null:
			push_error("%s missing authored dash lane guide: %s." % [name, guide_name])
			continue
		guide.visible = active_names.has(guide_name)


## 隐藏全部 authored 路线段，避免旧步骤持续抢视觉焦点。
func _hide_dash_lane_guides() -> void:
	_show_dash_lane_guides([])


## 根据完成的训练靶播放对应 authored 命中确认读法。
func _show_dash_confirm_for_target(target: Area2D) -> void:
	if target == null:
		return
	_hide_dash_whiff_reads()
	var read_name := ""
	var momentum_name := ""
	match String(target.name):
		"DashTarget":
			read_name = "FirstDashConfirm"
			momentum_name = "FirstToChainA"
		"ChainTargetA":
			read_name = "ChainConfirmA"
			momentum_name = "ChainAToB"
		"ChainTargetB":
			read_name = "ChainConfirmB"
			momentum_name = "ChainBToC"
		"ChainTargetC":
			read_name = "ChainConfirmC"
			momentum_name = "ChainCToBreak"
	if read_name == "":
		return
	_show_dash_confirm_read(read_name)
	_show_momentum_read(momentum_name)


## 玩家撞空时显示当前目标附近的 authored 断速读法。
func _on_player_dash_whiffed(_direction: Vector2) -> void:
	var read_name := _dash_whiff_read_for_current_step()
	if read_name == "":
		return
	_show_dash_whiff_read(read_name)
	if _step == Step.CLEAR_ENEMIES:
		_show_wave_recovery_read(_wave_recovery_read_for_current_wave())


## 返回当前教学/战斗段应该点亮的撞空读法。
func _dash_whiff_read_for_current_step() -> String:
	match _step:
		Step.DASH_TARGET:
			return "FirstDashWhiff"
		Step.DASH_CHAIN:
			match _dash_chain_index:
				1:
					return "ChainWhiffA"
				2:
					return "ChainWhiffB"
				_:
					return "ChainWhiffC"
		Step.CLEAR_ENEMIES:
			return "WaveWhiff"
		_:
			return ""


## 闪现一条 authored 撞空读法，强调没撞中就没有续航。
func _show_dash_whiff_read(read_name: String) -> void:
	if _dash_whiff_reads == null:
		push_error("%s cannot show dash whiff read because authored root is missing." % name)
		return
	var read := _dash_whiff_reads.get_node_or_null(read_name) as CanvasItem
	if read == null:
		push_error("%s missing authored dash whiff read: %s." % [name, read_name])
		return
	_hide_dash_confirm_reads()
	_hide_momentum_reads()
	_hide_dash_whiff_reads()
	read.visible = true
	read.modulate.a = 1.0
	read.scale = Vector2(0.88, 0.88)
	_dash_whiff_read_tween = create_tween()
	_dash_whiff_read_tween.tween_property(read, "scale", Vector2(1.14, 1.14), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dash_whiff_read_tween.parallel().tween_property(read, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_whiff_read_tween.tween_callback(Callable(self, "_finish_dash_whiff_read").bind(read))


## 隐藏完成淡出的撞空读法并恢复 authored 状态。
func _finish_dash_whiff_read(read: CanvasItem) -> void:
	if not is_instance_valid(read):
		return
	_dash_whiff_read_tween = null
	read.visible = false
	read.modulate.a = 1.0
	read.scale = Vector2.ONE


## 隐藏全部 authored 撞空读法，避免旧失败反馈跨步骤残留。
func _hide_dash_whiff_reads() -> void:
	if _dash_whiff_reads == null:
		return
	if _dash_whiff_read_tween != null and _dash_whiff_read_tween.is_valid():
		_dash_whiff_read_tween.kill()
	_dash_whiff_read_tween = null
	for read_name in DASH_WHIFF_READ_NAMES:
		var read := _dash_whiff_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored dash whiff read: %s." % [name, read_name])
			continue
		read.visible = false
		read.modulate.a = 1.0
		read.scale = Vector2.ONE


## 闪现一条 authored 命中确认读法，强调撞中后继续转向。
func _show_dash_confirm_read(read_name: String) -> void:
	if _dash_confirm_reads == null:
		push_error("%s cannot show dash confirm read because authored root is missing." % name)
		return
	var read := _dash_confirm_reads.get_node_or_null(read_name) as CanvasItem
	if read == null:
		push_error("%s missing authored dash confirm read: %s." % [name, read_name])
		return
	_hide_dash_confirm_reads()
	read.visible = true
	read.modulate.a = 1.0
	read.scale = Vector2(0.72, 0.72)
	var tween := create_tween()
	_dash_confirm_tweens[read.get_instance_id()] = tween
	tween.tween_property(read, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(read, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_finish_dash_confirm_read").bind(read))


## 隐藏完成淡出的命中确认读法并恢复 authored 状态。
func _finish_dash_confirm_read(read: CanvasItem) -> void:
	if not is_instance_valid(read):
		return
	_dash_confirm_tweens.erase(read.get_instance_id())
	read.visible = false
	read.modulate.a = 1.0
	read.scale = Vector2.ONE


## 隐藏全部 authored 命中确认读法，避免新阶段残留。
func _hide_dash_confirm_reads() -> void:
	if _dash_confirm_reads == null:
		return
	for tween in _dash_confirm_tweens.values():
		if tween is Tween and (tween as Tween).is_valid():
			(tween as Tween).kill()
	_dash_confirm_tweens.clear()
	for read_name in DASH_CONFIRM_READ_NAMES:
		var read := _dash_confirm_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored dash confirm read: %s." % [name, read_name])
			continue
		read.visible = false
		read.modulate.a = 1.0
		read.scale = Vector2.ONE


## 显示本次命中承接到下一目标的 authored 高速航线。
func _show_momentum_read(read_name: String) -> void:
	if _momentum_reads == null:
		push_error("%s cannot show momentum read because authored root is missing." % name)
		return
	if _momentum_read_tween != null and _momentum_read_tween.is_valid():
		_momentum_read_tween.kill()
	_momentum_read_tween = null
	for candidate in MOMENTUM_READ_NAMES:
		var read := _momentum_reads.get_node_or_null(candidate) as CanvasItem
		if read == null:
			push_error("%s missing authored momentum read: %s." % [name, candidate])
			continue
		var active: bool = String(candidate) == read_name
		read.visible = active
		read.modulate.a = 1.0 if active else 0.0
		read.scale = Vector2(0.94, 0.94) if active else Vector2.ONE
	if read_name == "":
		return
	var active_read := _momentum_reads.get_node_or_null(read_name) as CanvasItem
	if active_read == null:
		return
	_momentum_read_tween = create_tween()
	_momentum_read_tween.tween_property(active_read, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_momentum_read_tween.parallel().tween_property(active_read, "modulate:a", 0.72, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 隐藏全部 authored 高速航线，关卡步骤结束时复位。
func _hide_momentum_reads() -> void:
	if _momentum_reads == null:
		return
	if _momentum_read_tween != null and _momentum_read_tween.is_valid():
		_momentum_read_tween.kill()
	_momentum_read_tween = null
	for read_name in MOMENTUM_READ_NAMES:
		var read := _momentum_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored momentum read: %s." % [name, read_name])
			continue
		read.visible = false
		read.modulate.a = 1.0
		read.scale = Vector2.ONE


## 只显示当前训练段需要的高低差/补能节奏读法。
func _show_vertical_route_read(active_name: String) -> void:
	if _vertical_route_reads == null:
		push_error("%s cannot show vertical route reads because authored root is missing." % name)
		return
	for read_name in VERTICAL_ROUTE_READ_NAMES:
		var read := _vertical_route_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored vertical route read: %s." % [name, read_name])
			continue
		read.visible = read_name == active_name


## 隐藏全部高低差读法，避免旧路线跨步骤残留。
func _hide_vertical_route_reads() -> void:
	_show_vertical_route_read("")


## 只显示当前敌人波次需要看的 authored 战斗读线。
func _show_enemy_wave_guides(active_names: Array) -> void:
	if _enemy_wave_guides == null:
		push_error("%s cannot show enemy wave guides because authored EnemyWaveGuides is missing." % name)
		return
	for guide_name in WAVE_GUIDE_NAMES:
		var guide := _enemy_wave_guides.get_node_or_null(guide_name) as CanvasItem
		if guide == null:
			push_error("%s missing authored enemy wave guide: %s." % [name, guide_name])
			continue
		guide.visible = active_names.has(guide_name)


## 隐藏全部 authored 波次读线，避免战斗结束后残留路线。
func _hide_enemy_wave_guides() -> void:
	_show_enemy_wave_guides([])


## 只显示当前波次的压迫边界，让玩家读到高低差空间。
func _show_wave_pressure_read(active_name: String) -> void:
	if _wave_pressure_reads == null:
		push_error("%s cannot show wave pressure reads because authored root is missing." % name)
		return
	for read_name in WAVE_PRESSURE_READ_NAMES:
		var read := _wave_pressure_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored wave pressure read: %s." % [name, read_name])
			continue
		read.visible = read_name == active_name


## 隐藏全部波次压迫边界，关卡结束或离开清场段时复位。
func _hide_wave_pressure_reads() -> void:
	_show_wave_pressure_read("")


## 只显示当前波次的速度门，强调从读线进冲刺窗口。
func _show_wave_speed_gate_read(active_name: String) -> void:
	if _wave_speed_gate_reads == null:
		push_error("%s cannot show wave speed gates because authored root is missing." % name)
		return
	for read_name in WAVE_SPEED_GATE_READ_NAMES:
		var read := _wave_speed_gate_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored wave speed gate: %s." % [name, read_name])
			continue
		read.visible = read_name == active_name


## 隐藏全部速度门，避免旧波次读法残留。
func _hide_wave_speed_gate_reads() -> void:
	_show_wave_speed_gate_read("")


## 只显示当前波次撞空后的恢复路线，给玩家一个回到节奏的目标。
func _show_wave_recovery_read(active_name: String) -> void:
	if _wave_recovery_reads == null:
		push_error("%s cannot show wave recovery reads because authored root is missing." % name)
		return
	for read_name in WAVE_RECOVERY_READ_NAMES:
		var read := _wave_recovery_reads.get_node_or_null(read_name) as CanvasItem
		if read == null:
			push_error("%s missing authored wave recovery read: %s." % [name, read_name])
			continue
		read.visible = read_name == active_name


## 隐藏全部波次恢复路线，避免新波次继承旧失败反馈。
func _hide_wave_recovery_reads() -> void:
	_show_wave_recovery_read("")


## 返回当前波次撞空后应该点亮的恢复读线。
func _wave_recovery_read_for_current_wave() -> String:
	match _enemy_wave_index:
		1:
			return "LowRecoveryRead"
		2:
			return "AngleRecoveryRead"
		3:
			return "BreakRecoveryRead"
		_:
			return ""


## 只显示当前波次附近的 authored 补能口，避免全场亮点抢路线。
func _show_wave_energy_pockets(active_names: Array) -> void:
	if _wave_energy_pockets == null:
		push_error("%s cannot show wave energy pockets because authored root is missing." % name)
		return
	_wave_energy_pockets.visible = not active_names.is_empty()
	for pocket_name in WAVE_POCKET_NAMES:
		var pocket_node := _wave_energy_pockets.get_node_or_null(pocket_name)
		var pocket := pocket_node as CanvasItem
		if pocket == null or pocket_node == null:
			push_error("%s missing authored wave energy pocket: %s." % [name, pocket_name])
			continue
		var active := active_names.has(pocket_name)
		pocket.visible = active
		if pocket_node is Area2D:
			_set_area_collision_deferred(pocket_node as Area2D, active)


## 隐藏清场段补能口，教学靶链外不残留旧波次资源提示。
func _hide_wave_energy_pockets() -> void:
	_show_wave_energy_pockets([])


## 只显示当前空战房间的 authored 节拍读线。
func _show_air_combat_room(active_name: String) -> void:
	if _air_combat_rooms == null:
		push_error("%s cannot show air combat room because authored root is missing." % name)
		return
	if _air_room_timing_tween != null and _air_room_timing_tween.is_valid():
		_air_room_timing_tween.kill()
	_air_room_timing_tween = null
	for room_name in AIR_COMBAT_ROOM_NAMES:
		var room := _air_combat_rooms.get_node_or_null(room_name) as CanvasItem
		if room == null:
			push_error("%s missing authored air combat room: %s." % [name, room_name])
			continue
		var active: bool = room_name == active_name
		room.visible = active
		_set_air_combat_timing_read(room_name, active)
	if active_name != "":
		_pulse_air_combat_timing_read(active_name)


## 隐藏空战房间节拍层，避免清场外残留读线。
func _hide_air_combat_rooms() -> void:
	_show_air_combat_room("")


## 切换单个空战房间的 authored 节奏门读法。
func _set_air_combat_timing_read(room_name: String, readable: bool) -> void:
	if _air_combat_rooms == null:
		return
	var timing_read := _air_combat_rooms.get_node_or_null(room_name + "/TimingRead") as CanvasItem
	if timing_read == null:
		push_error("%s missing authored air combat timing read: %s/TimingRead." % [name, room_name])
		return
	timing_read.visible = readable
	timing_read.modulate.a = 0.82 if readable else 1.0
	timing_read.scale = Vector2.ONE


## 闪一下当前房间的节奏门，提示玩家“进线后立刻冲撞”。
func _pulse_air_combat_timing_read(room_name: String) -> void:
	if _air_combat_rooms == null:
		return
	var timing_read := _air_combat_rooms.get_node_or_null(room_name + "/TimingRead") as CanvasItem
	if timing_read == null:
		push_error("%s cannot pulse missing air combat timing read: %s." % [name, room_name])
		return
	timing_read.show()
	timing_read.modulate.a = 1.0
	timing_read.scale = Vector2(0.86, 0.86)
	_air_room_timing_tween = create_tween()
	_air_room_timing_tween.tween_property(timing_read, "scale", Vector2(1.08, 1.08), air_room_timing_pulse_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_air_room_timing_tween.parallel().tween_property(timing_read, "modulate:a", 0.74, air_room_timing_pulse_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
