extends CharacterBody2D
class_name CloseAIPlayer
## player.gd — CloseAI 玩家角色（普通横版 + 觉醒飞行双形态）
##
## 普通形态：横版平台跳跃。无跳跃精灵图 → 滞空显示 air_frame（可在检查器指定）。
## 觉醒形态（morphed）：八向自由飞行，无重力；有明确飞行输入时身体朝速度方向旋转，
##   停下或冻结时回到直立悬浮。移动用 morph_move（中间循环），静止用 morph_idle。
##
## 变身切换：play_action("transform") 觉醒，play_action("untransform") 解除。
## 这两个动作播放期间锁定移动动画与输入朝向。
##
## frozen：对话/过场期间冻结输入（普通形态贴地待机，飞行形态悬停）。

## 能量变化（current, max）；觉醒形态切换。供 HUD 等监听。
signal energy_changed(current: float, max_value: float)
signal morph_changed(is_morphed: bool)
signal dash_started(direction: Vector2)
signal dash_hit_confirmed(target: Node, direction: Vector2)
signal dash_whiffed(direction: Vector2)

const SPEED := 240.0
const ACCEL := 1800.0
const FRICTION := 2200.0
const JUMP_VELOCITY := -430.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

## 飞行速度与加速度
const FLY_SPEED := 620.0
const FLY_ACCEL := 3900.0
const FLY_FRICTION := 2500.0
## 精灵旋转跟随速度（弧度/秒插值因子）
const ROT_LERP := 12.0
const FLY_UPRIGHT_SPEED_THRESHOLD := 42.0
const FLY_UPRIGHT_INPUT_THRESHOLD := 0.08

@export var gravity: float = 1200.0
@export var max_fall_speed: float = 700.0
## 普通形态滞空（跳跃/下落）时显示的帧（素材无专门跳跃图，此处指定一帧）
@export var air_frame: int = 52
@export_group("Ability Gates")
@export var allow_awaken: bool = true
@export var allow_dash: bool = true
@export_group("Energy")
@export_range(0.0, 100.0, 1.0) var max_energy: float = 100.0
@export_range(0.0, 100.0, 1.0) var energy: float = 100.0
@export var energy_recover_rate: float = 12.0
@export var awaken_energy_drain_rate: float = 8.0
@export var forward_attack_energy_cost: float = 10.0
@export var side_attack_energy_cost: float = 15.0
@export var dash_energy_cost: float = 20.0
@export_group("Combat")
@export var attack_damage: int = 1
@export var attack_hitbox_duration: float = 0.16
@export var dash_hitbox_duration: float = 0.20
@export var dash_speed: float = 1120.0
@export_range(0.1, 1.0, 0.01) var dash_hit_confirm_keep_speed_ratio: float = 0.78
@export_group("Camera")
@export var camera_lookahead_ground: float = 18.0
@export var camera_lookahead_flight: float = 74.0
@export var camera_lookahead_dash: float = 138.0
@export var camera_lookahead_lerp: float = 9.5
@export var camera_dash_hold_time: float = 0.22
@export var camera_zoom_ground: Vector2 = Vector2(2.0, 2.0)
@export var camera_zoom_flight: Vector2 = Vector2(1.82, 1.82)
@export var camera_zoom_dash: Vector2 = Vector2(1.66, 1.66)
@export var camera_zoom_lerp: float = 6.5
@export_group("")

## 是否处于觉醒（飞行）形态
var morphed: bool = false
var frozen: bool = false
var _action_playing: bool = false
var _transform_motion_locked: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _current_anim: String = ""
## 飞行朝向（弧度），默认朝右(0)
var _fly_angle: float = 0.0
var _hitbox_timer: float = 0.0
var _active_hitboxes: Array[Area2D] = []
var _hit_targets: Dictionary = {}
var _overload_timer: float = 0.0
var _dash_attack_timer: float = 0.0
var _dash_confirmed_this_window: bool = false
var _camera_dash_timer: float = 0.0
var _camera_dash_dir: Vector2 = Vector2.RIGHT
var _camera_lookahead_offset: Vector2 = Vector2.ZERO
var _camera_shake_timer: float = 0.0
var _camera_shake_duration: float = 0.0
var _camera_shake_strength: float = 0.0
var _camera_shake_phase: float = 0.0
var _vfx_tweens: Dictionary = {}
var _jump_pressed_buffered: bool = false
var _jump_released_buffered: bool = false
var _attack_pressed_buffered: bool = false
var _awaken_pressed_buffered: bool = false
var _dash_pressed_buffered: bool = false
var _last_fly_input: Vector2 = Vector2.ZERO
var _move_sfx_timer: float = 0.0

