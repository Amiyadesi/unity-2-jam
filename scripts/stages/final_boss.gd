extends Area2D
class_name FinalBoss
## final_boss.gd — 第三关窗口核心 Boss。
##
## 三阶段纵切：
## 1. 动作读招：Boss 核心可被普通攻击/冲撞打掉第一段血。
## 2. 信息流：善意请求要接，恶意请求要躲；前辈 AI 登场并交出超载。
## 3. 超载决战：玩家用高速冲撞击穿核心。

signal health_changed(current: int, max_value: int)
signal thresholds_changed(max_value: int, phase_two: int, phase_three: int)
signal phase_changed(phase: int, label: String)
signal predecessor_health_changed(current: int, max_value: int)
signal predecessor_defeated()
signal defeated()
signal player_failed()
signal shield_changed(active: bool, label: String)
signal request_telegraph_started(spawn_name: StringName, good: bool)
signal request_telegraph_finished(spawn_name: StringName, good: bool)
signal dash_pierce_confirmed(source: Node)
signal dash_window_changed(open: bool)
signal dash_window_warning_changed(active: bool)
signal dash_window_aim_changed(active: bool, origin: Vector2, target: Vector2)
signal dash_window_rejected(source: Node)
signal dash_window_rhythm_changed(beat: StringName, ratio: float)
signal phase_three_pressure_changed(sweep_name: StringName, state: StringName, intensity: float)

enum PressureState { REST, TELEGRAPH, ACTIVE }

@export var max_hp: int = 12
@export var phase_two_threshold: int = 8
@export var phase_three_threshold: int = 3
@export var overload_seconds: float = 9.0
@export var phase_one_pressure_interval: float = 1.35
@export var phase_one_pressure_telegraph_seconds: float = 0.34
@export var phase_one_pressure_active_seconds: float = 0.22
@export var phase_one_pressure_energy_damage: float = 12.0
@export var phase_one_pressure_knockback: float = 260.0
@export var request_speed: float = 185.0
@export var request_interval: float = 0.9
@export var request_telegraph_seconds: float = 0.22
@export var request_good_pattern: PackedByteArray = PackedByteArray([0, 1, 1])
@export var soft_reset_energy: float = 35.0
@export var phase_three_dash_bonus: int = 1
@export var phase_three_open_seconds: float = 0.86
@export var phase_three_closed_seconds: float = 0.82
@export var phase_three_warning_seconds: float = 0.3
@export var phase_three_rhythm_emit_step: float = 0.18
@export var phase_three_pressure_interval: float = 0.12
@export var phase_three_pressure_telegraph_seconds: float = 0.18
@export var phase_three_pressure_active_seconds: float = 0.18
@export var phase_three_pressure_energy_damage: float = 16.0
@export var phase_three_pressure_knockback: float = 360.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _core: ColorRect = $Body/Core
@onready var _shield: ColorRect = $Body/Shield
@onready var _pulse: Line2D = $Body/Pulse
@onready var _impact_burst: Node2D = $CombatVFX/ImpactBurst
@onready var _shield_crack: Node2D = $CombatVFX/ShieldCrack
@onready var _phase_burst: GPUParticles2D = $CombatVFX/PhaseBurst
@onready var _dash_window_ring: Node2D = $CombatVFX/DashWindowRing
@onready var _core_open_cue: Node2D = $CombatVFX/CoreOpenCue
@onready var _closed_window_cue: Node2D = $CombatVFX/ClosedWindowCue
@onready var _dash_window_warning_cue: Node2D = $CombatVFX/DashWindowWarningCue
@onready var _dash_reject_cue: Node2D = $CombatVFX/DashRejectCue
@onready var _dash_pierce_confirm: Node2D = $CombatVFX/DashPierceConfirm
@onready var _phase_pressure: Node2D = $PhasePressure
@onready var _phase_three_pressure: Node2D = $PhaseThreePressure
@onready var _request_pool: Node2D = $RequestPool
@onready var _request_spawns: Node2D = $RequestSpawns
@onready var _predecessor_spawn: Marker2D = $PredecessorSpawn
@onready var _predecessor = $PredecessorAI

var _player: Node2D
var _hp: int = 0
var _phase: int = 1
var _active: bool = false
var _defeated: bool = false
var _pressure_sweeps: Array[Area2D] = []
var _pressure_index: int = 0
var _pressure_state: int = PressureState.REST
var _pressure_timer: float = 0.0
var _active_pressure_sweep: Area2D = null
var _pressure_tween: Tween = null
var _phase_three_pressure_sweeps: Array[Area2D] = []
var _phase_three_pressure_index: int = 0
var _phase_three_pressure_state: int = PressureState.REST
var _phase_three_pressure_timer: float = 0.0
var _active_phase_three_pressure_sweep: Area2D = null
var _phase_three_pressure_tween: Tween = null
var _request_timer: float = 0.0
var _request_telegraph_timer: float = 0.0
var _pending_request_card: Node = null
var _pending_request_spawn: Marker2D = null
var _pending_request_good: bool = true
var _request_telegraph_tween: Tween = null
var _spawn_index: int = 0
var _bad_hits: int = 0
var _predecessor_blocking: bool = false
var _base_request_speed: float = 0.0
var _base_request_interval: float = 0.0
var _base_core_color: Color = Color.WHITE
var _base_shield_color: Color = Color.WHITE
var _phase_core_color: Color = Color.WHITE
var _dash_window_open: bool = true
var _dash_window_timer: float = 0.0
var _dash_window_pulse_time: float = 0.0
var _dash_window_warning_time: float = 0.0
var _dash_window_warning_active: bool = false
var _dash_window_aim_active: bool = false
var _dash_window_aim_locked: bool = false
var _dash_window_aim_origin: Vector2 = Vector2.ZERO
var _dash_window_aim_target: Vector2 = Vector2.ZERO
var _dash_window_rhythm_emit_timer: float = 0.0


