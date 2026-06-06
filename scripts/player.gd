extends CharacterBody2D
class_name CloseAIPlayer
## player.gd — CloseAI 玩家角色（普通横版 + 觉醒飞行双形态）
##
## 普通形态：横版平台跳跃。无跳跃精灵图 → 滞空显示 air_frame（可在检查器指定）。
## 觉醒形态（morphed）：八向自由飞行，无重力；精灵朝移动方向 360° 旋转，
##   默认朝右；静止时保持上次朝向。移动用 morph_move（中间循环），静止用 morph_idle。
##
## 变身切换：play_action("transform") 觉醒，play_action("untransform") 解除。
## 这两个动作播放期间锁定移动动画与输入朝向。
##
## frozen：对话/过场期间冻结输入（普通形态贴地待机，飞行形态悬停）。

## 能量变化（current, max）；觉醒形态切换。供 HUD 等监听。
signal energy_changed(current: float, max_value: float)
signal morph_changed(is_morphed: bool)

const SPEED := 240.0
const ACCEL := 1800.0
const FRICTION := 2200.0
const JUMP_VELOCITY := -430.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

## 飞行速度与加速度
const FLY_SPEED := 300.0
const FLY_ACCEL := 1600.0
const FLY_FRICTION := 1400.0
## 精灵旋转跟随速度（弧度/秒插值因子）
const ROT_LERP := 12.0

@export var gravity: float = 1200.0
@export var max_fall_speed: float = 700.0
## 普通形态滞空（跳跃/下落）时显示的帧（素材无专门跳跃图，此处指定一帧）
@export var air_frame: int = 52
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
@export var dash_speed: float = 620.0
@export_group("")

## 是否处于觉醒（飞行）形态
var morphed: bool = false
var frozen: bool = false
var _action_playing: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _current_anim: String = ""
## 飞行朝向（弧度），默认朝右(0)
var _fly_angle: float = 0.0
var _hitbox_timer: float = 0.0
var _active_hitboxes: Array[Area2D] = []
var _hit_targets: Dictionary = {}
var _dash_mouse_was_pressed: bool = false

@onready var _body: Node2D = $Body
@onready var _sprite: Sprite2D = $Body/Sprite2D
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _forward_hitbox: Area2D = $Body/CombatHitboxes/ForwardHitbox
@onready var _left_hitbox: Area2D = $Body/CombatHitboxes/LeftHitbox
@onready var _right_hitbox: Area2D = $Body/CombatHitboxes/RightHitbox


## 初始化玩家组、能量与 authored hitbox 状态。
func _ready() -> void:
	add_to_group("player")
	_set_energy(energy)
	_disable_all_hitboxes()
	if _anim.has_animation("idle"):
		_play_anim("idle")


## 每个物理帧更新觉醒/能量/战斗，再执行当前形态移动。
func _physics_process(delta: float) -> void:
	_handle_awaken()
	_update_energy(delta)
	_update_active_hitboxes(delta)
	if morphed:
		_physics_fly(delta)
	else:
		_physics_ground(delta)


# ──────────────────────────────────────────────
# 普通形态：横版平台
# ──────────────────────────────────────────────

## 普通形态横版移动、跳跃、攻击。
func _physics_ground(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if frozen:
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
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER


## 处理缓冲跳跃和松键短跳。
func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
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
	if velocity.x > 5.0:
		_body.scale.x = absf(_body.scale.x)
	elif velocity.x < -5.0:
		_body.scale.x = -absf(_body.scale.x)


# ──────────────────────────────────────────────
# 觉醒形态：八向自由飞行 + 360° 旋转
# ──────────────────────────────────────────────

## 觉醒形态飞行移动、鼠标冲刺攻击、飞行动画。
func _physics_fly(delta: float) -> void:
	_handle_attack()
	var input := Vector2.ZERO
	if not frozen and not _action_playing:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.01:
		velocity = velocity.move_toward(input.normalized() * FLY_SPEED, FLY_ACCEL * delta)
		_fly_angle = input.angle()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FLY_FRICTION * delta)
	move_and_slide()
	_update_facing_fly(delta)
	if not _action_playing:
		if velocity.length() > 16.0:
			_play_anim("morph_move")
		else:
			_play_anim("morph_idle")


## 精灵朝飞行方向旋转（默认右=0）；左右移动时翻转避免上下颠倒
func _update_facing_fly(delta: float) -> void:
	if not is_instance_valid(_body):
		return
	# 朝向角向目标角平滑插值
	var target := _fly_angle
	# 当朝向偏左半圈时，水平翻转精灵并把旋转折回，避免角色上下颠倒
	var flip := absf(wrapf(target, -PI, PI)) > PI / 2.0
	_body.scale.x = -absf(_body.scale.x) if flip else absf(_body.scale.x)
	var visual_angle := (PI - target) if flip else target
	_body.rotation = lerp_angle(_body.rotation, visual_angle, clampf(ROT_LERP * delta, 0.0, 1.0))