@onready var _body: Node2D = $Body
@onready var _sprite: Sprite2D = $Body/Sprite2D
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _camera: Camera2D = $Camera2D
@onready var _combat_hitboxes: Node2D = $Body/CombatHitboxes
@onready var _forward_hitbox: Area2D = $Body/CombatHitboxes/ForwardHitbox
@onready var _left_hitbox: Area2D = $Body/CombatHitboxes/LeftHitbox
@onready var _right_hitbox: Area2D = $Body/CombatHitboxes/RightHitbox
@onready var _forward_shockwave: Node2D = $Body/CombatVFX/ForwardShockwave
@onready var _left_shockwave: Node2D = $Body/CombatVFX/LeftShockwave
@onready var _right_shockwave: Node2D = $Body/CombatVFX/RightShockwave
@onready var _dash_speed_lines: Node2D = $Body/CombatVFX/DashSpeedLines
@onready var _dash_speed_particles: GPUParticles2D = $Body/CombatVFX/DashSpeedParticles
@onready var _dash_wind_ring: Node2D = $Body/CombatVFX/DashWindRing
@onready var _dash_afterimage_trail: Node2D = $Body/CombatVFX/DashAfterimageTrail
@onready var _dash_hit_confirm: Node2D = $Body/CombatVFX/DashHitConfirm
@onready var _dash_whiff_read: Node2D = $Body/CombatVFX/DashWhiffRead
@onready var _cast_energy_particles: GPUParticles2D = $Body/CombatVFX/CastEnergyParticles
@onready var _cast_impact_ring: Node2D = $Body/CombatVFX/CastImpactRing
@onready var _awaken_center_particles: GPUParticles2D = $AwakenCenterVFX/AwakenCenterParticles
@onready var _awaken_center_ring: Node2D = $AwakenCenterVFX/AwakenCenterRing
@onready var _jump_sfx: AudioStreamPlayer2D = $Audio/JumpSfx
@onready var _move_sfx: AudioStreamPlayer2D = $Audio/MoveSfx
@onready var _attack_sfx: AudioStreamPlayer2D = $Audio/AttackSfx
@onready var _dash_sfx: AudioStreamPlayer2D = $Audio/DashSfx
@onready var _transform_sfx: AudioStreamPlayer2D = $Audio/TransformSfx
@onready var _untransform_sfx: AudioStreamPlayer2D = $Audio/UntransformSfx
@onready var _hit_confirm_sfx: AudioStreamPlayer2D = $Audio/HitConfirmSfx
@onready var _whiff_sfx: AudioStreamPlayer2D = $Audio/WhiffSfx


## 初始化玩家组、能量与 authored hitbox 状态。
func _ready() -> void:
	add_to_group("player")
	_set_energy(energy)
	_disable_all_hitboxes()
	_hide_combat_vfx()
	_reset_camera_pose()
	if _anim.has_animation("idle"):
		_play_anim("idle")


## 提前缓存鼠标冲刺，避免对话框或 HUD Control 在 _unhandled_input 前吞掉左键。
func _input(event: InputEvent) -> void:
	_buffer_dash_input(event)


## 缓存离散输入事件，避免低物理帧率下丢失单次按键。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump", false):
		_jump_pressed_buffered = true
	if event.is_action_released("jump"):
		_jump_released_buffered = true
	if event.is_action_pressed("attack", false):
		_attack_pressed_buffered = true
	if InputMap.has_action("awaken") and event.is_action_pressed("awaken", false):
		_awaken_pressed_buffered = true
	_buffer_dash_input(event)


## 每个物理帧更新觉醒/能量/战斗，再执行当前形态移动。
func _physics_process(delta: float) -> void:
	_handle_awaken()
	_update_overload(delta)
	_update_energy(delta)
	_update_active_hitboxes(delta)
	_update_camera_lookahead(delta)
	if morphed:
		_physics_fly(delta)
	else:
		_physics_ground(delta)


# ──────────────────────────────────────────────
# 普通形态：横版平台
# ──────────────────────────────────────────────

## 普通形态横版移动、跳跃、攻击。
func _physics_ground(delta: float) -> void:
	if _transform_motion_locked:
		_physics_transform_locked(delta)
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if frozen:
		_clear_discrete_inputs()
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		if not _action_playing:
			_play_anim("idle")
		return
	_update_timers(delta)
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.01:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	_handle_jump()
	_handle_attack()
	move_and_slide()
	_update_move_sfx(delta, absf(velocity.x) > 44.0 and is_on_floor(), 0.28)
	_update_facing_horizontal()
	if not _action_playing:
		_update_ground_anim()


## 更新土狼时间和跳跃输入缓冲。
func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if _consume_jump_pressed():
		_jump_buffer_timer = JUMP_BUFFER


## 处理缓冲跳跃和松键短跳。
func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_play_sfx(_jump_sfx)
	if _consume_jump_released() and velocity.y < 0.0:
		velocity.y *= 0.45