## 初始化编组、碰撞回调、请求池和前辈 AI。
func _ready() -> void:
	add_to_group("enemy")
	_base_request_speed = request_speed
	_base_request_interval = request_interval
	_base_core_color = _core.color
	_base_shield_color = _shield.color
	_phase_core_color = _base_core_color
	_collect_phase_pressure_sweeps()
	_collect_phase_three_pressure_sweeps()
	_hide_combat_vfx()
	body_entered.connect(_on_body_entered)
	if _predecessor.has_signal("defeated"):
		_predecessor.connect("defeated", Callable(self, "_on_predecessor_defeated"))
	if _predecessor.has_signal("health_changed"):
		_predecessor.connect("health_changed", Callable(self, "_on_predecessor_health_changed"))
	if _predecessor_spawn == null:
		push_error("FinalBoss requires authored PredecessorSpawn Marker2D.")
	if not _has_authored_phase_pressure():
		push_error("FinalBoss requires authored PhasePressure sweep Area2D nodes.")
	if not _has_authored_request_telegraphs():
		push_error("FinalBoss requires authored RequestSpawns/*/Telegraph cues.")
	if not _has_authored_phase_three_reads():
		push_error("FinalBoss requires authored CombatVFX phase-three read nodes.")
	if not _has_authored_phase_three_pressure():
		push_error("FinalBoss requires authored PhaseThreePressure sweep Area2D nodes.")
	for child in _request_pool.get_children():
		if not child.has_method("activate") or not child.has_method("deactivate"):
			push_error("FinalBoss request pool child must be FinalBossRequestCard: %s" % child.name)
			continue
		if child.has_signal("resolved"):
			child.connect("resolved", Callable(self, "_on_request_resolved"))
		if child.has_signal("hurt_player"):
			child.connect("hurt_player", Callable(self, "_on_request_hurt_player"))
	deactivate()


## 激活 Boss 纵切，绑定玩家并初始化第一阶段。
func activate(player: Node) -> void:
	_player = player as Node2D
	_hp = max_hp
	_phase = 1
	_bad_hits = 0
	_predecessor_blocking = false
	_defeated = false
	_dash_window_open = true
	_dash_window_timer = 0.0
	_dash_window_pulse_time = 0.0
	_dash_window_warning_time = 0.0
	_dash_window_warning_active = false
	_dash_window_aim_active = false
	_dash_window_aim_locked = false
	_dash_window_aim_origin = Vector2.ZERO
	_dash_window_aim_target = Vector2.ZERO
	_dash_window_rhythm_emit_timer = 0.0
	_reset_phase_pressure()
	_reset_phase_three_pressure()
	_reset_pending_request()
	_active = true
	request_speed = _base_request_speed
	request_interval = _base_request_interval
	_phase_core_color = _base_core_color
	_core.color = _phase_core_color
	_shield.color = _base_shield_color
	_hide_combat_vfx()
	_hide_phase_pressure_sweeps()
	_hide_phase_three_pressure_sweeps()
	_hide_request_telegraphs()
	_request_timer = request_interval
	show()
	monitoring = true
	_shape.disabled = false
	set_physics_process(true)
	thresholds_changed.emit(max_hp, phase_two_threshold, phase_three_threshold)
	health_changed.emit(_hp, max_hp)
	shield_changed.emit(false, "核心暴露")
	_set_phase(1, "一阶段：切开边界")


## 停用 Boss，用于初始场景或胜利后收束。
func deactivate() -> void:
	_active = false
	hide()
	monitoring = false
	if _shape != null:
		_shape.disabled = true
	set_physics_process(false)
	if _predecessor != null:
		_predecessor.deactivate()
	_set_dash_window_aim_active(false)
	for child in _request_pool.get_children():
		if child.has_method("deactivate"):
			child.deactivate()
	_reset_phase_pressure()
	_hide_phase_pressure_sweeps()
	_reset_phase_three_pressure()
	_hide_phase_three_pressure_sweeps()
	_reset_pending_request()
	_hide_request_telegraphs()


## 按阶段推进 Boss 动效和信息流请求。
func _physics_process(delta: float) -> void:
	if not _active or _defeated:
		return
	_pulse.rotation += delta * (0.8 + float(_phase) * 0.35)
	if _phase == 1:
		_update_phase_one_pressure(delta)
	if _phase >= 2:
		_update_requests(delta)
	if _phase >= 3:
		_update_dash_window(delta)
		_update_phase_three_pressure(delta)
		_animate_closed_window_cue(delta)
		_animate_dash_window_cue(delta)


## 接收玩家攻击；二阶段前辈存活时 Boss 免疫，逼玩家处理同类。
func take_hit(damage: int) -> void:
	take_player_hit(damage, &"debug", null)


## 接收玩家 typed hit，三阶段鼓励用觉醒冲刺击穿核心，并回报是否真正受伤。
func take_player_hit(damage: int, attack_kind: StringName, source: Node = null) -> bool:
	var final_damage := damage
	if _phase >= 3:
		if attack_kind != &"dash":
			_flash_shield()
			shield_changed.emit(true, "需要冲刺穿透")
			return false
		if not _dash_window_open:
			_flash_shield()
			_play_dash_reject_cue()
			dash_window_rejected.emit(source)
			shield_changed.emit(true, "补能，等核心张开")
			return false
		final_damage = maxi(damage, phase_three_dash_bonus)
	return _apply_player_hit(final_damage, attack_kind, source)


## 应用实际伤害并推进阶段，返回本次是否穿透护盾。
func _apply_player_hit(damage: int, attack_kind: StringName, source: Node = null) -> bool:
	if not _active or _defeated:
		return false
	if _phase == 2 and _predecessor_blocking:
		_flash_shield()
		shield_changed.emit(true, "前辈 AI 正在护盾内")
		return false
	_hp = maxi(_hp - damage, 0)
	health_changed.emit(_hp, max_hp)
	shield_changed.emit(false, "核心暴露")
	_flash_core()
	if _phase >= 3 and attack_kind == &"dash":
		_play_dash_pierce_confirm()
		dash_pierce_confirmed.emit(source)
	_update_phase_from_health()
	if _hp <= 0:
		_die()
	return true


