extends Area2D
class_name PredecessorAI
## predecessor_ai.gd — 终战二阶段的被污染前辈 AI。
##
## 它用主角同类的高速追逐/冲撞语言压迫玩家；被击败后自愿交出短时超载。

signal health_changed(current: int, max_value: int)
signal defeated()

@export var max_hp: int = 4
@export var chase_speed: float = 190.0
@export var dash_speed: float = 520.0
@export var dash_interval: float = 1.4
@export var spawn_hold_seconds: float = 0.35
@export var contact_energy_damage: float = 14.0
@export var contact_knockback: float = 420.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _body: Node2D = $Body
@onready var _core: ColorRect = $Body/Core
@onready var _trail: Line2D = $Body/Trail

var _player: Node2D
var _hp: int = 0
var _active: bool = false
var _dead: bool = false
var _dash_timer: float = 0.0
var _contact_cooldown: float = 0.0
var _spawn_hold_left: float = 0.0


## 初始化编组、碰撞回调与休眠状态。
func _ready() -> void:
	add_to_group("enemy")
	body_entered.connect(_on_body_entered)
	deactivate()


## 激活前辈 AI 并锁定玩家。
func activate(player: Node) -> void:
	_player = player as Node2D
	_hp = max_hp
	_dead = false
	_active = true
	_dash_timer = dash_interval
	_contact_cooldown = 0.0
	_spawn_hold_left = spawn_hold_seconds
	show()
	monitoring = true
	_shape.disabled = false
	set_physics_process(true)
	health_changed.emit(_hp, max_hp)


## 关闭前辈 AI，保持 authored 节点但停止碰撞和逻辑。
func deactivate() -> void:
	_active = false
	hide()
	monitoring = false
	if _shape != null:
		_shape.disabled = true
	set_physics_process(false)


## 追逐玩家，并按间隔发起短冲撞。
func _physics_process(delta: float) -> void:
	if not _active or _dead or _player == null:
		return
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	if _spawn_hold_left > 0.0:
		_spawn_hold_left = maxf(_spawn_hold_left - delta, 0.0)
		_trail.modulate.a = 0.9
		return
	var to_player := _player.global_position - global_position
	if to_player.length() <= 0.01:
		return
	var dir := to_player.normalized()
	_dash_timer -= delta
	var speed := chase_speed
	if _dash_timer <= 0.0:
		speed = dash_speed
		_dash_timer = dash_interval
	global_position += dir * speed * delta
	_body.rotation = dir.angle()
	_trail.modulate.a = 0.9 if speed >= dash_speed else 0.45


## 接收玩家攻击，HP 归零后把超载交出去。
func take_hit(damage: int) -> void:
	if _dead or not _active:
		return
	_hp = maxi(_hp - damage, 0)
	health_changed.emit(_hp, max_hp)
	_flash_hit()
	if _hp <= 0:
		_die()


## 命中闪烁提示玩家这也是可击败目标。
func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(_core, "color", Color(0.96, 0.98, 1.0, 1.0), 0.05)
	tween.tween_property(_core, "color", Color(0.55, 0.78, 1.0, 0.92), 0.16)


## 与玩家接触时扣能量并弹开。
func _on_body_entered(body: Node) -> void:
	if not _active or _dead or _contact_cooldown > 0.0:
		return
	if not body.is_in_group("player"):
		return
	_contact_cooldown = 0.55
	if body.has_method("drain_energy"):
		body.drain_energy(contact_energy_damage)
	if body.has_method("apply_knockback"):
		var body_2d := body as Node2D
		if body_2d != null:
			var dir: Vector2 = (body_2d.global_position - global_position).normalized()
			body.apply_knockback(dir * contact_knockback)


## 结束前辈 AI，淡出后发送 defeated。
func _die() -> void:
	_dead = true
	monitoring = false
	_shape.disabled = true
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(deactivate)