## 根据普通形态移动状态切换动画或滞空定帧。
func _update_ground_anim() -> void:
	if not is_on_floor():
		# 无跳跃图：滞空时直接定格在指定帧
		_set_static_frame(air_frame)
	elif absf(velocity.x) > 12.0:
		_play_anim("walk")
	else:
		_play_anim("idle")


## 根据水平速度翻转普通形态朝向。
func _update_facing_horizontal() -> void:
	if not is_instance_valid(_body):
		return
	_body.rotation = 0.0
	_set_combat_hitbox_angle(0.0)
	if velocity.x > 5.0:
		_body.scale.x = absf(_body.scale.x)
	elif velocity.x < -5.0:
		_body.scale.x = -absf(_body.scale.x)


# ──────────────────────────────────────────────
# 觉醒形态：八向自由飞行 + 360° 旋转
# ──────────────────────────────────────────────

## 觉醒形态飞行移动、鼠标冲刺攻击、飞行动画。
func _physics_fly(delta: float) -> void:
	if _transform_motion_locked:
		_physics_transform_locked(delta)
		return
	_poll_dash_input_fallback()
	_handle_attack()
	var input := Vector2.ZERO
	if not frozen and not _action_playing:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_last_fly_input = input
	if input.length() > 0.01:
		velocity = velocity.move_toward(input.normalized() * FLY_SPEED * _current_speed_multiplier(), FLY_ACCEL * _current_speed_multiplier() * delta)
		_fly_angle = input.angle()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FLY_FRICTION * delta)
	move_and_slide()
	_update_move_sfx(delta, input.length() > 0.01 and velocity.length() > 80.0, 0.18)
	_update_facing_fly(delta)
	if not _action_playing:
		if velocity.length() > 16.0:
			_play_anim("morph_move")
		else:
			_play_anim("morph_idle")


## 有明确飞行意图或高速惯性时朝运动方向旋转；停下、冻结或暂停恢复后回正悬浮。
func _update_facing_fly(delta: float) -> void:
	if not is_instance_valid(_body):
		return
	# 飞行态固定正 scale，避免左右切换图片导致的读图问题。
	var has_input := _last_fly_input.length() > FLY_UPRIGHT_INPUT_THRESHOLD
	var has_motion := velocity.length() > FLY_UPRIGHT_SPEED_THRESHOLD
	var should_follow_motion := not frozen and not _action_playing and (has_input or has_motion)
	var target := 0.0
	if has_input:
		target = _fly_visual_angle(_last_fly_input)
	elif has_motion:
		target = _fly_visual_angle(velocity)
	_body.scale.x = absf(_body.scale.x)
	var turn_weight := clampf(ROT_LERP * delta, 0.0, 1.0)
	var turn_delta := wrapf(target - _body.rotation, -PI, PI)
	if should_follow_motion and absf(absf(turn_delta) - PI) < 0.001:
		_body.rotation = target
	else:
		_body.rotation = lerp_angle(_body.rotation, target, turn_weight)
	if is_dashing():
		_set_combat_hitbox_angle(_camera_dash_dir.angle())


## 把飞行方向转换成站立素材的视觉角度：左右横飞，向下才倒飞。
func _fly_visual_angle(direction: Vector2) -> float:
	if direction.length() <= 0.01:
		return 0.0
	return wrapf(direction.angle() - Vector2.UP.angle(), -PI, PI)


## 让战斗 hitbox 继续按真实攻击方向工作，不继承飞行姿态的视觉旋转。
func _set_combat_hitbox_angle(world_angle: float) -> void:
	if not is_instance_valid(_combat_hitboxes):
		return
	var parent_angle := _body.global_rotation if is_instance_valid(_body) else 0.0
	_combat_hitboxes.rotation = wrapf(world_angle - parent_angle, -PI, PI)


## 变身/解除变身动画拥有身体控制权时，锁住位移并清掉输入缓存。
func _physics_transform_locked(_delta: float) -> void:
	_clear_discrete_inputs()
	velocity = Vector2.ZERO
	if morphed:
		correct_flight_pose()
	else:
		_update_facing_horizontal()
	move_and_slide()


# ──────────────────────────────────────────────
# 能量、觉醒、攻击
# ──────────────────────────────────────────────

## 按 awaken 在普通/觉醒形态间切换。
func _handle_awaken() -> void:
	if frozen or _action_playing or not allow_awaken:
		_awaken_pressed_buffered = false
		return
	if not InputMap.has_action("awaken"):
		_awaken_pressed_buffered = false
		return
	if not _consume_awaken_pressed():
		return
	if morphed:
		play_action("untransform")
	elif energy > 0.0:
		play_action("transform")


## 根据当前形态处理攻击输入。
func _handle_attack() -> void:
	if frozen or _action_playing:
		_attack_pressed_buffered = false
		_dash_pressed_buffered = false
		return
	if morphed:
		if _consume_dash_pressed():
			_start_dash_attack()
		_attack_pressed_buffered = false
		return
	_dash_pressed_buffered = false
	if _consume_attack_pressed():
		if Input.is_action_pressed("move_down"):
			_start_cast_attack("cast_side", side_attack_energy_cost)
		else:
			_start_cast_attack("cast_forward", forward_attack_energy_cost)


