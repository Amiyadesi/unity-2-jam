extends Area2D
class_name CloseAIEnemy
## enemy.gd — "错误进程"（极简敌人）
##
## 设计要求：极简，不加血条以外的系统，只需巡逻 + 碰撞伤害。
## jam 友好实现：
##  - 在两点间水平巡逻
##  - 玩家攻击 hitbox 调用 take_hit() 后按 HP 判定击败（emit defeated）
##  - 敌人碰到玩家 → 把玩家弹开（接触伤害的轻量替代，不做扣血死亡）
##
## 放置：加入编组 "enemy"。stage_2 / stage_3 监听 defeated 信号统计清场。

signal defeated()

## 巡逻速度与范围（像素）
@export var patrol_speed: float = 60.0
@export var patrol_range: float = 120.0
## 弹开玩家的力度
@export var knockback: float = 320.0
## 被玩家 hitbox 命中的生命值。
@export var hp: int = 1
@export_enum("any", "forward", "side", "dash") var required_attack_kind: String = "any"
@export var min_hit_speed: float = 0.0
@export var reward_energy: float = 0.0
@export var starts_enabled: bool = true

var _origin_x: float = 0.0
var _dir: float = 1.0
var _dead: bool = false
var _enabled: bool = true


## 初始化敌人编组和巡逻原点。
func _ready() -> void:
	add_to_group("enemy")
	_origin_x = global_position.x
	body_entered.connect(_on_body_entered)
	set_enabled(starts_enabled)


## 执行水平巡逻；死亡后停止。
func _physics_process(delta: float) -> void:
	if _dead or not _enabled:
		return
	global_position.x += _dir * patrol_speed * delta
	if absf(global_position.x - _origin_x) >= patrol_range:
		_dir = -_dir
		global_position.x = clampf(global_position.x, _origin_x - patrol_range, _origin_x + patrol_range)


## 接收带类型的玩家命中，并报告 authored 规则是否接受本次命中。
func take_player_hit(damage: int, attack_kind: StringName, source: Node = null) -> bool:
	if _dead or not _enabled:
		return false
	if not _accepts_attack_kind(attack_kind):
		_flash_reject()
		return false
	if not _accepts_hit_speed(source):
		_flash_reject()
		return false
	hp -= damage
	if hp <= 0:
		_die(source)
	return true


## 接收旧伤害接口；只有 any 敌人保留旧行为并回报是否接受。
func take_hit(damage: int) -> bool:
	if required_attack_kind == "any":
		return take_player_hit(damage, &"any", null)
	return false


## 判断当前 authored 敌人是否接受本次攻击类型。
func _accepts_attack_kind(attack_kind: StringName) -> bool:
	return required_attack_kind == "any" or String(attack_kind) == required_attack_kind


## 判断当前 authored 敌人是否接受本次命中速度。
func _accepts_hit_speed(source: Node) -> bool:
	if min_hit_speed <= 0.0:
		return true
	if source == null or not ("velocity" in source):
		return false
	var source_velocity: Vector2 = source.velocity
	return source_velocity.length() >= min_hit_speed


## 接触玩家时施加轻量击退。
func _on_body_entered(body: Node) -> void:
	if _dead or not _enabled:
		return
	if body is CharacterBody2D and body.is_in_group("player"):
		# 接触：把玩家弹开
		var push_dir := signf(body.global_position.x - global_position.x)
		if push_dir == 0.0:
			push_dir = 1.0
		body.velocity.x = push_dir * knockback
		body.velocity.y = -120.0


## 播放错误命中反馈，告诉玩家普通打击不能解这个进程。
func _flash_reject() -> void:
	var visual := get_node_or_null("Glitch") as CanvasItem
	if visual == null:
		return
	visual.modulate = Color(1.0, 0.18, 0.24, 0.9)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color(1.0, 0.6, 0.55, 0.5), 0.14)


## 发出击败信号、奖励来源玩家能量并淡出销毁。
func _die(source: Node = null) -> void:
	_dead = true
	if source != null and reward_energy > 0.0 and source.has_method("restore_energy"):
		source.restore_energy(reward_energy)
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


## Enables authored enemies when their tutorial section begins.
func set_enabled(value: bool) -> void:
	_enabled = value and not _dead
	monitoring = _enabled
	visible = _enabled
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = not _enabled
