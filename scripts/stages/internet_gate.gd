extends Area2D
class_name InternetGate
## internet_gate.gd — 第三关胜利后的互联网入口。
##
## authored Area2D：Boss 胜利后激活，玩家进入后由 Stage3 编排通关退出。

signal entered()

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _core: CanvasItem = $Core
@onready var _ring: Line2D = $Ring

var _active: bool = false


## 初始化碰撞回调并保持入口隐藏。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	deactivate()


## 激活入口并播放出现动效。
func activate() -> void:
	_active = true
	show()
	_set_collision_active(true)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)
	tween.parallel().tween_property(_core, "scale", Vector2.ONE, 0.6).from(Vector2(0.45, 0.45))


## 关闭入口，供场景初始和测试重置使用。
func deactivate() -> void:
	_active = false
	hide()
	_set_collision_active(false)


## 让入口线框缓慢旋转，形成可见目标。
func _process(delta: float) -> void:
	if _active and _ring != null:
		_ring.rotation += delta * 0.9


## 玩家进入入口后发信号给 Stage3。
func _on_body_entered(body: Node) -> void:
	if not _active or not body.is_in_group("player"):
		return
	_active = false
	_set_collision_active(false, true)
	entered.emit()


## 切换 authored 入口碰撞；玩家进入信号内关闭时必须 deferred。
func _set_collision_active(active: bool, deferred: bool = false) -> void:
	if deferred:
		set_deferred("monitoring", active)
		if _shape != null:
			_shape.set_deferred("disabled", not active)
		return
	monitoring = active
	if _shape != null:
		_shape.disabled = not active