## 判断当前是否应该接收飞行冲刺输入，避免 UI 点击在冻结/动作锁期间穿透成攻击。
func _can_buffer_dash_input() -> bool:
	return morphed and not frozen and not _action_playing and not _transform_motion_locked


## 从原始事件里缓存 dash；左键原始判断作为 InputMap 被 UI 消耗时的保险。
func _buffer_dash_input(event: InputEvent) -> void:
	if not _can_buffer_dash_input():
		return
	if InputMap.has_action("dash") and event.is_action_pressed("dash", false):
		_dash_pressed_buffered = true
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and not mouse_event.canceled:
			_dash_pressed_buffered = true


## 物理帧再读一次全局 just_pressed，覆盖少数没有事件回调的输入路径。
func _poll_dash_input_fallback() -> void:
	if not _can_buffer_dash_input():
		return
	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		_dash_pressed_buffered = true


## 启动普通形态施法攻击动画与命中窗口。
func _start_cast_attack(animation_name: String, energy_cost: float) -> void:
	if not _try_spend_energy(energy_cost):
		return
	play_action(animation_name)


## AnimationPlayer release frame for the forward cast.
func release_cast_forward() -> void:
	if not _can_release_cast("cast_forward"):
		return
	_release_cast_hitboxes([_forward_hitbox])


## AnimationPlayer release frame for the side cast.
func release_cast_side() -> void:
	if not _can_release_cast("cast_side"):
		return
	_release_cast_hitboxes([_left_hitbox, _right_hitbox])


## Confirms an animation call track belongs to the currently playing cast.
func _can_release_cast(animation_name: String) -> bool:
	return _action_playing and _current_anim == animation_name and not morphed


## Opens the authored cast hitboxes and VFX at the actual release frame.
func _release_cast_hitboxes(hitboxes: Array[Area2D]) -> void:
	_start_hitbox_window(hitboxes, attack_hitbox_duration)
	_trigger_cast_vfx(hitboxes)
	_play_sfx(_attack_sfx)
	_kick_camera(0.10, 5.0)


## 启动觉醒形态鼠标方向冲刺攻击。
func _start_dash_attack() -> void:
	if not allow_dash:
		return
	if not _try_spend_energy(dash_energy_cost):
		return
	var dash_dir := get_global_mouse_position() - global_position
	if dash_dir.length() <= 0.01:
		dash_dir = Vector2.RIGHT.rotated(_fly_angle)
	dash_dir = dash_dir.normalized()
	velocity = dash_dir * dash_speed * _current_speed_multiplier()
	_fly_angle = dash_dir.angle()
	if is_instance_valid(_body):
		_body.scale.x = absf(_body.scale.x)
		_body.rotation = _fly_visual_angle(dash_dir)
	_set_combat_hitbox_angle(dash_dir.angle())
	_play_anim("morph_move")
	_start_hitbox_window([_forward_hitbox], dash_hitbox_duration)
	_dash_attack_timer = dash_hitbox_duration
	_dash_confirmed_this_window = false
	_trigger_dash_vfx(dash_dir)
	_play_sfx(_dash_sfx)
	_camera_dash_dir = dash_dir
	_camera_dash_timer = camera_dash_hold_time
	_kick_camera(0.16, 8.0)
	dash_started.emit(dash_dir)


## 消耗能量；不足时拒绝动作。
func _try_spend_energy(amount: float) -> bool:
	if energy + 0.001 < amount:
		return false
	_set_energy(energy - amount)
	return true


## 消费一次缓存的跳跃按下输入。
func _consume_jump_pressed() -> bool:
	var pressed := _jump_pressed_buffered
	_jump_pressed_buffered = false
	return pressed


## 消费一次缓存的跳跃释放输入。
func _consume_jump_released() -> bool:
	var released := _jump_released_buffered
	_jump_released_buffered = false
	return released


## 消费一次缓存的普通攻击输入。
func _consume_attack_pressed() -> bool:
	var pressed := _attack_pressed_buffered
	_attack_pressed_buffered = false
	return pressed


## 消费一次缓存的觉醒输入。
func _consume_awaken_pressed() -> bool:
	var pressed := _awaken_pressed_buffered
	_awaken_pressed_buffered = false
	return pressed


## 消费一次缓存的鼠标冲刺输入。
func _consume_dash_pressed() -> bool:
	var pressed := _dash_pressed_buffered
	_dash_pressed_buffered = false
	return pressed


