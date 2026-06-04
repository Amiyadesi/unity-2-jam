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

## 是否处于觉醒（飞行）形态
var morphed: bool = false
var frozen: bool = false
var _action_playing: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _current_anim: String = ""
## 飞行朝向（弧度），默认朝右(0)
var _fly_angle: float = 0.0

@onready var _body: Node2D = $Body
@onready var _sprite: Sprite2D = $Body/Sprite2D
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("player")
	if _anim.has_animation("idle"):
		_play_anim("idle")


func _physics_process(delta: float) -> void:
	if morphed:
		_physics_fly(delta)
	else:
		_physics_ground(delta)


# ──────────────────────────────────────────────
# 普通形态：横版平台
# ──────────────────────────────────────────────

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
	move_and_slide()
	_update_facing_horizontal()
	if not _action_playing:
		_update_ground_anim()


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45


func _update_ground_anim() -> void:
	if not is_on_floor():
		# 无跳跃图：滞空时直接定格在指定帧
		_set_static_frame(air_frame)
	elif absf(velocity.x) > 12.0:
		_play_anim("walk")
	else:
		_play_anim("idle")


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

func _physics_fly(delta: float) -> void:
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
# 动画
# ──────────────────────────────────────────────

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


func _do_transform() -> void:
	_action_playing = true
	velocity = Vector2.ZERO
	if _anim.has_animation("transform"):
		_current_anim = "transform"
		_anim.play("transform")
		await _anim.animation_finished
	morphed = true
	_fly_angle = 0.0 if _body.scale.x >= 0 else PI
	_action_playing = false


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
	_action_playing = false


# ──────────────────────────────────────────────
# 公开 API
# ──────────────────────────────────────────────

func set_frozen(value: bool) -> void:
	frozen = value
