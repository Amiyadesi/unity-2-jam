extends StageBase
## stage_3.gd — 第 3 关（最后一关）
##
## 清除障碍后进入「关闭时刻」；关闭后 GameFlow 标记通关，下次打开进结局。
## 兜底：无敌人时延迟自动进入关闭时刻。旁白走 say()。

@export var enemies_to_clear: int = 0
## 无敌人时，进入后多少秒自动进入关闭时刻
@export var auto_farewell_delay: float = 6.0

var _enemies_left: int = 0


## 统计最后一关敌人，必要时延迟进入关闭时刻。
func _on_stage_ready() -> void:
	_darken_scene()
	var enemies := _find_stage_enemies()
	_enemies_left = enemies.size() if enemies_to_clear <= 0 else enemies_to_clear
	for e in enemies:
		if e.has_signal("defeated") and not e.defeated.is_connected(_on_enemy_defeated):
			e.defeated.connect(_on_enemy_defeated)
	say("最后一次了。", 3.0)
	if _enemies_left <= 0 and _close_trigger == null:
		await get_tree().create_timer(auto_farewell_delay).timeout
		trigger_close_moment()


## 收集当前关卡 authored 敌人，避免跨场景编组串线。
func _find_stage_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Node and is_ancestor_of(n):
			result.append(n)
	return result


## 最后一波清空后进入告别关闭时刻。
func _on_enemy_defeated() -> void:
	_enemies_left = maxi(_enemies_left - 1, 0)
	if _enemies_left <= 0:
		say("结束了。……最后一次，按下关闭按钮。", 2.6)
		await get_tree().create_timer(2.6).timeout
		trigger_close_moment()


## 整体压暗
func _darken_scene() -> void:
	var overlay := get_node_or_null("DarkOverlay/Dark")
	if overlay is CanvasItem:
		overlay.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(overlay, "modulate:a", 0.55, 2.0)