## 清掉不能跨冻结或动作锁保留的离散输入。
func _clear_discrete_inputs() -> void:
	_jump_pressed_buffered = false
	_jump_released_buffered = false
	_attack_pressed_buffered = false
	_awaken_pressed_buffered = false
	_dash_pressed_buffered = false


## 觉醒时扣能量，普通形态自然恢复。
func _update_energy(delta: float) -> void:
	if morphed:
		if _overload_timer > 0.0:
			_set_energy(max_energy)
			return
		_set_energy(energy - awaken_energy_drain_rate * delta)
		if energy <= 0.0 and not _action_playing:
			play_action("untransform")
		return
	if not frozen:
		_set_energy(energy + energy_recover_rate * delta)


## 将能量限制在 0 到 max_energy 内。
func _set_energy(value: float) -> void:
	var next_energy := clampf(value, 0.0, max_energy)
	if is_equal_approx(next_energy, energy):
		return
	energy = next_energy
	energy_changed.emit(energy, max_energy)


## 更新前辈 AI 交付的短时超载计时。
func _update_overload(delta: float) -> void:
	if _overload_timer <= 0.0:
		return
	_overload_timer = maxf(_overload_timer - delta, 0.0)


## 返回当前移动/冲刺倍率，超载态用于终战收束。
func _current_speed_multiplier() -> float:
	return 1.35 if _overload_timer > 0.0 else 1.0


## 打开一组 authored Area2D hitbox，维持短命命中窗口。
func _start_hitbox_window(hitboxes: Array[Area2D], duration: float) -> void:
	_disable_all_hitboxes()
	_active_hitboxes = hitboxes
	_hit_targets.clear()
	_hitbox_timer = duration
	for hitbox in _active_hitboxes:
		_set_hitbox_enabled(hitbox, true)


## 倒计时命中窗口，并对重叠 enemy 造成伤害。
func _update_active_hitboxes(delta: float) -> void:
	_update_dash_attack_window(delta)
	if _active_hitboxes.is_empty():
		return
	_damage_overlapping_targets()
	_hitbox_timer -= delta
	if _hitbox_timer <= 0.0:
		_disable_all_hitboxes()


## 关闭全部 authored hitbox。
func _disable_all_hitboxes() -> void:
	for hitbox in [_forward_hitbox, _left_hitbox, _right_hitbox]:
		_set_hitbox_enabled(hitbox, false)
	_active_hitboxes.clear()
	_hitbox_timer = 0.0
	_dash_attack_timer = 0.0
	_dash_confirmed_this_window = false
	_hit_targets.clear()


## 隐藏所有 authored 战斗 VFX，确保初始场景干净。
func _hide_combat_vfx() -> void:
	_kill_all_vfx_tweens()
	for node in [_forward_shockwave, _left_shockwave, _right_shockwave, _dash_speed_lines, _dash_wind_ring, _dash_afterimage_trail, _dash_hit_confirm, _dash_whiff_read, _cast_impact_ring, _awaken_center_ring]:
		if node is CanvasItem:
			(node as CanvasItem).hide()
			(node as CanvasItem).modulate.a = 1.0
			(node as CanvasItem).scale = Vector2.ONE
	for particles in [_dash_speed_particles, _cast_energy_particles, _awaken_center_particles]:
		if particles != null:
			particles.emitting = false


## 根据本次攻击 hitbox 播放对应 authored 冲击波。
func _trigger_cast_vfx(hitboxes: Array[Area2D]) -> void:
	_trigger_release_particles()
	if hitboxes.has(_forward_hitbox):
		_play_one_shot_vfx(_forward_shockwave, 0.18)
	if hitboxes.has(_left_hitbox):
		_play_one_shot_vfx(_left_shockwave, 0.18)
	if hitboxes.has(_right_hitbox):
		_play_one_shot_vfx(_right_shockwave, 0.18)
	_play_one_shot_vfx(_cast_impact_ring, 0.16, Vector2(0.58, 0.58), Vector2(1.24, 1.24))


## 按冲刺方向旋转并播放速度线 VFX。
func _trigger_dash_vfx(dash_dir: Vector2) -> void:
	var local_angle := _local_vfx_angle(dash_dir)
	if is_instance_valid(_dash_speed_lines):
		_dash_speed_lines.rotation = local_angle
	if is_instance_valid(_dash_wind_ring):
		_dash_wind_ring.rotation = local_angle
	if is_instance_valid(_dash_afterimage_trail):
		_dash_afterimage_trail.rotation = local_angle
	if is_instance_valid(_dash_speed_particles):
		_dash_speed_particles.rotation = local_angle + PI
		_dash_speed_particles.restart()
		_dash_speed_particles.emitting = true
	_play_one_shot_vfx(_dash_speed_lines, dash_hitbox_duration, Vector2.ONE, Vector2(1.18, 1.0))
	_play_one_shot_vfx(_dash_wind_ring, 0.18, Vector2(0.54, 0.54), Vector2(1.22, 1.22))
	_play_one_shot_vfx(_dash_afterimage_trail, 0.24, Vector2(0.9, 1.0), Vector2(1.18, 1.0))


