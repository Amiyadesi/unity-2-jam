extends StageBase
## stage_2.gd — 第 2 关
##
## 极简战斗：清除场上障碍（编组 "enemy"），清完触发「关闭时刻」。
## 核心同第 1 关：走到尽头 → 关掉游戏 → 继续。旁白走 say()。

@export var enemies_to_clear: int = 0  # 0 = 自动统计场景内 enemy 数量

var _enemies_left: int = 0


func _on_stage_ready() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	_enemies_left = enemies.size() if enemies_to_clear <= 0 else enemies_to_clear
	for e in enemies:
		if e.has_signal("defeated") and not e.defeated.is_connected(_on_enemy_defeated):
			e.defeated.connect(_on_enemy_defeated)
	if _enemies_left > 0:
		say("清掉挡路的东西。", 3.0)


func _on_enemy_defeated() -> void:
	_enemies_left = maxi(_enemies_left - 1, 0)
	if _enemies_left > 0:
		say("还剩 %d 个。" % _enemies_left, 1.6, "top_right+0,12@200x56")
	else:
		say("清空了。……关掉游戏，继续。", 2.6)
		if _close_trigger == null:
			await get_tree().create_timer(2.8).timeout
			trigger_close_moment()

