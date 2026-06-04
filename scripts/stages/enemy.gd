extends Area2D
class_name CloseAIEnemy
## enemy.gd — "错误进程"（极简敌人）
##
## 设计要求：极简，不加血条以外的系统，只需巡逻 + 碰撞伤害。
## jam 友好实现：
##  - 在两点间水平巡逻
##  - 玩家用 attack 键且在攻击范围内 → 敌人被击败（emit defeated）
##  - 敌人碰到玩家 → 把玩家弹开（接触伤害的轻量替代，不做扣血死亡）
##
## 放置：加入编组 "enemy"。stage_2 / stage_3 监听 defeated 信号统计清场。

signal defeated()

## 巡逻速度与范围（像素）
@export var patrol_speed: float = 60.0
@export var patrol_range: float = 120.0
## 玩家攻击命中所需的最大距离
@export var attack_reach: float = 64.0
## 弹开玩家的力度
@export var knockback: float = 320.0

var _origin_x: float = 0.0
var _dir: float = 1.0
var _dead: bool = false


func _ready() -> void:
	add_to_group("enemy")
	_origin_x = global_position.x
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position.x += _dir * patrol_speed * delta
	if absf(global_position.x - _origin_x) >= patrol_range:
		_dir = -_dir
		global_position.x = clampf(global_position.x, _origin_x - patrol_range, _origin_x + patrol_range)
	_check_player_attack()


## 玩家在范围内并按下 attack → 被击败
func _check_player_attack() -> void:
	if not Input.is_action_just_pressed("attack"):
		return
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node2D and global_position.distance_to(p.global_position) <= attack_reach:
			_die()
			return


func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body is CharacterBody2D and body.is_in_group("player"):
		# 接触：把玩家弹开
		var push_dir := signf(body.global_position.x - global_position.x)
		if push_dir == 0.0:
			push_dir = 1.0
		body.velocity.x = push_dir * knockback
		body.velocity.y = -120.0


func _die() -> void:
	_dead = true
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