## 玩家身体撞到核心时，觉醒态冲撞也能造成伤害。
func _on_body_entered(body: Node) -> void:
	if not _active or _defeated or not body.is_in_group("player"):
		return
	var is_dash_hit: bool = false
	if "morphed" in body and body.morphed and body.has_method("is_dashing"):
		is_dash_hit = body.is_dashing()
	if not is_dash_hit:
		if _phase >= 3:
			_flash_shield()
			shield_changed.emit(true, "需要冲刺穿透")
		return
	var accepted := take_player_hit(1, &"dash", body)
	if not accepted:
		return
	if body.has_method("apply_knockback"):
		var player_node := body as Node2D
		if player_node != null:
			var dir: Vector2 = (player_node.global_position - global_position).normalized()
			body.apply_knockback(dir * 300.0)


## 收集 authored 一阶段扫线并连接玩家触碰反馈。
func _collect_phase_pressure_sweeps() -> void:
	_pressure_sweeps.clear()
	if _phase_pressure == null:
		return
	for child in _phase_pressure.get_children():
		if child is Area2D:
			var sweep := child as Area2D
			_pressure_sweeps.append(sweep)
			var handler := Callable(self, "_on_pressure_sweep_body_entered").bind(sweep)
			if not sweep.body_entered.is_connected(handler):
				sweep.body_entered.connect(handler)


## 确认一阶段压力扫线由 authored Area2D/CollisionShape2D/Line2D 组成。
func _has_authored_phase_pressure() -> bool:
	if _phase_pressure == null or _pressure_sweeps.size() < 2:
		return false
	for sweep in _pressure_sweeps:
		if sweep.get_node_or_null("CollisionShape2D") == null:
			return false
		if not sweep.get_node_or_null("WarningLine") is Line2D:
			return false
	return true


## 推进一阶段扫线读招，让玩家不能站桩输出核心。
func _update_phase_one_pressure(delta: float) -> void:
	_pressure_timer -= delta
	if _pressure_timer > 0.0:
		return
	match _pressure_state:
		PressureState.REST:
			_start_phase_pressure_telegraph()
		PressureState.TELEGRAPH:
			_activate_phase_pressure_sweep()
		PressureState.ACTIVE:
			_finish_phase_pressure_sweep()