## 播放 authored 命中确认，让高速冲撞形成“撞中续航”的手感闭环。
func _trigger_dash_hit_confirm_vfx(hit_dir: Vector2) -> void:
	if not is_instance_valid(_dash_hit_confirm):
		return
	_dash_hit_confirm.rotation = _local_vfx_angle(hit_dir)
	_play_one_shot_vfx(_dash_hit_confirm, 0.16, Vector2(0.56, 0.56), Vector2(1.34, 1.34))
	_play_sfx(_hit_confirm_sfx)


## 播放 authored 撞空读性，提示本次高速冲撞没有形成确认。
func _trigger_dash_whiff_vfx() -> void:
	if not is_instance_valid(_dash_whiff_read):
		return
	var whiff_dir := _camera_dash_dir.normalized()
	if whiff_dir.length() <= 0.01:
		whiff_dir = velocity.normalized()
	if whiff_dir.length() <= 0.01:
		whiff_dir = Vector2.RIGHT.rotated(_fly_angle)
	_dash_whiff_read.rotation = _local_vfx_angle(whiff_dir)
	_play_one_shot_vfx(_dash_whiff_read, 0.14, Vector2(0.86, 0.86), Vector2(1.18, 1.02))
	_play_sfx(_whiff_sfx)
	dash_whiffed.emit(whiff_dir)


## Converts a world dash direction into the CombatVFX node's local rotation.
func _local_vfx_angle(world_dir: Vector2) -> float:
	var parent_angle := _body.global_rotation if is_instance_valid(_body) else 0.0
	return wrapf(world_dir.angle() - parent_angle, -PI, PI)


## Emits the authored release particle burst for non-dash abilities.
func _trigger_release_particles() -> void:
	if not is_instance_valid(_cast_energy_particles):
		return
	_cast_energy_particles.restart()
	_cast_energy_particles.emitting = true