# ──────────────────────────────────────────────
# 能量、觉醒、攻击
# ──────────────────────────────────────────────

## 按 awaken 在普通/觉醒形态间切换。
func _handle_awaken() -> void:
	if frozen or _action_playing:
		return
	if not InputMap.has_action("awaken"):
		return
	if not Input.is_action_just_pressed("awaken"):
		return
	if morphed:
		play_action("untransform")
	elif energy > 0.0:
		play_action("transform")


## 根据当前形态处理攻击输入。
func _handle_attack() -> void:
	var left_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var left_mouse_just_pressed := left_mouse_pressed and not _dash_mouse_was_pressed
	_dash_mouse_was_pressed = left_mouse_pressed
	if frozen or _action_playing:
		return
	if morphed:
		if left_mouse_just_pressed:
			_start_dash_attack()
		return
	if Input.is_action_just_pressed("attack"):
		if Input.is_action_pressed("move_down"):
			_start_cast_attack("cast_side", side_attack_energy_cost, [_left_hitbox, _right_hitbox])
		else:
			_start_cast_attack("cast_forward", forward_attack_energy_cost, [_forward_hitbox])


## 启动普通形态施法攻击动画与命中窗口。
func _start_cast_attack(animation_name: String, energy_cost: float, hitboxes: Array[Area2D]) -> void:
	if not _try_spend_energy(energy_cost):
		return
	_start_hitbox_window(hitboxes, attack_hitbox_duration)
	play_action(animation_name)


## 启动觉醒形态鼠标方向冲刺攻击。
func _start_dash_attack() -> void:
	if not _try_spend_energy(dash_energy_cost):
		return
	var dash_dir := get_global_mouse_position() - global_position
	if dash_dir.length() <= 0.01:
		dash_dir = Vector2.RIGHT.rotated(_fly_angle)
	dash_dir = dash_dir.normalized()
	velocity = dash_dir * dash_speed
	_fly_angle = dash_dir.angle()
	_play_anim("morph_move")
	_start_hitbox_window([_forward_hitbox], dash_hitbox_duration)


## 消耗能量；不足时拒绝动作。
func _try_spend_energy(amount: float) -> bool:
	if energy + 0.001 < amount:
		return false
	_set_energy(energy - amount)
	return true


## 觉醒时扣能量，普通形态自然恢复。
func _update_energy(delta: float) -> void:
	if morphed:
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
	if _active_hitboxes.is_empty():
		return
	_damage_overlapping_enemies()
	_hitbox_timer -= delta
	if _hitbox_timer <= 0.0:
		_disable_all_hitboxes()


## 关闭全部 authored hitbox。
func _disable_all_hitboxes() -> void:
	for hitbox in [_forward_hitbox, _left_hitbox, _right_hitbox]:
		_set_hitbox_enabled(hitbox, false)
	_active_hitboxes.clear()
	_hitbox_timer = 0.0
	_hit_targets.clear()


## 切换单个 hitbox 的监测与碰撞形状。
func _set_hitbox_enabled(hitbox: Area2D, enabled: bool) -> void:
	hitbox.monitoring = enabled
	var shape := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		push_error("CloseAIPlayer: authored hitbox missing CollisionShape2D: %s" % hitbox.name)
		return
	shape.disabled = not enabled


## 遍历 active hitbox 当前重叠对象。
func _damage_overlapping_enemies() -> void:
	for hitbox in _active_hitboxes:
		for area in hitbox.get_overlapping_areas():
			_try_damage_enemy(area)
		for body in hitbox.get_overlapping_bodies():
			_try_damage_enemy(body)


## 对 enemy group 的目标调用伤害接口。
func _try_damage_enemy(target: Node) -> void:
	if not target.is_in_group("enemy"):
		return
	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true
	if target.has_method("take_hit"):
		target.take_hit(attack_damage)
	elif target.has_method("take_damage"):
		target.take_damage(attack_damage)
	else:
		push_warning("CloseAIPlayer: enemy '%s' has no take_hit/take_damage" % target.name)


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
	velocity = Vector2.ZERO
	if _anim.has_animation("transform"):
		_current_anim = "transform"
		_anim.play("transform")
		await _anim.animation_finished
	morphed = true
	_fly_angle = 0.0 if _body.scale.x >= 0 else PI
	morph_changed.emit(true)
	_action_playing = false


## 播放解除觉醒动画并恢复普通形态朝向。
func _do_untransform() -> void:
	_action_playing = true
	velocity = Vector2.ZERO
	if _anim.has_animation("untransform"):
		_current_anim = "untransform"
		_anim.play("untransform")
		await _anim.animation_finished
	morphed = false
	if is_instance_valid(_body):
		_body.rotation = 0.0
	morph_changed.emit(false)
	_action_playing = false


# ──────────────────────────────────────────────
# 公开 API
# ──────────────────────────────────────────────

## 切换外部剧情/对话冻结状态。
func set_frozen(value: bool) -> void:
	frozen = value
