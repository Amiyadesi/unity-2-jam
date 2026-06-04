extends CharacterBody2D
class_name CloseAIPlayer
## player.gd — CloseAI 玩家角色（极简横版小人）
##
## 设计：不说话，靠行动代入。左右移动 + 跳跃。
##  - 移动：move_left / move_right
##  - 跳跃：jump（带土狼时间 + 跳跃缓冲，手感优先）
##  - frozen：对话 / 过场 / 关闭时刻期间冻结输入

const SPEED := 240.0
const ACCEL := 1800.0
const FRICTION := 2200.0
const JUMP_VELOCITY := -430.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

@export var gravity: float = 1200.0
@export var max_fall_speed: float = 700.0

## 冻结时不响应输入、不水平移动（仍受重力以贴地）
var frozen: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var _sprite: Node2D = $Visual


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if frozen:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return
	_update_timers(delta)
	_handle_horizontal(delta)
	_handle_jump()
	move_and_slide()
	_update_facing()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER


func _handle_horizontal(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.01:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	# 可变跳跃高度：松开跳跃键时截断上升速度
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45


func _update_facing() -> void:
	if not is_instance_valid(_sprite):
		return
	if velocity.x > 5.0:
		_sprite.scale.x = absf(_sprite.scale.x)
	elif velocity.x < -5.0:
		_sprite.scale.x = -absf(_sprite.scale.x)


## 冻结/解冻输入（供 stage_base 在对话与过场时调用）
func set_frozen(value: bool) -> void:
	frozen = value