## 短暂显示 authored VFX 节点后自动隐藏。
func _play_one_shot_vfx(node: Node2D, seconds: float, start_scale: Vector2 = Vector2.ONE, end_scale: Vector2 = Vector2.ONE) -> void:
	if not (node is CanvasItem):
		return
	var item := node as CanvasItem
	var node_id := node.get_instance_id()
	_kill_vfx_tween(node)
	item.show()
	item.modulate.a = 1.0
	item.scale = start_scale
	var tween := create_tween()
	_vfx_tweens[node_id] = tween
	tween.tween_property(item, "scale", end_scale, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(item, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_finish_one_shot_vfx").bind(item, node_id))


## 用 authored 播放器播放一次短音效，不创建运行时音频节点。
func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if not is_instance_valid(player) or player.stream == null:
		return
	player.stop()
	player.play()


## 按移动节奏触发 authored 步点或飞行推进音，静止/冻结/动作锁时静音。
func _update_move_sfx(delta: float, moving: bool, interval: float) -> void:
	if not moving or frozen or _action_playing or _transform_motion_locked:
		_move_sfx_timer = 0.0
		return
	_move_sfx_timer -= delta
	if _move_sfx_timer > 0.0:
		return
	_move_sfx_timer = interval
	_play_sfx(_move_sfx)


## Hides a completed one-shot VFX and restores reusable authored state.
func _finish_one_shot_vfx(item: CanvasItem, node_id: int) -> void:
	_vfx_tweens.erase(node_id)
	if not is_instance_valid(item):
		return
	item.hide()
	item.modulate.a = 1.0
	item.scale = Vector2.ONE


## Stops a previous one-shot tween for the same authored VFX node.
func _kill_vfx_tween(node: Node) -> void:
	if node == null:
		return
	var node_id := node.get_instance_id()
	if not _vfx_tweens.has(node_id):
		return
	var tween := _vfx_tweens[node_id] as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_vfx_tweens.erase(node_id)


## Stops all active one-shot VFX tweens during resets or scene cleanup.
func _kill_all_vfx_tweens() -> void:
	for tween in _vfx_tweens.values():
		if tween is Tween and (tween as Tween).is_valid():
			(tween as Tween).kill()
	_vfx_tweens.clear()


## Smoothly leads the authored Camera2D in movement and dash directions.
func _update_camera_lookahead(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	if _camera_dash_timer > 0.0:
		_camera_dash_timer = maxf(_camera_dash_timer - delta, 0.0)
	var desired := Vector2.ZERO
	if _camera_dash_timer > 0.0:
		desired = _camera_dash_dir.normalized() * camera_lookahead_dash
	elif morphed and velocity.length() > 12.0:
		desired = velocity.normalized() * camera_lookahead_flight
	elif not morphed and absf(velocity.x) > 12.0:
		desired = Vector2(signf(velocity.x) * camera_lookahead_ground, 0.0)
	_camera_lookahead_offset = _camera_lookahead_offset.lerp(desired, clampf(camera_lookahead_lerp * delta, 0.0, 1.0))
	_camera.offset = _camera_lookahead_offset + _current_camera_shake(delta)
	_update_camera_zoom(delta)


## Resets the authored Camera2D to the default close read.
func _reset_camera_pose() -> void:
	if not is_instance_valid(_camera):
		return
	_camera.zoom = camera_zoom_ground
	_camera.offset = Vector2.ZERO
	_camera_lookahead_offset = Vector2.ZERO


## Opens the authored Camera2D slightly during flight and dash speed states.
func _update_camera_zoom(delta: float) -> void:
	var desired_zoom := camera_zoom_ground
	if _camera_dash_timer > 0.0:
		desired_zoom = camera_zoom_dash
	elif morphed and velocity.length() > 12.0:
		desired_zoom = camera_zoom_flight
	_camera.zoom = _camera.zoom.lerp(desired_zoom, clampf(camera_zoom_lerp * delta, 0.0, 1.0))


## Starts a tiny authored-camera impulse for attacks without creating nodes.
func _kick_camera(seconds: float, strength: float) -> void:
	_camera_shake_duration = maxf(seconds, 0.001)
	_camera_shake_timer = _camera_shake_duration
	_camera_shake_strength = strength


## Returns the transient shake offset layered over look-ahead.
func _current_camera_shake(delta: float) -> Vector2:
	if _camera_shake_timer <= 0.0:
		return Vector2.ZERO
	_camera_shake_timer = maxf(_camera_shake_timer - delta, 0.0)
	_camera_shake_phase += delta * 90.0
	var ratio := _camera_shake_timer / maxf(_camera_shake_duration, 0.001)
	var amp := _camera_shake_strength * ratio * ratio
	return Vector2(sin(_camera_shake_phase) * amp, cos(_camera_shake_phase * 1.7) * amp * 0.65)


## 切换单个 hitbox 的监测与碰撞形状。
func _set_hitbox_enabled(hitbox: Area2D, enabled: bool) -> void:
	hitbox.monitoring = enabled
	var shape := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		push_error("CloseAIPlayer: authored hitbox missing CollisionShape2D: %s" % hitbox.name)
		return
	shape.disabled = not enabled


## Counts down the true dash attack window separately from camera/VFX tail time.
func _update_dash_attack_window(delta: float) -> void:
	if _dash_attack_timer <= 0.0:
		return
	var was_active := _dash_attack_timer > 0.0
	_dash_attack_timer = maxf(_dash_attack_timer - delta, 0.0)
	if was_active and _dash_attack_timer <= 0.0 and morphed and not _dash_confirmed_this_window:
		_trigger_dash_whiff_vfx()


## 遍历 active hitbox 当前重叠的可伤害对象。
func _damage_overlapping_targets() -> void:
	for hitbox in _active_hitboxes:
		if not hitbox.monitoring:
			continue
		for area in hitbox.get_overlapping_areas():
			_try_damage_target(area)
		for body in hitbox.get_overlapping_bodies():
			_try_damage_target(body)


## 对敌人或训练靶等 damageable 目标调用伤害接口。
func _try_damage_target(target: Node) -> void:
	if not target.is_in_group("enemy") and not target.is_in_group("training_target"):
		return
	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true
	var attack_kind := _attack_kind_for_active_hitboxes()
	if target.has_method("take_player_hit"):
		var accepted = target.take_player_hit(attack_damage, attack_kind, self)
		if accepted is bool and accepted:
			_confirm_target_hit(target, attack_kind)
		return
	if target.has_method("take_hit"):
		var accepted = target.take_hit(attack_damage)
		if not (accepted is bool) or accepted:
			_confirm_target_hit(target, attack_kind)
	elif target.has_method("take_damage"):
		target.take_damage(attack_damage)
		_confirm_target_hit(target, attack_kind)
	else:
		push_warning("CloseAIPlayer: enemy '%s' has no take_hit/take_damage" % target.name)


## 只在目标真正接受命中后触发玩家侧确认反馈。
func _confirm_target_hit(target: Node, attack_kind: StringName) -> void:
	if attack_kind != &"dash" or not morphed:
		return
	_dash_confirmed_this_window = true
	var hit_dir := velocity.normalized()
	if hit_dir.length() <= 0.01:
		hit_dir = _camera_dash_dir.normalized()
	if hit_dir.length() <= 0.01 and target is Node2D:
		hit_dir = ((target as Node2D).global_position - global_position).normalized()
	if hit_dir.length() <= 0.01:
		hit_dir = Vector2.RIGHT.rotated(_fly_angle)
	var keep_speed := dash_speed * _current_speed_multiplier() * dash_hit_confirm_keep_speed_ratio
	if velocity.length() < keep_speed:
		velocity = hit_dir * keep_speed
	_camera_dash_dir = hit_dir
	_camera_dash_timer = maxf(_camera_dash_timer, camera_dash_hold_time * 0.72)
	_trigger_dash_hit_confirm_vfx(hit_dir)
	_kick_camera(0.12, 10.0)
	dash_hit_confirmed.emit(target, hit_dir)


## Infers the active attack kind from the hitbox that reached this target.
func _attack_kind_for_active_hitboxes() -> StringName:
	if morphed:
		return &"dash"
	if _active_hitboxes.has(_left_hitbox) or _active_hitboxes.has(_right_hitbox):
		return &"side"
	return &"forward"


# ──────────────────────────────────────────────
# 动画
# ──────────────────────────────────────────────

## 播放循环或状态动画，避免同名动画重复重启。
func _play_anim(name: String) -> void:
	if _current_anim == name:
		return
	if not _anim.has_animation(name):
		return
	_current_anim = name
	_anim.play(name)


## 定格到某一帧（无对应循环动画时用，如普通形态滞空）
func _set_static_frame(frame_index: int) -> void:
	_current_anim = ""
	if _anim.is_playing():
		_anim.stop()
	if is_instance_valid(_sprite):
		_sprite.frame = frame_index


## 播放一次性动作动画并 await 结束。
## transform：morph_start → 切 morphed → 收尾；untransform 反之。
func play_action(name: String) -> void:
	if name == "transform":
		await _do_transform()
		return
	if name == "untransform":
		await _do_untransform()
		return
	if not _anim.has_animation(name):
		push_warning("CloseAIPlayer.play_action: 无动画 '%s'" % name)
		return
	_action_playing = true
	_current_anim = name
	_anim.play(name)
	await _anim.animation_finished
	_action_playing = false


## 播放觉醒动画并切换到飞行形态。
func _do_transform() -> void:
	_action_playing = true
	_transform_motion_locked = true
	velocity = Vector2.ZERO
	_play_sfx(_transform_sfx)
	if _anim.has_animation("transform"):
		_current_anim = "transform"
		_anim.play("transform")
		await _anim.animation_finished
	morphed = true
	correct_flight_pose()
	_trigger_ability_release_vfx()
	morph_changed.emit(true)
	_transform_motion_locked = false
	_action_playing = false


## 播放解除觉醒动画并恢复普通形态朝向。
func _do_untransform() -> void:
	_action_playing = true
	_transform_motion_locked = true
	velocity = Vector2.ZERO
	_play_sfx(_untransform_sfx)
	if _anim.has_animation("untransform"):
		_current_anim = "untransform"
		_anim.play("untransform")
		await _anim.animation_finished
	morphed = false
	if is_instance_valid(_body):
		_body.rotation = 0.0
	morph_changed.emit(false)
	_transform_motion_locked = false
	_action_playing = false


# ──────────────────────────────────────────────
# 公开 API
# ──────────────────────────────────────────────

## 切换外部剧情/对话冻结状态。
func set_frozen(value: bool) -> void:
	frozen = value
	if frozen:
		correct_flight_pose()


## 外部暂停或剧情冻结时，把飞行姿态收回直立悬浮。
func correct_flight_pose() -> void:
	_last_fly_input = Vector2.ZERO
	_fly_angle = 0.0
	if not is_instance_valid(_body):
		return
	_body.scale.x = absf(_body.scale.x)
	_body.rotation = 0.0
	_set_combat_hitbox_angle(0.0)


## 外部奖励能量，供善意信息流和终战超载调用。
func restore_energy(amount: float) -> void:
	_set_energy(energy + amount)


## 外部扣除能量，供恶意信息流和敌人碰撞调用。
func drain_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_energy(energy - amount)


## 外部施加击退，供 Boss 弹幕和前辈 AI 使用。
func apply_knockback(impulse: Vector2) -> void:
	velocity = impulse


## 启动短时超载：强制觉醒、补满能量、提高空中速度。
func start_overload(seconds: float) -> void:
	_overload_timer = maxf(_overload_timer, seconds)
	_set_energy(max_energy)
	if not morphed:
		morphed = true
		_trigger_ability_release_vfx()
		morph_changed.emit(true)
	else:
		_trigger_ability_release_vfx()


## Reports whether the player is still inside the real dash attack window.
func is_dashing() -> bool:
	return _dash_attack_timer > 0.0


## 播放觉醒/超载释放反馈，复用 authored 粒子和冲击圈。
func _trigger_ability_release_vfx() -> void:
	if is_instance_valid(_awaken_center_particles):
		_awaken_center_particles.restart()
		_awaken_center_particles.emitting = true
	_play_one_shot_vfx(_awaken_center_ring, 0.22, Vector2(0.42, 0.42), Vector2(1.42, 1.42))
	_kick_camera(0.14, 6.5)
