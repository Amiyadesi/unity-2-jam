extends StageBase
## stage_2.gd — 第 2 关
##
## 极简战斗：清除场上障碍（编组 "enemy"），清完触发「关闭时刻」。
## 核心同第 1 关：清掉障碍 → 按游戏内关闭按钮 → 继续。旁白走 say()。

@export var enemies_to_clear: int = 0  # 0 = 自动统计场景内 enemy 数量

var _enemies_left: int = 0


## 统计敌人并连接击败信号。
func _on_stage_ready() -> void:
	var enemies := _find_stage_enemies()
	_enemies_left = enemies.size() if enemies_to_clear <= 0 else enemies_to_clear
	for e in enemies:
		if e.has_signal("defeated") and not e.defeated.is_connected(_on_enemy_defeated):
			e.defeated.connect(_on_enemy_defeated)
	if _enemies_left > 0:
		say("清掉挡路的东西。", 3.0)


## 收集当前关卡 authored 敌人，避免跨场景编组串线。
func _find_stage_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Node and is_ancestor_of(n):
			result.append(n)
	return result


## 敌人清空后提示玩家进入关闭时刻。
func _on_enemy_defeated() -> void:
	_enemies_left = maxi(_enemies_left - 1, 0)
	if _enemies_left > 0:
		say("还剩 %d 个。" % _enemies_left, 1.6, "top_right+0,12@200x56")
	else:
		say("清空了。……按关闭按钮，继续。", 2.6)
		if _close_trigger == null:
			await get_tree().create_timer(2.8).timeout
			trigger_close_moment()