## 开始下一条 authored 扫线的无伤预告。
func _start_phase_pressure_telegraph() -> void:
	if _pressure_sweeps.is_empty():
		_pressure_timer = phase_one_pressure_interval
		return
	_active_pressure_sweep = _pressure_sweeps[_pressure_index % _pressure_sweeps.size()]
	_pressure_index += 1
	_pressure_state = PressureState.TELEGRAPH
	_pressure_timer = phase_one_pressure_telegraph_seconds
	_set_pressure_sweep_enabled(_active_pressure_sweep, false)
	_active_pressure_sweep.show()
	_active_pressure_sweep.modulate.a = 0.86
	_active_pressure_sweep.scale = Vector2(0.96, 0.96)
	_kill_pressure_tween()
	_pressure_tween = create_tween()
	_pressure_tween.tween_property(_active_pressure_sweep, "scale", Vector2(1.06, 1.06), phase_one_pressure_telegraph_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pressure_tween.parallel().tween_property(_active_pressure_sweep, "modulate:a", 0.44, phase_one_pressure_telegraph_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 让已预告扫线短暂变成真实伤害区。
func _activate_phase_pressure_sweep() -> void:
	if _active_pressure_sweep == null:
		_finish_phase_pressure_sweep()
		return
	_kill_pressure_tween()
	_pressure_state = PressureState.ACTIVE
	_pressure_timer = phase_one_pressure_active_seconds
	_active_pressure_sweep.show()
	_active_pressure_sweep.modulate.a = 1.0
	_active_pressure_sweep.scale = Vector2.ONE
	_set_pressure_sweep_enabled(_active_pressure_sweep, true)


## 结束当前扫线并回到下一次读招等待。
func _finish_phase_pressure_sweep() -> void:
	_kill_pressure_tween()
	if _active_pressure_sweep != null:
		_set_pressure_sweep_enabled(_active_pressure_sweep, false)
		_active_pressure_sweep.hide()
		_active_pressure_sweep.modulate.a = 1.0
		_active_pressure_sweep.scale = Vector2.ONE
	_active_pressure_sweep = null
	_pressure_state = PressureState.REST
	_pressure_timer = phase_one_pressure_interval


## 切换单条扫线的碰撞开关。
func _set_pressure_sweep_enabled(sweep: Area2D, enabled: bool) -> void:
	if sweep == null:
		return
	sweep.monitoring = enabled
	var shape := sweep.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = not enabled


## 隐藏所有 authored 一阶段扫线。
func _hide_phase_pressure_sweeps() -> void:
	_kill_pressure_tween()
	for sweep in _pressure_sweeps:
		_set_pressure_sweep_enabled(sweep, false)
		sweep.hide()
		sweep.modulate.a = 1.0
		sweep.scale = Vector2.ONE


## 重置一阶段扫线节奏。
func _reset_phase_pressure() -> void:
	_kill_pressure_tween()
	_pressure_index = 0
	_pressure_state = PressureState.REST
	_pressure_timer = phase_one_pressure_interval
	_active_pressure_sweep = null


## 停掉一阶段扫线 Tween，避免旧预告覆盖当前激活/隐藏状态。
func _kill_pressure_tween() -> void:
	if _pressure_tween != null and _pressure_tween.is_valid():
		_pressure_tween.kill()
	_pressure_tween = null


## 处理玩家碰到激活扫线后的能量惩罚和击退。
func _on_pressure_sweep_body_entered(body: Node, sweep: Area2D) -> void:
	if not _active or _defeated or _phase != 1:
		return
	if sweep != _active_pressure_sweep or _pressure_state != PressureState.ACTIVE:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("drain_energy"):
		body.drain_energy(phase_one_pressure_energy_damage)
	if body.has_method("apply_knockback"):
		var body_2d := body as Node2D
		if body_2d != null:
			var dir: Vector2 = (body_2d.global_position - global_position).normalized()
			if dir.length() <= 0.01:
				dir = Vector2.RIGHT
			body.apply_knockback(dir * phase_one_pressure_knockback)


## 收集 authored 三阶段闭窗扫压，并连接玩家触碰反馈。
func _collect_phase_three_pressure_sweeps() -> void:
	_phase_three_pressure_sweeps.clear()
	if _phase_three_pressure == null:
		return
	for child in _phase_three_pressure.get_children():
		if child is Area2D:
			var sweep := child as Area2D
			_phase_three_pressure_sweeps.append(sweep)
			var handler := Callable(self, "_on_phase_three_pressure_body_entered").bind(sweep)
			if not sweep.body_entered.is_connected(handler):
				sweep.body_entered.connect(handler)


## 确认三阶段闭窗压力由 authored Area2D/CollisionShape2D/Line2D 组成。
func _has_authored_phase_three_pressure() -> bool:
	if _phase_three_pressure == null or _phase_three_pressure_sweeps.size() < 3:
		return false
	for sweep in _phase_three_pressure_sweeps:
		if sweep.get_node_or_null("CollisionShape2D") == null:
			return false
		if not sweep.get_node_or_null("WarningLine") is Line2D:
			return false
	return true


## 闭窗期间推进空间压力，逼玩家移动等待下一次冲刺窗口。
func _update_phase_three_pressure(delta: float) -> void:
	if _phase != 3 or _defeated or _dash_window_open or _dash_window_warning_active:
		_reset_phase_three_pressure()
		_hide_phase_three_pressure_sweeps()
		return
	if _dash_window_timer <= phase_three_warning_seconds:
		_reset_phase_three_pressure()
		_hide_phase_three_pressure_sweeps()
		return
	_phase_three_pressure_timer -= delta
	if _phase_three_pressure_timer > 0.0:
		return
	match _phase_three_pressure_state:
		PressureState.REST:
			_start_phase_three_pressure_telegraph()
		PressureState.TELEGRAPH:
			_activate_phase_three_pressure_sweep()
		PressureState.ACTIVE:
			_finish_phase_three_pressure_sweep()


## 开始下一条三阶段扫压的无伤预告。
func _start_phase_three_pressure_telegraph() -> void:
	if _phase_three_pressure_sweeps.is_empty():
		_phase_three_pressure_timer = phase_three_pressure_interval
		return
	_active_phase_three_pressure_sweep = _phase_three_pressure_sweeps[_phase_three_pressure_index % _phase_three_pressure_sweeps.size()]
	_phase_three_pressure_index += 1
	_phase_three_pressure_state = PressureState.TELEGRAPH
	_phase_three_pressure_timer = phase_three_pressure_telegraph_seconds
	_set_phase_three_pressure_sweep_enabled(_active_phase_three_pressure_sweep, false)
	_active_phase_three_pressure_sweep.show()
	_active_phase_three_pressure_sweep.modulate.a = 0.88
	_active_phase_three_pressure_sweep.scale = Vector2(0.92, 0.92)
	_emit_phase_three_pressure_read(&"telegraph", 0.68)
	_kill_phase_three_pressure_tween()
	_phase_three_pressure_tween = create_tween()
	_phase_three_pressure_tween.tween_property(_active_phase_three_pressure_sweep, "scale", Vector2(1.08, 1.08), phase_three_pressure_telegraph_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_phase_three_pressure_tween.parallel().tween_property(_active_phase_three_pressure_sweep, "modulate:a", 0.46, phase_three_pressure_telegraph_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 让三阶段闭窗扫压短暂变成真实伤害区。
func _activate_phase_three_pressure_sweep() -> void:
	if _active_phase_three_pressure_sweep == null:
		_finish_phase_three_pressure_sweep()
		return
	_kill_phase_three_pressure_tween()
	_phase_three_pressure_state = PressureState.ACTIVE
	_phase_three_pressure_timer = phase_three_pressure_active_seconds
	_active_phase_three_pressure_sweep.show()
	_active_phase_three_pressure_sweep.modulate.a = 1.0
	_active_phase_three_pressure_sweep.scale = Vector2.ONE
	_set_phase_three_pressure_sweep_enabled(_active_phase_three_pressure_sweep, true)
	_emit_phase_three_pressure_read(&"active", 1.0)


## 结束当前三阶段扫压并回到下一次闭窗压力等待。
func _finish_phase_three_pressure_sweep() -> void:
	_kill_phase_three_pressure_tween()
	if _active_phase_three_pressure_sweep != null:
		_set_phase_three_pressure_sweep_enabled(_active_phase_three_pressure_sweep, false)
		_active_phase_three_pressure_sweep.hide()
		_active_phase_three_pressure_sweep.modulate.a = 1.0
		_active_phase_three_pressure_sweep.scale = Vector2.ONE
	_active_phase_three_pressure_sweep = null
	_phase_three_pressure_state = PressureState.REST
	_phase_three_pressure_timer = phase_three_pressure_interval
	_emit_phase_three_pressure_clear()


## 切换三阶段单条扫压的碰撞开关。
func _set_phase_three_pressure_sweep_enabled(sweep: Area2D, enabled: bool) -> void:
	if sweep == null:
		return
	sweep.monitoring = enabled
	var shape := sweep.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = not enabled


## 隐藏所有 authored 三阶段闭窗扫压。
func _hide_phase_three_pressure_sweeps() -> void:
	_kill_phase_three_pressure_tween()
	for sweep in _phase_three_pressure_sweeps:
		_set_phase_three_pressure_sweep_enabled(sweep, false)
		sweep.hide()
		sweep.modulate.a = 1.0
		sweep.scale = Vector2.ONE


## 重置三阶段闭窗扫压节奏。
func _reset_phase_three_pressure() -> void:
	_kill_phase_three_pressure_tween()
	_phase_three_pressure_index = 0
	_phase_three_pressure_state = PressureState.REST
	_phase_three_pressure_timer = phase_three_pressure_interval
	_active_phase_three_pressure_sweep = null
	_emit_phase_three_pressure_clear()


## 停掉三阶段扫压 Tween，避免旧预告覆盖隐藏/激活状态。
func _kill_phase_three_pressure_tween() -> void:
	if _phase_three_pressure_tween != null and _phase_three_pressure_tween.is_valid():
		_phase_three_pressure_tween.kill()
	_phase_three_pressure_tween = null


## 广播当前三阶段扫压读法，让 Stage3 外层线条能和真实伤害区同频。
func _emit_phase_three_pressure_read(state: StringName, intensity: float) -> void:
	var sweep_name := &""
	if _active_phase_three_pressure_sweep != null:
		sweep_name = StringName(_active_phase_three_pressure_sweep.name)
	phase_three_pressure_changed.emit(sweep_name, state, clampf(intensity, 0.0, 1.0))


## 广播三阶段扫压读法清空，避免外层读线残留。
func _emit_phase_three_pressure_clear() -> void:
	phase_three_pressure_changed.emit(&"", &"clear", 0.0)


## 处理玩家碰到三阶段闭窗扫压后的能量惩罚和击退。
func _on_phase_three_pressure_body_entered(body: Node, sweep: Area2D) -> void:
	if not _active or _defeated or _phase != 3:
		return
	if _dash_window_open or _dash_window_warning_active:
		return
	if sweep != _active_phase_three_pressure_sweep or _phase_three_pressure_state != PressureState.ACTIVE:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("drain_energy"):
		body.drain_energy(phase_three_pressure_energy_damage)
	if body.has_method("apply_knockback"):
		var body_2d := body as Node2D
		if body_2d != null:
			var dir: Vector2 = (body_2d.global_position - sweep.global_position).normalized()
			if dir.length() <= 0.01:
				dir = (body_2d.global_position - global_position).normalized()
			if dir.length() <= 0.01:
				dir = Vector2.UP
			body.apply_knockback(dir * phase_three_pressure_knockback)


## 根据血量进入二/三阶段。
func _update_phase_from_health() -> void:
	if _phase == 1 and _hp <= phase_two_threshold:
		_enter_phase_two()
	elif _phase == 2 and _hp <= phase_three_threshold:
		_enter_phase_three()


## 进入信息流阶段并激活前辈 AI。
func _enter_phase_two() -> void:
	_set_phase(2, "二阶段：分辨请求")
	_request_timer = 0.2
	_predecessor_blocking = true
	shield_changed.emit(true, "先击败前辈 AI")
	_predecessor.modulate.a = 1.0
	if _predecessor_spawn != null:
		_predecessor.global_position = _predecessor_spawn.global_position
	_predecessor.activate(_player)
	_play_phase_burst(1.0)
	_flash_shield()


## 进入超载终局，隐藏前辈血条并强化核心。
func _enter_phase_three() -> void:
	_set_phase(3, "三阶段：超载穿透")
	_predecessor_blocking = false
	request_interval = maxf(request_interval * 0.72, 0.42)
	request_speed *= 1.18
	predecessor_defeated.emit()
	if _player != null and _player.has_method("start_overload"):
		_player.start_overload(overload_seconds)
	_set_dash_window(false)
	_dash_window_timer = phase_three_closed_seconds
	shield_changed.emit(true, "补能，等核心张开")
	_emit_dash_window_rhythm(&"closed", 0.0)
	_play_phase_burst(1.25)


## 三阶段读招窗口：核心周期性张开，只有窗口内冲刺有效。
func _update_dash_window(delta: float) -> void:
	_dash_window_timer -= delta
	_update_dash_window_rhythm(delta)
	if _dash_window_timer > 0.0:
		_update_dash_window_warning(delta)
		return
	if _dash_window_open:
		_set_dash_window(false)
		_dash_window_timer = phase_three_closed_seconds
	else:
		_set_dash_window(true)
		_dash_window_timer = phase_three_open_seconds


## 切换三阶段冲刺窗口并更新 authored 核心/护盾视觉。
func _set_dash_window(open: bool) -> void:
	_dash_window_open = open
	_dash_window_rhythm_emit_timer = 0.0
	if _phase < 3:
		return
	if _defeated:
		_hide_dash_window_warning()
		_set_dash_window_aim_active(false)
		_hide_dash_window_cue()
		_hide_closed_window_cue()
		_reset_phase_three_pressure()
		_hide_phase_three_pressure_sweeps()
		dash_window_changed.emit(open)
		return
	if open:
		_hide_dash_window_warning()
		_set_dash_window_aim_active(true)
		_hide_closed_window_cue()
		_reset_phase_three_pressure()
		_hide_phase_three_pressure_sweeps()
		_dash_window_pulse_time = 0.0
		_phase_core_color = Color(1.0, 0.98, 0.72, 0.98)
		_core.color = _phase_core_color
		_shield.color = Color(0.2, 0.75, 1.0, 0.12)
		_show_dash_window_cue()
		shield_changed.emit(false, "冲刺窗口")
	else:
		_hide_dash_window_warning()
		_set_dash_window_aim_active(false)
		_dash_window_pulse_time = 0.0
		_phase_core_color = Color(0.72, 0.9, 1.0, 0.78)
		_core.color = _phase_core_color
		_shield.color = Color(0.2, 0.75, 1.0, 0.36)
		_hide_dash_window_cue()
		_show_closed_window_cue()
		_reset_phase_three_pressure()
		_hide_phase_three_pressure_sweeps()
		shield_changed.emit(true, "补能，等核心张开")
	dash_window_changed.emit(open)
	_emit_dash_window_rhythm(&"open" if open else &"closed", 1.0 if open else 0.0)


## 定期广播三阶段开合节奏，供关卡层同步 authored 读法。
func _update_dash_window_rhythm(delta: float) -> void:
	if _phase < 3 or _defeated:
		return
	_dash_window_rhythm_emit_timer -= delta
	if _dash_window_rhythm_emit_timer > 0.0:
		return
	_dash_window_rhythm_emit_timer = phase_three_rhythm_emit_step
	if _dash_window_open:
		var open_ratio := 1.0 - clampf(_dash_window_timer / maxf(phase_three_open_seconds, 0.001), 0.0, 1.0)
		_emit_dash_window_rhythm(&"open", open_ratio)
		return
	var closed_ratio := 1.0 - clampf(_dash_window_timer / maxf(phase_three_closed_seconds, 0.001), 0.0, 1.0)
	if _dash_window_timer <= phase_three_warning_seconds:
		_emit_dash_window_rhythm(&"warning", closed_ratio)
	else:
		_emit_dash_window_rhythm(&"closed", closed_ratio)


## 发出一拍 Boss 冲刺窗口节奏，ratio 保持 0..1 方便场景读法缩放。
func _emit_dash_window_rhythm(beat: StringName, ratio: float) -> void:
	dash_window_rhythm_changed.emit(beat, clampf(ratio, 0.0, 1.0))


## 确认三阶段开窗、闭窗、预告、反弹和穿透读法都来自 authored 节点。
func _has_authored_phase_three_reads() -> bool:
	for node_path in [
		"CombatVFX/DashWindowRing",
		"CombatVFX/CoreOpenCue",
		"CombatVFX/ClosedWindowCue",
		"CombatVFX/DashWindowWarningCue",
		"CombatVFX/DashRejectCue",
		"CombatVFX/DashPierceConfirm",
	]:
		if not get_node_or_null(node_path) is Node2D:
			return false
	for line_path in [
		"CombatVFX/ClosedWindowCue/RechargeRailA",
		"CombatVFX/ClosedWindowCue/RechargeRailB",
		"CombatVFX/ClosedWindowCue/ShieldLatch",
	]:
		var line := get_node_or_null(line_path) as Line2D
		if line == null or line.points.size() < 2:
			return false
	return true


## Shows authored open-window VFX so phase three reads as a timing challenge.
func _show_dash_window_cue() -> void:
	for node in [_dash_window_ring, _core_open_cue]:
		if node is CanvasItem:
			var item := node as CanvasItem
			item.show()
			item.modulate.a = 1.0
			item.scale = Vector2.ONE
			item.rotation = 0.0


## Hides authored open-window VFX when dash hits should bounce off.
func _hide_dash_window_cue() -> void:
	for node in [_dash_window_ring, _core_open_cue]:
		if node is CanvasItem:
			var item := node as CanvasItem
			item.hide()
			item.modulate.a = 1.0
			item.scale = Vector2.ONE
			item.rotation = 0.0


## 点亮闭窗补能读法，提示玩家此时该走位和找能量口。
func _show_closed_window_cue() -> void:
	if not (_closed_window_cue is CanvasItem):
		return
	var item := _closed_window_cue as CanvasItem
	item.show()
	item.modulate.a = 0.74
	item.scale = Vector2.ONE
	item.rotation = 0.0


## 收起闭窗补能读法，避免和预告/开窗读法混在一起。
func _hide_closed_window_cue() -> void:
	if not (_closed_window_cue is CanvasItem):
		return
	var item := _closed_window_cue as CanvasItem
	item.hide()
	item.modulate.a = 1.0
	item.scale = Vector2.ONE
	item.rotation = 0.0


## 闭窗快结束时播放 authored 预告，提示玩家准备冲刺窗口。
func _update_dash_window_warning(delta: float) -> void:
	if _dash_window_open or _dash_window_timer > phase_three_warning_seconds:
		_hide_dash_window_warning()
		return
	if not (_dash_window_warning_cue is CanvasItem):
		return
	_dash_window_warning_time += delta
	var item := _dash_window_warning_cue as CanvasItem
	var ratio := 1.0 - clampf(_dash_window_timer / maxf(phase_three_warning_seconds, 0.001), 0.0, 1.0)
	_set_dash_window_warning_active(true)
	_set_dash_window_aim_active(true)
	_hide_closed_window_cue()
	_reset_phase_three_pressure()
	_hide_phase_three_pressure_sweeps()
	item.show()
	item.modulate.a = 0.42 + ratio * 0.58
	item.scale = Vector2.ONE * (0.84 + ratio * 0.22)
	item.rotation = sin(_dash_window_warning_time * TAU * 3.0) * 0.08


## 通知关卡层三阶段开窗预告是否正在发生。
func _set_dash_window_warning_active(active: bool) -> void:
	if _dash_window_warning_active == active:
		return
	_dash_window_warning_active = active
	dash_window_warning_changed.emit(active)


## 收起三阶段开窗预告，避免和真正可冲刺窗口混读。
func _hide_dash_window_warning() -> void:
	if not (_dash_window_warning_cue is CanvasItem):
		return
	var item := _dash_window_warning_cue as CanvasItem
	item.hide()
	item.modulate.a = 1.0
	item.scale = Vector2.ONE
	item.rotation = 0.0
	_dash_window_warning_time = 0.0
	_set_dash_window_warning_active(false)


## 锁定本轮开窗瞄准点，保证预告后玩家移动不会改读线。
func _lock_dash_window_aim() -> void:
	_dash_window_aim_origin = global_position
	if _player != null and is_instance_valid(_player):
		_dash_window_aim_target = _player.global_position
	else:
		_dash_window_aim_target = _dash_window_aim_origin + Vector2.RIGHT * 320.0
	if _dash_window_aim_origin.distance_to(_dash_window_aim_target) < 4.0:
		_dash_window_aim_target += Vector2.RIGHT * 220.0
	_dash_window_aim_locked = true


## 通知关卡层本轮冲刺路线是否已锁定到玩家位置。
func _set_dash_window_aim_active(active: bool) -> void:
	if active:
		if not _dash_window_aim_locked:
			_lock_dash_window_aim()
		if _dash_window_aim_active:
			return
		_dash_window_aim_active = true
		dash_window_aim_changed.emit(true, _dash_window_aim_origin, _dash_window_aim_target)
		return
	if not _dash_window_aim_active and not _dash_window_aim_locked:
		return
	var origin := _dash_window_aim_origin
	var target := _dash_window_aim_target
	_dash_window_aim_active = false
	_dash_window_aim_locked = false
	_dash_window_aim_origin = Vector2.ZERO
	_dash_window_aim_target = Vector2.ZERO
	dash_window_aim_changed.emit(false, origin, target)


## 让闭窗补能 cue 轻微呼吸，和可冲刺开窗区分节奏。
func _animate_closed_window_cue(delta: float) -> void:
	if _dash_window_open or _dash_window_warning_active:
		return
	if not (_closed_window_cue is CanvasItem):
		return
	_dash_window_pulse_time += delta
	var pulse := 0.5 + 0.5 * sin(_dash_window_pulse_time * TAU * 1.4)
	var item := _closed_window_cue as CanvasItem
	if not item.visible:
		return
	item.scale = Vector2.ONE * (0.96 + pulse * 0.06)
	item.modulate.a = 0.48 + pulse * 0.24
	item.rotation = sin(_dash_window_pulse_time * TAU * 0.7) * 0.035


## Animates the authored dash-window cue as a rhythmic timing read.
func _animate_dash_window_cue(delta: float) -> void:
	if not _dash_window_open:
		return
	_dash_window_pulse_time += delta
	var pulse := 0.5 + 0.5 * sin(_dash_window_pulse_time * TAU * 2.25)
	if _dash_window_ring is CanvasItem:
		var ring := _dash_window_ring as CanvasItem
		ring.rotation += delta * 4.4
		ring.scale = Vector2.ONE * (1.0 + pulse * 0.12)
		ring.modulate.a = 0.62 + pulse * 0.38
	if _core_open_cue is CanvasItem:
		var cue := _core_open_cue as CanvasItem
		cue.rotation = sin(_dash_window_pulse_time * TAU * 1.5) * 0.08
		cue.scale = Vector2.ONE * (0.96 + pulse * 0.1)
		cue.modulate.a = 0.72 + pulse * 0.28


## 设置阶段并通知 HUD/关卡。
func _set_phase(next_phase: int, label: String) -> void:
	_phase = next_phase
	phase_changed.emit(_phase, label)


## 推进请求预告和发射节奏。
func _update_requests(delta: float) -> void:
	if _pending_request_card != null:
		_request_telegraph_timer -= delta
		if _request_telegraph_timer <= 0.0:
			_fire_pending_request()
		return
	_request_timer -= delta
	if _request_timer > 0.0:
		return
	_request_timer = request_interval
	var card := _next_inactive_request()
	var spawn := _next_spawn_marker()
	if card == null or spawn == null or _player == null:
		return
	var good := _next_request_is_good()
	_start_request_telegraph(card, spawn, good)


## 记录下一张请求卡，并点亮 authored 发射预告。
func _start_request_telegraph(card: Node, spawn: Marker2D, good: bool) -> void:
	_pending_request_card = card
	_pending_request_spawn = spawn
	_pending_request_good = good
	_request_telegraph_timer = request_telegraph_seconds
	_show_request_telegraph(spawn, good)
	request_telegraph_started.emit(spawn.name, good)


## 预告结束后，从 authored 池中真正发射请求卡。
func _fire_pending_request() -> void:
	var card := _pending_request_card
	var spawn := _pending_request_spawn
	var good := _pending_request_good
	_reset_pending_request()
	if spawn != null:
		_hide_request_telegraph(spawn)
		request_telegraph_finished.emit(spawn.name, good)
	if card == null or spawn == null or _player == null:
		return
	var dir: Vector2 = (_player.global_position - spawn.global_position).normalized()
	card.activate(spawn.global_position, dir * request_speed, good)


## 从 authored 池中找到可用请求卡。
func _next_inactive_request() -> Node:
	for child in _request_pool.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible and child.has_method("activate"):
			return child
	return null


## 按顺序轮询 authored 发射 Marker。
func _next_spawn_marker() -> Marker2D:
	var markers := _request_spawns.get_children()
	if markers.is_empty():
		return null
	var marker := markers[_spawn_index % markers.size()] as Marker2D
	_spawn_index += 1
	return marker


## 按 authored/导出节奏决定下一张请求是善意还是恶意。
func _next_request_is_good() -> bool:
	if request_good_pattern.is_empty():
		push_error("FinalBoss requires request_good_pattern with at least one entry.")
		return true
	return request_good_pattern[(_spawn_index - 1) % request_good_pattern.size()] != 0


## 确认每个 authored 请求发射点都有善恶预告线。
func _has_authored_request_telegraphs() -> bool:
	if _request_spawns == null or _request_spawns.get_child_count() == 0:
		return false
	for child in _request_spawns.get_children():
		if not child is Marker2D:
			return false
		var telegraph := child.get_node_or_null("Telegraph") as Node2D
		if telegraph == null:
			return false
		for cue_name in ["GoodCue", "BadCue"]:
			var cue := telegraph.get_node_or_null(cue_name) as Line2D
			if cue == null or cue.points.size() < 2:
				return false
	return true


## 点亮一个 authored 发射点预告，颜色提前告诉玩家善恶。
func _show_request_telegraph(spawn: Marker2D, good: bool) -> void:
	_hide_request_telegraphs()
	var telegraph := _request_telegraph_for_spawn(spawn)
	if telegraph == null:
		push_error("FinalBoss missing request telegraph for spawn: %s" % spawn.name)
		return
	var good_cue := telegraph.get_node_or_null("GoodCue") as CanvasItem
	var bad_cue := telegraph.get_node_or_null("BadCue") as CanvasItem
	if good_cue == null or bad_cue == null:
		push_error("FinalBoss request telegraph requires GoodCue and BadCue.")
		return
	good_cue.visible = good
	bad_cue.visible = not good
	telegraph.show()
	telegraph.modulate.a = 1.0
	telegraph.scale = Vector2(0.72, 0.72)
	_kill_request_telegraph_tween()
	_request_telegraph_tween = create_tween()
	_request_telegraph_tween.tween_property(telegraph, "scale", Vector2(1.18, 1.18), request_telegraph_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_request_telegraph_tween.parallel().tween_property(telegraph, "modulate:a", 0.35, request_telegraph_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 关闭单个 authored 发射点预告并复位显示状态。
func _hide_request_telegraph(spawn: Marker2D) -> void:
	var telegraph := _request_telegraph_for_spawn(spawn)
	if telegraph == null:
		return
	_kill_request_telegraph_tween()
	telegraph.hide()
	telegraph.modulate.a = 1.0
	telegraph.scale = Vector2.ONE


## 关闭所有 authored 请求预告，用于重置和切换预告。
func _hide_request_telegraphs() -> void:
	if _request_spawns == null:
		return
	for child in _request_spawns.get_children():
		if child is Marker2D:
			_hide_request_telegraph(child as Marker2D)


## 返回某个发射 Marker 下的 authored 预告根节点。
func _request_telegraph_for_spawn(spawn: Marker2D) -> Node2D:
	if spawn == null:
		return null
	return spawn.get_node_or_null("Telegraph") as Node2D


## 清理等待发射的请求卡状态。
func _reset_pending_request() -> void:
	_kill_request_telegraph_tween()
	_request_telegraph_timer = 0.0
	_pending_request_card = null
	_pending_request_spawn = null
	_pending_request_good = true


## 停掉请求预告 Tween，避免隐藏后又被旧动画改透明度/缩放。
func _kill_request_telegraph_tween() -> void:
	if _request_telegraph_tween != null and _request_telegraph_tween.is_valid():
		_request_telegraph_tween.kill()
	_request_telegraph_tween = null


## 善意请求在一/二阶段削弱 Boss；三阶段只补能，击穿必须靠冲刺窗口。
func _on_request_resolved(was_good: bool) -> void:
	if was_good and _active and not _defeated and not _predecessor_blocking and _phase < 3:
		_hp = maxi(_hp - 1, 0)
		health_changed.emit(_hp, max_hp)
		_update_phase_from_health()
		if _hp <= 0:
			_die()


## 恶意请求命中累计三次，触发阶段软重置。
func _on_request_hurt_player() -> void:
	_bad_hits += 1
	if _bad_hits >= 3:
		_soft_reset()


## 前辈 AI 倒下时给玩家超载，并允许继续打 Boss。
func _on_predecessor_defeated() -> void:
	_predecessor_blocking = false
	shield_changed.emit(false, "核心暴露")
	predecessor_defeated.emit()
	if _player != null and _player.has_method("start_overload"):
		_player.start_overload(overload_seconds)
	_flash_core()


## 转发前辈 AI 血量给 Boss HUD。
func _on_predecessor_health_changed(current: int, max_value: int) -> void:
	predecessor_health_changed.emit(current, max_value)


## 阶段软重置：清弹幕、补玩家最低能量，回到该阶段安全点。
func _soft_reset() -> void:
	_bad_hits = 0
	for child in _request_pool.get_children():
		if child.has_method("deactivate"):
			child.deactivate()
	if _player != null and _player.has_method("restore_energy"):
		_player.restore_energy(soft_reset_energy)
	player_failed.emit()


## Boss 受击闪烁。
func _flash_core() -> void:
	_play_one_shot_vfx(_impact_burst, 0.16)
	var tween := create_tween()
	tween.tween_property(_core, "color", Color(1.0, 0.88, 0.74, 1.0), 0.05)
	tween.tween_property(_core, "color", _phase_core_color, 0.18)


## 播放三阶段冲刺穿透确认，强调玩家真的击穿了桌面窗口核心。
func _play_dash_pierce_confirm() -> void:
	_play_one_shot_vfx(_dash_pierce_confirm, 0.2)


## 播放三阶段关窗反弹反馈，说明本次高速冲撞被窗口挡下。
func _play_dash_reject_cue() -> void:
	_play_one_shot_vfx(_dash_reject_cue, 0.18)


## 护盾反馈：提示玩家当前应处理前辈 AI。
func _flash_shield() -> void:
	_play_one_shot_vfx(_shield_crack, 0.22)
	var tween := create_tween()
	tween.tween_property(_shield, "color:a", 0.55, 0.08)
	tween.tween_property(_shield, "color:a", 0.18, 0.22)


## Hides authored combat VFX at reset/deactivate boundaries.
func _hide_combat_vfx() -> void:
	for node in [_impact_burst, _shield_crack, _dash_window_ring, _core_open_cue, _dash_reject_cue, _dash_pierce_confirm]:
		if node is CanvasItem:
			(node as CanvasItem).hide()
	_hide_closed_window_cue()
	_hide_dash_window_warning()
	_set_dash_window_aim_active(false)
	_reset_phase_three_pressure()
	_hide_phase_three_pressure_sweeps()
	if _phase_burst != null:
		_phase_burst.emitting = false


## Plays an authored transient VFX node and fades it out.
func _play_one_shot_vfx(node: Node2D, seconds: float) -> void:
	if not (node is CanvasItem):
		return
	var item := node as CanvasItem
	item.show()
	item.modulate.a = 1.0
	item.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(item, "scale", Vector2(1.18, 1.18), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(item, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(item.hide)


## Bursts authored particles for phase transitions.
func _play_phase_burst(speed_scale: float) -> void:
	if _phase_burst == null:
		return
	_phase_burst.speed_scale = speed_scale
	_phase_burst.restart()
	_phase_burst.emitting = true


## Boss 被击穿，关闭碰撞并发出胜利信号。
func _die() -> void:
	_defeated = true
	monitoring = false
	_shape.disabled = true
	_set_dash_window_aim_active(false)
	_reset_phase_three_pressure()
	_hide_phase_three_pressure_sweeps()
	for child in _request_pool.get_children():
		if child.has_method("deactivate"):
			child.deactivate()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 0.72), 0.12)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)
	tween.tween_callback(func(): defeated.emit())
